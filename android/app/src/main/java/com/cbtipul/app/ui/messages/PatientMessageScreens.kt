package com.cbtipul.app.ui.messages

import androidx.activity.compose.BackHandler
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.builtins.serializer
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import com.cbtipul.app.R
import com.cbtipul.app.data.PatientMessage
import com.cbtipul.app.data.PatientMessageDraft
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDateTime
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TherapistMessageComposeScreen(
    recipient: String,
    draftTarget: String,
    isSending: Boolean,
    errorMessage: String?,
    onSend: suspend (String) -> Boolean,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val savedDraft = com.cbtipul.app.ui.forms.rememberDeviceFormDraft("message", draftTarget, String.serializer(), "")
    val draft = savedDraft.value
    var didSubmit by remember { mutableStateOf(false) }
    var leavingDraft by remember { mutableStateOf(false) }
    val cleanupFailed = stringResource(R.string.submitted_draft_cleanup)

    val scope = rememberCoroutineScope()
    fun finish() {
        didSubmit = true
        if (savedDraft.clear()) onBack()
    }
    fun requestBack() {
        if (isSending) return
        if (didSubmit) finish() else if (draft.isNotBlank()) leavingDraft = true else onBack()
    }
    BackHandler { requestBack() }
    if (leavingDraft) com.cbtipul.app.ui.forms.DraftLeaveDialog(
        onKeep = { leavingDraft = false; if (savedDraft.persist()) onBack() },
        onDiscard = { leavingDraft = false; if (savedDraft.clear()) onBack() },
        onCancel = { leavingDraft = false },
    )
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold).imePadding(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.send_patient_message_action), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = { requestBack() }, enabled = !isSending) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        bottomBar = {
            Column(Modifier.fillMaxWidth().padding(16.dp)) {
                Text(stringResource(R.string.message_send_explanation), color = colors.textBody)
            Button(
                onClick = { if (didSubmit) finish() else scope.launch { if (onSend(draft)) finish() } },
                enabled = !isSending && PatientMessageDraft.canSend(draft),
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent),
            ) {
                Text(
                    if (didSubmit) stringResource(R.string.done) else if (isSending) stringResource(R.string.send_patient_message_sending) else stringResource(R.string.send_message_action),
                    fontWeight = FontWeight.SemiBold,
                )
            }
            }
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.message_recipient, recipient), color = colors.textBright, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.therapist_message_delivery_explanation), color = colors.textBody)
            com.cbtipul.app.ui.forms.DraftStatus(savedDraft.failed, savedDraft.hasSaved)
            OutlinedTextField(
                value = draft,
                onValueChange = { if (it.length <= PatientMessageDraft.MAX_LENGTH) savedDraft.value = it },
                modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp),
                enabled = !isSending && !didSubmit,
                placeholder = { Text(stringResource(R.string.send_patient_message_placeholder)) },
            )
            if (didSubmit && savedDraft.failed) Text(cleanupFailed, color = colors.error)
            if (errorMessage != null) Text(errorMessage, color = colors.error)

        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessageListScreen(
    title: String,
    load: suspend () -> List<PatientMessage>,
    emptyText: String,
    showReadState: Boolean,
    onBack: () -> Unit,
    onOpen: (PatientMessage) -> Unit,
    header: @Composable () -> Unit = {},
) {
    val colors = Theme.colors
    var items by remember { mutableStateOf<List<PatientMessage>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    suspend fun reload() {
        loading = items.isEmpty()
        try {
            items = load()
            failed = false
        } catch (error: CancellationException) { throw error } catch (_: Exception) {
            failed = true
        } finally {
            loading = false
        }
    }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { scope.launch { reload() } }
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(title, color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        bottomBar = { Column(Modifier.fillMaxWidth().padding(16.dp)) { header() } },
    ) { padding ->
        when {
            loading -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = colors.gold)
            }
            failed && items.isEmpty() -> Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.Center) {
                Text(stringResource(R.string.patient_messages_load_failed), color = colors.textBody)
                TextButton(onClick = { scope.launch { reload() } }) { Text(stringResource(R.string.retry), color = colors.gold) }
            }
            items.isEmpty() -> Box(Modifier.fillMaxSize().padding(padding).padding(24.dp), contentAlignment = Alignment.Center) {
                Text(emptyText, color = colors.textBody)
            }
            else -> LazyColumn(Modifier.fillMaxSize().padding(padding).padding(horizontal = 24.dp)) {
                if (failed) item {
                    Text(stringResource(R.string.patient_messages_load_failed), color = colors.error)
                    TextButton(onClick = { scope.launch { reload() } }) { Text(stringResource(R.string.retry_action)) }
                }
                itemsIndexed(items, key = { _, item -> item.id }) { index, item ->
                    GroupedListCard(accent = colors.gold) {
                        Column {
                            Row(Modifier.fillMaxWidth().clickable { onOpen(item) }.padding(16.dp)) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(item.body, color = colors.textBright, fontWeight = if (item.isUnread) FontWeight.SemiBold else FontWeight.Normal, maxLines = 3)
                                    Text(hebrewDateTime(item.createdAt), color = colors.textFaint, fontSize = 13.sp)
                                    if (showReadState) {
                                        Text(
                                            stringResource(if (item.isUnread) R.string.sent_message_unread_status else R.string.sent_message_read_status),
                                            color = colors.textBody,
                                            fontSize = 13.sp,
                                        )
                                    }
                                }
                            }
                            if (index < items.lastIndex) GroupedListDivider()
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientMessageDetailScreen(
    load: suspend () -> PatientMessage?,
    markRead: suspend (PatientMessage) -> Unit = {},
    showNoReply: Boolean = true,
    recipient: String = "",
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    var message by remember { mutableStateOf<PatientMessage?>(null) }
    var loading by remember { mutableStateOf(true) }
    var missing by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        try {
            val loaded = load()
            message = loaded
            missing = loaded == null
            if (showNoReply && loaded != null && loaded.isUnread) {
                try {
                    markRead(loaded)
                    message = loaded.markedRead(Date())
                } catch (error: CancellationException) { throw error }
                catch (_: Exception) { /* Keep the server's read state if acknowledgement fails. */ }
            }
        } catch (error: CancellationException) { throw error } catch (_: Exception) {
            missing = true
        } finally {
            loading = false
        }
    }
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(if (showNoReply) R.string.message_detail_title else R.string.sent_message_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        when {
            loading -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = colors.gold)
            }
            missing || message == null -> Box(Modifier.fillMaxSize().padding(padding).padding(24.dp), contentAlignment = Alignment.Center) {
                Text(stringResource(R.string.notification_target_unavailable), color = colors.textBody)
            }
            else -> {
                val item = message!!
                Column(
                    Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Text(if (showNoReply) stringResource(R.string.message_from_therapist) else stringResource(R.string.message_recipient, recipient), color = colors.textBody)
                    if (!showNoReply) Text(stringResource(if (item.isUnread) R.string.sent_message_unread_status else R.string.sent_message_read_status), color = colors.textBody)
                    Text(hebrewDateTime(item.createdAt), color = colors.textFaint, fontSize = 13.sp)
                    Text(item.body, color = colors.textBright, fontSize = 18.sp)
                    if (showNoReply) {
                        Text(stringResource(R.string.patient_message_no_reply), color = colors.textFaint, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}
