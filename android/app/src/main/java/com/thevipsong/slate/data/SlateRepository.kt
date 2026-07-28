package com.thevipsong.slate.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.InputStream
import java.io.OutputStream
import java.time.Instant
import java.util.UUID

class SlateRepository(
    private val store: SlateFileStore,
    initialArchive: SlateArchive = store.load(),
    private val onLocalChange: (() -> Unit)? = null
) {
    private val mutex = Mutex()
    private val _archive = MutableStateFlow(SlateArchiveCodec.normalize(initialArchive))
    val archive: StateFlow<SlateArchive> = _archive.asStateFlow()

    suspend fun addTodo(title: String, groupID: String, dueDate: Instant?) {
        val cleanTitle = title.trim()
        if (cleanTitle.isEmpty()) return
        mutate { archive ->
            val nextOrder = archive.items
                .filter { it.groupID == groupID && !it.isDeleted }
                .maxOfOrNull { it.sortOrder ?: 0.0 }
                ?.plus(1.0) ?: 0.0
            archive.copy(
                items = archive.items + SlateTodoItem(
                    title = cleanTitle,
                    groupID = groupID,
                    sortOrder = nextOrder,
                    dueDate = dueDate,
                    updatedAt = Instant.now(),
                    revision = archive.syncRevision + 1
                )
            )
        }
    }

    suspend fun toggleTodo(id: String) = mutateItem(id) { item, revision ->
        val completed = !item.isCompleted
        item.copy(
            isCompleted = completed,
            completedAt = if (completed) Instant.now() else null,
            updatedAt = Instant.now(),
            revision = revision
        )
    }

    suspend fun renameTodo(id: String, title: String) {
        val cleanTitle = title.trim()
        if (cleanTitle.isEmpty()) return
        mutateItem(id) { item, revision ->
            item.copy(title = cleanTitle, updatedAt = Instant.now(), revision = revision)
        }
    }

    suspend fun setDueDate(id: String, dueDate: Instant?) = mutateItem(id) { item, revision ->
        item.copy(dueDate = dueDate, updatedAt = Instant.now(), revision = revision)
    }

    suspend fun deleteTodo(id: String) = mutateItem(id) { item, revision ->
        item.copy(isDeleted = true, updatedAt = Instant.now(), revision = revision)
    }

    suspend fun moveTodo(id: String, targetGroupID: String) = mutateItem(id) { item, revision ->
        val nextOrder = _archive.value.items
            .filter { it.groupID == targetGroupID && !it.isDeleted }
            .maxOfOrNull { it.sortOrder ?: 0.0 }
            ?.plus(1.0) ?: 0.0
        item.copy(
            groupID = targetGroupID,
            sortOrder = nextOrder,
            updatedAt = Instant.now(),
            revision = revision
        )
    }

    suspend fun reorderTodo(sourceID: String, targetID: String) = mutate { archive ->
        val source = archive.items.firstOrNull { it.id == sourceID } ?: return@mutate archive
        val target = archive.items.firstOrNull { it.id == targetID } ?: return@mutate archive
        if (source.groupID != target.groupID) return@mutate archive

        val groupItems = archive.items
            .filter { it.groupID == source.groupID && !it.isDeleted }
            .sortedWith(compareBy<SlateTodoItem> { it.sortOrder ?: Double.MAX_VALUE }.thenBy { it.createdAt })
            .toMutableList()
        val from = groupItems.indexOfFirst { it.id == sourceID }
        val to = groupItems.indexOfFirst { it.id == targetID }
        if (from < 0 || to < 0 || from == to) return@mutate archive
        val moved = groupItems.removeAt(from)
        groupItems.add(to, moved)

        val orderByID = groupItems.mapIndexed { index, item -> item.id to index.toDouble() }.toMap()
        val revision = archive.syncRevision + 1
        archive.copy(
            items = archive.items.map { item ->
                orderByID[item.id]?.let {
                    item.copy(sortOrder = it, updatedAt = Instant.now(), revision = revision)
                } ?: item
            }
        )
    }

    suspend fun addGroup(name: String) {
        val cleanName = name.trim()
        if (cleanName.isEmpty()) return
        mutate { archive ->
            val nextOrder = archive.groups.maxOfOrNull(SlateTodoGroup::sortOrder)?.plus(1.0) ?: 0.0
            archive.copy(
                groups = archive.groups + SlateTodoGroup(
                    id = UUID.randomUUID().toString(),
                    name = cleanName,
                    sortOrder = nextOrder,
                    updatedAt = Instant.now(),
                    revision = archive.syncRevision + 1
                )
            )
        }
    }

    suspend fun renameGroup(id: String, name: String) {
        val cleanName = name.trim()
        if (cleanName.isEmpty()) return
        mutate { archive ->
            val revision = archive.syncRevision + 1
            archive.copy(
                groups = archive.groups.map { group ->
                    if (group.id == id) {
                        group.copy(name = cleanName, updatedAt = Instant.now(), revision = revision)
                    } else group
                }
            )
        }
    }

    suspend fun deleteGroup(id: String) = mutate { archive ->
        val remaining = archive.groups.filter { it.id != id && !it.isDeleted }
        if (remaining.isEmpty()) return@mutate archive
        val fallback = remaining.first().id
        val revision = archive.syncRevision + 1
        archive.copy(
            groups = remaining,
            items = archive.items.map { item ->
                if (item.groupID == id) {
                    item.copy(
                        groupID = fallback,
                        updatedAt = Instant.now(),
                        revision = revision
                    )
                } else item
            }
        )
    }

    suspend fun importFrom(input: InputStream) = withContext(Dispatchers.IO) {
        val decoded = input.bufferedReader(Charsets.UTF_8).use { reader ->
            SlateArchiveCodec.decode(reader.readText())
        }
        mutex.withLock {
            store.save(decoded)
            _archive.value = decoded
            onLocalChange?.invoke()
        }
    }

    suspend fun exportTo(output: OutputStream) = withContext(Dispatchers.IO) {
        // 手动交换文件必须兼容当前 macOS v3 客户端。同步墓碑只保留在
        // Android 本地档案中，不能导出为普通任务，否则旧客户端会重新显示已删除项。
        val exchangeArchive = _archive.value.copy(
            items = _archive.value.items.filterNot(SlateTodoItem::isDeleted),
            groups = _archive.value.groups.filterNot(SlateTodoGroup::isDeleted)
        )
        output.bufferedWriter(Charsets.UTF_8).use { writer ->
            writer.write(SlateArchiveCodec.encode(exchangeArchive))
        }
    }

    suspend fun replaceFromSync(archive: SlateArchive) {
        val normalized = SlateArchiveCodec.normalize(archive)
        mutex.withLock {
            withContext(Dispatchers.IO) { store.save(normalized) }
            _archive.value = normalized
        }
    }

    private suspend fun mutateItem(
        id: String,
        transform: (SlateTodoItem, Long) -> SlateTodoItem
    ) = mutate { archive ->
        val revision = archive.syncRevision + 1
        archive.copy(
            items = archive.items.map { item ->
                if (item.id == id) transform(item, revision) else item
            }
        )
    }

    private suspend fun mutate(transform: (SlateArchive) -> SlateArchive) {
        mutex.withLock {
            val current = _archive.value
            val transformed = transform(current)
            if (transformed == current) return
            val next = SlateArchiveCodec.normalize(
                transformed.copy(syncRevision = current.syncRevision + 1)
            )
            withContext(Dispatchers.IO) { store.save(next) }
            _archive.value = next
            onLocalChange?.invoke()
        }
    }
}
