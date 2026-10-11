package com.cbtipul.app.auth

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.minimalConfig
import io.github.jan.supabase.createSupabaseClient
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppleOAuthUrlTest {
    @Test fun generatedAuthorizationUrlEncodesAppRedirectAndKeepsPkce() = runBlocking {
        val client = createSupabaseClient(
            supabaseUrl = "https://example.supabase.co",
            supabaseKey = "local-test-key",
        ) {
            install(Auth) {
                flowType = FlowType.PKCE
                scheme = "cbtipul"
                host = "auth-callback"
                minimalConfig()
            }
        }
        val url = appleAuthorizationUrl(client)
        assertTrue(url, url.contains("redirect_to=cbtipul%3A%2F%2Fauth-callback"))
        assertFalse(url.contains("redirect_to=cbtipul://"))
        assertTrue(url.contains("provider=apple"))
        assertTrue(url.contains("scopes=email+name"))
        val challenge = url.substringAfter("code_challenge=").substringBefore("&")
        assertTrue(challenge.isNotEmpty())
        withTimeout(5_000) {
            while (true) {
                val verifier = client.auth.codeVerifierCache.loadCodeVerifier()
                val actual = verifier?.let { codeChallenge(it) }
                if (actual == challenge) break
                delay(20)
            }
        }
        assertEquals("s256", url.substringAfter("code_challenge_method=").substringBefore("&"))
    }

    private fun codeChallenge(verifier: String): String =
        java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
            java.security.MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8)),
        )
}
