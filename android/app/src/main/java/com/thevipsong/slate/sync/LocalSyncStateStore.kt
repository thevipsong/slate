package com.thevipsong.slate.sync

import android.content.Context
import com.thevipsong.slate.data.SlateArchiveCodec
import java.io.File
import java.time.Instant

class LocalSyncStateStore(context: Context) {
    private val file = File(File(context.filesDir, "Slate"), "sync-state.json")

    @Synchronized
    fun load(): LocalSyncState {
        if (!file.isFile) return LocalSyncState()
        return runCatching {
            SlateArchiveCodec.json.decodeFromString<LocalSyncState>(file.readText(Charsets.UTF_8))
        }.getOrDefault(LocalSyncState())
    }

    @Synchronized
    fun save(state: LocalSyncState) {
        file.parentFile?.mkdirs()
        val temporary = File(file.parentFile, ".sync-state.${System.nanoTime()}.tmp")
        temporary.writeText(
            SlateArchiveCodec.json.encodeToString(state),
            Charsets.UTF_8
        )
        if (file.exists()) file.delete()
        require(temporary.renameTo(file)) { "无法保存同步状态。" }
    }

    @Synchronized
    fun markLocalChange() {
        save(load().copy(localModifiedAt = Instant.now()))
    }

    @Synchronized
    fun clearBaseline() {
        val current = load()
        save(
            LocalSyncState(
                deviceID = current.deviceID,
                localModifiedAt = Instant.now()
            )
        )
    }
}
