import SwiftUI

extension Notification.Name {
    static let focusMenuBarTodo = Notification.Name("focusMenuBarTodo")
}

/// 菜单栏里的快速捕获面板。它只保留最常用的路径：
/// 选分组 → 输入 → 回车，以及查看/完成当前分组的待办。
struct MenuBarQuickView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(theme.font(18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppColors.accent)
                .frame(width: 22, height: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
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
                        withAnimation(reduceMotion ? nil : .snappy) {
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
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .frame(height: 58)
    }

    private var quickInput: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("添加任务…", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(theme.font(14, weight: .medium))
                .padding(.leading, 4)
                .focused($isInputFocused)
                .onSubmit(submit)
                .accessibilityLabel("添加新任务")

            Button {
                showingDueDate = true
            } label: {
                Image(systemName: draftDueDate == nil ? "calendar" : "calendar.badge.exclamationmark")
                    .font(theme.font(12, weight: .semibold))
                    .foregroundStyle(draftDueDate == nil ? AppColors.secondaryText : AppColors.accent)
                    .frame(width: 30, height: 30, alignment: .center)
                    .offset(y: 0.5)
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
                    .frame(width: 30, height: 30, alignment: .center)
                    .offset(y: 0.5)
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
        .frame(height: 44)
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
                    LazyVStack(spacing: 6) {
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
                .foregroundStyle(Color.primary.opacity(0.62))

            Spacer()

            Button(action: onOpenMainWindow) {
                Label("打开完整序事", systemImage: "macwindow")
                    .font(theme.font(11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primary.opacity(0.72))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var isHovering = false
    @State private var isCompleting = false
    @State private var showingDueDate = false
    @State private var dueDateDraft: Date?
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

            quickActions
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .quick) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingDueDate, arrowEdge: .bottom) {
            CalendarPickerView(
                selectedDate: $dueDateDraft,
                onSelection: { date in
                    viewModel.setDueDate(date, for: item.id)
                }
            ) {
                showingDueDate = false
            }
            .environmentObject(theme)
        }
        .contextMenu {
            Button(item.dueDate == nil ? "设置到期日" : "修改到期日") {
                openDueDateEditor()
            }
            if item.dueDate != nil {
                Button("清除到期日") {
                    viewModel.setDueDate(nil, for: item.id)
                }
            }
            Divider()
            Button("删除", role: .destructive) {
                deleteItem()
            }
        }
    }

    private var rowBackground: Color {
        guard isHovering, !isCompleting else { return .clear }
        return colorScheme == .dark
            ? AppColors.accent.opacity(0.055)
            : Color.black.opacity(0.04)
    }

    private var quickActions: some View {
        HStack(spacing: 2) {
            MenuBarRowActionButton(
                systemName: item.dueDate == nil
                    ? "calendar"
                    : "calendar.badge.exclamationmark",
                label: item.dueDate == nil ? "设置到期日" : "修改到期日"
            ) {
                openDueDateEditor()
            }

            MenuBarRowActionMenu {
                Button(item.dueDate == nil ? "设置到期日" : "修改到期日") {
                    openDueDateEditor()
                }
                if item.dueDate != nil {
                    Button("清除到期日") {
                        viewModel.setDueDate(nil, for: item.id)
                    }
                }
                Divider()
                Button("删除", role: .destructive) {
                    deleteItem()
                }
            }
        }
        .frame(width: 58, alignment: .trailing)
        .opacity(isHovering && !isCompleting ? 1 : 0)
        .allowsHitTesting(isHovering && !isCompleting)
        .accessibilityHidden(!isHovering || isCompleting)
        .animation(reduceMotion ? nil : .quick, value: isHovering)
    }

    private func togglePendingCompletion() {
        if isCompleting {
            completionTask?.cancel()
            completionTask = nil
            withAnimation(reduceMotion ? nil : .quick) {
                isCompleting = false
            }
            return
        }

        withAnimation(reduceMotion ? nil : .quick) {
            isCompleting = true
        }
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .snappy) {
                viewModel.setCompletion(true, for: item.id)
            }
            completionTask = nil
        }
    }

    private func openDueDateEditor() {
        dueDateDraft = viewModel.items.first(where: { $0.id == item.id })?.dueDate
        showingDueDate = true
    }

    private func deleteItem() {
        withAnimation(reduceMotion ? nil : .quick) {
            viewModel.delete(item)
        }
    }
}

private struct MenuBarRowActionButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 27, height: 27, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(0.64))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .quick) {
                isHovering = hovering
            }
        }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct MenuBarRowActionMenu<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 27, height: 27, alignment: .center)
                .contentShape(Rectangle())
                .foregroundStyle(Color.primary.opacity(0.64))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.07) : Color.clear)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .quick) {
                isHovering = hovering
            }
        }
        .help("更多操作")
        .accessibilityLabel("更多操作")
    }
}
