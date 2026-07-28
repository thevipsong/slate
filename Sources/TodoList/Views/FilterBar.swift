import SwiftUI

struct FilterChipsView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TodoFilter.allCases) { filter in
                FilterChip(
                    filter: filter,
                    isSelected: viewModel.filter == filter,
                    action: {
                        withAnimation(.snappy) {
                            viewModel.clearSelection()
                            viewModel.setFilter(filter)
                        }
                    }
                )
            }

            SearchField(viewModel: viewModel)

            Spacer()

            // 主题/字体入口：从 Header 挪到工具行右端，Header 只留信息
            ThemePickerView(viewModel: viewModel)
        }
    }
}

/// 标题搜索框：叠加在筛选之上，⌘F 聚焦
struct SearchField: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(theme.font(11, weight: .semibold))
                .foregroundStyle(isFocused ? AppColors.accent : AppColors.secondaryText)
            TextField("搜索", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.setSearch($0) }
            ))
            .textFieldStyle(.plain)
            .font(theme.font(13))
            .focused($isFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(theme.font(11))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 170, height: 30)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isFocused ? AppColors.accent.opacity(0.9) : Color.white.opacity(0.08),
                            lineWidth: isFocused ? 1.2 : 1
                        )
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            isFocused = true
        }
    }
}

/// 单个筛选 chip（独立 view 持有自己的 hover state）
private struct FilterChip: View {
    let filter: TodoFilter
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject var theme: AppTheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: filter.systemImage)
                    .font(theme.font(10, weight: .semibold))
                Text(filter.rawValue)
                    .font(theme.font(12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : (isHovering ? Color.primary : AppColors.inactiveText))
            .padding(.horizontal, 14)
            .frame(height: 30)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            Capsule()
                .fill(isSelected
                      ? AnyShapeStyle(.ultraThinMaterial)
                      : AnyShapeStyle(isHovering ? Color.white.opacity(0.06) : Color.clear))
                .overlay {
                    Capsule()
                        .fill(isSelected ? AppColors.accent.opacity(0.78) : Color.clear)
                }
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    isSelected ? Color.white.opacity(0.18) : Color.white.opacity(isHovering ? 0.12 : 0.06),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isSelected ? AppColors.accent.opacity(0.22) : .clear,
            radius: 6,
            y: 2
        )
        .onHover { hovering in
            withAnimation(.quick) { isHovering = hovering }
        }
        .accessibilityLabel(filter.rawValue)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilitySelected(isSelected)
    }
}
