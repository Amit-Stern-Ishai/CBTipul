package com.cbtipul.app.data

object SupabaseConfig {
    const val URL = "https://cckklnxteyumsgiptfck.supabase.co"
    const val ANON_KEY = "sb_publishable_FRfa8QyxuwnZ8dr167r39w_3OeXwq_a"

    const val AUTH_CALLBACK = "cbtipul://auth-callback"
    const val PASSWORD_RESET_CALLBACK = "cbtipul://password-reset"

    val isConfigured: Boolean
        get() = !URL.contains("YOUR-PROJECT-REF") && ANON_KEY != "YOUR-ANON-KEY"
}
