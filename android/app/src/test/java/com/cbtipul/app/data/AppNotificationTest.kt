package com.cbtipul.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

class AppNotificationTest {
    private val uuid = "11111111-1111-1111-1111-111111111111"
    private val patient = "22222222-2222-2222-2222-222222222222"

    @Test fun diaryDeepLinkStartsAtExactDetailWithoutHistory() {
        assertEquals("detail/$uuid", NotificationRouting.diaryStartRoute(uuid))
        assertEquals("history", NotificationRouting.diaryStartRoute(null))
        assertEquals("history", NotificationRouting.diaryStartRoute(""))
    }

    @Test
    fun completedQuestionnaireHasAHistoryScreenToGoBackTo() {
        assertEquals(
            listOf("patient/$patient", "patient/$patient/questionnaires", "patient/$patient/questionnaire-result/42"),
            NotificationRouting.therapistRoutes(AppDestination.QuestionnaireResult(patient, "42")),
        )
    }

    @Test
    fun questionnaireWithoutAValidResourceOpensHistory() {
        assertEquals(
            listOf("patient/$patient", "patient/$patient/questionnaires"),
            NotificationRouting.therapistRoutes(AppDestination.QuestionnaireResult(patient, null)),
        )
    }

    @Test
    fun diaryNotificationKeepsThePatientAsItsParent() {
        assertEquals(
            listOf("patient/$patient", "patient/$patient/diary-one?entry=$uuid"),
            NotificationRouting.therapistRoutes(AppDestination.DiaryOneEntry(patient, uuid)),
        )
    }

    @Test
    fun seenAndReadAreIndependent() {
        val item = AppNotification(uuid, "patient_connected", patient, null, null, null, null, Date(), null, null)
        assertTrue(item.isUnseen)
        assertTrue(item.isUnread)
        val seen = item.acknowledged(Date())
        assertFalse(seen.isUnseen)
        assertTrue(seen.isUnread)
        val read = seen.opened(Date())
        assertFalse(read.isUnseen)
        assertFalse(read.isUnread)
    }

    @Test
    fun applyingSeenDoesNotMarkRead() {
        val items = listOf(
            AppNotification("1", "x", null, null, null, null, null, Date(), null, null),
        )
        val next = NotificationInbox.applyingSeen(items, Date())
        assertTrue(next.all { !it.isUnseen && it.isUnread })
    }

    @Test
    fun unknownTypeDoesNotCrash() {
        val payload = NotificationPayload.from(mapOf("type" to "file_received", "resourceId" to "abc"))
        assertEquals("file_received", payload?.type)
        assertNull(NotificationRouting.destination(payload!!))
    }

    @Test
    fun patientConnectedRoutesToDetail() {
        val dest = NotificationRouting.destination(
            NotificationPayload("patient_connected", null, patient, null, null, null, null),
        )
        assertEquals(AppDestination.PatientDetail(patient), dest)
    }

    @Test
    fun questionnaireAssignedUsesAssignmentId() {
        val dest = NotificationRouting.destination(
            NotificationPayload("questionnaire_assigned", null, patient, null, uuid, "assignment", uuid),
        )
        assertEquals(AppDestination.PatientQuestionnaire(uuid, NotificationPayload("questionnaire_assigned", null, patient, null, uuid, "assignment", uuid)), dest)
    }

    @Test
    fun questionnaireCompletedRequiresQuestionnaireResource() {
        val dest = NotificationRouting.destination(
            NotificationPayload("questionnaire_completed", null, patient, null, null, "questionnaire", "42"),
        )
        assertEquals(AppDestination.QuestionnaireResult(patient, "42"), dest)
        assertNull(NotificationRouting.combinedMoodId("message", "42"))
        assertNull(NotificationRouting.combinedMoodId("questionnaire", "not-a-number"))
    }

    @Test
    fun messageReceivedUsesMessageResource() {
        val dest = NotificationRouting.destination(
            NotificationPayload("message_received", null, patient, null, null, "message", uuid),
        )
        assertEquals(uuid, (dest as AppDestination.PatientMessage).messageId)
        assertEquals(patient, dest.payload?.patientId)
        assertNull(NotificationRouting.messageId("assignment", uuid))
    }

    @Test
    fun diaryAssignedOpensForm() {
        val dest = NotificationRouting.destination(
            NotificationPayload("diary_1_assigned", null, patient, null, uuid, "assignment", uuid),
        )
        assertEquals(uuid, (dest as AppDestination.PatientDiaryOneForm).assignmentId)
        assertEquals(patient, dest.payload?.patientId)
    }

    @Test
    fun diaryEntryAddedRequiresEntryResource() {
        val dest = NotificationRouting.destination(
            NotificationPayload("diary_1_entry_added", null, patient, null, null, "diary_one_entry", uuid),
        )
        assertEquals(AppDestination.DiaryOneEntry(patient, uuid), dest)
        assertNull(NotificationRouting.diaryEntryId("diary_one_entry", "bad"))
        assertNull(NotificationRouting.diaryEntryId("questionnaire", uuid))
    }

    @Test
    fun malformedUuidIsRejected() {
        assertNull(NotificationRouting.uuidOrNull("not-uuid"))
        assertNull(NotificationRouting.assignmentId(NotificationPayload("x", null, null, null, "nope", null, null)))
    }
}
