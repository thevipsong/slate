import Foundation
import Testing
#if canImport(TodoList)
@testable import TodoList
#endif

struct SupabaseSyncIntegrationTests {
    @Test func hostedMacClientMergesAndroidTaskAndWritesBack() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SLATE_PRODUCTION_SYNC_SMOKE"] == "1",
              let projectURL = environment["SLATE_SUPABASE_URL"],
              let publishableKey = environment["SLATE_SUPABASE_PUBLISHABLE_KEY"],
              let email = environment["SLATE_SYNC_EMAIL"],
              let password = environment["SLATE_SYNC_PASSWORD"] else {
            return
        }

        let groupID = try #require(
            UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")
        )
        let macItemID = UUID()
        let group = TodoGroup(id: groupID, name: "生产同步验证")
        let localArchive = TodoArchive(
            items: [
                TodoItem(
                    id: macItemID,
                    title: "Mac Production Task",
                    createdAt: Date(),
                    groupID: groupID,
                    sortOrder: 2
                )
            ],
            groups: [group]
        )

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("slate-hosted-sync-\(UUID().uuidString)")
        let sessionStore = SlateSecureSessionStore(
            namespace: "hosted-integration-\(UUID().uuidString)"
        )
        let coordinator = SlateSyncCoordinator(
            stateStore: SlateSyncStateStore(baseDirectory: tempDirectory),
            sessionStore: sessionStore
        )
        let configuration = SupabaseConfiguration(
            projectURL: projectURL,
            publishableKey: publishableKey
        )

        _ = try await coordinator.signIn(
            configuration: configuration,
            email: email,
            password: password
        )
        let outcome = try await coordinator.sync(
            localArchive: localArchive,
            configuration: configuration
        )

        #expect(outcome.revision > 0)
        #expect(outcome.archive.items.contains { $0.title == "Android Production Task" })
        #expect(outcome.archive.items.contains { $0.id == macItemID })

        try await coordinator.signOut()
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @Test func macClientMergesAndroidChangesAndWritesBack() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SLATE_SYNC_INTEGRATION"] == "1",
              let projectURL = environment["SLATE_SUPABASE_URL"],
              let publishableKey = environment["SLATE_SUPABASE_PUBLISHABLE_KEY"],
              let email = environment["SLATE_SYNC_EMAIL"],
              let password = environment["SLATE_SYNC_PASSWORD"] else {
            return
        }

        let groupID = try #require(
            UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")
        )
        let seededItemID = try #require(
            UUID(uuidString: "11111111-1111-4111-8111-111111111111")
        )
        let returnedItemID = try #require(
            UUID(uuidString: "44444444-4444-4444-8444-444444444444")
        )
        let createdAt = try #require(
            ISO8601DateFormatter().date(from: "2026-07-28T12:00:00Z")
        )
        let group = TodoGroup(id: groupID, name: "双端验证")
        let seededItem = TodoItem(
            id: seededItemID,
            title: "来自 Mac 的同步任务",
            createdAt: createdAt,
            groupID: groupID,
            sortOrder: 0
        )
        let baseline = TodoArchive(items: [seededItem], groups: [group])
        let localArchive = TodoArchive(
            items: [
                seededItem,
                TodoItem(
                    id: returnedItemID,
                    title: "Mac 再次同步",
                    createdAt: Date(),
                    groupID: groupID,
                    sortOrder: 1
                )
            ],
            groups: [group]
        )

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("slate-sync-integration-\(UUID().uuidString)")
        let stateStore = SlateSyncStateStore(baseDirectory: tempDirectory)
        let sessionStore = SlateSecureSessionStore(
            namespace: "integration-\(UUID().uuidString)"
        )
        let coordinator = SlateSyncCoordinator(
            stateStore: stateStore,
            sessionStore: sessionStore
        )
        let configuration = SupabaseConfiguration(
            projectURL: projectURL,
            publishableKey: publishableKey
        )

        _ = try await coordinator.signIn(
            configuration: configuration,
            email: email,
            password: password
        )
        try await stateStore.save(
            SlateLocalSyncState(
                baseArchive: baseline,
                remoteRevision: 1,
                deviceID: "mac-integration",
                localModifiedAt: Date(),
                lastSyncedAt: createdAt
            )
        )

        let outcome = try await coordinator.sync(
            localArchive: localArchive,
            configuration: configuration
        )

        #expect(outcome.revision == 4)
        #expect(outcome.archive.items.contains { $0.title == "From Android" })
        #expect(outcome.archive.items.contains { $0.title == "Mac 再次同步" })
        #expect(outcome.archive.items.contains { $0.title == "来自 Mac 的同步任务" })

        try await coordinator.signOut()
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}
