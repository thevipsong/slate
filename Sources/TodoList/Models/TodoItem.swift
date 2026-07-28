import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var completedAt: Date?
    var groupID: UUID?
    var sortOrder: Double?
    /// 到期日（轻量提醒用，nil = 不设）。老数据缺此字段时解码为 nil，向后兼容。
    var dueDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        groupID: UUID? = nil,
        sortOrder: Double? = nil,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.groupID = groupID
        self.sortOrder = sortOrder
        self.dueDate = dueDate
    }
}