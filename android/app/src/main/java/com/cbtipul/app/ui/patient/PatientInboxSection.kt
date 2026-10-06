package com.cbtipul.app.ui.patient

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.theme.*

@Composable
internal fun PatientInboxSection(items: List<PatientInboxItem>, failed: Boolean, history: Boolean = false,
    onAll: () -> Unit = {}, onOpen: (PatientInboxItem) -> Unit) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column {
            if (!history) Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.patient_inbox_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    val count = items.count { it.isUnread }
                    if (count > 0) Text(stringResource(R.string.patient_inbox_unread, count), color = colors.gold, fontSize = 12.sp)
                }
                TextButton(onClick = onAll) { Text(stringResource(R.string.patient_inbox_all), color = colors.gold) }
            }
            val visible = if (history) items else items.filter { it.isUnread }
            visible.forEach { item ->
                if (!history) HorizontalDivider(color = colors.textFaint.copy(alpha = .15f))
                Row(Modifier.fillMaxWidth().clickable { onOpen(item) }.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(if (item.isMessage) Icons.Outlined.MailOutline else if (item.notification?.type == AppNotificationTypes.QUESTIONNAIRE_ASSIGNED) Icons.Outlined.Assignment else Icons.Outlined.MenuBook,
                        contentDescription = null, tint = colors.gold, modifier = Modifier.size(22.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        val title = if (item.isMessage) stringResource(R.string.message_from_therapist) else stringResource(R.string.patient_inbox_tool_enabled, stringResource(when (item.notification?.type) {
                            AppNotificationTypes.QUESTIONNAIRE_ASSIGNED -> R.string.questionnaires_title
                            AppNotificationTypes.DIARY_ONE_ASSIGNED -> R.string.diary_one_title
                            AppNotificationTypes.DIARY_TWO_ASSIGNED -> R.string.diary_two_title
                            else -> R.string.diary_three_title
                        }))
                        Text(title, color = colors.textBright, fontWeight = if (item.isUnread) FontWeight.SemiBold else FontWeight.Normal)
                        item.message?.let { Text(it.body, color = colors.textBody, maxLines = 2, fontSize = 14.sp) }
                        Text(hebrewDateTime(item.createdAt), color = colors.textBody, fontSize = 12.sp)
                        if (history && item.isUnread) Text(stringResource(R.string.patient_inbox_new), color = colors.gold, fontSize = 12.sp)
                    }
                }
            }
            if (history && items.isEmpty()) Text(stringResource(R.string.patient_inbox_empty), color = colors.textBody, modifier = Modifier.padding(12.dp))
            if (failed) Text(stringResource(R.string.patient_inbox_refresh_failed), color = colors.error, modifier = Modifier.padding(12.dp), fontSize = 12.sp)
        }
    }
}
