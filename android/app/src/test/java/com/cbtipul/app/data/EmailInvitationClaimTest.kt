package com.cbtipul.app.data

import kotlinx.coroutines.*
import kotlinx.coroutines.test.runTest
import io.github.jan.supabase.auth.auth
import org.junit.Test
import org.junit.Assert.*

class EmailInvitationClaimTest {
    private val revision = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
    private val therapist = AppContext(role = AppRole.Therapist)
    private val patient = AppContext(role = AppRole.Patient, activation = PatientActivation.Active, patientId = "synthetic")
    @Test fun incompleteEmailPatientChecksFreshInvitationOnlyOnExplicitRetry() = runTest {
        var calls = 0
        val incomplete = AppContext(role = AppRole.Patient, activation = PatientActivation.Incomplete)
        val gate = EmailInvitationClaim({ true }) { value -> assertNull(value); calls++; EmailInvitationClaim.Response("connected") }
        gate.resolve(therapist) { patient }
        assertEquals(1, calls)
        gate.resolve(incomplete) { incomplete }
        assertEquals(1, calls)
        gate.retry()
        assertEquals(patient, gate.resolve(incomplete) { patient })
        assertEquals(2, calls)
    }
    @Test fun incompleteAnonymousPatientDoesNotClaimEmail() = runTest {
        val incomplete = AppContext(role = AppRole.Patient, activation = PatientActivation.Incomplete)
        var calls = 0
        val gate = EmailInvitationClaim({ false }) { calls++; EmailInvitationClaim.Response("no_match") }
        assertEquals(incomplete, gate.resolve(incomplete) { incomplete })
        assertEquals(0, calls)
    }
    @Test fun changedInvitationRequiresNewConfirmation() = runTest {
        val next = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"
        val sent = mutableListOf<String?>()
        val gate = EmailInvitationClaim({ true }) { value ->
            sent.add(value)
            when(sent.size) {
                1 -> EmailInvitationClaim.Response("confirmation_required", revision)
                2 -> EmailInvitationClaim.Response("invitation_changed")
                3 -> EmailInvitationClaim.Response("confirmation_required", next)
                else -> EmailInvitationClaim.Response("connected")
            }
        }
        gate.resolve(therapist) { patient }; gate.retry(true)
        gate.resolve(therapist) { patient }
        assertEquals(EmailInvitationClaim.State.Confirmation, gate.state.value)
        assertEquals(listOf(null, revision, null), sent)
        gate.retry(true); gate.resolve(therapist) { patient }
        assertEquals(listOf(null, revision, null, next), sent)
    }
    @Test fun restoredAnonymousPatientBypassesClaimAndRetainsProfile() = runTest {
        var identity: String? = "existing-anonymous-account"
        var calls = 0
        val gate = EmailInvitationClaim({ false }) { calls++; EmailInvitationClaim.Response("no_match") }
        val repo = AppContextRepository(AppContextDependencies({}, { identity }, { patient }, {}, emailClaim = gate))
        repo.getCurrentAppContext()
        assertEquals(patient, repo.current.value); assertEquals("existing-anonymous-account", identity); assertEquals(0, calls)
        repo.authenticationChanged(identity); repo.getCurrentAppContext()
        assertEquals(patient, repo.current.value); assertEquals(0, calls)
        identity = null; repo.authenticationChanged(null); assertNull(repo.current.value)
    }
    @Test fun missingRevisionFailsClosed() = runTest {
        val gate = EmailInvitationClaim({ true }) { EmailInvitationClaim.Response("confirmation_required") }
        assertTrue(runCatching { gate.resolve(therapist) { therapist } }.isFailure)
        gate.retry(true)
        assertEquals(EmailInvitationClaim.State.Failed, gate.state.value)
    }
    @OptIn(kotlin.time.ExperimentalTime::class)
    @Test fun liveAdapterUsesAuthenticatedPostAndExactBodies() = kotlinx.coroutines.runBlocking {
        val bodies = mutableListOf<String>()
        val methods = mutableListOf<String>()
        val authorizationPresent = mutableListOf<Boolean>()
        val server = com.sun.net.httpserver.HttpServer.create(java.net.InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/functions/v1/claim-patient-email-invitation") { exchange ->
            bodies.add(exchange.requestBody.bufferedReader().readText())
            methods.add(exchange.requestMethod)
            authorizationPresent.add(exchange.requestHeaders.getFirst("Authorization")?.startsWith("Bearer ") == true)
            val bytes = (if(bodies.size == 1) "{\"status\":\"confirmation_required\",\"invitation_revision\":\"AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA\"}" else "{\"status\":\"no_match\"}").toByteArray()
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        val client = io.github.jan.supabase.createSupabaseClient("http://127.0.0.1:${server.address.port}", "synthetic") {
            install(io.github.jan.supabase.functions.Functions)
            install(io.github.jan.supabase.auth.Auth) {
                enableLifecycleCallbacks = false
                sessionManager = io.github.jan.supabase.auth.MemorySessionManager()
                codeVerifierCache = io.github.jan.supabase.auth.MemoryCodeVerifierCache()
                autoLoadFromStorage = false; autoSaveToStorage = false; alwaysAutoRefresh = false
            }
        }
        try {
            client.auth.importSession(io.github.jan.supabase.auth.user.UserSession("synthetic", "synthetic", expiresIn = 3600, tokenType = "bearer",
                user = io.github.jan.supabase.auth.user.UserInfo(id = "synthetic", aud = "authenticated", email = "test@example.invalid", emailConfirmedAt = kotlin.time.Clock.System.now())))
            val gate = EmailInvitationClaim.live(client)
            assertNull(gate.resolve(therapist) { therapist })
            gate.retry(true)
            assertEquals(therapist, gate.resolve(therapist) { therapist })
            assertEquals(listOf("POST", "POST"), methods)
            assertEquals(listOf(true, true), authorizationPresent)
            assertEquals(listOf("{\"version\":2}", "{\"version\":2,\"invitation_revision\":\"$revision\"}"), bodies)
        } finally { client.close(); server.stop(0) }
    }
    @Test fun inviteFirstWaitsForServerRoleAndDoesNotRepeat() = runTest {
        var calls = 0
        val gate = EmailInvitationClaim({ true }) { confirm -> assertNull(confirm); calls++; EmailInvitationClaim.Response("connected") }
        assertEquals(patient, gate.resolve(therapist) { patient })
        assertEquals(patient, gate.resolve(patient) { error("unexpected") })
        assertEquals(1, calls)
    }
    @Test fun signupFirstRequiresExplicitConfirmationAndNoMatchReloads() = runTest {
        val arguments = mutableListOf<String?>()
        val gate = EmailInvitationClaim({ true }) { confirm -> arguments.add(confirm); EmailInvitationClaim.Response(if(confirm != null) "no_match" else "confirmation_required", revision) }
        assertNull(gate.resolve(therapist) { error("unexpected") })
        assertNull(gate.resolve(therapist) { error("unexpected") })
        assertEquals(listOf(null), arguments)
        gate.retry(true)
        assertEquals(patient, gate.resolve(therapist) { patient })
        assertEquals(listOf(null, revision), arguments)
    }
    @Test fun declineAndNoMatchPermitClinicWithoutFurtherClaims() = runTest {
        for (result in listOf("confirmation_required", "no_match", "connection_unavailable")) {
            var calls = 0
            val gate = EmailInvitationClaim({ true }) { calls++; EmailInvitationClaim.Response(result, revision) }
            gate.resolve(therapist) { error("unexpected") }
            gate.decline()
            assertEquals(therapist, gate.resolve(therapist) { error("unexpected") })
            assertEquals(1, calls)
        }
    }
    @Test fun lostResponseRetryReloadsContextBeforeAnotherClaim() = runTest {
        var calls = 0
        var context = therapist
        val gate = EmailInvitationClaim({ true }) { calls++; context = patient; throw java.io.IOException() }
        val repo = AppContextRepository(AppContextDependencies({}, { "account" }, { context }, {}, emailClaim = gate))
        runCatching { repo.getCurrentAppContext() }
        assertNull(repo.current.value)
        assertEquals(EmailInvitationClaim.State.Failed, gate.state.value)
        gate.retry()
        assertEquals(patient, repo.getCurrentAppContext())
        assertEquals(1, calls)
    }
    @Test fun failureBeforeServerCanRetryAndRefreshDoesNotReclaim() = runTest {
        var calls = 0
        val gate = EmailInvitationClaim({ true }) { calls++; if(calls==1) throw java.io.IOException() else EmailInvitationClaim.Response("no_match") }
        val repo = AppContextRepository(AppContextDependencies({}, { "account" }, { therapist }, {}, emailClaim = gate))
        runCatching { repo.getCurrentAppContext() }; gate.retry()
        repo.getCurrentAppContext()
        repo.authenticationChanged("account", tokenRefresh = true)
        repo.getCurrentAppContext(); assertEquals(2, calls)
        repo.authenticationChanged("account")
        repo.getCurrentAppContext(); assertEquals(3, calls)
    }
    @Test fun accountSwitchIgnoresLateResponseAndResetsConfirmation() = runTest {
        val deferred = CompletableDeferred<String>()
        val gate = EmailInvitationClaim({ true }) { EmailInvitationClaim.Response(deferred.await()) }
        val job = async { runCatching { gate.resolve(therapist) { patient } } }
        yield(); gate.reset(); deferred.complete("connected"); job.await()
        assertEquals(EmailInvitationClaim.State.Idle, gate.state.value)
    }
    @Test fun patientsAndAnonymousOrUnverifiedAccountsNeverClaim() = runTest {
        val skipped = EmailInvitationClaim({ false }) { error("unexpected") }
        assertEquals(therapist, skipped.resolve(therapist) { error("unexpected") })
        val gate = EmailInvitationClaim({ true }) { error("unexpected") }
        assertEquals(patient, gate.resolve(patient) { error("unexpected") })
    }
    @Test fun connectedCannotInferPatientAndVerificationStaysBlocked() = runTest {
        val gate = EmailInvitationClaim({ true }) { EmailInvitationClaim.Response("connected") }
        assertTrue(runCatching { gate.resolve(therapist) { therapist } }.isFailure)
        assertEquals(EmailInvitationClaim.State.Failed, gate.state.value)
        val unverified = EmailInvitationClaim({ true }) { EmailInvitationClaim.Response("email_not_verified") }
        assertNull(unverified.resolve(therapist) { therapist })
        assertEquals(EmailInvitationClaim.State.Verification, unverified.state.value)
    }
}
