package com.cbtipul.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

class PatientMessageTest {
    private fun msg(id: String, unread: Boolean, time: Long) = PatientMessage(
        id = id,
        patientId = "p",
        body = "body-$id",
        createdAt = Date(time),
        readAt = if (unread) null else Date(time),
    )

    @Test
    fun unreadPreviewsNewestFirstMaxTwo() {
        val messages = listOf(
            msg("a", true, 1),
            msg("b", true, 3),
            msg("c", false, 4),
            msg("d", true, 2),
        )
        val previews = PatientHomeMessages.previews(messages)
        assertEquals(listOf("b", "d"), previews.map { it.id })
        assertEquals(1, PatientHomeMessages.remainingUnreadCount(messages))
    }

    @Test
    fun zeroUnreadHasNoPreviews() {
        val messages = listOf(msg("a", false, 1), msg("b", false, 2))
        assertTrue(PatientHomeMessages.previews(messages).isEmpty())
        assertEquals(0, PatientHomeMessages.remainingUnreadCount(messages))
    }

    @Test
    fun readingRemovesFromUnreadPreview() {
        val messages = listOf(msg("a", true, 1), msg("b", true, 2), msg("c", true, 3))
        val after = messages.map { if (it.id == "c") it.markedRead(Date()) else it }
        assertEquals(listOf("b", "a"), PatientHomeMessages.previews(after).map { it.id })
        assertEquals(0, PatientHomeMessages.remainingUnreadCount(after))
    }

    @Test
    fun draftRejectsEmptyAndTooLong() {
        assertFalse(PatientMessageDraft.canSend("   "))
        assertTrue(PatientMessageDraft.canSend("hello"))
        assertFalse(PatientMessageDraft.canSend("x".repeat(PatientMessageDraft.MAX_LENGTH + 1)))
    }
}
