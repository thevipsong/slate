package com.thevipsong.slate.data

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
data class SlateTodoItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val isCompleted: Boolean = false,
    @Serializable(with = InstantIsoSerializer::class)
    val createdAt: Instant = Instant.now(),
    @Serializable(with = NullableInstantIsoSerializer::class)
    val completedAt: Instant? = null,
    val groupID: String? = null,
    val sortOrder: Double? = null,
    @Serializable(with = NullableInstantIsoSerializer::class)
    val dueDate: Instant? = null,
    @Serializable(with = NullableInstantIsoSerializer::class)
    val updatedAt: Instant? = null,
    val revision: Long = 0,
    val isDeleted: Boolean = false
)

@Serializable
data class SlateTodoGroup(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val sortOrder: Double = 0.0,
    val systemImage: String = "folder",
    @Serializable(with = NullableInstantIsoSerializer::class)
    val updatedAt: Instant? = null,
    val revision: Long = 0,
    val isDeleted: Boolean = false
) {
    companion object {
        fun default() = SlateTodoGroup(
            name = "待办",
            systemImage = "checklist",
            updatedAt = Instant.now()
        )
    }
}

@Serializable
data class SlateArchive(
    val version: Int = CURRENT_VERSION,
    val items: List<SlateTodoItem> = emptyList(),
    val groups: List<SlateTodoGroup> = listOf(SlateTodoGroup.default()),
    val syncRevision: Long = 0
) {
    companion object {
        const val CURRENT_VERSION = 3
    }
}

enum class TodoFilter {
    ALL,
    PENDING,
    COMPLETED,
    OVERDUE
}

enum class SlateThemeMode {
    SYSTEM,
    DARK,
    LIGHT
}
