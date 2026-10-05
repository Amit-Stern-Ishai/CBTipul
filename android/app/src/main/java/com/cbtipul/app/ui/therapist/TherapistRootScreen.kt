package com.cbtipul.app.ui.therapist

import androidx.compose.material.icons.outlined.AutoAwesome
import com.cbtipul.app.ui.patients.AIPatientPickerScreen
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.activity.compose.BackHandler
import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.runtime.CompositionLocalProvider
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import androidx.lifecycle.Lifecycle
import kotlinx.coroutines.flow.MutableSharedFlow
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.ui.platform.LocalDensity
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.ui.onboarding.DemoModeBanner
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
    Patients, Sessions, AI, Notifications, Library, Settings,
    ;

    val id: String get() = when (this) {
        Patients -> "patients"
        Sessions -> "sessions"
        AI -> "ai"
        Notifications -> "notifications"
        Library -> "library"
        Settings -> "settings"
    }

    companion object {
        val ordered = listOf(Patients, Sessions, AI, Notifications, Settings)
        fun fromId(id: String) = entries.find { it.id == id } ?: Patients
    }
}

@Composable
fun TherapistRootScreen(
    viewModel: PatientListViewModel,
    settingsContent: @Composable () -> Unit,
    onCloseSettingsOverlay: (() -> Unit)? = null,
) {
    val context = LocalContext.current
    val app = context.applicationContext as CbTipulApp
    val patientsNav = rememberNavController()
    val isDemoMode by viewModel.isDemoMode.collectAsStateWithLifecycle()
    val aiNav = androidx.compose.runtime.key(isDemoMode) { rememberNavController() }
    val aiEntry by aiNav.currentBackStackEntryAsState()
    val inboxNav = rememberNavController()
    val inboxEntry by inboxNav.currentBackStackEntryAsState()
    val backDispatcher = LocalOnBackPressedDispatcherOwner.current?.onBackPressedDispatcher
    val reselections = remember { TherapistRootTab.entries.associateWith { MutableSharedFlow<Unit>(extraBufferCapacity = 1) } }
    val currentEntry by patientsNav.currentBackStackEntryAsState()
    val patients by viewModel.patients.collectAsStateWithLifecycle()
    val clinicState by viewModel.ui.collectAsStateWithLifecycle()
    val unseen by app.notifications.unseenCount.collectAsStateWithLifecycle()
    val pending by app.pendingDestinations.pending.collectAsStateWithLifecycle()
    val unnamed = stringResource(R.string.unnamed_patient)
    var tab by remember { mutableStateOf(TherapistRootTab.Patients) }
    val colors = Theme.colors
    val lifecycleOwner = LocalLifecycleOwner.current
    LaunchedEffect(lifecycleOwner, isDemoMode) {
        if (isDemoMode) return@LaunchedEffect
        lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (isActive) {
                delay(60_000)
                app.notifications.refresh(silently = true)
            }
        }
    }

    LaunchedEffect(isDemoMode) {
        tab = TherapistRootTab.Patients
        app.notifications.isDemoInbox = isDemoMode
        if (isDemoMode) app.notifications.clear() else app.notifications.refresh()
        if (isDemoMode && com.cbtipul.app.BuildConfig.DEBUG &&
            (context as? android.app.Activity)?.intent?.getBooleanExtra("cbtipul_test_notifications", false) == true
        ) {
            patients.firstOrNull { it.sessions.isNotEmpty() }?.let { patient ->
                val records = runCatching { app.patientRepository.loadQuestionnaires(patient.id) }.getOrDefault(emptyList())
                app.notifications.seedUITestingNotifications(patient.id.queryValue, records.firstOrNull()?.databaseId?.queryValue)
            }
        }
    }

    LaunchedEffect(pending, clinicState.hasLoaded, inboxEntry != null) {
        val destination = pending ?: return@LaunchedEffect
        if (destination is AppDestination.DiaryThreeEntry && (!clinicState.hasLoaded || currentEntry == null)) return@LaunchedEffect
        if (destination !is AppDestination.PatientDetail &&
            destination !is AppDestination.QuestionnaireResult &&
            destination !is AppDestination.DiaryOneEntry &&
            destination !is AppDestination.DiaryTwoEntry &&
            destination !is AppDestination.DiaryThreeEntry
        ) {
            return@LaunchedEffect
        }
        tab = TherapistRootTab.Notifications
        if (inboxEntry == null || !clinicState.hasLoaded) return@LaunchedEffect
        app.pendingDestinations.consume()
        navigateInboxDestination(inboxNav, destination)
    }

    Column(Modifier.fillMaxSize()) {
        if (isDemoMode) DemoModeBanner(onExit = { viewModel.exitDemoMode() })
        Box(Modifier.weight(1f).fillMaxSize()) {
            Box(Modifier.fillMaxSize().then(if (tab == TherapistRootTab.Patients) Modifier else Modifier.clearAndSetSemantics {})) {
                CompositionLocalProvider(LocalTabReselections provides reselections.getValue(TherapistRootTab.Patients)) {
                    PatientsNavHost(
                        viewModel = viewModel,
                        onOpenSettings = { tab = TherapistRootTab.Settings },
                        onCloseSettings = onCloseSettingsOverlay,
                        navController = patientsNav,
                    )
                }
            }
            // The mounted Patients stack must not handle Back behind another tab.
            // Child settings pages register later and keep their own Back behavior.
            BackHandler(enabled = tab != TherapistRootTab.Patients) { tab = TherapistRootTab.Patients }
            CompositionLocalProvider(LocalTabReselections provides reselections.getValue(tab)) {
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
                        onCreateSession = {
                            tab = TherapistRootTab.Patients
                            patientsNav.navigate("patient/_/session/new")
                        },
                    )
                    TherapistRootTab.AI -> PatientsNavHost(
                        viewModel = viewModel,
                        navController = aiNav,
                        rootContent = {
                            AIPatientPickerScreen(viewModel, unnamed) { patientId ->
                                aiNav.navigate("patient/$patientId/chat")
                            }
                        },
                    )
                    TherapistRootTab.Notifications -> PatientsNavHost(
                        viewModel = viewModel,
                        onOpenSettings = { tab = TherapistRootTab.Settings },
                        navController = inboxNav,
                        rootContent = {
                            NotificationsInboxScreen(
                                repository = app.notifications, patients = patients, unnamed = unnamed,
                                onOpen = { item ->
                                    val destination = NotificationRouting.destination(NotificationPayload.from(item))
                                    app.applicationScope.launch { app.notifications.markRead(item) }
                                    if (destination != null) navigateInboxDestination(inboxNav, destination)
                                },
                            )
                        },
                    )
                    TherapistRootTab.Library -> LibraryPlaceholderScreen()
                    TherapistRootTab.Settings -> settingsContent()
                }
            }
        }
        // Keep the full editor viewport available while typing.
        if (WindowInsets.ime.getBottom(LocalDensity.current) == 0) {
            NavigationBar(containerColor = colors.base, tonalElevation = 0.dp) {
                TherapistRootTab.ordered.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = {
                            if (tab != item) {
                                tab = item
                            } else if (item == TherapistRootTab.AI && aiEntry?.destination?.route != "list") {
                                backDispatcher?.onBackPressed()
                            } else if (item == TherapistRootTab.Notifications && inboxEntry?.destination?.route != "list") {
                                backDispatcher?.onBackPressed()
                            } else if (item == TherapistRootTab.Patients && currentEntry?.destination?.route != "list") {
                                // Ignore taps during transitions, and let editing screens handle
                                // Back themselves (save/discard, recording and in-flight work).
                                if (currentEntry?.lifecycle?.currentState == Lifecycle.State.RESUMED) {
                                    if (canResetPatientsTab(currentEntry?.destination?.route)) {
                                        patientsNav.popBackStack("list", inclusive = false)
                                    } else {
                                        backDispatcher?.onBackPressed()
                                    }
                                }
                            } else {
                                reselections.getValue(item).tryEmit(Unit)
                            }
                        },
                        icon = {
                            if (item == TherapistRootTab.Notifications) {
                                BadgedBox(
                                    badge = {
                                        if (unseen > 0 && tab != TherapistRootTab.Notifications) {
                                            Badge { Text(if (unseen > 99) "99+" else unseen.toString()) }
                                        }
                                    },
                                ) {
                                    Icon(Icons.Filled.Notifications, contentDescription = null)
                                }
                            } else {
                                Icon(item.icon(), contentDescription = null)
                            }
                        },
                        label = { Text(stringResource(item.labelRes())) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = colors.gold,
                            selectedTextColor = colors.gold,
                            unselectedIconColor = colors.textBody,
                            unselectedTextColor = colors.textBody,
                            indicatorColor = colors.goldGhost,
                        ),
                    )
                }
            }
        }
    }
}

private fun TherapistRootTab.icon() = when (this) {
    TherapistRootTab.Patients -> Icons.Filled.People
    TherapistRootTab.Sessions -> Icons.Outlined.CalendarMonth
    TherapistRootTab.AI -> Icons.Outlined.AutoAwesome
    TherapistRootTab.Notifications -> Icons.Filled.Notifications
    TherapistRootTab.Library -> Icons.Outlined.MenuBook
    TherapistRootTab.Settings -> Icons.Filled.Settings
}

private fun TherapistRootTab.labelRes() = when (this) {
    TherapistRootTab.Patients -> R.string.therapist_tab_patients
    TherapistRootTab.Sessions -> R.string.therapist_tab_sessions
    TherapistRootTab.AI -> R.string.therapist_tab_ai
    TherapistRootTab.Notifications -> R.string.therapist_tab_notifications
    TherapistRootTab.Library -> R.string.therapist_tab_library
    TherapistRootTab.Settings -> R.string.therapist_tab_settings
}

fun navigateTherapistDestination(nav: NavHostController, destination: AppDestination) {
    NotificationRouting.therapistRoutes(destination).forEachIndexed { index, route ->
        nav.navigate(route) {
            if (index == 0) popUpTo("list") { inclusive = false }
            launchSingleTop = true
        }
    }
}

@Suppress("unused")
fun therapistRootTabIds(): List<String> = TherapistRootTabs.ordered

private fun navigateInboxDestination(nav: NavHostController, destination: AppDestination) {
    val route = NotificationRouting.inboxRoute(destination) ?: return
    nav.navigate(route) {
        popUpTo("list") { inclusive = false }
        launchSingleTop = true
    }
}
