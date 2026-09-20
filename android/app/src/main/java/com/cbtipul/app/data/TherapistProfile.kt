package com.cbtipul.app.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TherapistProfile(
    @SerialName("therapist_id") val therapistId: String,
    @SerialName("display_name") val displayName: String,
) {
    val hasValidDisplayName: Boolean get() = isValid(displayName)

    companion object {
        fun normalized(raw: String) = raw.trim()
        fun isValid(raw: String) = normalized(raw).isNotEmpty()
    }
}

class TherapistProfileRepository(private val client: SupabaseClient) {
    var cached: TherapistProfile? = null
        private set

    suspend fun getCurrentProfile(): TherapistProfile? {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val userId = client.auth.currentSessionOrNull()?.user?.id
            ?: throw IllegalStateException("not_signed_in")
        val rows = client.from("therapist_profiles")
            .select(Columns.raw("therapist_id, display_name")) {
                filter { eq("therapist_id", userId.lowercase()) }
                limit(1)
            }
            .decodeList<TherapistProfile>()
        cached = rows.firstOrNull()
        return cached
    }

    suspend fun hasValidDisplayName(): Boolean = getCurrentProfile()?.hasValidDisplayName == true

    suspend fun saveDisplayName(raw: String): TherapistProfile {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        val trimmed = TherapistProfile.normalized(raw)
        if (!TherapistProfile.isValid(trimmed)) throw IllegalStateException("empty_display_name")
        val userId = client.auth.currentSessionOrNull()?.user?.id
            ?: throw IllegalStateException("not_signed_in")
        val record = TherapistProfile(therapistId = userId, displayName = trimmed)
        val saved = client.from("therapist_profiles")
            .upsert(record) {
                onConflict = "therapist_id"
                select(Columns.raw("therapist_id, display_name"))
            }
            .decodeSingle<TherapistProfile>()
        cached = saved
        return saved
    }
}
