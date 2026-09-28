package com.cbtipul.app.ui.therapist

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.AppDestination
import com.cbtipul.app.data.NotificationPayload
import com.cbtipul.app.data.NotificationRouting
import com.cbtipul.app.data.TherapistRootTabs
import com.cbtipul.app.ui.notifications.NotificationsInboxScreen
import com.cbtipul.app.ui.patients.GlobalSessionsScreen
import com.cbtipul.app.ui.patients.LibraryPlaceholderScreen
import com.cbtipul.app.ui.patients.PatientListViewModel
import com.cbtipul.app.ui.patients.PatientsNavHost
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.launch

enum class TherapistRootTab {
    Patients, Sessions, Notifications, Library, Settings,
    ;

    val id: String get() = when (this) {
        Patients -> "patients"
        Sessions -> "sessions"
        Notifications -> "notifications"
        Library -> "library"
        Settings -> "settings"
    }

    companion object {
        val ordered = listOf(Patients, Sessions, Notifications, Library, Settings)
        fun fromId(id: String) = entries.find { it.id == id } ?: Patients
    }
}

@Composable
fun TherapistRootScreen(
    viewModel: PatientListViewModel,
    settingsContent: @Composable () -> Unit,
    onCloseSettingsOverlay: (() -> Unit)? = null,
) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val patientsNav = rememberNavController()
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val isDemoMode by viewModel.isDemoMode.collectAsStateWithLifecycle()
    val unseen by app.notifications.unseenCount.collectAsStateWithLifecycle()
    val pending by app.pendingDestinations.pending.collectAsStateWithLifecycle()
    val unnamed = stringResource(R.string.unnamed_patient)
    var tab by remember { mutableStateOf(TherapistRootTab.Patients) }
    val colors = Theme.colors

    LaunchedEffect(isDemoMode) {
        app.notifications.isDemoInbox = isDemoMode
        if (isDemoMode) app.notifications.clear() else app.notifications.refresh()
    }

    LaunchedEffect(pending) {
        val destination = pending ?: return@LaunchedEffect
        if (destination !is AppDestination.PatientDetail &&
            destination !is AppDestination.QuestionnaireResult &&
            destination !is AppDestination.DiaryOneEntry
        ) {
            return@LaunchedEffect
        }
        app.pendingDestinations.consume()
        tab = TherapistRootTab.Patients
        navigateTherapistDestination(patientsNav, destination)
    }

    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).fillMaxSize()) {
            PatientsNavHost(
                viewModel = viewModel,
                onOpenSettings = { tab = TherapistRootTab.Settings },
                onCloseSettings = onCloseSettingsOverlay,
                navController = patientsNav,
            )
            when (tab) {
                TherapistRootTab.Patients -> Unit
                TherapistRootTab.Sessions -> GlobalSessionsScreen(
                    viewModel = viewModel,
                    unnamed = unnamed,
                    onOpenSession = { patientId, sessionId ->
                        tab = TherapistRootTab.Patients
                        patientsNav.navigate("patient/$patientId") {
                            popUpTo("list") { inclusive = false }
                            launchSingleTop = true
                        }
                        patientsNav.navigate("patient/$patientId/session/$sessionId")
                    },
                    onCreateSession = { patientId ->
                        tab = TherapistRootTab.Patients
                        patientsNav.navigate("patient/$patientId") {
                            popUpTo("list") { inclusive = false }
                            launchSingleTop = true
                        }
                        patientsNav.navigate("patient/$patientId/session/new")
                    },
                )
                TherapistRootTab.Notifications -> NotificationsInboxScreen(
                    repository = app.notifications,
                    patients = patients,
                    unnamed = unnamed,
                    onOpen = { item ->
                        val destination = NotificationRouting.destination(NotificationPayload.from(item))
                        app.applicationScope.launch { app.notifications.markRead(item) }
                        if (destination != null) {
                            tab = TherapistRootTab.Patients
                            navigateTherapistDestination(patientsNav, destination)
                        }
                    },
                )
                TherapistRootTab.Library -> LibraryPlaceholderScreen()
                TherapistRootTab.Settings -> settingsContent()
            }
        }
        NavigationBar(containerColor = colors.surface) {
            TherapistRootTab.ordered.forEach { item ->
                NavigationBarItem(
                    selected = tab == item,
                    onClick = { tab = item },
                    icon = {
                        if (item == TherapistRootTab.Notifications) {
                            BadgedBox(
                                badge = {
                                    if (unseen > 0 && tab != TherapistRootTab.Notifications) {
                                        Badge { Text(if (unseen > 99) "99+" else unseen.toString()) }
                                    }
                                },
                            ) {
                                Icon(Icons.Outlined.Notifications, contentDescription = null)
                            }
                        } else {
                            Icon(item.icon(), contentDescription = null)
                        }
                    },
                    label = { Text(stringResource(item.labelRes())) },
                    colors = NavigationBarItemDefaults.colors(indicatorColor = colors.goldGhost),
                )
            }
        }
    }
}

private fun TherapistRootTab.icon() = when (this) {
    TherapistRootTab.Patients -> Icons.Outlined.People
    TherapistRootTab.Sessions -> Icons.Outlined.CalendarMonth
    TherapistRootTab.Notifications -> Icons.Outlined.Notifications
    TherapistRootTab.Library -> Icons.Outlined.MenuBook
    TherapistRootTab.Settings -> Icons.Outlined.Settings
}

private fun TherapistRootTab.labelRes() = when (this) {
    TherapistRootTab.Patients -> R.string.therapist_tab_patients
    TherapistRootTab.Sessions -> R.string.therapist_tab_sessions
    TherapistRootTab.Notifications -> R.string.therapist_tab_notifications
    TherapistRootTab.Library -> R.string.therapist_tab_library
    TherapistRootTab.Settings -> R.string.therapist_tab_settings
}

fun navigateTherapistDestination(nav: NavHostController, destination: AppDestination) {
    when (destination) {
        is AppDestination.PatientDetail -> nav.navigate("patient/${destination.patientId}") {
            popUpTo("list") { inclusive = false }
            launchSingleTop = true
        }
        is AppDestination.QuestionnaireResult -> {
            nav.navigate("patient/${destination.patientId}") {
                popUpTo("list") { inclusive = false }
                launchSingleTop = true
            }
            destination.moodId?.let {
                nav.navigate("patient/${destination.patientId}/questionnaire-result/$it")
            }
        }
        is AppDestination.DiaryOneEntry -> {
            nav.navigate("patient/${destination.patientId}") {
                popUpTo("list") { inclusive = false }
                launchSingleTop = true
            }
            val entry = destination.entryId
            nav.navigate(
                if (entry != null) "patient/${destination.patientId}/diary-one?entry=$entry"
                else "patient/${destination.patientId}/diary-one",
            )
        }
        else -> Unit
    }
}

@Suppress("unused")
fun therapistRootTabIds(): List<String> = TherapistRootTabs.ordered
