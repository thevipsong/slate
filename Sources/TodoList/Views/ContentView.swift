import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @EnvironmentObject var reminderService: TodoReminderService
    @State private var isImportingArchive = false
    @State private var isExportingArchive = false
    @State private var exportDocument = SlateArchiveDocument()
    @State private var pendingImportData: Data?
    @State private var isConfirmingImport = false
    @State private var isConfiguringSync = false

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
        .onReceive(NotificationCenter.default.publisher(for: .importSlateArchive)) { _ in
            isImportingArchive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportSlateArchive)) { _ in
            do {
                exportDocument = SlateArchiveDocument(data: try viewModel.exportArchiveData())
                isExportingArchive = true
            } catch {
                viewModel.setError("导出待办数据失败：\(error.localizedDescription)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .configureSlateSync)) { _ in
            isConfiguringSync = true
        }
        .sheet(isPresented: $isConfiguringSync) {
            SyncSetupView(viewModel: viewModel)
        }
        .fileImporter(
            isPresented: $isImportingArchive,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                pendingImportData = try Data(contentsOf: url)
                isConfirmingImport = true
            } catch {
                viewModel.setError("读取导入文件失败：\(error.localizedDescription)")
            }
        }
        .fileExporter(
            isPresented: $isExportingArchive,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "slate-backup"
        ) { result in
            if case .failure(let error) = result {
                viewModel.setError("导出待办数据失败：\(error.localizedDescription)")
            }
        }
        .alert("替换当前全部待办？", isPresented: $isConfirmingImport) {
            Button("取消", role: .cancel) {
                pendingImportData = nil
            }
            Button("替换", role: .destructive) {
                guard let data = pendingImportData else { return }
                do {
                    try viewModel.importArchiveData(data)
                    pendingImportData = nil
                } catch {
                    pendingImportData = nil
                    viewModel.setError("导入待办数据失败：\(error.localizedDescription)")
                }
            }
        } message: {
            Text("导入会替换当前任务与分组；完成后仍可使用撤销恢复。")
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
