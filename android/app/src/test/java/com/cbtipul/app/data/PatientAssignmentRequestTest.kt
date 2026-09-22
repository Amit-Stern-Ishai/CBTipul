package com.cbtipul.app.data

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class PatientAssignmentRequestTest {
    @Test
    fun questionnaireRequestContainsOnlyPatientIdAndSessionId() {
        val json = PatientAssignmentRepository.encodeQuestionnaireRequest(
            patientId = "patient-1",
            sessionId = "session-1",
        )
        val obj = EdgePayload.json.parseToJsonElement(json) as JsonObject
        assertEquals("patient-1", obj.getValue("patientId").jsonPrimitive.content)
        assertEquals("session-1", obj.getValue("sessionId").jsonPrimitive.content)
        assertFalse(obj.containsKey("therapistId"))
        assertFalse(obj.containsKey("therapist_id"))
        assertEquals(setOf("patientId", "sessionId"), obj.keys)
    }

    @Test
    fun edgeFunctionResponseMapsToAssignmentModel() {
        val assignment = PatientAssignmentRepository.assignmentFromEdgeJson(
            """
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "patient_id": "22222222-2222-2222-2222-222222222222",
              "therapist_id": "33333333-3333-3333-3333-333333333333",
              "session_id": "44444444-4444-4444-4444-444444444444",
              "type": "questionnaire",
              "created_at": "2026-09-22T12:34:56.789+00:00",
              "completed_at": null,
              "cancelled_at": null
            }
            """.trimIndent(),
        )
        assertEquals("11111111-1111-1111-1111-111111111111", assignment.id)
        assertEquals("22222222-2222-2222-2222-222222222222", assignment.patientId)
        assertEquals("33333333-3333-3333-3333-333333333333", assignment.therapistId)
        assertEquals("44444444-4444-4444-4444-444444444444", assignment.sessionId)
        assertEquals("questionnaire", assignment.typeValue)
        assertNull(assignment.completedAt)
        assertNull(assignment.cancelledAt)
        val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            time = assignment.createdAt
        }
        assertEquals(2026, calendar.get(Calendar.YEAR))
        assertEquals(Calendar.SEPTEMBER, calendar.get(Calendar.MONTH))
        assertEquals(22, calendar.get(Calendar.DAY_OF_MONTH))
        assertEquals(12, calendar.get(Calendar.HOUR_OF_DAY))
        assertEquals(34, calendar.get(Calendar.MINUTE))
        assertEquals(56, calendar.get(Calendar.SECOND))
    }

    @Test
    fun postgresTimestampsParseWithAndWithoutFractionAndOffset() {
        PatientAssignmentRepository.parseAssignmentTimestamp("2026-09-22T12:34:56Z")
        PatientAssignmentRepository.parseAssignmentTimestamp("2026-09-22T12:34:56.123Z")
        PatientAssignmentRepository.parseAssignmentTimestamp("2026-09-22T12:34:56+00:00")
        PatientAssignmentRepository.parseAssignmentTimestamp("2026-09-22T12:34:56.123456+00:00")
    }

    @Test
    fun patientNotConnectedMapsToDomainError() {
        assertEquals(
            PatientAssignmentException.PatientNotConnected,
            PatientAssignmentRepository.mapRequestQuestionnaireCode("patient_not_connected", 400),
        )
    }

    @Test
    fun unauthorizedMapsToNotSignedIn() {
        assertEquals(
            PatientAssignmentException.NotSignedIn,
            PatientAssignmentRepository.mapRequestQuestionnaireCode("unauthorized", 401),
        )
        assertEquals(
            PatientAssignmentException.NotSignedIn,
            PatientAssignmentRepository.mapRequestQuestionnaireCode("", 403),
        )
    }

    @Test
    fun otherBackendFailuresMapToGenericInvalidIdentifier() {
        assertEquals(
            PatientAssignmentException.InvalidIdentifier,
            PatientAssignmentRepository.mapRequestQuestionnaireCode("patient_not_found", 404),
        )
        assertEquals(
            PatientAssignmentException.InvalidIdentifier,
            PatientAssignmentRepository.mapRequestQuestionnaireCode("session_not_found", 404),
        )
        assertEquals(
            PatientAssignmentException.InvalidIdentifier,
            PatientAssignmentRepository.mapRequestQuestionnaireCode("assignment_failed", 500),
        )
    }
}
