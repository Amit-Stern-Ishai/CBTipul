package com.cbtipul.app.push

import org.junit.Assert.assertEquals
import org.junit.Test

class PatientPushPersonalizerTest {
    private val generic = "המטופל/ת התחבר/ה בהצלחה ל-CBTipul"
    private val names = mapOf("known-id" to "דני")

    @Test
    fun patientConnectedKnownIdUsesLocalName() {
        val result = personalize(type = "patient_connected", patientId = "known-id", fallback = generic)
        assertEquals("CBTipul", result.title)
        assertEquals("דני התחבר/ה בהצלחה ל-CBTipul", result.body)
    }

    @Test
    fun patientConnectedUnknownIdUsesGenericFallback() {
        val result = personalize(type = "patient_connected", patientId = "unknown-id", fallback = generic)
        assertEquals(generic, result.body)
    }

    @Test
    fun patientConnectedMissingPatientIdUsesGenericFallback() {
        val result = personalize(type = "patient_connected", patientId = null, fallback = generic)
        assertEquals(generic, result.body)
        assertEquals(null, result.patientId)
    }

    @Test
    fun unrelatedTypePreservesSuppliedContent() {
        val result = PatientPushPersonalizer.personalize(
            type = "other",
            patientId = "known-id",
            fallbackTitle = "Other title",
            fallbackBody = "Other body",
            nameForPatientId = { names[it] },
        )
        assertEquals("Other title", result.title)
        assertEquals("Other body", result.body)
    }

    @Test
    fun nameLookupFailureUsesGenericFallback() {
        val result = PatientPushPersonalizer.personalize(
            type = "patient_connected",
            patientId = "known-id",
            fallbackTitle = "CBTipul",
            fallbackBody = generic,
            nameForPatientId = { error("unavailable") },
        )
        assertEquals(generic, result.body)
    }

    private fun personalize(type: String?, patientId: String?, fallback: String) =
        PatientPushPersonalizer.personalize(
            type = type,
            patientId = patientId,
            fallbackTitle = "CBTipul",
            fallbackBody = fallback,
            nameForPatientId = { names[it] },
        )
}
