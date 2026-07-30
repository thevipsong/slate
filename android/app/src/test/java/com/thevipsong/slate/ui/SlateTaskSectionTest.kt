package com.thevipsong.slate.ui

import com.thevipsong.slate.data.SlateTodoItem
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Test

class SlateTaskSectionTest {
    private val today = LocalDate.of(2026, 7, 29)

    @Test
    fun tasksAreGroupedByTimeAndCompletion() {
        val items = listOf(
            task("past", "2026-07-28T00:00:00Z"),
            task("today", "2026-07-29T00:00:00Z"),
            task("future", "2026-07-30T00:00:00Z"),
            SlateTodoItem(id = "none", title = "none"),
            SlateTodoItem(id = "done", title = "done", isCompleted = true)
        )

        val sections = buildTaskSections(items, today, ZoneOffset.UTC)

        assertEquals(
            listOf("overdue", "today", "upcoming", "no-date", "completed"),
            sections.map(SlateTaskSection::key)
        )
        assertEquals(listOf("past"), sections[0].items.map(SlateTodoItem::id))
        assertEquals(listOf("done"), sections.last().items.map(SlateTodoItem::id))
    }

    private fun task(id: String, date: String) = SlateTodoItem(
        id = id,
        title = id,
        dueDate = Instant.parse(date)
    )
}
