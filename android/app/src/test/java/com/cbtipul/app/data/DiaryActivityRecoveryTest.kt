package com.cbtipul.app.data

import com.sun.net.httpserver.HttpServer
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicInteger

@OptIn(kotlin.time.ExperimentalTime::class)
class DiaryActivityRecoveryTest {
    @After fun reset() = Entitlements.clear()
    private val owner = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private val patient = "11111111-1111-4111-8111-111111111111"
    private val assignment = "22222222-2222-4222-8222-222222222222"

    @Test fun restoredAndFreshTherapistsEnableTheExactDiaryThroughConfirmedApi() = runBlocking {
        for (restored in listOf(true, false)) verifyAssignment(restored, false)
    }
    @Test fun restoredReadOnlyTherapistCannotSendTheEnableRequest() = runBlocking {
        verifyAssignment(true, true)
    }
    private suspend fun verifyAssignment(restored: Boolean, readOnly: Boolean) {
        Entitlements.clear()
        val writes = AtomicInteger(); var requestedPatient: String? = null
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { e ->
            val body = when {
                e.requestURI.path.endsWith("/token") -> """{"access_token":"synthetic","refresh_token":"synthetic","token_type":"bearer","expires_in":3600,"user":{"id":"$owner","aud":"authenticated"}}"""
                e.requestURI.path.endsWith("get-app-context") -> """{"role":"therapist","entitlement":{"access":"${if(readOnly) "read_only" else "full"}"}}"""
                e.requestURI.path.endsWith("is_patient_connected") -> "true"
                e.requestURI.path.endsWith("request-patient-diary-one") -> {
                    writes.incrementAndGet()
                    val json = kotlinx.serialization.json.Json.parseToJsonElement(e.requestBody.bufferedReader().readText()) as kotlinx.serialization.json.JsonObject
                    requestedPatient = (json["patientId"] as kotlinx.serialization.json.JsonPrimitive).content
                    """{"success":true,"assignment":{"id":"$assignment","patientId":"$patient","therapistId":"$owner","type":"diary_one","createdAt":"2026-11-11T10:00:00Z"},"createdNew":true}"""
                }
                else -> "[]"
            }.toByteArray()
            e.responseHeaders.add("Content-Type", "application/json"); e.sendResponseHeaders(200, body.size.toLong())
            e.responseBody.use {it.write(body)}
        }
        server.start()
        val client = createSupabaseClient("http://127.0.0.1:${server.address.port}", "synthetic") {
            install(Functions); install(Postgrest)
            install(Auth) {
                enableLifecycleCallbacks = false
                codeVerifierCache = io.github.jan.supabase.auth.MemoryCodeVerifierCache()
                sessionManager = io.github.jan.supabase.auth.MemorySessionManager()
                autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false
            }
        }
        try {
            if(restored) client.auth.importSession(UserSession("synthetic", "synthetic", expiresIn=3600, tokenType="bearer", user=UserInfo(aud="authenticated",id=owner)))
            else client.auth.signInWith(Email) {email="synthetic@example.invalid";password="synthetic"}
            AppContextRepository(client).getCurrentAppContext()
            val repo=PatientAssignmentRepository(client)
            if(readOnly) {
                try { repo.activateOngoingAssignment(patient,PatientAssignmentType.DiaryOne); fail("read-only must fail closed") }
                catch(_:EntitlementDenied) {}
                assertEquals(0,writes.get())
            } else {
                val confirmed=repo.activateOngoingAssignment(patient,PatientAssignmentType.DiaryOne)
                assertEquals(assignment,confirmed.id);assertEquals(patient,confirmed.patientId)
                assertEquals(PatientAssignmentType.DiaryOne,confirmed.type)
                assertEquals(patient,requestedPatient);assertEquals(1,writes.get())
                assertEquals(assignment,repo.cachedOngoingAssignment(patient,PatientAssignmentType.DiaryOne)?.assignmentId)
            }
        } finally {client.close();server.stop(0)}
    }
}
