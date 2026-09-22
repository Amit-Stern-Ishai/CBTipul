package com.cbtipul.app.push

import org.junit.Assert.assertEquals
import org.junit.Test

class PatientPushPersonalizerTest {
    private val connectedGeneric = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
    private val questionnaireGeneric = "מטופל/ת מילא/ה שאלון חדש"
    private val names = mapOf("known-id" to "דני")

    @Test
    fun patientConnectedKnownIdUsesLocalName() {
        val result = personalize(
            type = "patient_connected",
            patientId = "known-id",
            fallback = connectedGeneric,
        )
        assertEquals("CBTipul", result.title)
        assertEquals("דני התחבר/ה בהצלחה ל-CBTipul", result.body)
    }

    @Test
    fun patientConnectedUnknownIdUsesGenericFallback() {
        val result = personalize(
            type = "patient_connected",
            patientId = "unknown-id",
            fallback = connectedGeneric,
        )
        assertEquals(connectedGeneric, result.body)
    }

    @Test
    fun patientConnectedMissingPatientIdUsesGenericFallback() {
        val result = personalize(
            type = "patient_connected",
            patientId = null,
            fallback = connectedGeneric,
        )
        assertEquals(connectedGeneric, result.body)
        assertEquals(null, result.patientId)
    }

    @Test
    fun questionnaireCompletedKnownIdUsesLocalName() {
        val result = personalize(
            type = "questionnaire_completed",
            patientId = "known-id",
            fallback = questionnaireGeneric,
            assignmentId = "assign-1",
            sessionId = "session-1",
        )
        assertEquals("דני מילא/ה שאלון חדש", result.body)
        assertEquals("assign-1", result.assignmentId)
        assertEquals("session-1", result.sessionId)
    }

    @Test
    fun questionnaireCompletedUnknownIdUsesGenericFallback() {
        val result = personalize(
            type = "questionnaire_completed",
            patientId = "unknown-id",
            fallback = questionnaireGeneric,
            assignmentId = "assign-1",
            sessionId = "session-1",
        )
        assertEquals(questionnaireGeneric, result.body)
        assertEquals("assign-1", result.assignmentId)
        assertEquals("session-1", result.sessionId)
    }

    @Test
    fun questionnaireCompletedMissingPatientIdUsesGenericFallback() {
        val result = personalize(
            type = "questionnaire_completed",
            patientId = null,
            fallback = questionnaireGeneric,
            assignmentId = "assign-1",
            sessionId = "session-1",
        )
        assertEquals(questionnaireGeneric, result.body)
        assertEquals(null, result.patientId)
        assertEquals("assign-1", result.assignmentId)
        assertEquals("session-1", result.sessionId)
    }

    @Test
    fun unrelatedTypePreservesSuppliedContentAndMetadata() {
        val result = PatientPushPersonalizer.personalize(
            type = "other",
            patientId = "known-id",
            fallbackTitle = "Other title",
            fallbackBody = "Other body",
            assignmentId = "assign-1",
            sessionId = "session-1",
            nameForPatientId = { names[it] },
        )
        assertEquals("Other title", result.title)
        assertEquals("Other body", result.body)
        assertEquals("assign-1", result.assignmentId)
        assertEquals("session-1", result.sessionId)
    }

    @Test
    fun nameLookupFailureUsesGenericFallback() {
        val result = PatientPushPersonalizer.personalize(
            type = "patient_connected",
            patientId = "known-id",
            fallbackTitle = "CBTipul",
            fallbackBody = connectedGeneric,
            nameForPatientId = { error("unavailable") },
        )
        assertEquals(connectedGeneric, result.body)
    }

    private fun personalize(
        type: String?,
        patientId: String?,
        fallback: String,
        assignmentId: String? = null,
        sessionId: String? = null,
    ) = PatientPushPersonalizer.personalize(
        type = type,
        patientId = patientId,
        fallbackTitle = "CBTipul",
        fallbackBody = fallback,
        assignmentId = assignmentId,
        sessionId = sessionId,
        nameForPatientId = { names[it] },
    )
}
