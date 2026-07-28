import SwiftUI

struct TodoRowView: View {
    let item: TodoItem
    /// 行必须直接观察选择状态。若这里只保留普通引用，LazyVStack 会复用旧行，
    /// 取消选中的行可能不会重绘，视觉上就会残留多个蓝色背景。
    @ObservedObject var viewModel: TodoViewModel

    @EnvironmentObject var theme: AppTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isDropTarget = false
    @State private var showingDuePopover = false
    @State private var dueDateDraft: Date?
    @State private var rowWidth: CGFloat = 0
    @FocusState private var isEditingFocused: Bool

    private var isSelected: Bool {
        viewModel.selectedItemIDs.contains(item.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            statusButton

            titleArea

            if let dueText = viewModel.dueLabel(item) {
                dueChip(text: dueText, overdue: viewModel.isOverdue(item))
            }

            if item.isCompleted {
                if let completedAt = item.completedAt {
                    Text(completedAt, format: .dateTime.month().day().hour().minute())
                        .font(theme.font(11))
                        .foregroundStyle(AppColors.secondaryText.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.primary.opacity(0.05))
                        )
                }
            }

            if isHovering {
                HStack(spacing: 4) {
                    RowActionButton(
                        systemName: item.dueDate == nil ? "calendar" : "calendar.badge.exclamationmark",
                        label: item.dueDate == nil ? "设置到期日" : "修改到期日"
                    ) {
                        selectExclusively()
                        openDueEditor()
                    }
                    RowActionButton(systemName: "pencil", label: "编辑") {
                        selectExclusively()
                        viewModel.beginEditing(item)
                    }
                    RowActionButton(systemName: "xmark", label: "删除", isDestructive: true) {
                        withAnimation(.quick) {
                            viewModel.delete(item)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        // 捕获行实际宽度，让拖拽预览跟源行同宽
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { rowWidth = $0 }
        .background(rowBackground)
        .overlay(rowBorder)
        .contentShape(Rectangle())
        .draggable(item.id.uuidString) {
            dragPreview
        }
        .dropDestination(for: String.self) { droppedIDs, _ in
            guard let value = droppedIDs.first,
                  let sourceID = UUID(uuidString: value),
                  sourceID != item.id,
                  let source = viewModel.items.first(where: { $0.id == sourceID }),
                  let sourceGroupID = source.groupID,
                  sourceGroupID == item.groupID else {
                // 跨组拖动：静默拒绝，系统显示禁止光标；引导交给右键菜单，不弹模态
                return false
            }
            withAnimation(.snappy) {
                viewModel.moveItem(withID: sourceID, before: item.id)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.quick) {
                isDropTarget = targeted
            }
        }
        .onHover { hovering in
            withAnimation(.quick) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingDuePopover, arrowEdge: .bottom) {
            CalendarPickerView(
                selectedDate: $dueDateDraft,
                onSelection: { date in
                    viewModel.setDueDate(date, for: item.id)
                }
            ) {
                showingDuePopover = false
            }
            .environmentObject(theme)
        }
        .contextMenu {
            Button("编辑") { viewModel.beginEditing(item) }
            Button(item.dueDate == nil ? "设置到期日" : "修改到期日") {
                openDueEditor()
            }
            if item.dueDate != nil {
                Button("清除到期日") {
                    viewModel.setDueDate(nil, for: item.id)
                }
            }
            Button(item.isCompleted ? "标记为待完成" : "标记为已完成") {
                withAnimation(.quick) {
                    viewModel.toggleCompletion(of: item)
                }
            }

            Menu("移动到分组") {
                ForEach(viewModel.groups) { group in
                    Button {
                        viewModel.moveItem(withID: item.id, toGroupID: group.id)
                    } label: {
                        Label(group.name, systemImage: group.systemImage)
                        if group.id == item.groupID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()
            Button("删除", role: .destructive) { viewModel.delete(item) }
        }
    }

    @ViewBuilder
    private var titleArea: some View {
        if viewModel.editingItemID == item.id {
            TextField("任务内容", text: Binding(
                get: { viewModel.editingTitle },
                set: { viewModel.editingTitle = $0 }
            ))
                .textFieldStyle(.plain)
                .font(theme.font(15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($isEditingFocused)
                .onSubmit {
                    viewModel.commitEditing()
                    // Enter 提交 = 键盘流延续，焦点回"添加新任务"框
                    NotificationCenter.default.post(name: .focusNewTodo, object: nil)
                }
                .onExitCommand { viewModel.cancelEditing() }
                .onAppear { isEditingFocused = true }
                .onChange(of: isEditingFocused) { _, isFocused in
                    // 失焦且编辑状态仍生效时，自动提交（点击其他位置 / 切换窗口 / 切组 等都会触发）
                    if !isFocused && viewModel.editingItemID == item.id {
                        viewModel.commitEditing()
                    }
                }
        } else {
            HStack(spacing: 0) {
                Text(item.title)
                    .font(theme.font(15, weight: item.isCompleted ? .regular : .medium))
                    .foregroundStyle(item.isCompleted ? AppColors.completedText : Color.primary)
                    .opacity(item.isCompleted ? 0.66 : 1)
                    .strikethrough(item.isCompleted, color: AppColors.secondaryText)
                    .lineLimit(2)
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
            // 单击与双击并行识别：单击在 mouse-up 后立即选中，不再等待
            // 系统的双击判定超时；双击的第二次点击再进入编辑。
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        handleSingleTap()
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        // 等本轮单击回调全部结束后再创建并聚焦编辑框，
                        // 避免单击清焦点与双击聚焦发生竞争。
                        DispatchQueue.main.async {
                            viewModel.beginEditing(item)
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        let fill: Color = isSelected
            ? AppColors.accent.opacity(0.18)
            : (isHovering
                ? (colorScheme == .light ? Color.black.opacity(0.045) : Color.primary.opacity(0.06))
                : Color.clear)

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }

    @ViewBuilder
    private var rowBorder: some View {
        let strokeColor: Color = isSelected
            ? AppColors.accent.opacity(0.65)
            : (isDropTarget
                ? AppColors.accent.opacity(0.55)
                : (isHovering
                    ? Color.white.opacity(0.12)
                    : Color.white.opacity(0.08)))

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(strokeColor, lineWidth: 1)
    }

    private var statusButton: some View {
        Button {
            selectExclusively()
            withAnimation(.quick) {
                viewModel.toggleCompletion(of: item)
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 1.7)
                    .frame(width: 22, height: 22)

                if item.isCompleted {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(theme.font(10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(statusHelp)
        .accessibilityLabel(statusHelp)
    }

    private var statusColor: Color {
        item.isCompleted ? AppColors.accent : AppColors.secondaryText.opacity(0.6)
    }

    /// 到期日胶囊：逾期显示橙色，其余用次要文字色
    private func dueChip(text: String, overdue: Bool) -> some View {
        Button {
            selectExclusively()
            openDueEditor()
        } label: {
            Text(text)
                .font(theme.font(11, weight: .medium))
                .foregroundStyle(overdue ? Color.orange : AppColors.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(overdue ? Color.orange.opacity(0.14) : Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .help("修改到期日")
        .accessibilityLabel("到期日\(text)，点击修改")
    }

    private var statusHelp: String {
        item.isCompleted ? "取消完成" : "标记为已完成"
    }

    private func openDueEditor() {
        // 从 ViewModel 读取最新值，不依赖 ForEach 传入的行快照。
        dueDateDraft = viewModel.items.first(where: { $0.id == item.id })?.dueDate
        showingDuePopover = true
    }

    private func handleSingleTap() {
        // 双击进入编辑后，第二个单击回调不应再清除 TextField 焦点。
        guard viewModel.editingItemID != item.id else { return }
        selectExclusively()
    }

    /// 普通行交互始终是严格单选。不要在手势完成后读取
    /// NSEvent.modifierFlags：合成快捷键或系统事件可能让全局修饰键状态短暂残留，
    /// 从而把普通点击误判成 Cmd/Shift 多选。
    private func selectExclusively() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        viewModel.select(item, mode: .single)
    }

    /// 拖拽预览：完整重建一行的视觉，跟源行同宽，
    /// 让用户拖起来看到的是"整条待办跟着光标走"，而不是一个小胶囊。
    private var dragPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(theme.font(9, weight: .bold))
                .foregroundStyle(AppColors.secondaryText.opacity(0.55))
                .frame(width: 12, height: 22)

            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 1.7)
                    .frame(width: 22, height: 22)
                if item.isCompleted {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(theme.font(10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(item.title)
                .font(theme.font(15, weight: item.isCompleted ? .regular : .medium))
                .foregroundStyle(item.isCompleted ? AppColors.completedText : Color.primary)
                .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .frame(width: max(rowWidth, 360), height: 50)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppColors.accent.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: AppColors.accent.opacity(0.30), radius: 14, y: 6)
        )
    }
}

private struct RowActionButton: View {
    let systemName: String
    let label: String
    var isDestructive = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 25, height: 25)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isDestructive && isHovering
                ? Color.red
                : AppColors.secondaryText.opacity(0.86)
        )
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.quick) {
                isHovering = hovering
            }
        }
        .help(label)
        .accessibilityLabel(label)
    }
}
