import SwiftUI

enum AppColors {
    static let accent = Color(red: 0.25, green: 0.52, blue: 1.0)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let placeholderText = Color.primary.opacity(0.48)
    static let inactiveText = Color(nsColor: .tertiaryLabelColor)
    static let completedText = Color(nsColor: .tertiaryLabelColor)
}

/// 应用窗口的环境背景
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var tintStrength: Double { colorScheme == .dark ? 0.10 : 0.05 }
    private var midTintStrength: Double { colorScheme == .dark ? 0.06 : 0.03 }

    var body: some View {
        ZStack {
            AppColors.windowBackground

            // 左上：accent 主光源（窗口呼吸感的主调）
            RadialGradient(
                colors: [AppColors.accent.opacity(tintStrength), .clear],
                center: UnitPoint(x: 0.18, y: 0.06),
                startRadius: 0,
                endRadius: 560
            )

            // 右下：accent 反向偏冷补光（给玻璃面板右下角多一点折射环境）
            RadialGradient(
                colors: [AppColors.accent.opacity(midTintStrength), .clear],
                center: UnitPoint(x: 0.92, y: 0.96),
                startRadius: 0,
                endRadius: 480
            )

            // 底部偏右：暖色柔光（避免整面冷调，拉一点色温）
            RadialGradient(
                colors: [Color.orange.opacity(colorScheme == .dark ? 0.05 : 0.025), .clear],
                center: UnitPoint(x: 0.7, y: 1.0),
                startRadius: 0,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}