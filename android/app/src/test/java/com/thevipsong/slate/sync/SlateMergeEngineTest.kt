package com.thevipsong.slate.sync

import com.thevipsong.slate.data.SlateArchive
import com.thevipsong.slate.data.SlateTodoGroup
import com.thevipsong.slate.data.SlateTodoItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SlateMergeEngineTest {
    private val group = SlateTodoGroup(id = "G", name = "待办")
    private val first = SlateTodoItem(id = "A", title = "第一项", groupID = "G")
    private val second = SlateTodoItem(id = "B", title = "第二项", groupID = "G")
    private val base = SlateArchive(items = listOf(first, second), groups = listOf(group))

    @Test
    fun independentEditsFromBothDevicesArePreserved() {
        val local = base.copy(items = listOf(first.copy(title = "本地修改"), second))
        val remote = base.copy(items = listOf(first, second.copy(title = "远端修改")))

        val result = SlateMergeEngine.merge(base, local, remote, preferLocalOnConflict = true)

        assertEquals("本地修改", result.archive.items.first { it.id == "A" }.title)
        assertEquals("远端修改", result.archive.items.first { it.id == "B" }.title)
        assertTrue(result.conflictingIDs.isEmpty())
    }

    @Test
    fun deletionWinsWhenOtherSideDidNotChangeEntity() {
        val local = base.copy(items = listOf(second))

        val result = SlateMergeEngine.merge(base, local, base, preferLocalOnConflict = true)

        assertFalse(result.archive.items.any { it.id == "A" })
        assertTrue(result.conflictingIDs.isEmpty())
    }

    @Test
    fun simultaneousEditIsReportedAndPreferenceIsDeterministic() {
        val local = base.copy(items = listOf(first.copy(title = "本地"), second))
        val remote = base.copy(items = listOf(first.copy(title = "远端"), second))

        val result = SlateMergeEngine.merge(base, local, remote, preferLocalOnConflict = false)

        assertEquals("远端", result.archive.items.first { it.id == "A" }.title)
        assertEquals(setOf("A"), result.conflictingIDs)
    }

    @Test
    fun duplicateRemoteIDsUseNewestSerializedValueWithoutCrashing() {
        val remote = SlateArchive(
            items = listOf(
                first.copy(title = "远端旧值"),
                first.copy(title = "远端新值")
            ),
            groups = listOf(group)
        )

        val result = SlateMergeEngine.merge(
            base = null,
            local = SlateArchive(items = emptyList(), groups = listOf(group)),
            remote = remote,
            preferLocalOnConflict = false
        )

        assertEquals(1, result.archive.items.size)
        assertEquals("远端新值", result.archive.items.single().title)
    }
}
