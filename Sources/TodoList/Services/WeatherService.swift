import Foundation

/// Header 右侧的日期 + 本地天气。
/// 天气源：Open-Meteo（免费、无 key），WMO weather_code 本地映射中文和图标，
/// 中文输出 100% 可控，不依赖第三方翻译。失败静默——只显示日期，不留错误态。
/// 30 分钟刷新一次；日期跟着同一循环走，跨天最多滞后 30 分钟。
@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var dateText: String = ""
    @Published private(set) var quoteText: String = ""
    @Published private(set) var weatherText: String?   // "29° 阴"，nil = 未拉到
    @Published private(set) var weatherSymbol: String = "cloud"

    private var refreshTask: Task<Void, Never>?

    // 默认蚌埠坐标（目标用户所在地）；可通过 configure 切换城市
    var latitude: Double = 32.94
    var longitude: Double = 117.36

    /// 幂等：重复调用不叠加任务
    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Date()
                dateText = Self.dateFormatter.string(from: now)
                quoteText = Self.dailyQuote(for: now)
                if let snapshot = await Self.fetch(latitude: self.latitude, longitude: self.longitude) {
                    weatherText = snapshot.displayText
                    weatherSymbol = snapshot.symbolName
                }
                try? await Task.sleep(for: .seconds(30 * 60))
            }
        }
    }

    /// 切换城市：更新坐标并重启刷新循环
    func configure(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        restart()
    }

    private func restart() {
        refreshTask?.cancel()
        refreshTask = nil
        start()
    }

    /// 每日一句英文名言：按「一年中的第几天」确定性轮换——
    /// 当天内稳定不跳变，跨天自动换；纯函数便于测试。
    nonisolated static func dailyQuote(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return Self.dailyQuotes[(day - 1) % Self.dailyQuotes.count]
    }

    /// 短句优先，保证 Header 副标题一行放得下（中文界面保持一致）
    nonisolated static let dailyQuotes: [String] = [
        "开始，胜过完美。",
        "今日事，今日毕。",
        "行动，胜于空谈。",
        "慢即是快，稳才能远。",
        "完成，比完美更重要。",
        "保持饥饿，保持愚蠢。",
        "勇敢者，自有其运。",
        "一分耕耘，一分收获。",
        "光阴不待人。",
        "趁热打铁。",
        "熟能生巧。",
        "积水成渊。",
        "稳，才能快。",
        "每天都是新开始。",
        "莫等闲。",
        "知识就是力量。",
        "犹豫者失机。",
        "迟做，好过不做。"
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter
    }()

    // MARK: - 纯逻辑（可测试）

    struct Snapshot: Equatable {
        /// 摄氏度（已取整）
        let temperatureC: Int
        /// WMO weather code
        let weatherCode: Int

        var displayText: String { "\(temperatureC)° \(Self.description(for: weatherCode))" }
        var symbolName: String { Self.symbol(for: weatherCode) }

        static func description(for code: Int) -> String {
            switch code {
            case 0: "晴"
            case 1: "晴间多云"
            case 2: "多云"
            case 3: "阴"
            case 45, 48: "雾"
            case 51, 53, 55: "毛毛雨"
            case 56, 57: "冻毛毛雨"
            case 61: "小雨"
            case 63: "中雨"
            case 65: "大雨"
            case 66, 67: "冻雨"
            case 71: "小雪"
            case 73: "中雪"
            case 75: "大雪"
            case 77: "雪粒"
            case 80: "阵雨"
            case 81: "强阵雨"
            case 82: "暴雨"
            case 85, 86: "阵雪"
            case 95: "雷暴"
            case 96, 99: "雷暴冰雹"
            default: "—"
            }
        }

        static func symbol(for code: Int) -> String {
            switch code {
            case 0: "sun.max"
            case 1, 2: "cloud.sun"
            case 3: "cloud"
            case 45, 48: "cloud.fog"
            case 51, 53, 55, 56, 57: "cloud.drizzle"
            case 61, 63, 65, 66, 67, 80, 81, 82: "cloud.rain"
            case 71, 73, 75, 77, 85, 86: "cloud.snow"
            case 95, 96, 99: "cloud.bolt.rain"
            default: "cloud"
            }
        }
    }

    /// 解析 Open-Meteo current 响应；结构不符返回 nil
    nonisolated static func parse(_ data: Data) -> Snapshot? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = raw["current"] as? [String: Any],
              let temp = current["temperature_2m"] as? Double,
              let code = current["weather_code"] as? Int else {
            return nil
        }
        return Snapshot(temperatureC: Int(temp.rounded()), weatherCode: code)
    }

    nonisolated static func fetch(latitude: Double, longitude: Double) async -> Snapshot? {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)&longitude=\(longitude)"
            + "&current=temperature_2m,weather_code&timezone=auto"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return parse(data)
    }
}
