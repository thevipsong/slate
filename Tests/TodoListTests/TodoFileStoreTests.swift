import Testing
import Foundation
#if canImport(TodoList)
@testable import TodoList
#endif

/// 存储层测试：全部用临时目录，不碰真实 Application Support
/// Swift Testing：每个 @Test 自动获得 suite 新实例，init/deinit 即 setUp/tearDown
final class TodoFileStoreTests {

    let tempDir: URL
    let store: TodoFileStore

    init() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("slate-tests-\(UUID().uuidString)", isDirectory: true)
        store = TodoFileStore(baseDirectory: tempDir)
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - 首启空档

    /// 主文件和备份都不存在 → 返回空档，不抛错（P0 回归）
    @Test func loadEmptyReturnsBlankArchive() throws {
        let archive = try store.load()
        #expect(archive.items.isEmpty)
        #expect(archive.groups.count == 1)
        #expect(archive.groups.first?.name == TodoGroup.defaultName)
    }

    // MARK: - 往返

    @Test func saveLoadRoundTrip() throws {
        let group = TodoGroup.defaultGroup()
        let item = TodoItem(
            title: "往返测试",
            isCompleted: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_100),
            groupID: group.id,
            sortOrder: 3
        )
        try store.save(TodoArchive(items: [item], groups: [group]))

        let loaded = try store.load()
        #expect(loaded.items.count == 1)
        #expect(loaded.items.first?.title == "往返测试")
        #expect(loaded.items.first?.isCompleted == true)
        #expect(loaded.items.first?.groupID == group.id)
        #expect(loaded.items.first?.sortOrder == 3)
        #expect(loaded.groups.first?.id == group.id)
    }

    // MARK: - 备份轮转

    /// 第二次 save 后备份存在，主文件损坏 → 从备份恢复上一代
    @Test func corruptedMainFallsBackToBackup() throws {
        let group = TodoGroup.defaultGroup()
        try store.save(TodoArchive(items: [TodoItem(title: "第一代")], groups: [group]))
        try store.save(TodoArchive(items: [TodoItem(title: "第二代")], groups: [group]))

        try Data("corrupted!!!".utf8).write(to: store.fileURL)

        let loaded = try store.load()
        #expect(loaded.items.first?.title == "第一代")
    }

    /// 三次 save → 两代备份都在，逐级回退
    @Test func backupRotationKeepsTwoGenerations() throws {
        let group = TodoGroup.defaultGroup()
        try store.save(TodoArchive(items: [TodoItem(title: "一")], groups: [group]))
        try store.save(TodoArchive(items: [TodoItem(title: "二")], groups: [group]))
        try store.save(TodoArchive(items: [TodoItem(title: "三")], groups: [group]))

        let dir = store.fileURL.deletingLastPathComponent()
        let backup1 = dir.appendingPathComponent("todos.backup.json")
        let backup2 = dir.appendingPathComponent("todos.backup-2.json")
        #expect(FileManager.default.fileExists(atPath: backup1.path))
        #expect(FileManager.default.fileExists(atPath: backup2.path))

        // 损坏主文件 → 恢复"二"；再把 backup 也损坏 → 恢复"一"
        try Data("x".utf8).write(to: store.fileURL)
        #expect(try store.load().items.first?.title == "二")

        try Data("x".utf8).write(to: backup1)
        #expect(try store.load().items.first?.title == "一")
    }

    /// 主文件和备份全部损坏 → 抛错（此时只能让用户知道）
    @Test func allCorruptedThrows() throws {
        let group = TodoGroup.defaultGroup()
        try store.save(TodoArchive(items: [TodoItem(title: "一")], groups: [group]))
        try store.save(TodoArchive(items: [TodoItem(title: "二")], groups: [group]))

        let dir = store.fileURL.deletingLastPathComponent()
        try Data("x".utf8).write(to: store.fileURL)
        try Data("x".utf8).write(to: dir.appendingPathComponent("todos.backup.json"))
        try Data("x".utf8).write(to: dir.appendingPathComponent("todos.backup-2.json"))

        #expect(throws: (any Error).self) {
            try store.load()
        }
    }

    // MARK: - 版本兼容

    /// v1 老数据 → 迁移到 v3，任务进默认组
    @Test func v1Migration() throws {
        let id = UUID()
        let json = """
        {"version":1,"items":[{"id":"\(id.uuidString)","title":"老任务","date":"2024-01-01T00:00:00Z","isCompleted":true,"sortOrder":5}]}
        """
        let dir = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)

        let loaded = try store.load()
        #expect(loaded.items.count == 1)
        #expect(loaded.items.first?.id == id)
        #expect(loaded.items.first?.title == "老任务")
        #expect(loaded.items.first?.isCompleted == true)
        #expect(loaded.items.first?.sortOrder == 5)
        #expect(loaded.items.first?.groupID == loaded.groups.first?.id)
        #expect(loaded.version == 3)
    }

    /// 未来版本号 → 抛 invalidArchiveVersion
    @Test func invalidVersionThrows() throws {
        let json = """
        {"version":99,"items":[],"groups":[]}
        """
        let dir = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)

        #expect {
            try store.load()
        } throws: { error in
            guard case TodoFileStore.StoreError.invalidArchiveVersion(99) = error else { return false }
            return true
        }
    }
}
