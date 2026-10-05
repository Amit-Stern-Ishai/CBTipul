package com.cbtipul.app.data

import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.After
import org.junit.Test

class EntitlementTest {
    @After fun reset() = Entitlements.clear()
    private fun context(access: EntitlementAccess, patient: Boolean = false) = AppContext(role = if (patient) AppRole.Patient else AppRole.Therapist,
        activation = if (patient) PatientActivation.Active else null, patientId = if (patient) "patient" else null, entitlement = AppEntitlement(access))

    @Test fun decodingKeepsHistoryRoutingForMalformedEntitlement() {
        for (value in listOf("full", "read_only", "unknown")) {
            val decoded = Json.decodeFromString<AppContext>("""{"version":1,"role":"therapist","entitlement":{"access":"$value"}}""")
            assertEquals(AppRole.Therapist, decoded.role)
            assertEquals(if (value == "unknown") null else value == "full", decoded.entitlement?.canWrite)
        }
        for (value in listOf("null", "42", "{}", "{\"access\":false}")) {
            val decoded = Json.decodeFromString<AppContext>("""{"role":"patient","activation":"active","patientId":"patient","entitlement":$value}""")
            assertTrue(decoded.isActivePatient)
            assertNull(decoded.entitlement)
        }
        val incomplete = Json.decodeFromString<AppContext>("""{"role":"patient","activation":"incomplete"}""")
        Entitlements.apply(incomplete)
        assertTrue(incomplete.isIncompletePatient)
        assertNull(Entitlements.state.value.access)
    }
    @Test fun refreshTransitionsAndIdentityReset() {
        Entitlements.setIdentity("one")
        Entitlements.apply(context(EntitlementAccess.Full))
        assertTrue(Entitlements.canWrite && Entitlements.canUseAI && Entitlements.canPatientWrite)
        Entitlements.apply(context(EntitlementAccess.ReadOnly))
        assertFalse(Entitlements.canWrite)
        assertFalse(Entitlements.allowMutation())
        assertTrue(Entitlements.explanationVisible.value)
        Entitlements.apply(context(EntitlementAccess.Full)); Entitlements.requireWrite()
        Entitlements.setIdentity("two")
        assertFalse(Entitlements.canWrite)
        assertFalse(Entitlements.explanationVisible.value)
        Entitlements.apply(context(EntitlementAccess.ReadOnly, true))
        assertEquals(AppRole.Patient, Entitlements.state.value.role)
        assertFalse(Entitlements.canPatientWrite)
        Entitlements.invalidate(); assertFalse(Entitlements.canUseAI)
    }
    @Test fun localDemoDoesNotGrantRemoteOrPatientPermissions() {
        Entitlements.apply(context(EntitlementAccess.ReadOnly))
        Entitlements.setLocalDemo(true)
        assertTrue(Entitlements.canWrite)
        assertTrue(Entitlements.allowMutation())
        assertFalse(Entitlements.allowMutation(allowLocalDemo = false))
        assertFalse(Entitlements.canUseAI)
        assertFalse(Entitlements.canPatientWrite)
        Entitlements.requireWrite(localDemo = true)
        try { Entitlements.requireWrite(); fail("Remote write allowed") } catch (_: EntitlementDenied) {}
        Entitlements.apply(context(EntitlementAccess.ReadOnly))
        assertTrue(Entitlements.canWrite)
        Entitlements.setLocalDemo(false)
        assertFalse(Entitlements.canWrite)
        try { Entitlements.requireWrite(localDemo = true); fail("Demo allowed after exit") } catch (_: EntitlementDenied) {}
        Entitlements.setLocalDemo(true)
        Entitlements.setIdentity("another-account")
        assertFalse(Entitlements.canWrite)
    }
    @Test fun writesDeniedBeforeValidationOrNetworkWhileHistoryRemains() = runTest {
        val client = createSupabaseClient("https://example.invalid", "test") {
            install(Postgrest); install(Functions)
            install(Auth) { enableLifecycleCallbacks = false; codeVerifierCache = io.github.jan.supabase.auth.MemoryCodeVerifierCache(); sessionManager = io.github.jan.supabase.auth.MemorySessionManager(); autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false }
        }
        suspend fun denied(operation: suspend () -> Unit) {
            try { operation(); fail("Mutation succeeded") } catch (error: EntitlementDenied) { /* expected before IO */ }
        }
        try {
            val diary = DiaryOneRepository(client)
            val patient = DatabaseId.Text("demo-entitlement")
            Entitlements.apply(context(EntitlementAccess.Full))
            val entry = diary.createEntry(patient, "existing", listOf("thought"), listOf(DiaryFeeling("עצוב", 80)), "existing", null)
            Entitlements.apply(context(EntitlementAccess.ReadOnly))
            denied { diary.deleteEntry(entry.id, patient) }
            denied { diary.createEntry(patient, "new", emptyList(), emptyList(), "", null) }
            assertEquals(listOf(entry.id), diary.loadEntries(patient).map { it.id })
            val assignments = PatientAssignmentRepository(client)
            for (type in PatientAssignmentType.entries) denied { assignments.activateOngoingAssignment("patient", type) }
            denied { assignments.cancelOngoingAssignment("assignment") }
            Entitlements.setLocalDemo(true)
            val added = diary.createEntry(patient, "sample", listOf("thought"), listOf(DiaryFeeling("עצוב", 80)), "sample", null)
            assertTrue(diary.loadEntries(patient).any { it.id == added.id })
            diary.deleteEntry(added.id, patient)
            denied { diary.createEntry(DatabaseId.Text("real-patient"), "", emptyList(), emptyList(), "", null) }
            denied { assignments.activateOngoingAssignment("patient", PatientAssignmentType.Questionnaire) }
            Entitlements.setLocalDemo(false)
            Entitlements.apply(context(EntitlementAccess.ReadOnly, true))
            denied { assignments.submitPatientQuestionnaire("assignment", emptyList(), emptyList(), 0) }
            denied { PatientDiaryOneService(client, diary).submitEntry("", emptyList(), emptyList(), "", null, "failed", "invalid") }
            denied { PatientDiaryTwoService(client).submitEntry(SubmitDiaryTwoEntryRequest("", emptyList(), emptyList(), emptyList(), emptyList())) }
            denied { PatientDiaryThreeService(client).submitEntry(SubmitDiaryThreeEntryRequest("", emptyList(), emptyList(), emptyList(), emptyList())) }
        } finally { client.close() }
    }
}
