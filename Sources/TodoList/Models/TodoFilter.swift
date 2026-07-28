import Foundation

enum TodoFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case pending = "待完成"
    case completed = "已完成"
    case overdue = "逾期"

    var id: String { rawValue }

    /// SF Symbol 图标，用于筛选 chip 左侧
    var systemImage: String {
        switch self {
        case .all: "list.bullet"
        case .pending: "circle"
        case .completed: "checkmark.circle.fill"
        case .overdue: "exclamationmark.circle"
        }
    }
}
