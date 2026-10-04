package com.cbtipul.app.data

import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.util.Date
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.atomic.AtomicInteger

@OptIn(ExperimentalCoroutinesApi::class)
class OngoingQuestionnaireTest {
    @org.junit.Before fun grantFullAccess() {
        com.cbtipul.app.data.Entitlements.apply(com.cbtipul.app.data.AppContext(role = com.cbtipul.app.data.AppRole.Therapist, entitlement = com.cbtipul.app.data.AppEntitlement(com.cbtipul.app.data.EntitlementAccess.Full)))
    }
    @org.junit.After fun clearAccess() { com.cbtipul.app.data.Entitlements.clear() }

    private val patient = "22222222-2222-2222-2222-222222222222"
    private val assignmentId = "11111111-1111-1111-1111-111111111111"
    private fun assignment(cancelled: Boolean = false) = """{"id":"$assignmentId","patient_id":"$patient","type":"questionnaire","created_at":"2026-09-01T12:00:00Z",
        "completed_at":"2026-09-02T12:00:00Z","cancelled_at":${if (cancelled) "\"2026-09-03T12:00:00Z\"" else "null"},"session_id":null}"""
    private fun row(id: Int, date: String, source: String = "patient", owner: String = patient) = """{"id":$id,"patient_id":"$owner","created_by":"$source","assignment_id":"$assignmentId",
        "answered_date":"$date","gad7_answers":[1,1,1,1,1,1,1],"phq9_answers":[0,0,0,0,0,0,0,0,3],"interference_level":2,"combined_notes":{"gad7":["private therapist note"]}}"""
    data class Request(val method: String, val path: String, val query: String, val body: String)

    @Test fun activationRepeatedSubmissionsCancellationAndPatientOnlyHistoryUseTheExistingContracts() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val response = AtomicReference("[]")
        val status = AtomicInteger(200)
        val requests = CopyOnWriteArrayList<Request>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            requests += Request(exchange.requestMethod, exchange.requestURI.path,
                URLDecoder.decode(exchange.requestURI.rawQuery.orEmpty(), "UTF-8"), exchange.requestBody.bufferedReader().readText())
            val body = if (exchange.requestURI.path.endsWith("is_patient_connected")) "true" else response.get()
            val bytes = body.toByteArray(Charsets.UTF_8)
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(status.get(), bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client = createSupabaseClient("http://127.0.0.1:${server.address.port}", "test") {
            install(Postgrest); install(Functions)
            install(Auth) { enableLifecycleCallbacks = false; codeVerifierCache = io.github.jan.supabase.auth.MemoryCodeVerifierCache(); sessionManager = io.github.jan.supabase.auth.MemorySessionManager(); autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false }
        }
        try {
            val service = PatientAssignmentRepository(client)
            val history = PatientQuestionnaireHistoryRepository(client)
            response.set(assignment())
            val active = service.sendQuestionnaireAssignment(patient)
            assertTrue(active.isOpen)
            assertNotNull(active.completedAt)
            assertNull(active.sessionId)
            assertEquals("/functions/v1/request-patient-questionnaire", requests.single().path)
            assertEquals(setOf("patientId"), Json.parseToJsonElement(requests.single().body).jsonObject.keys)
            response.set("[${assignment()}]"); requests.clear()
            assertTrue(service.activeOngoingAssignment(patient, PatientAssignmentType.Questionnaire)!!.isOpen)
            assertTrue(requests.single().query.contains("cancelled_at=is.null"))
            assertFalse(requests.single().query.contains("completed_at=is.null"))
            requests.clear()
            for (id in listOf(41, 42)) {
                response.set("""{"success":true,"combinedMoodId":$id,"sessionId":null}""")
                service.submitPatientQuestionnaire(assignmentId, List(7) { 1 }, listOf(0,0,0,0,0,0,0,0,3), 2)
            }
            assertEquals(2, requests.size)
            requests.forEach {
                assertEquals("POST", it.method)
                assertEquals("/functions/v1/submit-patient-questionnaire", it.path)
                val body = Json.parseToJsonElement(it.body).jsonObject
                assertEquals(setOf("assignmentId", "gad7Answers", "phq9Answers", "interferenceLevel"), body.keys)
                assertEquals(assignmentId, body.getValue("assignmentId").jsonPrimitive.content)
                assertEquals(3, body.getValue("phq9Answers").jsonArray[8].jsonPrimitive.int)
                assertEquals(2, body.getValue("interferenceLevel").jsonPrimitive.int)
            }
            val historyBody = "[${row(41, "2026-09-02T12:00:00Z")},${row(42, "2026-09-02T12:00:00Z")},${row(43, "2026-09-03", "therapist")},${row(44, "2026-09-04", owner = "other")}]"
            response.set(historyBody); requests.clear()
            val records = history.history(patient)
            assertTrue(records.all { it.createdBy == "patient" })
            assertEquals(listOf("42", "41"), records.map { it.databaseId.queryValue })
            assertTrue(records.all { it.questionnaire.gad7Notes.all(String::isEmpty) && it.sessionId == null })
            assertEquals(7, records[0].questionnaire.gad7Score)
            assertEquals(3, records[0].questionnaire.phq9Score)
            assertTrue(requests.single().query.contains("created_by=eq.patient"))
            assertTrue(requests.single().query.contains("patient_id=eq.$patient"))
            assertTrue(requests.single().query.contains("order=answered_date.desc"))
            assertFalse(requests.single().query.contains("combined_notes"))
            assertFalse(requests.single().query.contains("session_id="))
            response.set("[${assignment(true)}]"); requests.clear()
            service.cancelOngoingAssignment(assignmentId)
            assertEquals("PATCH", requests.single().method)
            assertEquals("/rest/v1/patient_assignments", requests.single().path)
            assertEquals(setOf("cancelled_at"), Json.parseToJsonElement(requests.single().body).jsonObject.keys)
            response.set("""{"error":"assignment_cancelled"}"""); status.set(400); requests.clear()
            try { service.submitPatientQuestionnaire(assignmentId, List(7) { 0 }, List(9) { 0 }, 0); fail("Expected cancelled error") }
            catch (_: PatientQuestionnaireSubmitError.Cancelled) { }
            assertTrue(requests.all { it.method == "POST" })
            response.set(historyBody); status.set(200)
            assertEquals(listOf("42", "41"), history.history(patient).map { it.databaseId.queryValue })
        } finally { client.close(); server.stop(0); Dispatchers.resetMain() }
    }

    @Test fun assignedNotificationRefreshesAndAcceptsPreviouslyCompletedActiveAssignment() = runTest {
        val active = PatientAssignmentRepository.assignmentFromEdgeJson(assignment())
        val payload = NotificationPayload("questionnaire_assigned", null, patient, null, assignmentId, "assignment", assignmentId)
        var loads = 0
        assertEquals(assignmentId, PatientQuestionnaireNotificationRouting.resolve(payload, patient) { loads++; listOf(active) }?.id)
        assertEquals(1, loads)
        assertNull(PatientQuestionnaireNotificationRouting.matchingAssignment(listOf(active.copy(cancelledAt = Date())), payload, patient))
        assertNull(PatientQuestionnaireNotificationRouting.matchingAssignment(listOf(active), payload, "33333333-3333-3333-3333-333333333333"))
        assertEquals(AppDestination.PatientQuestionnaire(assignmentId, payload), NotificationRouting.destination(payload))
    }
    @Test fun sameAssignmentDifferentResultNotificationsAreNotDeduplicated() {
        val store = PendingDestinationStore()
        for (id in listOf("41", "42")) {
            store.offer(NotificationPayload("questionnaire_completed", null, patient, null, assignmentId, "questionnaire", id))
            val target = store.consume() as AppDestination.QuestionnaireResult
            assertEquals(id, target.moodId)
            assertEquals("patient/$patient/questionnaire-result/$id", NotificationRouting.therapistRoutes(target).last())
        }
    }
    @Test fun maxScoresAndQ9RemainUnchanged() {
        val questionnaire = CombinedMoodQuestionnaire(List(7) { 3 }, List(9) { 3 }, 3)
        assertEquals(21, questionnaire.gad7Score)
        assertEquals(27, questionnaire.phq9Score)
        assertEquals(3, questionnaire.phq9Answers[8])
    }
}
