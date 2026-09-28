package com.cbtipul.app.ui.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cbtipul.app.R
import com.cbtipul.app.data.AppNotification
import com.cbtipul.app.data.InboxCopyKind
import com.cbtipul.app.data.NotificationInbox
import com.cbtipul.app.data.NotificationRepository
import com.cbtipul.app.data.NotificationRouting
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDateTime
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsInboxScreen(
    repository: NotificationRepository,
    patients: List<Patient>,
    unnamed: String,
    onOpen: (AppNotification) -> Unit,
) {
    val colors = Theme.colors
    val items by repository.items.collectAsStateWithLifecycle()
    val loading by repository.isLoading.collectAsStateWithLifecycle()
    val failed by repository.failed.collectAsStateWithLifecycle()
    val unread = NotificationInbox.unread(items)
    val read = NotificationInbox.read(items)
    val scope = rememberCoroutineScope()

    suspend fun loadAndMarkSeen() {
        repository.refresh()
        repository.markInboxSeen()
    }

    LaunchedEffect(Unit) { loadAndMarkSeen() }

    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.therapist_tab_notifications), color = colors.textBright) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        when {
            loading && items.isEmpty() -> Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = colors.gold)
            }
            failed && items.isEmpty() -> Column(
                Modifier.fillMaxSize().padding(padding).padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(stringResource(R.string.notifications_load_failed), color = colors.textBody)
                TextButton(onClick = { scope.launch { loadAndMarkSeen() } }) {
                    Text(stringResource(R.string.retry), color = colors.gold)
                }
            }
            items.isEmpty() -> Box(Modifier.fillMaxSize().padding(padding).padding(24.dp), contentAlignment = Alignment.Center) {
                Text(stringResource(R.string.notifications_empty), color = colors.textBody)
            }
            else -> PullToRefreshBox(
                isRefreshing = loading && items.isNotEmpty(),
                onRefresh = { scope.launch { loadAndMarkSeen() } },
                modifier = Modifier.fillMaxSize().padding(padding),
            ) {
                LazyColumn(Modifier.fillMaxSize().padding(horizontal = 24.dp)) {
                    if (unread.isNotEmpty()) {
                        item {
                            Text(stringResource(R.string.notifications_unread_section), color = colors.textBright, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 12.dp))
                        }
                        item {
                            GroupedListCard(accent = colors.gold) {
                                unread.forEachIndexed { index, item ->
                                    InboxRow(item, resolveName(item.patientId, patients, unnamed), { onOpen(item) }, index < unread.lastIndex)
                                }
                            }
                        }
                    }
                    if (read.isNotEmpty()) {
                        item {
                            Text(stringResource(R.string.notifications_read_section), color = colors.textBright, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 20.dp, bottom = 12.dp))
                        }
                        item {
                            GroupedListCard(accent = colors.gold) {
                                read.forEachIndexed { index, item ->
                                    InboxRow(item, resolveName(item.patientId, patients, unnamed), { onOpen(item) }, index < read.lastIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun InboxRow(item: AppNotification, patientName: String, onClick: () -> Unit, showDivider: Boolean) {
    val colors = Theme.colors
    Column {
        Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(patientName, color = colors.textBright, fontWeight = if (item.isUnread) FontWeight.SemiBold else FontWeight.Normal)
                Text(inboxMessage(item.type), color = colors.textBody, fontSize = 14.sp)
                Text(hebrewDateTime(item.createdAt), color = colors.textFaint, fontSize = 13.sp)
            }
            if (item.isUnseen) {
                Box(Modifier.padding(top = 6.dp).size(8.dp).background(colors.gold, CircleShape))
            }
        }
        if (showDivider) GroupedListDivider()
    }
}

@Composable
private fun inboxMessage(type: String): String = when (NotificationRouting.inboxCopy(type)) {
    InboxCopyKind.QuestionnaireCompleted -> stringResource(R.string.notification_questionnaire_completed)
    InboxCopyKind.PatientConnected -> stringResource(R.string.notification_patient_connected)
    InboxCopyKind.DiaryOneEntryAdded -> stringResource(R.string.notification_diary_one_entry_added)
    InboxCopyKind.Generic -> stringResource(R.string.notification_generic)
}

private fun resolveName(patientId: String?, patients: List<Patient>, unnamed: String): String {
    if (patientId.isNullOrBlank()) return unnamed
    val match = patients.firstOrNull { it.id.matches(patientId) }
    return match?.displayName(unnamed)?.trim()?.takeIf { it.isNotEmpty() } ?: unnamed
}
