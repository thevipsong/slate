@preconcurrency import AppKit
import Combine
import SwiftUI

/// 用户可选择的字体族
enum AppFontFamily: String, CaseIterable, Identifiable {
    case rounded = "圆润"
    case system = "系统"
    case serif = "衬线"
    case mono = "等宽"
    case kaiti = "楷体"
    case yuanti = "圆体"
    case avenir = "Avenir"
    case optima = "Optima"

    var id: String { rawValue }

    /// 用于 Font.system 的 design 参数；nil 表示走 customFontName
    var design: Font.Design? {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        case .kaiti, .yuanti, .avenir, .optima: nil
        }
    }

    /// 用于 Font.custom 的实际字体名；nil 表示走 system + design
    var customFontName: String? {
        switch self {
        case .kaiti: "Kaiti SC"
        case .yuanti: "Yuanti SC"
        case .avenir: "Avenir"
        case .optima: "Optima"
        default: nil
        }
    }
}

/// 字号档：基准上 +0/+2/+4
enum AppFontScale: Int, CaseIterable, Identifiable {
    case small = 0
    case regular = 2
    case large = 4

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .small: "小"
        case .regular: "中"
        case .large: "大"
        }
    }
    var offset: CGFloat { CGFloat(rawValue) }
}

/// 菜单栏面板保持固定宽度，通过三档高度兼顾小屏与长列表。
enum MenuBarPanelSize: String, CaseIterable, Identifiable {
    case compact
    case regular
    case roomy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "紧凑"
        case .regular: "标准"
        case .roomy: "宽敞"
        }
    }

    var height: CGFloat {
        switch self {
        case .compact: 420
        case .regular: 520
        case .roomy: 620
        }
    }
}

/// 全局主题：字体、字号、外观和菜单栏尺寸的单一状态源。
///
/// 这里不能直接依赖类中的 `@AppStorage`：它虽然能写入偏好设置，却不会稳定地通过
/// `ObservableObject` 通知常驻的菜单栏面板。改用 `@Published` 发布变化，再显式持久化，
/// 可确保主窗口、菜单栏面板和 AppKit 标题栏在同一次设置后立即同步。
final class AppTheme: ObservableObject {
    private enum DefaultsKey {
        static let fontFamily = "theme.fontFamily"
        static let fontScale = "theme.fontScale"
        static let colorScheme = "theme.colorScheme"
        static let menuBarPanelSize = "menuBar.panelSize"
        static let weatherCityID = "theme.weatherCityID"
    }

    private let defaults: UserDefaults

    @Published var fontFamilyRaw: String {
        didSet { defaults.set(fontFamilyRaw, forKey: DefaultsKey.fontFamily) }
    }

    @Published var fontScaleRaw: Int {
        didSet { defaults.set(fontScaleRaw, forKey: DefaultsKey.fontScale) }
    }

    @Published var colorSchemeRaw: String {
        didSet { defaults.set(colorSchemeRaw, forKey: DefaultsKey.colorScheme) }
    }

    @Published var menuBarPanelSizeRaw: String {
        didSet { defaults.set(menuBarPanelSizeRaw, forKey: DefaultsKey.menuBarPanelSize) }
    }

    /// 天气城市（默认蚌埠，目标用户所在地）；本地可选，不申请定位权限
    @Published var weatherCityID: String {
        didSet { defaults.set(weatherCityID, forKey: DefaultsKey.weatherCityID) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fontFamilyRaw = defaults.string(forKey: DefaultsKey.fontFamily)
            ?? AppFontFamily.rounded.rawValue
        fontScaleRaw = defaults.object(forKey: DefaultsKey.fontScale) as? Int
            ?? AppFontScale.regular.rawValue
        colorSchemeRaw = defaults.string(forKey: DefaultsKey.colorScheme) ?? "system"
        menuBarPanelSizeRaw = defaults.string(forKey: DefaultsKey.menuBarPanelSize)
            ?? MenuBarPanelSize.regular.rawValue
        weatherCityID = defaults.string(forKey: DefaultsKey.weatherCityID) ?? "bengbu"
    }

    /// 可选城市列表（中文界面，覆盖主要城市即可）
    static let weatherCities: [(id: String, name: String, lat: Double, lon: Double)] = [
        ("bengbu", "蚌埠", 32.94, 117.36),
        ("beijing", "北京", 39.90, 116.40),
        ("shanghai", "上海", 31.23, 121.47),
        ("guangzhou", "广州", 23.13, 113.26),
        ("shenzhen", "深圳", 22.54, 114.06),
        ("chengdu", "成都", 30.57, 104.07),
        ("hangzhou", "杭州", 30.27, 120.16),
        ("wuhan", "武汉", 30.59, 114.31)
    ]

    /// 当前选中城市的坐标，供 WeatherService 使用
    var weatherCoordinate: (lat: Double, lon: Double) {
        let city = AppTheme.weatherCities.first { $0.id == weatherCityID } ?? AppTheme.weatherCities[0]
        return (lat: city.lat, lon: city.lon)
    }

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// 同步窗口标题栏、材质背景等 AppKit 层级的外观。
    /// `nil` 表示恢复跟随系统，不在窗口上保留旧的强制主题。
    var appKitAppearance: NSAppearance? {
        switch colorSchemeRaw {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    var fontFamily: AppFontFamily {
        AppFontFamily(rawValue: fontFamilyRaw) ?? .rounded
    }

    var fontScale: AppFontScale {
        AppFontScale(rawValue: fontScaleRaw) ?? .regular
    }

    var menuBarPanelSize: MenuBarPanelSize {
        MenuBarPanelSize(rawValue: menuBarPanelSizeRaw) ?? .regular
    }

    var menuBarPanelHeight: CGFloat {
        menuBarPanelSize.height
    }

    /// 字号 = 基准 + 字号档偏移
    func size(_ base: CGFloat) -> CGFloat {
        base + fontScale.offset
    }

    func font(_ base: CGFloat, weight: Font.Weight = .regular) -> Font {
        let resolvedSize = size(base)
        if let name = fontFamily.customFontName {
            return .custom(name, size: resolvedSize, relativeTo: .body).weight(weight)
        }
        return .system(size: resolvedSize, weight: weight, design: fontFamily.design ?? .default)
    }

    func monoDigits(_ base: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size(base), weight: weight, design: .monospaced)
    }
}

// MARK: - 动画 token（全 app 统一两条曲线，不再散落魔法数字）

extension Animation {
    /// 快速反馈：hover、增删行、状态切换
    static let quick = Animation.easeInOut(duration: 0.18)
    /// 弹性位移：分组/筛选切换、拖放归位
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.85)
}
