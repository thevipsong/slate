import Foundation

actor SlateSyncCoordinator {
    private let stateStore: SlateSyncStateStore
    private let sessionStore: SlateSecureSessionStore

    init(
        stateStore: SlateSyncStateStore,
        sessionStore: SlateSecureSessionStore
    ) {
        self.stateStore = stateStore
        self.sessionStore = sessionStore
    }

    func storedSession() async -> StoredSupabaseSession? {
        await sessionStore.load()
    }

    func signIn(
        configuration: SupabaseConfiguration,
        email: String,
        password: String
    ) async throws -> StoredSupabaseSession {
        let session = try await SupabaseHTTPClient(configuration: configuration)
            .signIn(email: email, password: password)
        try await sessionStore.save(session)
        return session
    }

    func signUp(
        configuration: SupabaseConfiguration,
        email: String,
        password: String
    ) async throws -> StoredSupabaseSession? {
        let session = try await SupabaseHTTPClient(configuration: configuration)
            .signUp(email: email, password: password)
        if let session {
            try await sessionStore.save(session)
        }
        return session
    }

    func signOut() async throws {
        try await sessionStore.clear()
        try await stateStore.clearBaseline()
    }

    func sync(
        localArchive: TodoArchive,
        configuration: SupabaseConfiguration
    ) async throws -> SlateSyncOutcome {
        guard var session = await sessionStore.load() else {
            throw CoordinatorError(message: "请先登录同步账户。")
        }
        let client = SupabaseHTTPClient(configuration: configuration)
        if session.expiresAt <= Date().addingTimeInterval(60) {
            session = try await client.refresh(session)
            try await sessionStore.save(session)
        }

        var state = await stateStore.load()
        var candidate = localArchive
        var conflicts = Set<UUID>()

        for _ in 0..<3 {
            let response = try await client.sync(
                session: session,
                expectedRevision: state.remoteRevision,
                archive: candidate,
                deviceID: state.deviceID
            )
            if response.accepted {
                let syncedAt = Date()
                state.baseArchive = candidate
                state.remoteRevision = response.revision
                state.lastSyncedAt = syncedAt
                try await stateStore.save(state)
                return SlateSyncOutcome(
                    archive: candidate,
                    revision: response.revision,
                    conflictCount: conflicts.count,
                    syncedAt: syncedAt
                )
            }

            let merged = SlateMergeEngine.merge(
                base: state.baseArchive,
                local: localArchive,
                remote: response.archive,
                preferLocalOnConflict: state.localModifiedAt >= response.updatedAt
            )
            conflicts.formUnion(merged.conflictingIDs)
            candidate = merged.archive
            state.remoteRevision = response.revision
        }

        throw CoordinatorError(
            message: "云端数据持续变化，已保留本地内容，请稍后重试。"
        )
    }

    /// Read-only remote revision check used by the foreground polling loop.
    /// It avoids incrementing the cloud revision when nothing changed.
    func refreshIfRemoteChanged(
        localArchive: TodoArchive,
        configuration: SupabaseConfiguration
    ) async throws -> SlateSyncOutcome? {
        guard var session = await sessionStore.load() else {
            throw CoordinatorError(message: "请先登录同步账户。")
        }
        let client = SupabaseHTTPClient(configuration: configuration)
        if session.expiresAt <= Date().addingTimeInterval(60) {
            session = try await client.refresh(session)
            try await sessionStore.save(session)
        }

        let state = await stateStore.load()
        guard let remote = try await client.fetchArchive(session: session),
              remote.revision > state.remoteRevision else {
            return nil
        }
        return try await sync(
            localArchive: localArchive,
            configuration: configuration
        )
    }
}

private struct CoordinatorError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
