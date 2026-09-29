package com.cbtipul.app.ui.patient

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
import java.util.Date

private enum class TasksLoadState { Loading, Loaded, Failed }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientModeScreen(
    diaryTwo: PatientDiaryTwoAccess,
    patientId: String,
    loadAssignments: suspend () -> List<PatientAssignment>,
    submitQuestionnaire: suspend (String, List<Int>, List<Int>, Int) -> Unit,
    submitDiaryOne: suspend (String, List<String>, List<DiaryFeeling>, String, String?) -> Unit,
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
    var didSubmitQuestionnaire by remember { mutableStateOf(false) }
    var didSubmitDiaryOne by remember { mutableStateOf(false) }
    var diaryTwoEntries by remember(patientId) { mutableStateOf<List<DiaryTwoEntry>>(emptyList()) }
    var didSubmitDiaryTwo by remember { mutableStateOf(false) }
    var diaryEntries by remember { mutableStateOf<List<DiaryOneEntry>>(emptyList()) }

    suspend fun reload() {
        if (assignments.isEmpty()) loadState = TasksLoadState.Loading
        try {
            assignments = loadAssignments()
            messages = runCatching { loadMessages() }.getOrDefault(emptyList())
            loadState = TasksLoadState.Loaded
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
    LaunchedEffect(loadState, pendingDestination) {
        if (loadState != TasksLoadState.Loaded) return@LaunchedEffect
        val destination = pendingDestination ?: return@LaunchedEffect
        when (destination) {
            is AppDestination.PatientQuestionnaire,
            is AppDestination.PatientMessage,
            is AppDestination.PatientDiaryOneForm,
            -> {
                onConsumePending()
                when (destination) {
                    is AppDestination.PatientQuestionnaire -> {
                        val assignment = NotificationRouting.matchingOpenAssignment(
                            assignments, destination.assignmentId, PatientAssignmentType.Questionnaire,
                        )
                        if (assignment != null) nav.navigate("questionnaire/${assignment.id}")
                    }
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
                onOpenSettings = onOpenSettings,
                onRefresh = { scope.launch { reload() } },
                onOpenQuestionnaire = { nav.navigate("questionnaire/$it") },
                onOpenDiaryOne = { nav.navigate("diary-one") },
                onOpenDiaryTwo = { nav.navigate("diary-two") },
                onOpenMessage = { nav.navigate("message/$it") },
                onOpenAllMessages = { nav.navigate("messages") },
            )
        }
        composable("questionnaire/{assignmentId}", arguments = listOf(navArgument("assignmentId") { type = NavType.StringType })) { entry ->
            val assignmentId = entry.arguments?.getString("assignmentId").orEmpty()
            PatientQuestionnaireScreen(
                assignmentId = assignmentId,
                onSubmit = { gad7, phq9, interference ->
                    submitQuestionnaire(assignmentId, gad7, phq9, interference)
                    didSubmitQuestionnaire = true
                },
                onBack = {
                    nav.popScreen()
                    scope.launch { reload() }
                },
            )
        }
        composable("diary-one") {
            PatientDiaryOneHubScreen(
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
                    didSubmitDiaryOne = true
                    reload()
                },
                onDiaryInactive = { scope.launch { reload() } },
                onBack = { nav.popScreen() },
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
    MessageOverlay(visible = didSubmitDiaryTwo, title = stringResource(R.string.patient_diary_one_saved), message = "", onDismiss = { didSubmitDiaryTwo = false })
    MessageOverlay(visible = didSubmitDiaryOne, title = stringResource(R.string.patient_diary_one_saved), message = "", onDismiss = { didSubmitDiaryOne = false })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PatientHomeContent(
    loadState: TasksLoadState,
    assignments: List<PatientAssignment>,
    messages: List<PatientMessage>,
    onOpenSettings: () -> Unit,
    onRefresh: () -> Unit,
    onOpenQuestionnaire: (String) -> Unit,
    onOpenDiaryOne: () -> Unit,
    onOpenDiaryTwo: () -> Unit,
    onOpenMessage: (String) -> Unit,
    onOpenAllMessages: () -> Unit,
) {
    val colors = Theme.colors
    val openAssignments = assignments.filter { if (it.type == PatientAssignmentType.DiaryTwo) it.cancelledAt == null else it.isOpen }
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
                    Text(stringResource(R.string.patient_tasks_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
                    if (openAssignments.isEmpty()) {
                        GroupedListCard(accent = colors.gold) {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(stringResource(R.string.patient_tasks_empty_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                Text(stringResource(R.string.patient_tasks_empty_body), color = colors.textBody)
                            }
                        }
                    } else {
                        openAssignments.forEach { assignment ->
                            when (assignment.type) {
                                PatientAssignmentType.Questionnaire -> TaskCard(
                                    stringResource(R.string.patient_questionnaire_card_title),
                                    stringResource(R.string.patient_questionnaire_card_body),
                                    stringResource(R.string.patient_questionnaire_start),
                                ) { onOpenQuestionnaire(assignment.id) }
                                PatientAssignmentType.DiaryOne -> TaskCard(
                                    stringResource(R.string.patient_diary_one_card_title),
                                    stringResource(R.string.patient_diary_one_card_body),
                                    stringResource(R.string.patient_diary_one_start),
                                    stringResource(R.string.patient_diary_one_ongoing_hint),
                                ) { onOpenDiaryOne() }
                                PatientAssignmentType.DiaryTwo -> TaskCard(
                                    stringResource(R.string.diary_two_title),
                                    stringResource(R.string.patient_diary_two_card_body),
                                    stringResource(R.string.patient_diary_one_start),
                                    stringResource(R.string.patient_diary_one_ongoing_hint),
                                ) { onOpenDiaryTwo() }
                                PatientAssignmentType.DiaryThree, null -> TaskCard(
                                    stringResource(R.string.patient_upcoming_task_title),
                                    stringResource(R.string.patient_upcoming_task_body),
                                    null,
                                ) {}
                            }
                        }
                    }
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

@Composable
private fun TaskCard(title: String, body: String, action: String?, hint: String? = null, onStart: () -> Unit) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(body, color = colors.textBody)
            hint?.let { Text(it, color = colors.textFaint, fontSize = 13.sp) }
            if (action != null) GoldActionButton(action, onStart)
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
