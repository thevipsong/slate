import Foundation
import Testing
#if canImport(TodoList)
@testable import TodoList
#endif

struct SlateMergeEngineTests {
    private let groupID = UUID()
    private let firstID = UUID()
    private let secondID = UUID()

    private var group: TodoGroup {
        TodoGroup(id: groupID, name: "待办")
    }

    private var first: TodoItem {
        TodoItem(
            id: firstID,
            title: "第一项",
            createdAt: Date(timeIntervalSince1970: 100),
            groupID: groupID
        )
    }

    private var second: TodoItem {
        TodoItem(
            id: secondID,
            title: "第二项",
            createdAt: Date(timeIntervalSince1970: 200),
            groupID: groupID
        )
    }

    private var base: TodoArchive {
        TodoArchive(items: [first, second], groups: [group])
    }

    @Test func independentEditsAreCombined() {
        var localFirst = first
        localFirst.title = "本地修改"
        var remoteSecond = second
        remoteSecond.title = "远端修改"

        let result = SlateMergeEngine.merge(
            base: base,
            local: TodoArchive(items: [localFirst, second], groups: [group]),
            remote: TodoArchive(items: [first, remoteSecond], groups: [group]),
            preferLocalOnConflict: true
        )

        #expect(result.archive.items.first { $0.id == firstID }?.title == "本地修改")
        #expect(result.archive.items.first { $0.id == secondID }?.title == "远端修改")
        #expect(result.conflictingIDs.isEmpty)
    }

    @Test func unchangedRemoteDoesNotRestoreLocalDeletion() {
        let result = SlateMergeEngine.merge(
            base: base,
            local: TodoArchive(items: [second], groups: [group]),
            remote: base,
            preferLocalOnConflict: true
        )

        #expect(!result.archive.items.contains { $0.id == firstID })
        #expect(result.conflictingIDs.isEmpty)
    }

    @Test func sameEntityConflictUsesRequestedSide() {
        var localFirst = first
        localFirst.title = "本地"
        var remoteFirst = first
        remoteFirst.title = "远端"

        let result = SlateMergeEngine.merge(
            base: base,
            local: TodoArchive(items: [localFirst, second], groups: [group]),
            remote: TodoArchive(items: [remoteFirst, second], groups: [group]),
            preferLocalOnConflict: false
        )

        #expect(result.archive.items.first { $0.id == firstID }?.title == "远端")
        #expect(result.conflictingIDs == [firstID])
    }
}
