package com.thevipsong.slate.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class SlateArchiveCodecTest {
    @Test
    fun roundTripPreservesMacCompatibleFields() {
        val group = SlateTodoGroup(id = "A", name = "工作", systemImage = "briefcase")
        val item = SlateTodoItem(
            id = "B",
            title = "准备合同",
            groupID = group.id,
            createdAt = Instant.parse("2026-07-28T08:00:00Z"),
            dueDate = Instant.parse("2026-07-29T00:00:00Z")
        )
        val decoded = SlateArchiveCodec.decode(
            SlateArchiveCodec.encode(SlateArchive(items = listOf(item), groups = listOf(group)))
        )

        assertEquals("准备合同", decoded.items.single().title)
        assertEquals("工作", decoded.groups.single().name)
        assertEquals(3, decoded.version)
    }

    @Test
    fun decodeAcceptsMacArchiveWithoutSyncFields() {
        val raw = """
            {
              "version": 3,
              "groups": [{"id":"A","name":"财务相关","sortOrder":0,"systemImage":"folder"}],
              "items": [{
                "id":"B",
                "title":"开发票",
                "isCompleted":false,
                "createdAt":"2026-07-28T08:00:00Z",
                "groupID":"A",
                "sortOrder":0
              }]
            }
        """.trimIndent()

        val decoded = SlateArchiveCodec.decode(raw)

        assertEquals("A", decoded.items.single().groupID)
        assertFalse(decoded.items.single().isDeleted)
        assertEquals(0, decoded.items.single().revision)
    }

    @Test
    fun normalizationRepairsMissingGroupAndBlankItems() {
        val archive = SlateArchive(
            groups = emptyList(),
            items = listOf(
                SlateTodoItem(title = "  保留  ", groupID = "missing"),
                SlateTodoItem(title = "   ")
            )
        )

        val normalized = SlateArchiveCodec.normalize(archive)

        assertTrue(normalized.groups.isNotEmpty())
        assertEquals(listOf("保留"), normalized.items.map(SlateTodoItem::title))
        assertEquals(normalized.groups.first().id, normalized.items.first().groupID)
    }
}
