package com.cbtipul.app.ui.theme

import androidx.lifecycle.Lifecycle
import androidx.navigation.NavHostController

/** Ignore repeated back taps during a transition and never pop the graph's root. */
fun NavHostController.popScreen() {
    if (currentBackStackEntry?.lifecycle?.currentState == Lifecycle.State.RESUMED &&
        previousBackStackEntry != null
    ) {
        popBackStack()
    }
}
