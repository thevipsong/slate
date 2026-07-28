import SwiftUI

extension Notification.Name {
    static let focusNewTodo = Notification.Name("focusNewTodo")
    static let focusSearch = Notification.Name("focusSearch")
}

struct TodoInputView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @FocusState private var isInputFocused: Bool
    @State private var showDuePopover = false

    var body: some View {
        HStack(spacing: 10) {
            TextField(
                "",
                text: $viewModel.newTitle,
                prompt: Text("添加新任务…")
                    .foregroundStyle(AppColors.placeholderText)
            )
            .textFieldStyle(.plain)
            .font(theme.font(15))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isInputFocused ? AppColors.accent.opacity(0.9) : Color.white.opacity(0.08),
                                lineWidth: isInputFocused ? 1.4 : 1
                            )
                    }
            )
            .focused($isInputFocused)
            .onSubmit(add)

            dueButton

            Button(action: add) {
                HStack(spacing: 5) {
                    Text("添加")
                    Text("⌘↩")
                        .font(theme.font(10, weight: .medium))
                        .opacity(0.64)
                }
            }
            .buttonStyle(LiquidAddButtonStyle())
            .disabled(!viewModel.canAdd)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNewTodo)) { _ in
            isInputFocused = true
        }
    }

    private var dueButton: some View {
        Button {
            showDuePopover = true
        } label: {
            Image(systemName: viewModel.newDueDate == nil ? "calendar" : "calendar.badge.exclamationmark")
                .font(theme.font(13, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(viewModel.newDueDate == nil ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(AppColors.accent.opacity(0.18)))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    viewModel.newDueDate == nil ? Color.white.opacity(0.08) : AppColors.accent.opacity(0.6),
                                    lineWidth: 1
                                )
                        }
                )
                .foregroundStyle(viewModel.newDueDate == nil ? AppColors.secondaryText : AppColors.accent)
        }
        .buttonStyle(.plain)
        .help(viewModel.newDueDate == nil ? "设置到期日" : "已设到期日，点击修改")
        .popover(isPresented: $showDuePopover, arrowEdge: .bottom) {
            CalendarPickerView(selectedDate: $viewModel.newDueDate) {
                showDuePopover = false
            }
            .environmentObject(theme)
        }
    }

    private func add() {
        guard viewModel.canAdd else { return }
        withAnimation(.quick) {
            viewModel.addTodo()
        }
        isInputFocused = true
    }
}

private struct LiquidAddButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @EnvironmentObject var theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.font(13, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : AppColors.secondaryText)
            .frame(width: 84, height: 42)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEnabled
                          ? AnyShapeStyle(AppColors.accent.opacity(configuration.isPressed ? 0.95 : 0.85))
                          : AnyShapeStyle(.ultraThinMaterial))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isEnabled ? Color.white.opacity(0.16) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.quick, value: configuration.isPressed)
    }
}