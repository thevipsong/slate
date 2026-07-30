package com.thevipsong.slate.data

import android.content.Context
import java.io.File
import java.io.FileOutputStream

class SlateFileStore(context: Context) {
    private val directory = File(context.filesDir, "Slate")
    private val archiveFile = File(directory, "todos.json")
    private val backupFile = File(directory, "todos.backup.json")
    private val olderBackupFile = File(directory, "todos.backup-2.json")

    fun load(): SlateArchive {
        val candidates = listOf(archiveFile, backupFile, olderBackupFile)
        val existing = candidates.filter(File::isFile)
        if (existing.isEmpty()) return SlateArchive()

        var lastError: Throwable? = null
        for (file in existing) {
            try {
                return SlateArchiveCodec.decode(file.readText(Charsets.UTF_8))
            } catch (error: Throwable) {
                lastError = error
            }
        }
        throw IllegalStateException("待办数据和备份均无法读取。", lastError)
    }

    @Synchronized
    fun save(archive: SlateArchive) {
        directory.mkdirs()
        if (backupFile.exists()) {
            olderBackupFile.delete()
            require(backupFile.renameTo(olderBackupFile)) { "无法轮换旧备份。" }
        }
        if (archiveFile.exists()) {
            archiveFile.copyTo(backupFile, overwrite = true)
        }

        val temporary = File(directory, ".todos.${System.nanoTime()}.tmp")
        FileOutputStream(temporary).use { stream ->
            stream.write(SlateArchiveCodec.encode(archive).toByteArray(Charsets.UTF_8))
            stream.fd.sync()
        }

        if (archiveFile.exists()) archiveFile.delete()
        require(temporary.renameTo(archiveFile)) { "无法写入待办数据。" }
    }
}
