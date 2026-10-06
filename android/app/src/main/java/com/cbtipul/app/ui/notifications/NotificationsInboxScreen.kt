package com.cbtipul.app.ui.notifications

import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.HowToReg
import androidx.compose.material.icons.outlined.WarningAmber
import com.cbtipul.app.ui.theme.IconLabel
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.PersonAddAlt1
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.cbtipul.app.data.AppDestination
import com.cbtipul.app.data.NotificationPayload
import java.time.LocalDate
import java.time.ZoneId
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
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
import androidx.compose.foundation.lazy.rememberLazyListState
import com.cbtipul.app.ui.therapist.TabReselectionEffect
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
    val listState = rememberLazyListState()
    TabReselectionEffect { listState.animateScrollToItem(0) }
    val items by repository.items.collectAsStateWithLifecycle()
    val loading by repository.isLoading.collectAsStateWithLifecycle()
    val failed by repository.failed.collectAsStateWithLifecycle()
    val unread = NotificationInbox.unread(items)
    val read = NotificationInbox.read(items)
    val scope = rememberCoroutineScope()

    suspend fun loadAndMarkSeen(showLoading: Boolean = false) {
        repository.refresh(showLoading = showLoading)
        if (!repository.failed.value) repository.markInboxSeen()
    }

    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { scope.launch { loadAndMarkSeen() } }

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
                IconLabel(stringResource(R.string.notifications_load_failed), Icons.Outlined.WarningAmber, color = colors.textBody)
                TextButton(onClick = { scope.launch { loadAndMarkSeen() } }) {
                    Text(stringResource(R.string.retry), color = colors.gold)
                }
            }
            items.isEmpty() -> Column(
                Modifier.fillMaxSize().padding(padding).padding(32.dp),
                verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(Icons.Outlined.NotificationsNone, contentDescription = null,
                    tint = colors.gold, modifier = Modifier.size(56.dp).padding(bottom = 8.dp))
                Text(stringResource(R.string.notifications_empty), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                Text(stringResource(if (repository.isDemoInbox) R.string.notifications_demo_body else R.string.notifications_empty_body),
                    color = colors.textBody, textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.padding(top = 8.dp))
            }
            else -> PullToRefreshBox(
                isRefreshing = loading && items.isNotEmpty(),
                onRefresh = { scope.launch { loadAndMarkSeen(showLoading = true) } },
                modifier = Modifier.fillMaxSize().padding(padding),
            ) {
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (failed) item(key = "refresh-error") {
                        Column {
                            Text(stringResource(R.string.notifications_refresh_failed), color = colors.textBody)
                            TextButton(onClick = { scope.launch { loadAndMarkSeen() } }) { Text(stringResource(R.string.retry)) }
                        }
                    }
                    if (unread.isNotEmpty()) {
                        item(key = "unread-header") { InboxSectionHeader(stringResource(R.string.notifications_unread_section), unread.size, true) }
                        items(unread, key = { it.id }) { item ->
                            InboxRow(item, resolveName(item.patientId, patients, unnamed), { onOpen(item) })
                        }
                    }
                    if (read.isNotEmpty()) {
                        item(key = "read-header") { InboxSectionHeader(stringResource(R.string.notifications_read_section), read.size, false) }
                        items(read, key = { it.id }) { item ->
                            InboxRow(item, resolveName(item.patientId, patients, unnamed), { onOpen(item) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun InboxSectionHeader(title: String, count: Int, highlighted: Boolean) {
    val colors = Theme.colors
    Row(Modifier.padding(top = 8.dp, bottom = 2.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, color = if (highlighted) colors.gold else colors.textBody, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        Text("$count", fontSize = 12.sp, color = if (highlighted) colors.gold else colors.textBody,
            modifier = Modifier.background(if (highlighted) colors.goldGhost else colors.surface, RoundedCornerShape(50)).padding(horizontal = 8.dp, vertical = 3.dp))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun InboxRow(item: AppNotification, patientName: String, onClick: () -> Unit) {
    val colors = Theme.colors
    val kind = NotificationRouting.inboxCopy(item.type)
    val eventColor = when (kind) {
        InboxCopyKind.PatientConnected -> colors.success
        InboxCopyKind.DiaryOneEntryAdded, InboxCopyKind.DiaryTwoEntryAdded, InboxCopyKind.DiaryThreeEntryAdded -> colors.accentFill
        else -> colors.gold
    }
    val icon = when (kind) {
        InboxCopyKind.QuestionnaireCompleted -> Icons.Outlined.Assignment
        InboxCopyKind.PatientConnected -> Icons.Outlined.HowToReg
        InboxCopyKind.DiaryOneEntryAdded, InboxCopyKind.DiaryTwoEntryAdded, InboxCopyKind.DiaryThreeEntryAdded -> Icons.Outlined.Book
        InboxCopyKind.Generic -> Icons.Outlined.NotificationsNone
    }
    val action = when (NotificationRouting.destination(NotificationPayload.from(item))) {
        is AppDestination.PatientDetail -> R.string.notification_open_patient
        is AppDestination.QuestionnaireResult -> R.string.notification_open_questionnaires
        is AppDestination.DiaryOneEntry, is AppDestination.DiaryTwoEntry, is AppDestination.DiaryThreeEntry -> R.string.notification_open_diary
        else -> null
    }
    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        border = BorderStroke(1.dp, if (item.isUnread) colors.gold.copy(alpha = 0.4f) else colors.borderFaint)) {
        Row(Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(34.dp).background(eventColor.copy(alpha = 0.12f), RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = null, tint = eventColor, modifier = Modifier.size(20.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(patientName, color = colors.textBright, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    if (item.isUnread) {
                        val unreadLabel = stringResource(R.string.notification_unread_accessibility)
                        Box(Modifier.size(7.dp).background(colors.gold, CircleShape).semantics { contentDescription = unreadLabel })
                    }
                }
                Text(inboxMessage(item.type), color = colors.textBody, fontSize = 14.sp)
                FlowRow(modifier = Modifier.fillMaxWidth().padding(top = 2.dp),
                    horizontalArrangement = Arrangement.SpaceBetween, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(inboxTimestamp(item.createdAt), color = colors.textFaint, fontSize = 12.sp, modifier = Modifier.padding(end = 12.dp))
                    if (action != null) Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(action), color = colors.gold, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        Icon(Icons.AutoMirrored.Outlined.ArrowForward, contentDescription = null, tint = colors.gold, modifier = Modifier.size(14.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun inboxTimestamp(date: Date): String {
    val zone = ZoneId.systemDefault()
    val day = date.toInstant().atZone(zone).toLocalDate()
    val today = LocalDate.now(zone)
    val time = SimpleDateFormat("HH:mm", Locale("he", "IL")).format(date)
    return when (day) {
        today -> stringResource(R.string.notification_today, time)
        today.minusDays(1) -> stringResource(R.string.notification_yesterday, time)
        else -> hebrewDateTime(date)
    }
}

@Composable
private fun inboxMessage(type: String): String = when (NotificationRouting.inboxCopy(type)) {
    InboxCopyKind.QuestionnaireCompleted -> stringResource(R.string.notification_questionnaire_completed)
    InboxCopyKind.PatientConnected -> stringResource(R.string.notification_patient_connected)
    InboxCopyKind.DiaryTwoEntryAdded -> stringResource(R.string.notification_diary_two_entry_added)
    InboxCopyKind.DiaryThreeEntryAdded -> stringResource(R.string.notification_diary_three_entry_added)
    InboxCopyKind.DiaryOneEntryAdded -> stringResource(R.string.notification_diary_one_entry_added)
    InboxCopyKind.Generic -> stringResource(R.string.notification_generic)
}

private fun resolveName(patientId: String?, patients: List<Patient>, unnamed: String): String {
    if (patientId.isNullOrBlank()) return unnamed
    val match = patients.firstOrNull { it.id.matches(patientId) }
    return match?.displayName(unnamed)?.trim()?.takeIf { it.isNotEmpty() } ?: unnamed
}
