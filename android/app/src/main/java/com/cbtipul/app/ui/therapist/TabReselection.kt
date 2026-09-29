package com.cbtipul.app.ui.therapist

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.staticCompositionLocalOf
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collectLatest

// Events are scoped to one tab and are never replayed when a screen opens.
val LocalTabReselections = staticCompositionLocalOf<Flow<Unit>?> { null }

@Composable
fun TabReselectionEffect(enabled: Boolean = true, onReselect: suspend () -> Unit) {
    val events = LocalTabReselections.current
    val currentEnabled = rememberUpdatedState(enabled)
    val currentAction = rememberUpdatedState(onReselect)
    LaunchedEffect(events) {
        events?.collectLatest {
            if (currentEnabled.value) currentAction.value()
        }
    }
}

/** Only reading destinations can skip straight to the list. Editors use normal guarded Back. */
internal fun canResetPatientsTab(route: String?): Boolean = route in setOf(
    "patient/{id}/sessions",
    "patient/{id}/questionnaires?graphs={graphs}",
    "patient/{id}/questionnaire-trends",
    "patient/{id}/diary-one?entry={entry}",
    "patient/{id}/prepare",
    "patient/{id}/messages",
    "patient/{id}/messages/{messageId}",
)
