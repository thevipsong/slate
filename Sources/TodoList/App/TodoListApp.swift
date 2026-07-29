import SwiftUI

@main
struct TodoListApp: App {
    @StateObject private var viewModel: TodoViewModel
    @StateObject private var theme = AppTheme()
    @StateObject private var weatherService = WeatherService()
    @StateObject private var reminderService: TodoReminderService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let reminders = TodoReminderService()
        _reminderService = StateObject(wrappedValue: reminders)
        _viewModel = StateObject(
            wrappedValue: TodoViewModel(reminderScheduler: reminders)
        )
    }

    var body: some Scene {
        Window("Slate", id: "main") {
            ContentView(viewModel: viewModel)
                .environmentObject(theme)
                .environmentObject(weatherService)
                .environmentObject(reminderService)
                .frame(minWidth: 760, idealWidth: 1040, minHeight: 640, idealHeight: 780)
                .background(AmbientBackground())
                .containerBackground(.regularMaterial, for: .window)
                .preferredColorScheme(theme.preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加新任务") {
                    NotificationCenter.default.post(name: .focusNewTodo, object: nil)
                }
                .keyboardShortcut("n")
            }
            CommandGroup(after: .undoRedo) {
                Button("搜索任务") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("撤销") {
                    viewModel.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.canUndo)
            }
            CommandMenu("任务") {
                Button("编辑选中任务") {
                    viewModel.beginEditingSelectedItem()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(viewModel.selectedCount != 1)

                Button("切换完成状态") {
                    if let first = viewModel.visibleItems.first(where: { viewModel.selectedItemIDs.contains($0.id) }) {
                        viewModel.toggleCompletion(of: first)
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(viewModel.selectedCount != 1)

                Button("删除选中任务") {
                    viewModel.deleteSelected()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(viewModel.selectedCount == 0)

                Divider()

                Button("取消选择") {
                    viewModel.clearSelection()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!viewModel.hasEditableSelection)
            }
            CommandMenu("视图") {
                Button("全部") {
                    viewModel.clearSelection()
                    viewModel.setFilter(.all)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("待完成") {
                    viewModel.clearSelection()
                    viewModel.setFilter(.pending)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("已完成") {
                    viewModel.clearSelection()
                    viewModel.setFilter(.completed)
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("上一个分组") {
                    cycleGroup(-1)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("下一个分组") {
                    cycleGroup(1)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                viewModel.stopAutomaticSync()
                viewModel.persistImmediately()
            } else if phase == .active {
                viewModel.startAutomaticSync()
                viewModel.syncIfConfigured()
            }
        }
    }

    private func cycleGroup(_ delta: Int) {
        guard let currentIdx = viewModel.groups.firstIndex(where: { $0.id == viewModel.selectedGroupID }),
              !viewModel.groups.isEmpty else { return }
        let nextIdx = (currentIdx + delta + viewModel.groups.count) % viewModel.groups.count
        viewModel.selectGroup(viewModel.groups[nextIdx].id)
    }
}
