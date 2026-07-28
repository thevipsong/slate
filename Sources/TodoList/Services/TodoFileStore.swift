import Foundation

struct TodoFileStore: Sendable {
    private static let directoryName = "Slate"
    private static let archiveName = "todos.json"
    private static let backupNames = ["todos.backup.json", "todos.backup-2.json"]

    enum StoreError: LocalizedError {
        case invalidArchiveVersion(Int)
        case noReadableArchive

        var errorDescription: String? {
            switch self {
            case .invalidArchiveVersion(let version):
                "无法读取版本为 \(version) 的待办数据。"
            case .noReadableArchive:
                "待办数据和备份都无法读取。"
            }
        }
    }

    let fileURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        let root: URL
        if let baseDirectory {
            root = baseDirectory
        } else {
            let applicationSupport = try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            root = applicationSupport ?? fileManager.homeDirectoryForCurrentUser
        }

        fileURL = root
            .appendingPathComponent(Self.directoryName, isDirectory: true)
            .appendingPathComponent(Self.archiveName)

        // 一次性迁移：从老目录 MinimalTodoList 拷到 Slate，不删老目录（保险）
        migrateLegacyDataIfNeeded(fileManager: fileManager, root: root)
    }

    /// 一次性数据迁移：老版本数据在 MinimalTodoList/，新版本在 Slate/。
    /// 检测到 Slate/todos.json 不存在但 MinimalTodoList/todos.json 存在时，
    /// 把 todos.json 和备份文件拷到 Slate 下。迁移过的标记写入 .slate-migrated 避免每次启动重复检查。
    private func migrateLegacyDataIfNeeded(fileManager: FileManager, root: URL) {
        let slateDir = root.appendingPathComponent("Slate", isDirectory: true)
        let legacyDir = root.appendingPathComponent("MinimalTodoList", isDirectory: true)
        let migrationMarker = slateDir.appendingPathComponent(".slate-migrated")

        if fileManager.fileExists(atPath: migrationMarker.path) { return }
        try? fileManager.createDirectory(at: slateDir, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: legacyDir.path) {
            for filename in ["todos.json", "todos.backup.json", "todos.backup-2.json"] {
                let src = legacyDir.appendingPathComponent(filename)
                let dst = slateDir.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: src.path),
                   !fileManager.fileExists(atPath: dst.path) {
                    try? fileManager.copyItem(at: src, to: dst)
                }
            }
            let legacyAttachments = legacyDir.appendingPathComponent("Attachments")
            if fileManager.fileExists(atPath: legacyAttachments.path) {
                let dst = slateDir.appendingPathComponent("Attachments")
                if !fileManager.fileExists(atPath: dst.path) {
                    try? fileManager.copyItem(at: legacyAttachments, to: dst)
                }
            }
        }

        try? Data().write(to: migrationMarker)
    }

    func load(fileManager: FileManager = .default) throws -> TodoArchive {
        // 主文件和所有备份都不存在 = 全新用户，返回空档，不算错误
        let hasAnyFile = fileManager.fileExists(atPath: fileURL.path)
            || rollingBackupURLs(fileManager: fileManager).contains {
                fileManager.fileExists(atPath: $0.path)
            }
        guard hasAnyFile else { return TodoArchive() }

        if let archive = try? decodeArchive(at: fileURL, fileManager: fileManager) {
            return archive
        }
        for backupURL in rollingBackupURLs(fileManager: fileManager) {
            if let archive = try? decodeArchive(at: backupURL, fileManager: fileManager) {
                return archive
            }
        }
        // 全部失败，再抛一次真正的错误
        return try decodeArchive(at: fileURL, fileManager: fileManager)
    }

    private func decodeArchive(at url: URL, fileManager: FileManager) throws -> TodoArchive {
        guard fileManager.fileExists(atPath: url.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // 单次解码取版本号，避免 JSONSerialization 全量预解析一遍
        let version = (try? decoder.decode(VersionHeader.self, from: data).version) ?? 0

        switch version {
        case 3:
            let archive = try decoder.decode(TodoArchive.self, from: data)
            return archive
        case 0, 1, 2:
            // 旧 v1/v2 兼容：尽力把 title 提取出来
            let legacy = try decoder.decode(LegacyArchive.self, from: data)
            return legacy.migratedToV3()
        default:
            throw StoreError.invalidArchiveVersion(version)
        }
    }

    private func rollingBackupURLs(fileManager: FileManager) -> [URL] {
        let directory = fileURL.deletingLastPathComponent()
        let urls = Self.backupNames.map { directory.appendingPathComponent($0) }
        return urls
    }

    func save(_ archive: TodoArchive, fileManager: FileManager = .default) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let backupURL = directory.appendingPathComponent(Self.backupNames[0])
        let olderBackupURL = directory.appendingPathComponent(Self.backupNames[1])

        if fileManager.fileExists(atPath: fileURL.path) {
            if fileManager.fileExists(atPath: backupURL.path) {
                if fileManager.fileExists(atPath: olderBackupURL.path) {
                    try fileManager.removeItem(at: olderBackupURL)
                }
                try fileManager.moveItem(at: backupURL, to: olderBackupURL)
            }
            try fileManager.copyItem(at: fileURL, to: backupURL)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)

        let tempURL = directory.appendingPathComponent(".todos.\(UUID().uuidString).tmp")
        try data.write(to: tempURL, options: .atomic)
        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: fileURL)
        }
    }
}

struct TodoArchive: Codable, Equatable {
    static let currentVersion = 3

    let version: Int
    var items: [TodoItem]
    var groups: [TodoGroup]

    init(
        version: Int = TodoArchive.currentVersion,
        items: [TodoItem] = [],
        groups: [TodoGroup] = [TodoGroup.defaultGroup()]
    ) {
        self.version = version
        self.items = items
        self.groups = groups
    }
}

// MARK: - 旧 v1/v2 数据兼容（一次性迁移）

/// 只取版本号的轻量头，用于分发到正确的解码路径
private struct VersionHeader: Decodable {
    let version: Int?
}

private struct LegacyArchive: Decodable {
    let version: Int
    let items: [LegacyTodoItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        items = try container.decodeIfPresent([LegacyTodoItem].self, forKey: .items) ?? []
    }

    private enum CodingKeys: String, CodingKey { case version, items }

    func migratedToV3() -> TodoArchive {
        let defaultGroup = TodoGroup.defaultGroup()
        let migrated = items.map { legacy in
            TodoItem(
                id: legacy.id,
                title: legacy.title,
                isCompleted: legacy.isCompleted,
                createdAt: legacy.date, // 用旧 date 当创建时间，保留顺序线索
                groupID: defaultGroup.id, // 老数据迁移时显式分配到默认分组
                sortOrder: legacy.sortOrder
            )
        }
        return TodoArchive(version: 3, items: migrated, groups: [defaultGroup])
    }
}

private struct LegacyTodoItem: Decodable {
    let id: UUID
    let title: String
    let date: Date
    let isCompleted: Bool
    let sortOrder: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, isCompleted, sortOrder
    }
}
