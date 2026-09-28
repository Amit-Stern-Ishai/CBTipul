package com.cbtipul.app.data

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

class PatientInvitationRequestTest {
    @Test
    fun createRequestIncludesPatientIdAndInitialKind() {
        val json = PatientInvitationService.encodeCreateRequest("patient-1")
        val obj = EdgePayload.json.parseToJsonElement(json) as JsonObject
        assertEquals("patient-1", obj.getValue("patientId").jsonPrimitive.content)
        assertEquals("initial", obj.getValue("kind").jsonPrimitive.content)
        assertEquals(setOf("patientId", "kind"), obj.keys)
    }

    @Test
    fun invitationResponseMapsCamelCaseAndUrl() {
        val invitation = PatientInvitationService.invitationFromEdgeJson(
            """
            {
              "invitationId": "11111111-1111-1111-1111-111111111111",
              "invitationUrl": "https://cbtipul.com/invite/opaque-token",
              "expiresAt": "2026-09-29T00:00:00Z"
            }
            """.trimIndent(),
        )
        assertEquals("11111111-1111-1111-1111-111111111111", invitation.invitationId)
        assertEquals("https://cbtipul.com/invite/opaque-token", invitation.invitationUrl)
    }
}
