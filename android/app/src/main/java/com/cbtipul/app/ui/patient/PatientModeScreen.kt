package com.cbtipul.app.ui.patient

import androidx.compose.material.icons.outlined.MenuBook

import androidx.compose.material.icons.outlined.Assignment

import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.heightIn

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.cbtipul.app.data.DeviceFormDraftStore
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.MailOutline
import com.cbtipul.app.ui.theme.IconLabel
import com.cbtipul.app.ui.theme.popScreen
import com.cbtipul.app.ui.theme.AppMotion
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.collectAsState
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.cbtipul.app.data.PatientInbox
import com.cbtipul.app.data.PatientInboxItem
import com.cbtipul.app.data.NotificationPayload
import com.cbtipul.app.data.AppNotificationTypes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.cbtipul.app.R
import com.cbtipul.app.data.AppDestination
import com.cbtipul.app.data.DiaryFeeling
import com.cbtipul.app.data.DiaryThreeEntry
import com.cbtipul.app.data.PatientDiaryThreeAccess
import com.cbtipul.app.data.PatientDiaryThreeHistory
import com.cbtipul.app.data.DiaryTwoEntry
import com.cbtipul.app.data.PatientDiaryTwoAccess
import com.cbtipul.app.data.PatientDiaryTwoHistory
import com.cbtipul.app.data.DiaryOneEntry
import com.cbtipul.app.data.NotificationRouting
import com.cbtipul.app.data.PatientAssignment
import com.cbtipul.app.data.PatientAssignmentType
import com.cbtipul.app.data.PatientHomeMessages
import com.cbtipul.app.data.PatientMessage
import com.cbtipul.app.ui.messages.MessageListScreen
import com.cbtipul.app.ui.messages.PatientMessageDetailScreen
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDateTime
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import com.cbtipul.app.data.PatientHomeCache
import com.cbtipul.app.data.PatientHomeSnapshot
import androidx.compose.runtime.SideEffect
import com.cbtipul.app.ui.theme.hebrewDate
import java.util.Date

private enum class TasksLoadState { Loading, Loaded, Failed }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientModeScreen(
    diaryTwo: PatientDiaryTwoAccess,
    diaryThree: PatientDiaryThreeAccess,
    patientId: String,
    loadAssignments: suspend () -> List<PatientAssignment>,
    submitQuestionnaire: suspend (String, List<Int>, List<Int>, Int) -> Unit,
    submitDiaryOne: suspend (String, List<String>, List<DiaryFeeling>, String, String?) -> Unit,
    loadQuestionnaireHistory: suspend () -> List<com.cbtipul.app.model.CompletedQuestionnaire>,
    loadDiaryOneHistory: suspend () -> List<DiaryOneEntry> = { emptyList() },
    loadMessages: suspend () -> List<PatientMessage> = { emptyList() },
    loadMessage: suspend (String) -> PatientMessage? = { null },
    markMessageRead: suspend (String) -> Unit = {},
    pendingDestination: AppDestination? = null,
    onConsumePending: () -> Unit = {},
    onOpenSettings: () -> Unit,
) {
    val introContext = androidx.compose.ui.platform.LocalContext.current
    val introPreferences = remember { introContext.getSharedPreferences("patient_introduction", android.content.Context.MODE_PRIVATE) }
    var showIntroduction by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(!introPreferences.getBoolean("completed.v1", false)) }
    val scope = rememberCoroutineScope()
    val nav = rememberNavController()
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as com.cbtipul.app.CbTipulApp
    val cacheKey = "${app.authRepository.currentUserId()}:$patientId"
    val cached = remember(cacheKey) { PatientHomeCache.read(cacheKey) }
    var manualRefreshing by remember(cacheKey) { mutableStateOf(false) }
    var refreshing by remember(cacheKey) { mutableStateOf(false) }
    var refreshAgain by remember(cacheKey) { mutableStateOf(false) }
    var loadState by remember(cacheKey) { mutableStateOf(if (cached.assignments != null) TasksLoadState.Loaded else TasksLoadState.Loading) }
    var assignments by remember(cacheKey) { mutableStateOf(cached.assignments.orEmpty()) }
    var messages by remember(cacheKey) { mutableStateOf<List<PatientMessage>>(emptyList()) }
    var questionnaireHistory by remember(cacheKey) { mutableStateOf(cached.questionnaires.orEmpty()) }
    var didSubmitQuestionnaire by remember { mutableStateOf(false) }
    var pendingDiaryOneSuccess by remember { mutableStateOf(false) }
    var didSubmitDiaryOne by remember { mutableStateOf(false) }
    var diaryTwoEntries by remember(cacheKey) { mutableStateOf(cached.diaryTwo.orEmpty()) }
    var diaryThreeEntries by remember(cacheKey) { mutableStateOf(cached.diaryThree.orEmpty()) }
    var didSubmitDiaryThree by remember { mutableStateOf(false) }
    var diaryThreeUnavailable by remember(patientId) { mutableStateOf(false) }
    var didSubmitDiaryTwo by remember { mutableStateOf(false) }
    var diaryEntries by remember(cacheKey) { mutableStateOf(cached.diaryOne.orEmpty()) }

    val notifications by app.notifications.items.collectAsState()
    val notificationsFailed by app.notifications.failed.collectAsState()
    var messagesFailed by remember(cacheKey) { mutableStateOf(false) }
    var unavailable by remember { mutableStateOf(false) }
    var openedAssignmentId by remember(cacheKey) { mutableStateOf<String?>(null) }
    val acknowledgedAssignments = remember(cacheKey) { mutableSetOf<String>() }
    val inboxItems = PatientInbox.items(patientId, messages, notifications)
    suspend fun acknowledgeAssignment(type: PatientAssignmentType) {
        val id = openedAssignmentId ?: return
        if (assignments.none { it.id == id && it.type == type && it.cancelledAt == null }) return
        acknowledgedAssignments.add(id)
        app.notifications.markPatientResourceRead(patientId, assignmentId = id)
        if (openedAssignmentId == id) openedAssignmentId = null
    }
    fun openTool(type: PatientAssignmentType, exactId: String? = null) {
        openedAssignmentId = exactId ?: assignments.firstOrNull { it.type == type && it.cancelledAt == null }?.id
        nav.navigate(when (type) {
            PatientAssignmentType.Questionnaire -> "questionnaires"
            PatientAssignmentType.DiaryOne -> "diary-one"
            PatientAssignmentType.DiaryTwo -> "diary-two"
            PatientAssignmentType.DiaryThree -> "diary-three"
        }) { launchSingleTop = true }
    }
    suspend fun openDirectTool(type: PatientAssignmentType) {
        val current = assignments.firstOrNull { it.type == type && it.cancelledAt == null }
        if (current != null) {
            val fresh = runCatching { loadAssignments() }.getOrNull()
            if (fresh == null || fresh.none { it.id == current.id && it.type == type && it.cancelledAt == null }) {
                unavailable = true; return
            }
            assignments = fresh
        }
        openTool(type, current?.id)
    }
    suspend fun openPayload(payload: NotificationPayload) {
        if (!payload.patientId.equals(patientId, true)) { unavailable = true; return }
        if (payload.type == AppNotificationTypes.MESSAGE_RECEIVED) {
            val id = payload.resourceId.takeIf { payload.resourceType == "message" }
            if (id == null || runCatching { java.util.UUID.fromString(id) }.isFailure) { unavailable = true; return }
            nav.navigate("message/$id") { launchSingleTop = true }
            return
        }
        val type = PatientInbox.assignmentType(payload.type)
        val loaded = runCatching { loadAssignments() }.getOrNull()
        val match = loaded?.let { PatientInbox.assignment(payload, patientId, it) }
        if (match == null) { unavailable = true; return }
        if (cacheKey != "${app.authRepository.currentUserId()}:$patientId") return
        assignments = loaded.orEmpty()
        openTool(type ?: return, match.id)
    }
    fun openItem(item: PatientInboxItem) {
        item.message?.let { nav.navigate("message/${it.id}"); return }
        item.notification?.let { scope.launch { openPayload(NotificationPayload.from(it)) } }
    }

    SideEffect {
        if (loadState == TasksLoadState.Loaded) PatientHomeCache.save(cacheKey,
            PatientHomeSnapshot(assignments, questionnaireHistory, diaryEntries, diaryTwoEntries, diaryThreeEntries))
    }
    suspend fun reload(lightweight: Boolean = false) {
        if (refreshing) { refreshAgain = true; return }
        refreshing = true
        try {
            coroutineScope {
                val tasks = async { runCatching { loadAssignments() }.getOrNull() }
                val inbox = async { runCatching { loadMessages() }.getOrNull() }
                val updates = async { app.notifications.refresh() }
                val questionnaires = async { if (lightweight) questionnaireHistory else runCatching { loadQuestionnaireHistory() }.getOrNull() }
                val one = async { if (lightweight) diaryEntries else runCatching { loadDiaryOneHistory() }.getOrNull() }
                val two = async { if (lightweight) diaryTwoEntries else runCatching { diaryTwo.loadPatientCreatedEntries(patientId) }.getOrNull() }
                val three = async { if (lightweight) diaryThreeEntries else runCatching { diaryThree.loadPatientCreatedEntries(patientId) }.getOrNull() }
                val fetchedTasks = tasks.await()
                val fetchedInbox = inbox.await()
                updates.await()
                messagesFailed = fetchedInbox == null
                val fetchedQuestionnaires = questionnaires.await()
                val fetchedOne = one.await()
                val fetchedTwo = two.await()
                val fetchedThree = three.await()
                if (cacheKey != "${app.authRepository.currentUserId()}:$patientId") return@coroutineScope
                fetchedTasks?.let { assignments = it }
                fetchedInbox?.let { messages = it }
                fetchedQuestionnaires?.let { questionnaireHistory = it }
                fetchedOne?.let { diaryEntries = it }
                fetchedTwo?.let { diaryTwoEntries = it }
                fetchedThree?.let { diaryThreeEntries = it }
                if (fetchedTasks != null) loadState = TasksLoadState.Loaded
                else if (loadState != TasksLoadState.Loaded) loadState = TasksLoadState.Failed
            }
            messages.filter { !it.isUnread }.forEach { app.notifications.markPatientResourceRead(patientId, messageId = it.id) }
            acknowledgedAssignments.toList().forEach { app.notifications.markPatientResourceRead(patientId, assignmentId = it) }
        } finally { refreshing = false }
        if (refreshAgain) { refreshAgain = false; reload() }
    }

    suspend fun manualReload() {
        if (manualRefreshing) return
        manualRefreshing = true
        try {
            while (refreshing) kotlinx.coroutines.delay(50)
            reload()
        } finally { manualRefreshing = false }
    }

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(cacheKey, lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            app.notifications.isDemoInbox = false
            app.pushManager.clearPatientModeNotifications(inboxItems.mapNotNull { it.notification?.id }.toSet())
            app.notifications.markInboxSeen(clearSystemNotifications = false)
            launch(start = kotlinx.coroutines.CoroutineStart.UNDISPATCHED) { app.patientPushRevision.drop(1).collect { reload() } }
            reload()
            app.pushManager.clearPatientModeNotifications(app.notifications.items.value.filter { it.patientId.equals(patientId, true) && NotificationPayload.from(it).isPatientMode() }.map { it.id }.toSet())
            while (true) { kotlinx.coroutines.delay(60_000); reload(lightweight = true) }
        }
    }
    LaunchedEffect(pendingDestination, showIntroduction) {
        if (showIntroduction) return@LaunchedEffect
        val destination = pendingDestination ?: return@LaunchedEffect
        val payload = when (destination) {
            is AppDestination.PatientQuestionnaire -> destination.payload
            is AppDestination.PatientDiaryTwoForm -> destination.payload
            is AppDestination.PatientDiaryThreeForm -> destination.payload
            is AppDestination.PatientDiaryOneForm -> destination.payload ?: NotificationPayload(AppNotificationTypes.DIARY_ONE_ASSIGNED, null, patientId, null, destination.assignmentId, "assignment", destination.assignmentId)
            is AppDestination.PatientMessage -> destination.payload ?: NotificationPayload(AppNotificationTypes.MESSAGE_RECEIVED, null, patientId, null, null, "message", destination.messageId)
            else -> null
        }
        if (payload != null) openPayload(payload) else unavailable = true
        onConsumePending()
    }

    if (showIntroduction) {
        com.cbtipul.app.ui.onboarding.AppIntroductionScreen(isPatientMode = true, onTrySample = {}, onContinue = {
            introPreferences.edit().putBoolean("completed.v1", true).apply()
            showIntroduction = false
        })
        return
    }

    val navigationDirection = LocalLayoutDirection.current
    NavHost(
        navController = nav,
        startDestination = "home",
        enterTransition = { AppMotion.enter(navigationDirection) },
        exitTransition = { AppMotion.exit(navigationDirection) },
        popEnterTransition = { AppMotion.enter(navigationDirection, back = true) },
        popExitTransition = { AppMotion.exit(navigationDirection, back = true) },
    ) {
        composable("home") {
            PatientHomeContent(
                loadState = loadState,
                assignments = assignments,
                messages = messages,
                inboxItems = inboxItems,
                inboxFailed = messagesFailed || notificationsFailed,
                onOpenInboxItem = ::openItem,
                patientId = patientId,
                lastQuestionnaire = questionnaireHistory.maxByOrNull { it.answeredDate }?.answeredDate,
                lastSubmissions = mapOf(
                    PatientAssignmentType.Questionnaire to questionnaireHistory.maxByOrNull { it.answeredDate }?.answeredDate,
                    PatientAssignmentType.DiaryOne to diaryEntries.maxByOrNull { it.createdAt }?.createdAt,
                    PatientAssignmentType.DiaryTwo to diaryTwoEntries.maxByOrNull { it.createdAt }?.createdAt,
                    PatientAssignmentType.DiaryThree to diaryThreeEntries.maxByOrNull { it.createdAt }?.createdAt,
                ),
                historyTypes = PatientAssignmentType.entries.filter { type ->
                    PatientHomeSnapshot(questionnaires = questionnaireHistory, diaryOne = diaryEntries,
                        diaryTwo = diaryTwoEntries, diaryThree = diaryThreeEntries).hasHistory(type)
                }.toSet(),
                onResume = { assignment ->
                    openedAssignmentId = assignment.id
                    when (assignment.type) {
                        PatientAssignmentType.Questionnaire -> { nav.navigate("questionnaires"); if (com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("questionnaire/${assignment.id}") }
                        PatientAssignmentType.DiaryOne -> if (com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("diary-one/new")
                        PatientAssignmentType.DiaryTwo -> if (com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("diary-two/new")
                        else -> Unit
                    }
                },
                onOpenSettings = onOpenSettings,
                manualRefreshing = manualRefreshing,
                onBackgroundRefresh = { scope.launch { reload() } },
                onRefresh = { scope.launch { manualReload() } },
                onOpenQuestionnaire = { scope.launch { openDirectTool(PatientAssignmentType.Questionnaire) } },
                onOpenDiaryOne = { scope.launch { openDirectTool(PatientAssignmentType.DiaryOne) } },
                onOpenDiaryTwo = { scope.launch { openDirectTool(PatientAssignmentType.DiaryTwo) } },
                onOpenDiaryThree = { diaryThreeUnavailable = false; scope.launch { openDirectTool(PatientAssignmentType.DiaryThree) } },
                onOpenMessage = { nav.navigate("message/$it") },
                onOpenAllMessages = { nav.navigate("messages") },
            )
        }
        composable("questionnaires") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.Questionnaire) }
            PatientQuestionnaireHubScreen(
                loadAssignments = { loadAssignments().also { assignments = it } },
                loadHistory = loadQuestionnaireHistory,
                onNew = { id -> if (assignments.any { it.id == id && it.cancelledAt == null } && com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("questionnaire/$id") },
                onOpen = { nav.navigate("questionnaires/result/${it.databaseId.queryValue}") },
                onLoaded = { questionnaireHistory = it },
                onBack = { nav.popScreen() },
            )
        }
        composable("questionnaires/result/{resultId}", arguments = listOf(navArgument("resultId") { type = NavType.StringType })) { entry ->
            val id = entry.arguments?.getString("resultId")
            PatientQuestionnaireResultScreen(questionnaireHistory.firstOrNull { it.databaseId.queryValue == id }, onBack = { nav.popScreen() })
        }
        composable("questionnaire/{assignmentId}", arguments = listOf(navArgument("assignmentId") { type = NavType.StringType })) { entry ->
            val assignmentId = entry.arguments?.getString("assignmentId").orEmpty()
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.Questionnaire) }
            PatientQuestionnaireScreen(
                assignmentId = assignmentId,
                onSubmit = { gad7, phq9, interference ->
                    submitQuestionnaire(assignmentId, gad7, phq9, interference)
                    didSubmitQuestionnaire = true
                },
                onInactive = { scope.launch { reload() } },
                onBack = {
                    if (!nav.popBackStack("questionnaires", inclusive = false)) nav.navigate("questionnaires")
                    scope.launch { reload() }
                },
            )
        }
        composable("diary-one") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.DiaryOne) }
            PatientDiaryOneHubScreen(
                active = assignments.any { it.type == PatientAssignmentType.DiaryOne && it.isOpen },
                loadEntries = {
                    val loaded = loadDiaryOneHistory()
                    diaryEntries = loaded
                    loaded
                },
                onAddEntry = { if (assignments.any { it.type == PatientAssignmentType.DiaryOne && it.cancelledAt == null } && com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("diary-one/new") },
                onOpenEntry = { nav.navigate("diary-one/entry/${it.id}") },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-one/new") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.DiaryOne) }
            PatientDiaryOneEntryScreen(
                draftTarget = assignments.firstOrNull { it.type == PatientAssignmentType.DiaryOne }?.patientId ?: "diary-one",
                onSubmit = { event, automaticThoughts, feelings, behaviour, physicalSymptoms ->
                    submitDiaryOne(event, automaticThoughts, feelings, behaviour, physicalSymptoms)
                    pendingDiaryOneSuccess = true
                    reload()
                },
                onDiaryInactive = {
                    assignments = assignments.filterNot { it.type == PatientAssignmentType.DiaryOne }
                    scope.launch { reload() }
                },
                onBack = { nav.popScreen(); if (pendingDiaryOneSuccess) { pendingDiaryOneSuccess = false; didSubmitDiaryOne = true } },
            )
        }
        composable(
            "diary-one/entry/{entryId}",
            arguments = listOf(navArgument("entryId") { type = NavType.StringType }),
        ) { entry ->
            val entryId = entry.arguments?.getString("entryId").orEmpty()
            var detail by remember(entryId, diaryEntries) {
                mutableStateOf(diaryEntries.firstOrNull { it.id.equals(entryId, true) })
            }
            LaunchedEffect(entryId) {
                if (detail == null) {
                    val loaded = runCatching { loadDiaryOneHistory() }.getOrDefault(emptyList())
                    diaryEntries = loaded
                    detail = loaded.firstOrNull { it.id.equals(entryId, true) }
                }
            }
            val current = detail
            if (current != null) {
                PatientDiaryOneDetailScreen(entry = current, onBack = { nav.popScreen() })
            } else {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Theme.colors.gold)
                }
            }
        }
        composable("diary-two") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.DiaryTwo) }
            PatientDiaryTwoHubScreen(
                patientId = patientId, service = diaryTwo,
                active = assignments.any { it.type == PatientAssignmentType.DiaryTwo && it.cancelledAt == null },
                onLoaded = { diaryTwoEntries = it },
                onAddEntry = { if (assignments.any { it.type == PatientAssignmentType.DiaryTwo && it.cancelledAt == null } && com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("diary-two/new") },
                onOpenEntry = { nav.navigate("diary-two/entry/${it.id}") },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-two/new") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.DiaryTwo) }
            PatientDiaryTwoEntryScreen(patientId, diaryTwo,
                onSubmitted = {
                    nav.popScreen()
                    didSubmitDiaryTwo = true
                    scope.launch { reload() }
                },
                onDiaryInactive = {
                    assignments = assignments.filterNot { it.type == PatientAssignmentType.DiaryTwo }
                    nav.popScreen()
                    scope.launch { reload() }
                },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-two/entry/{entryId}", arguments = listOf(navArgument("entryId") { type = NavType.StringType })) { destination ->
            val id = destination.arguments?.getString("entryId").orEmpty()
            var detail by remember(id, diaryTwoEntries) { mutableStateOf(diaryTwoEntries.firstOrNull { it.id.equals(id, true) }) }
            var loading by remember(id) { mutableStateOf(detail == null) }
            var failed by remember(id) { mutableStateOf(false) }
            var retry by remember(id) { mutableStateOf(0) }
            LaunchedEffect(id, retry) {
                if (detail == null) {
                    loading = true
                    try {
                        val entries = PatientDiaryTwoHistory.visible(diaryTwo.loadPatientCreatedEntries(patientId), patientId)
                        diaryTwoEntries = entries
                        detail = entries.firstOrNull { it.id.equals(id, true) }
                        failed = false
                    } catch (e: kotlinx.coroutines.CancellationException) { throw e }
                    catch (_: Exception) { failed = true }
                    loading = false
                }
            }
            val current = detail
            if (current != null) PatientDiaryTwoDetailScreen(current) { nav.popScreen() }
            else Column(Modifier.fillMaxSize().safeDrawingPadding().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                TextButton(onClick = { nav.popScreen() }) { Text(stringResource(R.string.back)) }
                if (loading) CircularProgressIndicator(color = Theme.colors.gold)
                else {
                    Text(stringResource(if (failed) R.string.diary_two_load_failed else R.string.notification_target_unavailable), color = Theme.colors.textBody)
                    if (failed) TextButton(onClick = { retry++ }) { Text(stringResource(R.string.retry_action)) }
                }
            }
        }
        composable("diary-three") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.DiaryThree) }
            PatientDiaryThreeHubScreen(
                patientId = patientId, service = diaryThree,
                active = !diaryThreeUnavailable && assignments.any { it.type == PatientAssignmentType.DiaryThree && it.cancelledAt == null },
                onLoaded = { diaryThreeEntries = it },
                onAddEntry = { if (PatientAssignmentType.diaryThreeSendingEnabled && assignments.any { it.type == PatientAssignmentType.DiaryThree && it.cancelledAt == null } && com.cbtipul.app.data.Entitlements.allowMutation()) nav.navigate("diary-three/new") },
                onRefreshAssignments = { scope.launch { reload() } },
                onOpenEntry = { nav.navigate("diary-three/entry/${it.id}") },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-three/new") {
            LaunchedEffect(openedAssignmentId) { acknowledgeAssignment(PatientAssignmentType.DiaryThree) }
            if (!PatientAssignmentType.diaryThreeSendingEnabled) {
                // A back stack restored after an app update may still contain the entry form.
                LaunchedEffect(Unit) {
                    nav.navigate("diary-three") {
                        popUpTo("home")
                        launchSingleTop = true
                    }
                }
            } else {
                PatientDiaryThreeEntryScreen(patientId, diaryThree,
                    onSubmitted = {
                        nav.popScreen()
                        didSubmitDiaryThree = true
                        scope.launch { reload() }
                    },
                    onAccessInvalidated = {
                        diaryThreeUnavailable = true
                        assignments = assignments.filterNot { it.type == PatientAssignmentType.DiaryThree }
                        scope.launch { reload() }
                    },
                    onDiaryInactive = { nav.popScreen() },
                    onBack = { nav.popScreen() },
                )
            }
        }
        composable("diary-three/entry/{entryId}", arguments = listOf(navArgument("entryId") { type = NavType.StringType })) { destination ->
            val id = destination.arguments?.getString("entryId").orEmpty()
            var detail by remember(id, diaryThreeEntries) { mutableStateOf(diaryThreeEntries.firstOrNull { it.id.equals(id, true) }) }
            var loading by remember(id) { mutableStateOf(detail == null) }
            var failed by remember(id) { mutableStateOf(false) }
            var retry by remember(id) { mutableStateOf(0) }
            LaunchedEffect(id, retry) {
                if (detail == null) {
                    loading = true
                    try {
                        val entries = PatientDiaryThreeHistory.visible(diaryThree.loadPatientCreatedEntries(patientId), patientId)
                        diaryThreeEntries = entries
                        detail = entries.firstOrNull { it.id.equals(id, true) }
                        failed = false
                    } catch (e: kotlinx.coroutines.CancellationException) { throw e }
                    catch (_: Exception) { failed = true }
                    loading = false
                }
            }
            val current = detail
            if (current != null) PatientDiaryThreeDetailScreen(current) { nav.popScreen() }
            else Column(Modifier.fillMaxSize().safeDrawingPadding().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                TextButton(onClick = { nav.popScreen() }) { Text(stringResource(R.string.back)) }
                if (loading) CircularProgressIndicator(color = Theme.colors.gold)
                else {
                    Text(stringResource(if (failed) R.string.diary_three_load_failed else R.string.notification_target_unavailable), color = Theme.colors.textBody)
                    if (failed) TextButton(onClick = { retry++ }) { Text(stringResource(R.string.retry_action)) }
                }
            }
        }
        composable("messages") {
            Scaffold(containerColor = Color.Transparent, modifier = Modifier.themedScreen(Theme.colors.gold), topBar = {
                TopAppBar(title = { Text(stringResource(R.string.patient_inbox_title)) }, navigationIcon = {
                    TextButton(onClick = { nav.popScreen() }) { Text(stringResource(R.string.back)) }
                })
            }) { padding ->
                Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp)) {
                    PatientInboxSection(inboxItems, messagesFailed || notificationsFailed, history = true, onOpen = ::openItem)
                    TextButton(onClick = { scope.launch { manualReload() } }) { Text(stringResource(R.string.patient_tasks_refresh)) }
                }
            }
        }
        composable("message/{messageId}", arguments = listOf(navArgument("messageId") { type = NavType.StringType })) { entry ->
            val messageId = entry.arguments?.getString("messageId").orEmpty()
            PatientMessageDetailScreen(
                load = { loadMessage(messageId)?.takeIf { it.patientId.equals(patientId, true) } },
                markRead = {
                    if (it.isUnread) markMessageRead(it.id)
                    app.notifications.markPatientResourceRead(patientId, messageId = it.id)
                    messages = messages.map { item -> if (item.id == it.id) item.markedRead(Date()) else item }
                },
                showNoReply = true,
                onBack = { nav.popScreen() },
            )
        }
    }
    if (unavailable) androidx.compose.material3.AlertDialog(
        onDismissRequest = { unavailable = false },
        text = { Text(stringResource(R.string.patient_inbox_unavailable)) },
        confirmButton = { TextButton(onClick = { unavailable = false }) { Text(stringResource(R.string.close_action)) } },
    )
    MessageOverlay(visible = didSubmitQuestionnaire, title = stringResource(R.string.patient_questionnaire_submitted), message = "", onDismiss = { didSubmitQuestionnaire = false })
    if (didSubmitDiaryThree) androidx.compose.material3.AlertDialog(
        onDismissRequest = { didSubmitDiaryThree = false },
        title = { Text(stringResource(R.string.patient_diary_one_saved)) },
        text = { Text(stringResource(R.string.patient_shared_help)) },
        confirmButton = { TextButton(onClick = { didSubmitDiaryThree = false; nav.navigate("diary-three") { launchSingleTop = true } }) { Text(stringResource(R.string.patient_view_entries)) } },
        dismissButton = { TextButton(onClick = { didSubmitDiaryThree = false; nav.popBackStack("home", false) }) { Text(stringResource(R.string.patient_return_home)) } })
    if (didSubmitDiaryTwo) androidx.compose.material3.AlertDialog(
        onDismissRequest = { didSubmitDiaryTwo = false },
        title = { Text(stringResource(R.string.patient_diary_one_saved)) },
        text = { Text(stringResource(R.string.patient_shared_help)) },
        confirmButton = { TextButton(onClick = { didSubmitDiaryTwo = false; nav.navigate("diary-two") { launchSingleTop = true } }) { Text(stringResource(R.string.patient_view_entries)) } },
        dismissButton = { TextButton(onClick = { didSubmitDiaryTwo = false; nav.popBackStack("home", false) }) { Text(stringResource(R.string.patient_return_home)) } })
    if (didSubmitDiaryOne) androidx.compose.material3.AlertDialog(
        onDismissRequest = { didSubmitDiaryOne = false },
        title = { Text(stringResource(R.string.patient_diary_one_saved)) },
        text = { Text(stringResource(R.string.patient_shared_help)) },
        confirmButton = { TextButton(onClick = { didSubmitDiaryOne = false; nav.navigate("diary-one") { launchSingleTop = true } }) { Text(stringResource(R.string.patient_view_entries)) } },
        dismissButton = { TextButton(onClick = { didSubmitDiaryOne = false; nav.popBackStack("home", false) }) { Text(stringResource(R.string.patient_return_home)) } })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PatientHomeContent(
    loadState: TasksLoadState,
    assignments: List<PatientAssignment>,
    messages: List<PatientMessage>,
    inboxItems: List<PatientInboxItem>,
    inboxFailed: Boolean,
    onOpenInboxItem: (PatientInboxItem) -> Unit,
    patientId: String,
    lastQuestionnaire: Date?,
    lastSubmissions: Map<PatientAssignmentType, Date?>,
    historyTypes: Set<PatientAssignmentType>,
    onResume: (PatientAssignment) -> Unit,
    onOpenSettings: () -> Unit,
    manualRefreshing: Boolean,
    onBackgroundRefresh: () -> Unit,
    onRefresh: () -> Unit,
    onOpenQuestionnaire: (String) -> Unit,
    onOpenDiaryOne: () -> Unit,
    onOpenDiaryTwo: () -> Unit,
    onOpenDiaryThree: () -> Unit,
    onOpenMessage: (String) -> Unit,
    onOpenAllMessages: () -> Unit,
) {
    val colors = Theme.colors
    val openAssignments = assignments.filter { if (it.type == PatientAssignmentType.DiaryTwo || it.type == PatientAssignmentType.DiaryThree) it.cancelledAt == null else it.isOpen }
    val app = androidx.compose.ui.platform.LocalContext.current.applicationContext as com.cbtipul.app.CbTipulApp
    val account = app.authRepository.currentUserId()
    var draftRevision by remember { mutableStateOf(0) }
    var resumable by remember(account, patientId) { mutableStateOf<List<PatientAssignment>>(emptyList()) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { draftRevision++ }
    LaunchedEffect(account, patientId, assignments, draftRevision) {
        resumable = withContext(Dispatchers.IO) {
            if (account == null) emptyList() else openAssignments.filter { assignment ->
                val kind = when (assignment.type) {
                    PatientAssignmentType.Questionnaire -> "questionnaire"
                    PatientAssignmentType.DiaryOne -> "diary-one"
                    PatientAssignmentType.DiaryTwo -> "diary-two"
                    else -> return@filter false
                }
                val target = if (assignment.type == PatientAssignmentType.Questionnaire) assignment.id else patientId
                runCatching { app.formDrafts.read(DeviceFormDraftStore.key(account, kind, target)) != null }.getOrDefault(false)
            }
        }
    }
    val refreshLabel = stringResource(R.string.patient_tasks_refresh)
    val unread = PatientHomeMessages.unread(messages)
    val previews = PatientHomeMessages.previews(messages)
    val remaining = PatientHomeMessages.remainingUnreadCount(messages)
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Outlined.Settings, contentDescription = stringResource(R.string.settings_title), tint = colors.gold)
                    }
                },
                actions = {
                    IconButton(onClick = onRefresh, enabled = loadState != TasksLoadState.Loading && !manualRefreshing, modifier = Modifier.semantics { contentDescription = refreshLabel }) {
                        if (manualRefreshing) CircularProgressIndicator(modifier = Modifier.size(22.dp), strokeWidth = 2.dp, color = colors.gold)
                        else Icon(Icons.Outlined.Refresh, contentDescription = stringResource(R.string.patient_tasks_refresh), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        when {
            else -> PullToRefreshBox(
                isRefreshing = manualRefreshing,
                onRefresh = onRefresh,
                modifier = Modifier.fillMaxSize().padding(padding),
            ) {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    PatientInboxSection(inboxItems, inboxFailed, onAll = onOpenAllMessages, onOpen = onOpenInboxItem)
                    if (loadState == TasksLoadState.Loading) CircularProgressIndicator(color = colors.gold)
                    if (loadState == TasksLoadState.Failed) Text(stringResource(R.string.patient_tasks_load_error), color = colors.error)
                    Column(
                        Modifier.fillMaxWidth().padding(top = 12.dp, bottom = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        androidx.compose.material3.HorizontalDivider(
                            color = colors.textFaint.copy(alpha = 0.25f),
                            modifier = Modifier.padding(bottom = 4.dp),
                        )
                        Text(stringResource(R.string.patient_tools_section_title), color = colors.textBright,
                            fontWeight = FontWeight.SemiBold, fontSize = 17.sp, modifier = Modifier.semantics { heading() })
                        Text(stringResource(R.string.patient_available_help), color = colors.textBody, fontSize = 13.sp)
                    }
                    if (!com.cbtipul.app.ui.entitlementCanWrite()) {
                        Text(stringResource(R.string.entitlement_patient_unavailable), color = colors.textBody, fontSize = 13.sp)
                    }
                    PatientAssignmentType.entries.forEach { type ->
                        val active = openAssignments.any { it.type == type } && (type != PatientAssignmentType.DiaryThree || PatientAssignmentType.diaryThreeSendingEnabled)
                        if (active || type in historyTypes) {
                            val title = when (type) {
                                PatientAssignmentType.Questionnaire -> R.string.questionnaires_title
                                PatientAssignmentType.DiaryOne -> R.string.diary_one_title
                                PatientAssignmentType.DiaryTwo -> R.string.diary_two_title
                                PatientAssignmentType.DiaryThree -> R.string.diary_three_title
                            }
                            val draft = resumable.firstOrNull { it.type == type }
                            GroupedListCard(accent = colors.gold) {
                                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Row(Modifier.weight(1f).clickable {
                                        when (type) {
                                            PatientAssignmentType.Questionnaire -> onOpenQuestionnaire("")
                                            PatientAssignmentType.DiaryOne -> onOpenDiaryOne()
                                            PatientAssignmentType.DiaryTwo -> onOpenDiaryTwo()
                                            PatientAssignmentType.DiaryThree -> onOpenDiaryThree()
                                        }
                                    }.heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                        Icon(if (type == PatientAssignmentType.Questionnaire) Icons.Outlined.Assignment else Icons.Outlined.MenuBook, contentDescription = null, tint = if (active) colors.success else colors.textBody)
                                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Text(stringResource(title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                            Text(stringResource(when (type) { PatientAssignmentType.Questionnaire -> R.string.tool_questionnaire_purpose; PatientAssignmentType.DiaryOne -> R.string.patient_diary_one_purpose; PatientAssignmentType.DiaryTwo -> R.string.patient_diary_two_purpose; PatientAssignmentType.DiaryThree -> R.string.patient_diary_three_description }), color = colors.textBody, fontSize = 12.sp, maxLines = 2)
                                            PatientToolStatus(active)
                                            lastSubmissions[type]?.let {
                                                Text(stringResource(R.string.tool_last_sent, com.cbtipul.app.ui.theme.hebrewDate(it)), color = colors.textBody, fontSize = 12.sp)
                                            }
                                        }
                                        Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = colors.textFaint)
                                    }
                                    if (active && draft != null) {
                                        TextButton(onClick = { if (com.cbtipul.app.data.Entitlements.allowMutation()) onResume(draft) }) {
                                            Text(stringResource(R.string.patient_resume_action), color = colors.gold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if (openAssignments.isEmpty() && historyTypes.isEmpty()) {
                        Text(stringResource(R.string.patient_tasks_empty_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                        Text(stringResource(R.string.patient_tasks_empty_body), color = colors.textBody)
                    }

                }
            }
        }
    }
}

@Composable
private fun TaskCard(title: String, body: String, action: String?, hint: String? = null, available: Boolean? = null, onStart: () -> Unit) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, color = colors.textBright, fontWeight = FontWeight.SemiBold)
            available?.let {
                IconLabel(stringResource(if (it) R.string.patient_tool_enabled else R.string.patient_tool_disabled),
                    if (it) Icons.Outlined.CheckCircle else Icons.Outlined.Lock,
                    color = if (it) colors.textBright else colors.textBody, fontSize = 14.sp)
            }
            Text(body, color = colors.textBody)
            hint?.let { Text(it, color = colors.textFaint, fontSize = 13.sp) }
            if (action != null) {
                if (available == false) TextButton(onClick = onStart) { Text(action, color = colors.gold) }
                else GoldActionButton(action, onStart)
            }
        }
    }
}

@Composable
private fun GoldActionButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = Theme.colors
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(48.dp),
        colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent),
        shape = RoundedCornerShape(14.dp),
    ) { Text(text, fontWeight = FontWeight.SemiBold) }
}
