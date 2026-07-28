package com.thevipsong.slate.sync

import com.thevipsong.slate.data.SlateRepository
import java.time.Instant

class SlateSyncCoordinator(
    private val repository: SlateRepository,
    private val stateStore: LocalSyncStateStore,
    private val sessionStore: SecureSessionStore
) {
    suspend fun sync(configuration: SupabaseConfiguration): SyncOutcome {
        var session = sessionStore.load() ?: error("请先登录同步账户。")
        val api = SupabaseHTTPClient(configuration)
        if (session.expiresAtEpochSeconds <= Instant.now().epochSecond + 60) {
            session = api.refresh(session)
            sessionStore.save(session)
        }

        var localState = stateStore.load()
        var candidate = repository.archive.value
        var conflicts = emptySet<String>()

        repeat(MAX_ATTEMPTS) {
            val response = api.sync(
                session = session,
                expectedRevision = localState.remoteRevision,
                archive = candidate,
                deviceID = localState.deviceID
            )
            if (response.accepted) {
                if (candidate != repository.archive.value) {
                    repository.replaceFromSync(candidate)
                }
                val syncedAt = Instant.now()
                stateStore.save(
                    localState.copy(
                        baseArchive = candidate,
                        remoteRevision = response.revision,
                        lastSyncedAt = syncedAt
                    )
                )
                return SyncOutcome(response.revision, conflicts.size, syncedAt)
            }

            val preferLocal = localState.localModifiedAt >= response.updatedAt
            val merged = SlateMergeEngine.merge(
                base = localState.baseArchive,
                local = repository.archive.value,
                remote = response.archive,
                preferLocalOnConflict = preferLocal
            )
            conflicts = conflicts + merged.conflictingIDs
            candidate = merged.archive
            localState = localState.copy(remoteRevision = response.revision)
        }

        error("云端数据持续变化，已保留本地内容，请稍后重试。")
    }

    companion object {
        private const val MAX_ATTEMPTS = 3
    }
}
