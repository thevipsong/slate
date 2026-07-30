import SwiftUI

private enum SlatePreferencesMigration {
    private static let legacyBundleIdentifier = "app.local.Slate"
    private static let migrationKey = "migration.legacyBundlePreferences.v1"

    static func runIfNeeded(defaults: UserDefaults = .standard) {
        guard Bundle.main.bundleIdentifier != legacyBundleIdentifier,
              !defaults.bool(forKey: migrationKey) else {
            return
        }

        if let legacyValues = defaults.persistentDomain(
            forName: legacyBundleIdentifier
        ) {
            for (key, value) in legacyValues where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: migrationKey)
    }
}

@main
struct TodoListApp: App {
    @NSApplicationDelegateAdaptor(SlateApplicationDelegate.self) private var appDelegate
    @StateObject private var viewModel: TodoViewModel
    @StateObject private var theme: AppTheme
    @StateObject private var weatherService: WeatherService
    @StateObject private var reminderService: TodoReminderService
    @StateObject private var menuBarController: SlateMenuBarController

    init() {
        SlatePreferencesMigration.runIfNeeded()

        let reminders = TodoReminderService()
        let viewModel = TodoViewModel(reminderScheduler: reminders)
        let theme = AppTheme()
        let weatherService = WeatherService()

        _reminderService = StateObject(wrappedValue: reminders)
        _viewModel = StateObject(wrappedValue: viewModel)
        _theme = StateObject(wrappedValue: theme)
        _weatherService = StateObject(wrappedValue: weatherService)
        let menuBarController = SlateMenuBarController(
            viewModel: viewModel,
            theme: theme,
            weatherService: weatherService,
            reminderService: reminders
        )
        _menuBarController = StateObject(wrappedValue: menuBarController)
        appDelegate.configure(menuBarController: menuBarController)
    }

    var body: some Scene {
        Settings {
            // 序事的设置与完整管理入口都位于菜单栏面板和主窗口中。
            // 保留一个空 Settings scene 作为纯菜单栏应用的 SwiftUI 生命周期根。
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("退出序事") {
                    menuBarController.terminate()
                }
                .keyboardShortcut("q")
            }
        }
    }
}
