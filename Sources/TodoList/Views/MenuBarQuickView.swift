import SwiftUI

extension Notification.Name {
    static let focusMenuBarTodo = Notification.Name("focusMenuBarTodo")
}

/// 菜单栏里的快速捕获面板。它只保留最常用的路径：
/// 选分组 → 输入 → 回车，以及查看/完成当前分组的待办。
struct MenuBarQuickView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme

    let onOpenMainWindow: () -> Void
    let onQuit: () -> Void

    @State private var draftTitle = ""
    @State private var draftDueDate: Date?
    @State private var showingDueDate = false
    @FocusState private var isInputFocused: Bool

    private var pendingItems: [TodoItem] {
        viewModel.items
            .filter { $0.groupID == viewModel.selectedGroupID && !$0.isCompleted }
            .sorted {
                let left = $0.sortOrder ?? .greatestFiniteMagnitude
                let right = $1.sortOrder ?? .greatestFiniteMagnitude
                if left == right { return $0.createdAt < $1.createdAt }
                return left < right
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.45)

            quickInput
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            taskList

            Divider()
                .opacity(0.45)

            footer
        }
        .frame(width: 380, height: theme.menuBarPanelHeight)
        .background(.regularMaterial)
        .preferredColorScheme(theme.preferredColorScheme)
        .onAppear {
            focusInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusMenuBarTodo)) { _ in
            focusInput()
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
                .font(theme.font(20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppColors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("序事")
                        .font(theme.font(15, weight: .semibold))
                    Text("Slate")
                        .font(theme.font(9, weight: .semibold))
                        .foregroundStyle(AppColors.inactiveText)
                        .tracking(0.3)
                }
                Text("\(pendingItems.count) 项待完成")
                    .font(theme.font(11, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer(minLength: 8)

            Menu {
                ForEach(viewModel.groups) { group in
                    Button {
                        withAnimation(.snappy) {
                            viewModel.selectGroup(group.id)
                        }
                        focusInput()
                    } label: {
                        Label(group.name, systemImage: group.systemImage)
                        if group.id == viewModel.selectedGroupID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: selectedGroup?.systemImage ?? "folder")
                    Text(selectedGroup?.name ?? "待办")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(theme.font(8, weight: .bold))
                        .opacity(0.55)
                }
                .font(theme.font(11, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("切换分组")
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
    }

    private var quickInput: some View {
        HStack(spacing: 8) {
            TextField("添加任务…", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(theme.font(14, weight: .medium))
                .focused($isInputFocused)
                .onSubmit(submit)
                .accessibilityLabel("添加新任务")

            Button {
                showingDueDate = true
            } label: {
                Image(systemName: draftDueDate == nil ? "calendar" : "calendar.badge.exclamationmark")
                    .font(theme.font(12, weight: .semibold))
                    .foregroundStyle(draftDueDate == nil ? AppColors.secondaryText : AppColors.accent)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(draftDueDate == nil ? "设置到期日" : "修改到期日")
            .popover(isPresented: $showingDueDate, arrowEdge: .bottom) {
                CalendarPickerView(selectedDate: $draftDueDate) {
                    showingDueDate = false
                    focusInput()
                }
                .environmentObject(theme)
            }

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(theme.font(11, weight: .bold))
                    .foregroundStyle(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.secondaryText : .white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(
                            draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.primary.opacity(0.06)
                                : AppColors.accent
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("添加任务")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            isInputFocused ? AppColors.accent.opacity(0.72) : Color.primary.opacity(0.09),
                            lineWidth: isInputFocused ? 1.2 : 1
                        )
                }
        )
    }

    @ViewBuilder
    private var taskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pendingItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(theme.font(22, weight: .light))
                        .foregroundStyle(AppColors.accent.opacity(0.70))
                    Text("这个分组已经清空")
                        .font(theme.font(12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(pendingItems) { item in
                            MenuBarTaskRow(item: item, viewModel: viewModel)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label("⌥Space", systemImage: "keyboard")
                .font(theme.font(10, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)

            Spacer()

            Button(action: onOpenMainWindow) {
                Label("打开完整序事", systemImage: "macwindow")
                    .font(theme.font(11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.inactiveText)
            .help("打开任务管理窗口")

            Menu {
                Button("打开完整序事", action: onOpenMainWindow)
                Divider()
                Picker("面板高度", selection: $theme.menuBarPanelSizeRaw) {
                    ForEach(MenuBarPanelSize.allCases) { size in
                        Text(size.label).tag(size.rawValue)
                    }
                }
                Divider()
                Button("退出序事", action: onQuit)
            } label: {
                Image(systemName: "ellipsis")
                    .font(theme.font(12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("更多")
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var selectedGroup: TodoGroup? {
        viewModel.groups.first { $0.id == viewModel.selectedGroupID }
    }

    private func submit() {
        guard viewModel.addTodo(title: draftTitle, dueDate: draftDueDate) else { return }
        draftTitle = ""
        draftDueDate = nil
        focusInput()
    }

    private func focusInput() {
        DispatchQueue.main.async {
            isInputFocused = true
        }
    }
}

private struct MenuBarTaskRow: View {
    let item: TodoItem
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme

    @State private var isHovering = false
    @State private var isCompleting = false
    @State private var completionTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePendingCompletion()
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            isCompleting
                                ? AppColors.accent
                                : AppColors.secondaryText.opacity(isHovering ? 0.75 : 0.48),
                            lineWidth: 1.5
                        )
                        .frame(width: 19, height: 19)
                    if isCompleting {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 19, height: 19)
                        Image(systemName: "checkmark")
                            .font(theme.font(8, weight: .bold))
                            .foregroundStyle(.white)
                    } else if isHovering {
                        Image(systemName: "checkmark")
                            .font(theme.font(8, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(isCompleting ? "撤销完成" : "标记为已完成")
            .accessibilityLabel(isCompleting ? "撤销完成\(item.title)" : "完成\(item.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(theme.font(13, weight: .medium))
                    .lineLimit(1)
                    .strikethrough(isCompleting, color: AppColors.secondaryText)
                    .opacity(isCompleting ? 0.48 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let dueLabel = viewModel.dueLabel(item) {
                    Text(dueLabel)
                        .font(theme.font(10, weight: .medium))
                        .foregroundStyle(viewModel.isOverdue(item) ? Color.orange : AppColors.secondaryText)
                        .opacity(isCompleting ? 0.45 : 1)
                }
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 43)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isHovering && !isCompleting ? Color.primary.opacity(0.055) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.quick) {
                isHovering = hovering
            }
        }
    }

    private func togglePendingCompletion() {
        if isCompleting {
            completionTask?.cancel()
            completionTask = nil
            withAnimation(.quick) {
                isCompleting = false
            }
            return
        }

        withAnimation(.quick) {
            isCompleting = true
        }
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) {
                viewModel.setCompletion(true, for: item.id)
            }
            completionTask = nil
        }
    }
}
