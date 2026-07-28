import SwiftUI

extension View {
    /// 同时支持添加和移除 selected trait，避免 SwiftUI 复用按钮时遗留旧状态。
    @ViewBuilder
    func accessibilitySelected(_ isSelected: Bool) -> some View {
        if isSelected {
            self.accessibilityAddTraits(.isSelected)
        } else {
            self.accessibilityRemoveTraits(.isSelected)
        }
    }
}
