package com.cbtipul.app

import android.os.Bundle
import android.util.Log
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.cbtipul.app.data.EdgePayload
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.launch
import kotlinx.serialization.json.*

/** Read-only authenticated context diagnostic. Only status and non-identifying enum codes. */
class AppContextDiagnosticActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val view = TextView(this); view.text = "Checking account context…"; setContentView(view)
        lifecycleScope.launch {
            val client = (application as CbTipulApp).authRepository.supabaseClient
            client.auth.awaitInitialization()
            if (client.auth.currentSessionOrNull() == null) { view.text = "No signed-in session"; return@launch }
            fun code(value: String?) = value?.takeIf { it.matches(Regex("[a-z_]{1,80}")) } ?: "unavailable"
            val result = try {
                val response = client.functions.invoke("get-app-context")
                val json = Json.parseToJsonElement(response.bodyAsText()).jsonObject
                "get-app-context http=${response.status.value} role=${code(json["role"]?.jsonPrimitive?.contentOrNull)} activation=${code(json["activation"]?.jsonPrimitive?.contentOrNull)} patient_id_present=${json["patientId"] is JsonPrimitive && json["patientId"] != JsonNull}"
            } catch (error: Exception) {
                val raw = EdgePayload.responseBody(error)
                val value = EdgePayload.codeAndMessage(raw).first.ifBlank { raw.trim() }
                "get-app-context http=${EdgePayload.httpStatus(error) ?: 0} code=${code(value)}"
            }
            Log.i("ContextReadProbe", result); view.text = result
        }
    }
}
