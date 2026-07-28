import Foundation

struct TodoGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sortOrder: Double
    /// SF Symbol 名称，用作分组图标
    var systemImage: String

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Double = 0,
        systemImage: String = "folder"
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.systemImage = systemImage
    }

    static let defaultName = "待办"

    static func defaultGroup() -> TodoGroup {
        TodoGroup(name: defaultName, sortOrder: 0, systemImage: "checklist")
    }

    /// 候选 SF Symbol，用户重命名分组时可换图标
    static let symbolChoices: [String] = [
        "checklist",
        "briefcase",
        "house",
        "leaf",
        "book",
        "fork.knife",
        "cart",
        "envelope",
        "phone",
        "music.note",
        "wand.and.stars",
        "lightbulb",
        "graduationcap",
        "heart",
        "tag",
        "tray",
        "folder",
        "doc.text",
        "pencil.and.list.clipboard",
        "calendar"
    ]
}
