import SwiftUI

struct BulkActionBar: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            Label("\(viewModel.selectedCount) 项已选择", systemImage: "checkmark.circle")
                .font(theme.font(12, weight: .semibold))
                .foregroundStyle(AppColors.inactiveText)

            Spacer()

            actionButton("全部完成", systemName: "checkmark") {
                withAnimation(.quick) {
                    viewModel.setSelectedCompleted(true)
                }
            }
            .disabled(!viewModel.hasEditableSelection)

            actionButton("设为待完成", systemName: "arrow.uturn.backward") {
                withAnimation(.quick) {
                    viewModel.setSelectedCompleted(false)
                }
            }
            .disabled(!viewModel.hasEditableSelection)

            actionButton("删除", systemName: "trash", isDestructive: true) {
                showDeleteConfirmation = true
            }
            .disabled(!viewModel.hasEditableSelection)

            Button {
                viewModel.clearSelection()
            } label: {
                Image(systemName: "xmark")
                    .font(theme.font(11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.secondaryText)
            .help("取消选择")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .confirmationDialog(
            "删除选中的 \(viewModel.selectedCount) 个任务？",
            isPresented: $showDeleteConfirmation
        ) {
            Button("删除任务", role: .destructive) {
                withAnimation(.quick) {
                    viewModel.deleteSelected()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销。")
        }
    }

    private func actionButton(
        _ title: String,
        systemName: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(theme.font(11, weight: .semibold))
                .padding(.horizontal, 9)
                .frame(height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDestructive ? Color.red.opacity(0.9) : AppColors.inactiveText)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        }
        .help(title)
    }
}