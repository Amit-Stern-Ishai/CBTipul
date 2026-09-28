package com.cbtipul.app.ui.messages

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
    isSending: Boolean,
    errorMessage: String?,
    onSend: (String) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    var draft by remember { mutableStateOf("") }
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold).imePadding(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.send_patient_message_action), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack, enabled = !isSending) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            OutlinedTextField(
                value = draft,
                onValueChange = { if (it.length <= PatientMessageDraft.MAX_LENGTH) draft = it },
                modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp),
                enabled = !isSending,
                placeholder = { Text(stringResource(R.string.send_patient_message_placeholder)) },
            )
            if (errorMessage != null) Text(errorMessage, color = colors.error)
            Button(
                onClick = { onSend(draft) },
                enabled = !isSending && PatientMessageDraft.canSend(draft),
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = colors.gold, contentColor = colors.textOnAccent),
            ) {
                Text(
                    if (isSending) stringResource(R.string.send_patient_message_sending) else stringResource(R.string.send_message_action),
                    fontWeight = FontWeight.SemiBold,
                )
            }
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
        } catch (_: Exception) {
            failed = true
        } finally {
            loading = false
        }
    }
    LaunchedEffect(Unit) { reload() }
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
                itemsIndexed(items, key = { _, item -> item.id }) { index, item ->
                    GroupedListCard(accent = colors.gold) {
                        Column {
                            Row(Modifier.fillMaxWidth().clickable { onOpen(item) }.padding(16.dp)) {
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(item.body, color = colors.textBright, fontWeight = if (item.isUnread) FontWeight.SemiBold else FontWeight.Normal, maxLines = 3)
                                    Text(hebrewDateTime(item.createdAt), color = colors.textFaint, fontSize = 13.sp)
                                    if (showReadState) {
                                        Text(
                                            stringResource(if (item.isUnread) R.string.message_unread_status else R.string.message_read_status),
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
            if (loaded != null && loaded.isUnread) {
                runCatching { markRead(loaded) }
                message = loaded.markedRead(Date())
            }
        } catch (_: Exception) {
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
                title = { Text(stringResource(R.string.message_detail_title), color = colors.textBright) },
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
                    Text(stringResource(R.string.message_from_therapist), color = colors.textBody)
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
