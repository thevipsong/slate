import SwiftUI

struct TodoListView: View {
    @ObservedObject var viewModel: TodoViewModel
    @EnvironmentObject var theme: AppTheme

    var body: some View {
        if viewModel.visibleItems.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(viewModel.visibleItems) { item in
                        TodoRowView(
                            item: item,
                            viewModel: viewModel
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
                // 增删移动画的动画已在各操作点用 withAnimation 显式触发，
                // 这里不再对整个数组做 O(n) 相等比较驱动动画
            }
            .background(ScrollViewConfigurator())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyIcon)
                .font(theme.font(28, weight: .light))
                .foregroundStyle(AppColors.accent.opacity(0.55))
            Text(emptyTitle)
                .font(theme.font(14, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
            if viewModel.filter == .all {
                Text("记下每件事，按自己的节奏完成。")
                    .font(theme.font(12))
                    .foregroundStyle(AppColors.inactiveText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch viewModel.filter {
        case .all: "checklist"
        case .pending: "clock"
        case .completed: "checkmark.circle"
        case .overdue: "exclamationmark.circle"
        }
    }

    private var emptyTitle: String {
        switch viewModel.filter {
        case .all: "这个分组还没有任务"
        case .pending: "没有待完成的任务"
        case .completed: "还没有已完成的任务"
        case .overdue: "没有逾期的任务"
        }
    }
}

private struct ScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let scrollView = view?.enclosingScrollView else { return }
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            // 极简：默认几乎透明，macOS 自动在滚动 / 悬停时短暂显现
            scrollView.scrollerInsets = NSEdgeInsets(top: 14, left: 0, bottom: 14, right: 2)
            scrollView.verticalScroller?.controlSize = .mini
            scrollView.verticalScroller?.alphaValue = 0.18
            scrollView.verticalScroller?.knobStyle = .default
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
