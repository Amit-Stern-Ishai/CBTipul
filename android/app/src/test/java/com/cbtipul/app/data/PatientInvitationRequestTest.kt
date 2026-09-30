package com.cbtipul.app.data

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
    fun replacementRequestPreservesPatientAndUsesBackendContract() {
        val json = PatientInvitationService.encodeCreateRequest("patient-1", InvitationKind.Replacement)
        val obj = EdgePayload.json.parseToJsonElement(json) as JsonObject
        assertEquals("patient-1", obj.getValue("patientId").jsonPrimitive.content)
        assertEquals("replacement", obj.getValue("kind").jsonPrimitive.content)
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

    @Test
    fun shareMessageIncludesTherapistNameExactUrlAndNewCopy() {
        val name = "דנה כהן"
        val url = "https://cbtipul.com/invite/opaque-token"
        val body = PatientInvitationShare.message(name, url)
        assertTrue(body.contains(name))
        assertTrue(body.contains(url))
        assertEquals(body.indexOf(url), body.lastIndexOf(url))
        assertTrue(body.contains("דרך האפליקציה ניתן למלא שאלונים ויומנים ולצפות בתכנים שנשלחו אליך כחלק מהטיפול."))
        assertTrue(body.contains("ההזמנה אישית ומיועדת עבורך בלבד."))
        assertTrue(body.contains("$name הזמין/ה אותך להתחבר ל-CBTipul."))
        assertTrue(body.contains("לפתיחת ההזמנה:"))
        assertFalse(body.contains("הוזמנת להתחבר ל-CBTipul על ידי"))
        assertFalse(body.contains("להתחברות:"))
        assertEquals("הזמנה להתחבר ל-CBTipul", PatientInvitationShare.SUBJECT)
        assertFalse(body.contains("patientId"))
        assertFalse(body.contains("patient_id"))
        assertFalse(body.contains("Supabase"))
    }
}
