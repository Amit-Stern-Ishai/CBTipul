package com.cbtipul.app.data

import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class PatientActivitiesTransportTest {
    @OptIn(kotlin.time.ExperimentalTime::class)
    @Test fun explicitSendUsesFunctionAndLostResponseReadsRPC() = runBlocking {
        var rejectSend = true
        val paths = mutableListOf<String>()
        val bodies = mutableListOf<String>()
        val auth = mutableListOf<Boolean>()
        val methods = mutableListOf<String>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            val path = exchange.requestURI.path
            paths += path; bodies += exchange.requestBody.bufferedReader().readText()
            auth += exchange.requestHeaders.getFirst("Authorization").orEmpty().startsWith("Bearer ")
            methods += exchange.requestMethod
            val send = path == "/functions/v1/request-patient-activities"
            val body = if (send && rejectSend) """{"error":"temporary_failure"}""" else if (send) """{"status":"activities_available"}""" else if (paths.size == 1) "\"no_request\"" else "\"pending\""
            val bytes = body.toByteArray()
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(if (send && rejectSend) 500 else 200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
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
            client.auth.importSession(UserSession("synthetic", "synthetic", expiresIn = 3600, tokenType = "bearer", user = UserInfo(aud = "authenticated", id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")))
            val repository = PatientAssignmentRepository(client)
            val model = PatientActivitiesRequest()
            model.run(false, { true }, repository::requestActivities)
            model.run(true, { true }, repository::requestActivities)
            assertEquals(PatientActivitiesRequest.State.Pending, model.state.value)
            assertEquals(listOf("/rest/v1/rpc/request_patient_activities", "/functions/v1/request-patient-activities", "/rest/v1/rpc/request_patient_activities"), paths)
            assertEquals(listOf("{\"p_send\":false}", "{}", "{\"p_send\":false}"), bodies)
            assertTrue(auth.all { it }); assertTrue(methods.all { it == "POST" })
            rejectSend = false
            assertEquals("activities_available", repository.requestActivities(true))
            assertEquals("{}", bodies.last())
        } finally { client.close(); server.stop(0) }
    }
}
