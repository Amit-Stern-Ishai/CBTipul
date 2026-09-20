package com.cbtipul.app.data

import com.cbtipul.app.debug.InviteDebugLog
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable

@Serializable
enum class AppRole {
    @kotlinx.serialization.SerialName("therapist") Therapist,
    @kotlinx.serialization.SerialName("patient") Patient,
}

@Serializable
enum class PatientActivation {
    @kotlinx.serialization.SerialName("active") Active,
    @kotlinx.serialization.SerialName("incomplete") Incomplete,
}

@Serializable
data class AppContext(
    val version: Int = 1,
    val role: AppRole,
    val activation: PatientActivation? = null,
    val patientId: String? = null,
) {
    val isActivePatient: Boolean
        get() = role == AppRole.Patient && activation == PatientActivation.Active && !patientId.isNullOrBlank()

    val isIncompletePatient: Boolean
        get() = role == AppRole.Patient && activation == PatientActivation.Incomplete
}

class AppContextRepository(private val client: SupabaseClient) {
    private val _current = MutableStateFlow<AppContext?>(null)
    val current: StateFlow<AppContext?> = _current.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    suspend fun getCurrentAppContext(): AppContext {
        if (!SupabaseConfig.isConfigured) throw IllegalStateException("not_configured")
        _isLoading.value = true
        return try {
            val http = client.functions.invoke(
                function = "get-app-context",
                headers = Headers.build {
                    append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                },
            )
            val context = EdgePayload.json.decodeFromString(AppContext.serializer(), http.bodyAsText())
            _current.value = context
            context
        } catch (error: Exception) {
            InviteDebugLog.e("get-app-context", error)
            throw error
        } finally {
            _isLoading.value = false
        }
    }

    fun clear() {
        _current.value = null
        _isLoading.value = false
    }
}
