package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest

fun createCbTipulSupabaseClient(): SupabaseClient = createSupabaseClient(
    supabaseUrl = SupabaseConfig.URL,
    supabaseKey = SupabaseConfig.ANON_KEY,
) {
    install(Auth) {
        flowType = FlowType.PKCE
        // Keep the SDK default SettingsCodeVerifierCache (persistent on Android).
        scheme = "cbtipul"
        host = "auth-callback"
    }
    install(Postgrest)
    install(Functions)
}
