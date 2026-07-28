import SwiftUI

struct GroupBar: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @State private var showingNewGroupSheet = false
    @State private var editingGroupID: UUID?
    @State private var newGroupName = ""
    /// 等待用户确认删除的分组（触发 confirmationDialog）
    @State private var groupPendingDeletion: TodoGroup?

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.groups) { group in
                        GroupChip(
                            group: group,
                            isSelected: viewModel.selectedGroupID == group.id,
                            pendingCount: viewModel.pendingCount(for: group.id),
                            onSelect: {
                                withAnimation(.snappy) {
                                    viewModel.selectGroup(group.id)
                                }
                            },
                            onRename: {
                                editingGroupID = group.id
                            },
                            onDelete: {
                                guard viewModel.groups.count > 1 else { return }
                                groupPendingDeletion = group
                            },
                            onChangeSymbol: { symbol in
                                viewModel.updateGroupSymbol(group.id, systemImage: symbol)
                            }
                        )
                    }

                    addButton
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showingNewGroupSheet) {
            newGroupSheet
        }
        .sheet(item: Binding(
            get: { editingGroupID.map { RenameTarget(id: $0) } },
            set: { editingGroupID = $0?.id }
        )) { target in
            RenameGroupSheet(
                groupID: target.id,
                initialName: viewModel.groups.first(where: { $0.id == target.id })?.name ?? "",
                onSave: { newName in
                    viewModel.renameGroup(target.id, to: newName)
                    editingGroupID = nil
                },
                onCancel: { editingGroupID = nil }
            )
            .environmentObject(theme)
        }
        .confirmationDialog(
            groupPendingDeletion.map { "删除分组「\($0.name)」？" } ?? "",
            isPresented: Binding(
                get: { groupPendingDeletion != nil },
                set: { if !$0 { groupPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除分组", role: .destructive) {
                if let group = groupPendingDeletion {
                    viewModel.deleteGroup(group.id)
                }
                groupPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                groupPendingDeletion = nil
            }
        } message: {
            if let group = groupPendingDeletion {
                let count = viewModel.totalCount(for: group.id)
                let keepName = viewModel.groups.first(where: { $0.id != group.id })?.name ?? ""
                if count > 0 {
                    Text("组内 \(count) 个任务将移至「\(keepName)」。")
                } else {
                    Text("该分组为空。")
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            newGroupName = ""
            showingNewGroupSheet = true
        } label: {
            Image(systemName: "plus")
                .font(theme.font(13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .help("新增分组")
    }

    private var newGroupSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建分组")
                .font(theme.font(17, weight: .semibold))
                .foregroundStyle(.primary)

            TextField("分组名称", text: $newGroupName)
                .textFieldStyle(.plain)
                .font(theme.font(15))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                )

            HStack {
                Spacer()
                Button("取消") {
                    showingNewGroupSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("创建") {
                    viewModel.addGroup(name: newGroupName)
                    showingNewGroupSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

private struct RenameTarget: Identifiable {
    let id: UUID
}

/// 重命名 sheet：独立 view 持有自己的输入 state，不与"新建分组"共享 newGroupName
private struct RenameGroupSheet: View {
    let groupID: UUID
    let initialName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var theme: AppTheme
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名分组")
                .font(theme.font(17, weight: .semibold))
                .foregroundStyle(.primary)

            TextField("分组名称", text: $name)
                .textFieldStyle(.plain)
                .font(theme.font(15))
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                )

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Button("保存") { onSave(name) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { name = initialName }
    }
}

/// 单个分组 chip
private struct GroupChip: View {
    let group: TodoGroup
    let isSelected: Bool
    let pendingCount: Int
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onChangeSymbol: (String) -> Void

    @EnvironmentObject var theme: AppTheme
    @State private var showingIconPicker = false
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: group.systemImage)
                    .font(theme.font(11, weight: .semibold))
                Text(group.name)
                    .font(theme.font(13, weight: .semibold))
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(theme.font(10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(
                                isSelected
                                    ? Color.white.opacity(0.25)
                                    : AppColors.accent.opacity(0.85)
                            )
                        )
                }
            }
            .foregroundStyle(isSelected ? Color.white : (isHovering ? Color.primary : AppColors.inactiveText))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(.ultraThinMaterial)
                          : AnyShapeStyle(isHovering ? Color.white.opacity(0.06) : Color.clear))
                    .overlay {
                        if isSelected {
                            Capsule()
                                .fill(AppColors.accent.opacity(0.85))
                        }
                    }
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.20) : Color.white.opacity(isHovering ? 0.14 : 0.08),
                        lineWidth: 1
                    )
            }
            .shadow(color: isSelected ? AppColors.accent.opacity(0.22) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .onHover { hovering in
            withAnimation(.quick) { isHovering = hovering }
        }
        .accessibilityLabel(group.name)
        .accessibilityValue("\(pendingCount) 项待办，\(isSelected ? "已选择" : "未选择")")
        .accessibilitySelected(isSelected)
        .contextMenu {
            Button("重命名") { onRename() }
            Menu {
                ForEach(TodoGroup.symbolChoices, id: \.self) { symbol in
                    Button {
                        onChangeSymbol(symbol)
                    } label: {
                        Image(systemName: symbol)
                            .accessibilityLabel(symbol)
                    }
                }
            } label: {
                Text("更换图标")
            }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}
