package com.cbtipul.app.data

import org.junit.Assert.*
import org.junit.Test
import java.util.Date
import java.util.UUID

class PatientInboxTest {
    private val patient = UUID.randomUUID().toString()
    private val message = UUID.randomUUID().toString()
    private val assignment = UUID.randomUUID().toString()
    private fun notice(type: String, resource: String, id: String, target: String = patient) = AppNotification(
        UUID.randomUUID().toString(), type, target, null, id.takeIf { resource == "assignment" },
        resource, id, Date(20), null, null)
    @Test fun messageAndDeliveryNotificationAreOneItemWithMessageReadState() {
        val personal = PatientMessage(message, patient, "hello", Date(10), Date(15))
        val items = PatientInbox.items(patient, listOf(personal), listOf(notice("message_received", "message", message)))
        assertEquals(1, items.size)
        assertFalse(items.single().isUnread)
    }
    @Test fun filtersOtherPatientsAndTherapistEventsAndSortsNewestFirst() {
        val items = PatientInbox.items(patient, listOf(PatientMessage(message, patient, "hello", Date(10), null)), listOf(
            notice("diary_1_assigned", "assignment", assignment),
            notice("questionnaire_assigned", "assignment", assignment, "someone-else"),
            notice("questionnaire_completed", "questionnaire", assignment)))
        assertEquals(2, items.size)
        assertEquals(assignment, items.first().notification?.assignmentId)
        assertTrue(items.all { it.isUnread })
    }
    @Test fun badgeAcknowledgementDoesNotReadAndAssignmentIdsMustAgree() {
        val item = notice("questionnaire_assigned", "assignment", assignment)
        assertTrue(item.acknowledged(Date()).isUnread)
        assertEquals(assignment, PatientInbox.assignmentId(NotificationPayload.from(item)))
        assertNull(PatientInbox.assignmentId(NotificationPayload.from(item.copy(resourceId = UUID.randomUUID().toString()))))
    }
    @Test fun completedOngoingQuestionnaireRemainsAvailableButCancelledOrWrongPatientDoesNot() {
        val active = PatientAssignment(assignment, patient, null, null, "questionnaire", Date(), Date(), null)
        val payload = NotificationPayload.from(notice("questionnaire_assigned", "assignment", assignment))
        assertEquals(active, PatientInbox.assignment(payload, patient, listOf(active)))
        assertNull(PatientInbox.assignment(payload, patient, listOf(active.copy(cancelledAt = Date()))))
        assertNull(PatientInbox.assignment(payload, "someone-else", listOf(active)))
        assertNull(PatientInbox.assignment(payload, patient, emptyList()))
    }
    @Test fun duplicateDeliveryNotificationsDoNotDuplicateMissingMessage() {
        val item = notice("message_received", "message", message)
        assertEquals(1, PatientInbox.items(patient, emptyList(), listOf(item, item.copy(id = UUID.randomUUID().toString()))).size)
    }
}
