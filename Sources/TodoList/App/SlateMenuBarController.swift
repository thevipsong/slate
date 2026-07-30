@preconcurrency import AppKit
@preconcurrency import Carbon.HIToolbox
import Combine
import SwiftUI

/// 用 Carbon 注册不需要辅助功能权限的系统级快捷键。
/// 默认使用 Option + Space，避免与微信截图等常用快捷键冲突。
private final class GlobalHotKeyController: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    private static let signature: OSType = 0x534C4154 // "SLAT"
    private static let identifier: UInt32 = 1

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        register()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                MainActor.assumeIsolated {
                    controller.action()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registrationStatus != noErr {
            NSLog("序事无法注册 ⌥Space（OSStatus %d）", registrationStatus)
        }
    }
}

/// 序事的原生菜单栏生命周期。
///
/// 使用 NSStatusItem + NSPopover 而不是只能由鼠标点击展示的 MenuBarExtra，
/// 这样状态栏点击和 ⌥Space 可以可靠地打开同一个 SwiftUI 面板。
@MainActor
final class SlateMenuBarController: NSObject, ObservableObject, NSPopoverDelegate {
    private let viewModel: TodoViewModel
    private let theme: AppTheme
    private let weatherService: WeatherService
    private let reminderService: TodoReminderService

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private lazy var mainWindowController = SlateMainWindowController(
        viewModel: viewModel,
        theme: theme,
        weatherService: weatherService,
        reminderService: reminderService
    )
    private var hotKeyController: GlobalHotKeyController?
    private var viewModelCancellable: AnyCancellable?
    private var themeCancellable: AnyCancellable?
    private var notificationObservers: [NSObjectProtocol] = []
    private var globalMouseMonitor: Any?
    private var isInstalled = false

    init(
        viewModel: TodoViewModel,
        theme: AppTheme,
        weatherService: WeatherService,
        reminderService: TodoReminderService
    ) {
        self.viewModel = viewModel
        self.theme = theme
        self.weatherService = weatherService
        self.reminderService = reminderService
        super.init()
    }

    func terminate() {
        viewModel.persistImmediately()
        NSApp.terminate(nil)
    }

    func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        // 纯菜单栏应用：不占用 Dock，也不参与 Cmd+Tab 应用切换。
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        configurePopover()
        configureObservers()
        configureGlobalMouseMonitor()

        hotKeyController = GlobalHotKeyController { [weak self] in
            self?.togglePopover()
        }

        viewModel.startAutomaticSync()
        viewModel.syncIfConfigured()
        updateStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(
            systemSymbolName: "checkmark.circle",
            accessibilityDescription: "序事"
        )
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(togglePopoverFromStatusItem)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        let rootView = MenuBarQuickView(
            viewModel: viewModel,
            onOpenMainWindow: { [weak self] in
                self?.closePopover()
                self?.mainWindowController.show()
            },
            onQuit: { [weak self] in
                self?.terminate()
            }
        )
        .environmentObject(theme)
        .environmentObject(weatherService)
        .environmentObject(reminderService)

        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.contentSize = NSSize(width: 380, height: theme.menuBarPanelHeight)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func configureObservers() {
        viewModelCancellable = viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        themeCancellable = theme.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.popover.contentSize = NSSize(
                    width: 380,
                    height: self.theme.menuBarPanelHeight
                )
            }
        }

        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.viewModel.persistImmediately()
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.viewModel.startAutomaticSync()
                    self?.viewModel.syncIfConfigured()
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.closePopover()
                }
            }
        )
    }

    /// `NSPopover.behavior = .transient` 偶尔会在应用焦点快速切换时漏掉收起事件。
    /// 全局鼠标监听作为兜底，只接收发生在其他应用中的点击，不影响面板内部交互。
    private func configureGlobalMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.popover.isShown == true else { return }
                self?.closePopover()
            }
        }
    }

    @objc
    private func togglePopoverFromStatusItem() {
        togglePopover()
    }

    private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            NotificationCenter.default.post(name: .focusMenuBarTodo, object: nil)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func updateStatusItem() {
        let pendingCount = viewModel.totalPendingCount
        statusItem?.button?.title = pendingCount > 0 ? "\(pendingCount)" : ""
        statusItem?.button?.toolTip = pendingCount > 0
            ? "序事 · \(pendingCount) 项待办 · ⌥Space"
            : "序事 · 已清空 · ⌥Space"
    }
}

/// SwiftUI 没有普通窗口时，StateObject 的场景存储可能不会立即挂载。
/// AppDelegate 为菜单栏控制器提供与进程等长的强引用，并在应用启动完成后安装状态项。
@MainActor
final class SlateApplicationDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: SlateMenuBarController?

    func configure(menuBarController: SlateMenuBarController) {
        self.menuBarController = menuBarController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController?.installIfNeeded()
    }
}

/// 按需创建的完整管理窗口。窗口关闭后应用仍常驻菜单栏。
@MainActor
private final class SlateMainWindowController: NSObject, NSWindowDelegate {
    private let viewModel: TodoViewModel
    private let theme: AppTheme
    private let weatherService: WeatherService
    private let reminderService: TodoReminderService

    private var window: NSWindow?
    private var keyMonitor: Any?

    init(
        viewModel: TodoViewModel,
        theme: AppTheme,
        weatherService: WeatherService,
        reminderService: TodoReminderService
    ) {
        self.viewModel = viewModel
        self.theme = theme
        self.weatherService = weatherService
        self.reminderService = reminderService
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        installKeyMonitorIfNeeded()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .focusNewTodo, object: nil)
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.persistImmediately()
    }

    private func makeWindow() -> NSWindow {
        let rootView = ContentView(viewModel: viewModel)
            .environmentObject(theme)
            .environmentObject(weatherService)
            .environmentObject(reminderService)
            .frame(minWidth: 760, idealWidth: 1040, minHeight: 640, idealHeight: 780)
            .background(AmbientBackground())
            .preferredColorScheme(theme.preferredColorScheme)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "序事"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 760, height: 640)
        window.collectionBehavior = [.moveToActiveSpace]
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: rootView)
        window.setFrameAutosaveName("SlateMainWindow")
        window.center()
        window.delegate = self
        return window
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard NSApp.keyWindow === window else { return event }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers?.lowercased()
        let isEditingText = window?.firstResponder is NSTextView

        if flags == .command {
            switch characters {
            case "n":
                NotificationCenter.default.post(name: .focusNewTodo, object: nil)
                return nil
            case "f":
                NotificationCenter.default.post(name: .focusSearch, object: nil)
                return nil
            case "z":
                viewModel.undo()
                return nil
            case "1":
                viewModel.clearSelection()
                viewModel.setFilter(.all)
                return nil
            case "2":
                viewModel.clearSelection()
                viewModel.setFilter(.pending)
                return nil
            case "3":
                viewModel.clearSelection()
                viewModel.setFilter(.completed)
                return nil
            case "[":
                cycleGroup(-1)
                return nil
            case "]":
                cycleGroup(1)
                return nil
            case "w":
                window?.close()
                return nil
            case "q":
                viewModel.persistImmediately()
                NSApp.terminate(nil)
                return nil
            default:
                break
            }
        }

        if flags == [.command, .shift],
           event.keyCode == UInt16(kVK_Return),
           viewModel.selectedCount == 1,
           let selectedID = viewModel.selectedItemIDs.first,
           let item = viewModel.items.first(where: { $0.id == selectedID }) {
            viewModel.toggleCompletion(of: item)
            return nil
        }

        if flags == .command,
           event.keyCode == UInt16(kVK_Delete),
           !isEditingText,
           viewModel.selectedCount > 0 {
            viewModel.deleteSelected()
            return nil
        }

        if flags.isEmpty,
           event.keyCode == UInt16(kVK_Escape),
           !isEditingText,
           viewModel.hasEditableSelection {
            viewModel.clearSelection()
            return nil
        }

        return event
    }

    private func cycleGroup(_ delta: Int) {
        guard let currentIndex = viewModel.groups.firstIndex(where: { $0.id == viewModel.selectedGroupID }),
              !viewModel.groups.isEmpty else {
            return
        }
        let nextIndex = (currentIndex + delta + viewModel.groups.count) % viewModel.groups.count
        viewModel.selectGroup(viewModel.groups[nextIndex].id)
    }
}
