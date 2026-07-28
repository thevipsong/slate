package com.thevipsong.slate.data

import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

object SlateArchiveCodec {
    val json = Json {
        encodeDefaults = true
        explicitNulls = false
        ignoreUnknownKeys = true
        prettyPrint = true
    }

    fun encode(archive: SlateArchive): String = json.encodeToString(archive)

    fun decode(raw: String): SlateArchive {
        val archive = try {
            json.decodeFromString<SlateArchive>(raw)
        } catch (error: SerializationException) {
            throw IllegalArgumentException("文件不是有效的 Slate 待办数据。", error)
        }

        require(archive.version == SlateArchive.CURRENT_VERSION) {
            "暂不支持 Slate v${archive.version} 数据。"
        }
        return normalize(archive)
    }

    fun normalize(source: SlateArchive): SlateArchive {
        val activeGroups = source.groups
            .filterNot(SlateTodoGroup::isDeleted)
            .distinctBy(SlateTodoGroup::id)
            .ifEmpty { listOf(SlateTodoGroup.default()) }
        val validGroupIDs = activeGroups.mapTo(mutableSetOf(), SlateTodoGroup::id)
        val fallbackID = activeGroups.first().id
        val items = source.items
            .distinctBy(SlateTodoItem::id)
            .map { item ->
                item.copy(
                    title = item.title.trim(),
                    groupID = item.groupID?.takeIf(validGroupIDs::contains) ?: fallbackID
                )
            }
            .filter { it.title.isNotBlank() }

        return source.copy(items = items, groups = activeGroups)
    }
}
