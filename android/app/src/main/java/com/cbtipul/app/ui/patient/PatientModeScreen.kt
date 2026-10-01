package com.cbtipul.app.ui.patient

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
import kotlinx.coroutines.launch
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
    val scope = rememberCoroutineScope()
    val nav = rememberNavController()
    var loadState by remember { mutableStateOf(TasksLoadState.Loading) }
    var assignments by remember { mutableStateOf<List<PatientAssignment>>(emptyList()) }
    var messages by remember { mutableStateOf<List<PatientMessage>>(emptyList()) }
    var questionnaireHistory by remember(patientId) { mutableStateOf<List<com.cbtipul.app.model.CompletedQuestionnaire>>(emptyList()) }
    var didSubmitQuestionnaire by remember { mutableStateOf(false) }
    var pendingDiaryOneSuccess by remember { mutableStateOf(false) }
    var didSubmitDiaryOne by remember { mutableStateOf(false) }
    var diaryTwoEntries by remember(patientId) { mutableStateOf<List<DiaryTwoEntry>>(emptyList()) }
    var diaryThreeEntries by remember(patientId) { mutableStateOf<List<DiaryThreeEntry>>(emptyList()) }
    var didSubmitDiaryThree by remember { mutableStateOf(false) }
    var diaryThreeUnavailable by remember(patientId) { mutableStateOf(false) }
    var didSubmitDiaryTwo by remember { mutableStateOf(false) }
    var diaryEntries by remember { mutableStateOf<List<DiaryOneEntry>>(emptyList()) }

    suspend fun reload() {
        if (assignments.isEmpty()) loadState = TasksLoadState.Loading
        try {
            assignments = loadAssignments()
            messages = runCatching { loadMessages() }.getOrDefault(emptyList())
            loadState = TasksLoadState.Loaded
            runCatching { loadQuestionnaireHistory() }.onSuccess { questionnaireHistory = it }
        } catch (_: Exception) {
            loadState = TasksLoadState.Failed
        }
    }

    LaunchedEffect(Unit) { reload() }
    LaunchedEffect(pendingDestination) {
        val destination = pendingDestination as? AppDestination.PatientDiaryTwoForm ?: return@LaunchedEffect
        val assignment = com.cbtipul.app.data.PatientDiaryTwoNotificationRouting.resolve(destination.payload, patientId) {
            loadAssignments().also { assignments = it }
        }
        nav.popBackStack("home", inclusive = false)
        if (assignment != null) nav.navigate("diary-two/new") { launchSingleTop = true }
        onConsumePending()
    }
    LaunchedEffect(pendingDestination) {
        val destination = pendingDestination as? AppDestination.PatientDiaryThreeForm ?: return@LaunchedEffect
        val assignment = com.cbtipul.app.data.PatientDiaryThreeNotificationRouting.resolve(destination.payload, patientId) {
            loadAssignments().also { assignments = it }
        }
        val route = if (PatientAssignmentType.diaryThreeSendingEnabled) "diary-three/new" else "diary-three"
        // Preserve the current screen when the same notification is opened again.
        if (assignment == null || nav.currentDestination?.route != route) {
            nav.popBackStack("home", inclusive = false)
            if (assignment != null) nav.navigate(route) { launchSingleTop = true }
        }
        onConsumePending()
    }
    LaunchedEffect(pendingDestination) {
        val destination = pendingDestination as? AppDestination.PatientQuestionnaire ?: return@LaunchedEffect
        val payload = destination.payload ?: run { onConsumePending(); return@LaunchedEffect }
        val assignment = com.cbtipul.app.data.PatientQuestionnaireNotificationRouting.resolve(payload, patientId) {
            loadAssignments().also { assignments = it }
        }
        if (assignment != null && nav.currentBackStackEntry?.arguments?.getString("assignmentId") != assignment.id) {
            nav.popBackStack("home", inclusive = false)
            nav.navigate("questionnaires")
            nav.navigate("questionnaire/${assignment.id}") { launchSingleTop = true }
        }
        onConsumePending()
    }
    LaunchedEffect(loadState, pendingDestination) {
        if (loadState != TasksLoadState.Loaded) return@LaunchedEffect
        val destination = pendingDestination ?: return@LaunchedEffect
        when (destination) {
            is AppDestination.PatientMessage,
            is AppDestination.PatientDiaryOneForm,
            -> {
                onConsumePending()
                when (destination) {
                    is AppDestination.PatientMessage -> {
                        val id = destination.messageId
                        if (id != null) nav.navigate("message/$id") else nav.navigate("messages")
                    }
                    is AppDestination.PatientDiaryOneForm -> {
                        val assignment = NotificationRouting.matchingOpenAssignment(
                            assignments, destination.assignmentId, PatientAssignmentType.DiaryOne,
                        )
                        if (assignment != null) nav.navigate("diary-one/new")
                    }
                    else -> Unit
                }
            }
            else -> Unit
        }
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
                patientId = patientId,
                lastQuestionnaire = questionnaireHistory.maxByOrNull { it.answeredDate }?.answeredDate,
                onResume = { assignment ->
                    when (assignment.type) {
                        PatientAssignmentType.Questionnaire -> { nav.navigate("questionnaires"); nav.navigate("questionnaire/${assignment.id}") }
                        PatientAssignmentType.DiaryOne -> nav.navigate("diary-one/new")
                        PatientAssignmentType.DiaryTwo -> nav.navigate("diary-two/new")
                        else -> Unit
                    }
                },
                onOpenSettings = onOpenSettings,
                onRefresh = { scope.launch { reload() } },
                onOpenQuestionnaire = { nav.navigate("questionnaires") },
                onOpenDiaryOne = { nav.navigate("diary-one") },
                onOpenDiaryTwo = { nav.navigate("diary-two") },
                onOpenDiaryThree = { diaryThreeUnavailable = false; nav.navigate("diary-three") },
                onOpenMessage = { nav.navigate("message/$it") },
                onOpenAllMessages = { nav.navigate("messages") },
            )
        }
        composable("questionnaires") {
            PatientQuestionnaireHubScreen(
                loadAssignments = { loadAssignments().also { assignments = it } },
                loadHistory = loadQuestionnaireHistory,
                onNew = { nav.navigate("questionnaire/$it") },
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
            PatientDiaryOneHubScreen(
                active = assignments.any { it.type == PatientAssignmentType.DiaryOne && it.isOpen },
                loadEntries = {
                    val loaded = loadDiaryOneHistory()
                    diaryEntries = loaded
                    loaded
                },
                onAddEntry = { nav.navigate("diary-one/new") },
                onOpenEntry = { nav.navigate("diary-one/entry/${it.id}") },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-one/new") {
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
            PatientDiaryTwoHubScreen(
                patientId = patientId, service = diaryTwo,
                active = assignments.any { it.type == PatientAssignmentType.DiaryTwo && it.cancelledAt == null },
                onLoaded = { diaryTwoEntries = it },
                onAddEntry = { nav.navigate("diary-two/new") },
                onOpenEntry = { nav.navigate("diary-two/entry/${it.id}") },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-two/new") {
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
            PatientDiaryThreeHubScreen(
                patientId = patientId, service = diaryThree,
                active = !diaryThreeUnavailable && assignments.any { it.type == PatientAssignmentType.DiaryThree && it.cancelledAt == null },
                onLoaded = { diaryThreeEntries = it },
                onAddEntry = { nav.navigate("diary-three/new") },
                onRefreshAssignments = { scope.launch { reload() } },
                onOpenEntry = { nav.navigate("diary-three/entry/${it.id}") },
                onBack = { nav.popScreen() },
            )
        }
        composable("diary-three/new") {
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
            MessageListScreen(
                title = stringResource(R.string.messages_title),
                load = {
                    val loaded = loadMessages()
                    messages = loaded
                    loaded
                },
                emptyText = stringResource(R.string.patient_messages_empty),
                showReadState = false,
                onBack = { nav.popScreen() },
                onOpen = { nav.navigate("message/${it.id}") },
            )
        }
        composable("message/{messageId}", arguments = listOf(navArgument("messageId") { type = NavType.StringType })) { entry ->
            val messageId = entry.arguments?.getString("messageId").orEmpty()
            PatientMessageDetailScreen(
                load = { loadMessage(messageId) ?: messages.firstOrNull { it.id.equals(messageId, true) } },
                markRead = {
                    markMessageRead(it.id)
                    messages = messages.map { item -> if (item.id == it.id) item.markedRead(Date()) else item }
                },
                showNoReply = true,
                onBack = { nav.popScreen() },
            )
        }
    }
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
    patientId: String,
    lastQuestionnaire: Date?,
    onResume: (PatientAssignment) -> Unit,
    onOpenSettings: () -> Unit,
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
                    IconButton(onClick = onRefresh, enabled = loadState != TasksLoadState.Loading) {
                        Icon(Icons.Outlined.Refresh, contentDescription = stringResource(R.string.patient_tasks_refresh), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        when {
            loadState == TasksLoadState.Loading && assignments.isEmpty() ->
                Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = colors.gold) }
            loadState == TasksLoadState.Failed && assignments.isEmpty() -> Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.Center) {
                Text(stringResource(R.string.patient_tasks_load_error), color = colors.textBody)
                GoldActionButton(stringResource(R.string.patient_activation_retry), onRefresh, Modifier.padding(top = 16.dp))
            }
            else -> PullToRefreshBox(
                isRefreshing = loadState == TasksLoadState.Loading && assignments.isNotEmpty(),
                onRefresh = onRefresh,
                modifier = Modifier.fillMaxSize().padding(padding),
            ) {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 24.dp, bottom = 28.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    Text(stringResource(R.string.app_title), color = colors.textBright, fontWeight = FontWeight.Bold, fontSize = 28.sp)
                    if (resumable.isNotEmpty()) {
                        Text(stringResource(R.string.patient_attention_title), color = colors.textBright, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
                        resumable.forEach { assignment ->
                            val title = when (assignment.type) {
                                PatientAssignmentType.DiaryOne -> R.string.patient_diary_one_purpose
                                PatientAssignmentType.DiaryTwo -> R.string.patient_diary_two_purpose
                                else -> R.string.patient_questionnaire_card_title
                            }
                            TaskCard(stringResource(title), stringResource(R.string.patient_local_only), stringResource(R.string.patient_resume_action)) { onResume(assignment) }
                        }
                    }
                    if (unread.isNotEmpty()) {
                    Text(stringResource(R.string.patient_messages_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
                    if (unread.isEmpty()) {
                        IconLabel(stringResource(if (messages.isEmpty()) R.string.patient_messages_empty else R.string.no_new_messages), Icons.Outlined.MailOutline, color = colors.textBody, fontSize = 14.sp)
                    } else {
                        previews.forEach { message ->
                            GroupedListCard(accent = colors.gold) {
                                Column(Modifier.fillMaxWidth().clickable { onOpenMessage(message.id) }.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(message.body, color = colors.textBright, fontWeight = FontWeight.SemiBold, maxLines = 3, modifier = Modifier.weight(1f))
                                        Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = colors.textFaint)
                                    }
                                    Text(hebrewDateTime(message.createdAt), color = colors.textFaint, fontSize = 13.sp)
                                }
                            }
                        }
                        if (remaining > 0) {
                            Text(
                                if (remaining == 1) stringResource(R.string.more_unread_messages_one)
                                else stringResource(R.string.more_unread_messages, remaining),
                                color = colors.gold,
                                modifier = Modifier.clickable(onClick = onOpenAllMessages),
                            )
                        }
                    }
                    if (messages.isNotEmpty()) {
                        TextButton(onClick = onOpenAllMessages) {
                            Text(
                                if (unread.isEmpty()) stringResource(R.string.all_messages_action)
                                else stringResource(R.string.all_messages_action_with_count, unread.size),
                                color = colors.gold,
                            )
                            Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = colors.gold)
                        }
                    }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(stringResource(R.string.patient_available_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
                        Text(stringResource(R.string.patient_available_help), color = colors.textBody)
                    }
                    TaskCard(
                        stringResource(R.string.patient_questionnaire_card_title),
                        stringResource(if (openAssignments.any { it.type == PatientAssignmentType.Questionnaire }) R.string.patient_questionnaire_card_body else R.string.patient_questionnaire_inactive_hint),
                        stringResource(if (openAssignments.any { it.type == PatientAssignmentType.Questionnaire }) R.string.patient_questionnaire_open else R.string.patient_questionnaire_history_action),
                        lastQuestionnaire?.let { stringResource(R.string.patient_last_questionnaire, hebrewDate(it)) },
                        available = openAssignments.any { it.type == PatientAssignmentType.Questionnaire },
                    ) { onOpenQuestionnaire("") }
                    listOf(PatientAssignmentType.DiaryOne, PatientAssignmentType.DiaryTwo).forEach { type ->
                        val active = openAssignments.any { it.type == type }
                        val diaryOne = type == PatientAssignmentType.DiaryOne
                        TaskCard(
                            stringResource(if (diaryOne) R.string.patient_diary_one_purpose else R.string.patient_diary_two_purpose),
                            stringResource(if (diaryOne) R.string.diary_one_title else R.string.diary_two_title) + "\n" +
                                stringResource(if (!active) R.string.patient_tool_activation_help else if (diaryOne) R.string.patient_diary_one_card_body else R.string.patient_diary_two_card_body),
                            action = stringResource(if (active) R.string.patient_diary_one_start else R.string.diary_one_my_entries),
                            hint = if (active) stringResource(R.string.patient_diary_one_ongoing_hint) else null,
                            available = active,
                        ) { if (diaryOne) onOpenDiaryOne() else onOpenDiaryTwo() }
                    }
                    run {
                        val active = PatientAssignmentType.diaryThreeSendingEnabled && openAssignments.any { it.type == PatientAssignmentType.DiaryThree }
                        TaskCard(
                            stringResource(R.string.diary_three_title),
                            stringResource(if (PatientAssignmentType.diaryThreeSendingEnabled) R.string.patient_diary_three_card_body else R.string.diary_three_sending_paused),
                            stringResource(if (active) R.string.patient_diary_one_start else R.string.diary_one_my_entries),
                            available = active,
                        ) { onOpenDiaryThree() }
                    }
                    if (openAssignments.any { it.type == null }) {
                        TaskCard(stringResource(R.string.patient_upcoming_task_title),
                            stringResource(R.string.patient_upcoming_task_body), null) {}
                    }
                    if (unread.isEmpty()) {
                    Text(stringResource(R.string.patient_messages_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
                    if (unread.isEmpty()) {
                        IconLabel(stringResource(if (messages.isEmpty()) R.string.patient_messages_empty else R.string.no_new_messages), Icons.Outlined.MailOutline, color = colors.textBody, fontSize = 14.sp)
                    } else {
                        previews.forEach { message ->
                            GroupedListCard(accent = colors.gold) {
                                Column(Modifier.fillMaxWidth().clickable { onOpenMessage(message.id) }.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(message.body, color = colors.textBright, fontWeight = FontWeight.SemiBold, maxLines = 3, modifier = Modifier.weight(1f))
                                        Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = colors.textFaint)
                                    }
                                    Text(hebrewDateTime(message.createdAt), color = colors.textFaint, fontSize = 13.sp)
                                }
                            }
                        }
                        if (remaining > 0) {
                            Text(
                                if (remaining == 1) stringResource(R.string.more_unread_messages_one)
                                else stringResource(R.string.more_unread_messages, remaining),
                                color = colors.gold,
                                modifier = Modifier.clickable(onClick = onOpenAllMessages),
                            )
                        }
                    }
                    if (messages.isNotEmpty()) {
                        TextButton(onClick = onOpenAllMessages) {
                            Text(
                                if (unread.isEmpty()) stringResource(R.string.all_messages_action)
                                else stringResource(R.string.all_messages_action_with_count, unread.size),
                                color = colors.gold,
                            )
                            Icon(Icons.AutoMirrored.Outlined.KeyboardArrowRight, contentDescription = null, tint = colors.gold)
                        }
                    }
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
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
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
