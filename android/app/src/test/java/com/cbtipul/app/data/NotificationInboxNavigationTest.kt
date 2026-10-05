package com.cbtipul.app.data

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationInboxNavigationTest {
    @Test fun notificationsOpenOnlyTheirFinalDestination() {
        assertEquals("patient/p", NotificationRouting.inboxRoute(AppDestination.PatientDetail("p")))
        assertEquals("patient/p/questionnaire-result/42", NotificationRouting.inboxRoute(AppDestination.QuestionnaireResult("p", "42")))
        assertEquals("patient/p/questionnaires", NotificationRouting.inboxRoute(AppDestination.QuestionnaireResult("p", null)))
        assertEquals("patient/p/diary-one?entry=e", NotificationRouting.inboxRoute(AppDestination.DiaryOneEntry("p", "e")))
        assertEquals("patient/p/diary-two?entry=e", NotificationRouting.inboxRoute(AppDestination.DiaryTwoEntry("p", "e")))
        assertEquals("patient/p/diary-three?entry=e", NotificationRouting.inboxRoute(AppDestination.DiaryThreeEntry("p", "e")))
    }
}
