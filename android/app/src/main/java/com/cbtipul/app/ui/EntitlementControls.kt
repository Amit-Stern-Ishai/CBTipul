package com.cbtipul.app.ui

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.onClick
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.data.Entitlements

@Composable fun entitlementCanWrite(): Boolean {
    val state by Entitlements.state.collectAsStateWithLifecycle()
    return state.canWrite
}

/** Keep the existing label accessible; taps explain read-only instead of creating. */
@Composable
fun androidx.compose.ui.Modifier.entitlementCreateControl(): androidx.compose.ui.Modifier {
    val canWrite = entitlementCanWrite()
    if (canWrite) return this
    return this.alpha(0.45f)
        .semantics { onClick { Entitlements.allowMutation(); true } }
        .pointerInput(Unit) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                down.consume()
                val up = waitForUpOrCancellation(pass = PointerEventPass.Initial)
                if (up != null) {
                    up.consume()
                    Entitlements.allowMutation()
                }
            }
        }
}
