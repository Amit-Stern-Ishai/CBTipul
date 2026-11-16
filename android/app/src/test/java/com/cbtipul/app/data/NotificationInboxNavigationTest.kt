package com.cbtipul.app.data

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationInboxNavigationTest {
    @Test fun notificationsOpenOnlyTheirFinalDestination() {
        assertEquals("patient/p?connection=send", NotificationRouting.inboxRoute(AppDestination.PatientDetail("p")))
        assertEquals("patient/p/questionnaire-result/42", NotificationRouting.inboxRoute(AppDestination.QuestionnaireResult("p", "42")))
        assertEquals("patient/p/questionnaires", NotificationRouting.inboxRoute(AppDestination.QuestionnaireResult("p", null)))
        assertEquals("patient/p/diary-one?entry=e", NotificationRouting.inboxRoute(AppDestination.DiaryOneEntry("p", "e")))
        assertEquals("patient/p/diary-two?entry=e", NotificationRouting.inboxRoute(AppDestination.DiaryTwoEntry("p", "e")))
        assertEquals("patient/p/diary-three?entry=e", NotificationRouting.inboxRoute(AppDestination.DiaryThreeEntry("p", "e")))
    }
    @Test fun joinedPushSurvivesColdStartAndUsesSameActivityRouteAsInbox() {
        val payload = NotificationPayload.from(mapOf("type" to "patient_connected", "patient_id" to "p"))!!
        val pending = PendingDestinationStore()
        pending.offer(payload) // Offered before any therapist NavHost exists.
        val destination = pending.pending.value!!
        assertEquals("patient/p?connection=send", NotificationRouting.inboxRoute(destination))
        assertEquals(listOf("patient/p?connection=send"), NotificationRouting.therapistRoutes(pending.consume()!!))
        assertEquals(null, pending.consume())
        pending.offer(payload) // A warm notification tap follows the identical route.
        assertEquals("patient/p?connection=send", NotificationRouting.inboxRoute(pending.consume()!!))
    }

}
