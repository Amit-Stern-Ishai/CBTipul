package com.cbtipul.app.debug

import android.util.Log
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.cbtipul.app.BuildConfig
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject

@Composable
internal fun DebugPushTestSection(client: SupabaseClient) {
    if (!BuildConfig.DEBUG) return
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    var sendingFunction by remember { mutableStateOf<String?>(null) }
    var alertTitle by remember { mutableStateOf<String?>(null) }
    var alertMessage by remember { mutableStateOf<String?>(null) }

    fun send(function: String) {
        if (sendingFunction != null) return
        scope.launch {
            sendingFunction = function
            val result = invokeDebugPushTest(client, function)
            sendingFunction = null
            if (result.isSuccess) {
                alertTitle = "התראת הבדיקה נשלחה"
                alertMessage = null
            } else {
                alertTitle = "שליחת התראת הבדיקה נכשלה"
                alertMessage = redactSecrets(result.exceptionOrNull()?.message.orEmpty())
                    .ifBlank { null }
            }
        }
    }

    GroupedListCard(accent = colors.gold) {
        DebugPushTestRow(
            title = "שליחת התראת בדיקה",
            sending = sendingFunction == "test-apns-push",
            enabled = sendingFunction == null,
            color = colors.textBright,
            progressColor = colors.gold,
            onClick = { send("test-apns-push") },
        )
        GroupedListDivider()
        DebugPushTestRow(
            title = "שליחת התראת Android לבדיקה",
            sending = sendingFunction == "test-fcm-push",
            enabled = sendingFunction == null,
            color = colors.textBright,
            progressColor = colors.gold,
            onClick = { send("test-fcm-push") },
        )
    }
    MessageOverlay(
        visible = alertTitle != null,
        title = alertTitle.orEmpty(),
        message = alertMessage.orEmpty(),
        onDismiss = {
            alertTitle = null
            alertMessage = null
        },
    )
}

@Composable
private fun DebugPushTestRow(
    title: String,
    sending: Boolean,
    enabled: Boolean,
    color: Color,
    progressColor: Color,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = color)
        if (sending) {
            CircularProgressIndicator(
                modifier = Modifier
                    .padding(start = 12.dp)
                    .size(16.dp),
                color = progressColor,
                strokeWidth = 2.dp,
            )
        }
    }
}

private suspend fun invokeDebugPushTest(client: SupabaseClient, function: String): Result<String> {
    return try {
        val http = client.functions.invoke(
            function = function,
            body = buildJsonObject { },
            headers = Headers.build {
                append(HttpHeaders.ContentType, ContentType.Application.Json.toString())
            },
        )
        val raw = "status=${http.status.value} body=${http.bodyAsText()}"
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "$function ${redactSecrets(raw)}")
        }
        Result.success(raw)
    } catch (error: Exception) {
        if (BuildConfig.DEBUG) {
            Log.e(TAG, "$function failed: ${redactSecrets(error.message.orEmpty())}")
        }
        Result.failure(error)
    }
}

private fun redactSecrets(text: String): String {
    var result = InviteDebugLog.sanitize(text)
    result = HEX.replace(result, "[redacted]")
    return result
}

private const val TAG = "CBTipulPush"
private val HEX = Regex("\\b[a-fA-F0-9]{32,}\\b")
