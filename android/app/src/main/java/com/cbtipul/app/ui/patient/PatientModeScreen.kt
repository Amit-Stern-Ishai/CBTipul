package com.cbtipul.app.ui.patient

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
    loadAssignments: suspend () -> List<PatientAssignment>,
    submitQuestionnaire: suspend (String, List<Int>, List<Int>, Int) -> Unit,
    submitDiaryOne: suspend (String, String, List<DiaryFeeling>, String, String?) -> Unit,
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
                        if (assignment != null) nav.navigate("diary-one")
                    }
                    else -> Unit
                }
            }
            else -> Unit
        }
    }

    NavHost(navController = nav, startDestination = "home") {
        composable("home") {
            PatientHomeContent(
                loadState = loadState,
                assignments = assignments,
                messages = messages,
                onOpenSettings = onOpenSettings,
                onRefresh = { scope.launch { reload() } },
                onOpenQuestionnaire = { nav.navigate("questionnaire/$it") },
                onOpenDiaryOne = { nav.navigate("diary-one") },
                onOpenMessage = { nav.navigate("message/$it") },
                onOpenAllMessages = { nav.navigate("messages") },
            )
        }
        composable("questionnaire/{assignmentId}", arguments = listOf(navArgument("assignmentId") { type = NavType.StringType })) { entry ->
            val assignmentId = entry.arguments?.getString("assignmentId").orEmpty()
            PatientQuestionnaireScreen(
                onSubmit = { gad7, phq9, interference ->
                    submitQuestionnaire(assignmentId, gad7, phq9, interference)
                    didSubmitQuestionnaire = true
                },
                onBack = {
                    nav.popBackStack()
                    scope.launch { reload() }
                },
            )
        }
        composable("diary-one") {
            PatientDiaryOneEntryScreen(
                onSubmit = { event, thought, feelings, behaviour, physicalSymptoms ->
                    submitDiaryOne(event, thought, feelings, behaviour, physicalSymptoms)
                    didSubmitDiaryOne = true
                    reload()
                },
                onDiaryInactive = { scope.launch { reload() } },
                onBack = { nav.popBackStack() },
            )
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
                onBack = { nav.popBackStack() },
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
                onBack = { nav.popBackStack() },
            )
        }
    }
    MessageOverlay(visible = didSubmitQuestionnaire, title = stringResource(R.string.patient_questionnaire_submitted), message = "", onDismiss = { didSubmitQuestionnaire = false })
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
    onOpenMessage: (String) -> Unit,
    onOpenAllMessages: () -> Unit,
) {
    val colors = Theme.colors
    val openAssignments = assignments.filter { it.isOpen }
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
                    Text(stringResource(R.string.patient_messages_title), color = colors.textBright, fontWeight = FontWeight.SemiBold, fontSize = 22.sp)
                    if (unread.isEmpty()) {
                        GroupedListCard(accent = colors.gold) {
                            Text(stringResource(R.string.no_new_messages), color = colors.textBody, modifier = Modifier.padding(16.dp))
                        }
                    } else {
                        previews.forEach { message ->
                            GroupedListCard(accent = colors.gold) {
                                Column(Modifier.fillMaxWidth().clickable { onOpenMessage(message.id) }.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(message.body, color = colors.textBright, fontWeight = FontWeight.SemiBold, maxLines = 3)
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
                    GoldActionButton(
                        if (unread.isEmpty()) stringResource(R.string.all_messages_action)
                        else stringResource(R.string.all_messages_action_with_count, unread.size),
                        onOpenAllMessages,
                    )
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
                                    stringResource(R.string.diary_one_add_entry),
                                    stringResource(R.string.patient_diary_one_ongoing_hint),
                                ) { onOpenDiaryOne() }
                                PatientAssignmentType.DiaryTwo, null -> TaskCard(
                                    stringResource(R.string.patient_upcoming_task_title),
                                    stringResource(R.string.patient_upcoming_task_body),
                                    null,
                                ) {}
                            }
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
        colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
        shape = RoundedCornerShape(14.dp),
    ) { Text(text, fontWeight = FontWeight.SemiBold) }
}
