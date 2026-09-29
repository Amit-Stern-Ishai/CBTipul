package com.cbtipul.app.ui.therapist

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TabReselectionTest {
    @Test fun readingHistoryCanReturnToRoot() {
        assertTrue(canResetPatientsTab("patient/{id}/questionnaires?graphs={graphs}"))
        assertTrue(canResetPatientsTab("patient/{id}/questionnaire-trends"))
        assertTrue(canResetPatientsTab("patient/{id}/messages/{messageId}"))
    }

    @Test fun editingAndDraftChildrenMustUseGuardedBack() {
        listOf(
            "patient/{id}", "add", "patient/{id}/session/{sessionId}",
            "patient/{id}/session/{sessionId}/analysis",
            "patient/{id}/session/{sessionId}/questionnaire",
            "patient/{id}/questionnaire-result/{moodId}",
            "patient/{id}/formulation/challenge", "patient/{id}/message-compose",
        ).forEach { assertFalse(it, canResetPatientsTab(it)) }
    }

    @Test fun rootAndUnknownDestinationsNeverPopTheRoot() {
        assertFalse(canResetPatientsTab("list"))
        assertFalse(canResetPatientsTab(null))
        assertFalse(canResetPatientsTab("future-editor"))
    }
}
