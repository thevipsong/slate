import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var reminderService: TodoReminderService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderView(viewModel: viewModel)
                .padding(.bottom, 10)  // Header→分组区 28pt，层次舒展

            GroupBar(viewModel: viewModel)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 16) {
                TodoInputView(viewModel: viewModel)
                FilterChipsView(viewModel: viewModel)

                if viewModel.selectedCount > 1 {
                    BulkActionBar(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                TodoListView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 36)
        .padding(.top, 26)
        .padding(.bottom, 26)
        .frame(maxWidth: 1600, maxHeight: .infinity, alignment: .topLeading)
        .background(TaskEditingKeyMonitor(viewModel: viewModel))
        .animation(.quick, value: viewModel.selectedCount)
        .animation(.quick, value: viewModel.selectedGroupID)
        // Cmd+Q / 退出前强制落盘：scenePhase 在 macOS Quit 路径上的时机不够可靠，
        // willTerminate 是最后一道保险，防止防抖窗口内的修改丢失
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.persistImmediately()
        }
        .alert(
            "出现问题",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(
            "提醒设置",
            isPresented: Binding(
                get: { reminderService.statusMessage != nil },
                set: { if !$0 { reminderService.clearStatusMessage() } }
            )
        ) {
            Button("好", role: .cancel) {
                reminderService.clearStatusMessage()
            }
        } message: {
            Text(reminderService.statusMessage ?? "")
        }
    }
}
