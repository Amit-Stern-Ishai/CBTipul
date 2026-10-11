package com.cbtipul.app.auth

import com.russhwolf.settings.Settings
import io.github.jan.supabase.auth.SettingsCodeVerifierCache
import java.lang.reflect.Proxy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

class PkcePersistenceTest {
    @Test fun sdkVerifierSurvivesCacheRecreationAndIsRemovedAfterUse() = runTest {
        // Mock persistent Settings backing: no Android app, SDK client, or network.
        val disk = mutableMapOf<String, String>()
        fun settings(): Settings = Proxy.newProxyInstance(
            Settings::class.java.classLoader, arrayOf(Settings::class.java),
        ) { _, method, args ->
            when (method.name) {
                "getStringOrNull" -> disk[args!![0] as String]
                "getString" -> disk[args!![0] as String] ?: args[1]
                "putString" -> { disk[args!![0] as String] = args[1] as String; Unit }
                "remove" -> { disk.remove(args!![0] as String); Unit }
                "hasKey" -> disk.containsKey(args!![0] as String)
                else -> error("Unexpected Settings call")
            }
        } as Settings
        SettingsCodeVerifierCache(settings(), "test-verifier").saveCodeVerifier("mock-verifier")
        val recreated = SettingsCodeVerifierCache(settings(), "test-verifier")
        assertEquals("mock-verifier", recreated.loadCodeVerifier())
        recreated.deleteCodeVerifier()
        assertNull(SettingsCodeVerifierCache(settings(), "test-verifier").loadCodeVerifier())
    }
}
