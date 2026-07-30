package com.thevipsong.slate.sync

import com.thevipsong.slate.data.SlateArchive
import com.thevipsong.slate.data.SlateArchiveCodec
import com.thevipsong.slate.data.SlateTodoGroup
import com.thevipsong.slate.data.SlateTodoItem
import kotlin.math.max

data class SlateMergeResult(
    val archive: SlateArchive,
    val conflictingIDs: Set<String>
)

object SlateMergeEngine {
    fun merge(
        base: SlateArchive?,
        local: SlateArchive,
        remote: SlateArchive,
        preferLocalOnConflict: Boolean
    ): SlateMergeResult {
        val conflicts = mutableSetOf<String>()
        val groups = mergeEntities(
            base = base?.groups.orEmpty(),
            local = local.groups,
            remote = remote.groups,
            id = SlateTodoGroup::id,
            preferLocal = preferLocalOnConflict,
            conflicts = conflicts
        )
        val items = mergeEntities(
            base = base?.items.orEmpty(),
            local = local.items,
            remote = remote.items,
            id = SlateTodoItem::id,
            preferLocal = preferLocalOnConflict,
            conflicts = conflicts
        )
        val merged = SlateArchiveCodec.normalize(
            SlateArchive(
                version = SlateArchive.CURRENT_VERSION,
                items = items,
                groups = groups,
                syncRevision = max(local.syncRevision, remote.syncRevision) + 1
            )
        )
        return SlateMergeResult(merged, conflicts)
    }

    private fun <T> mergeEntities(
        base: List<T>,
        local: List<T>,
        remote: List<T>,
        id: (T) -> String,
        preferLocal: Boolean,
        conflicts: MutableSet<String>
    ): List<T> {
        val baseByID = base.associateBy(id)
        val localByID = local.associateBy(id)
        val remoteByID = remote.associateBy(id)
        val allIDs = baseByID.keys + localByID.keys + remoteByID.keys

        return allIDs.mapNotNull { entityID ->
            val baseline = baseByID[entityID]
            val localValue = localByID[entityID]
            val remoteValue = remoteByID[entityID]
            when {
                localValue == remoteValue -> localValue
                localValue == baseline -> remoteValue
                remoteValue == baseline -> localValue
                else -> {
                    conflicts += entityID
                    if (preferLocal) localValue else remoteValue
                }
            }
        }
    }
}
