package com.cbtipul.app.ui.forms

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowDownward
import androidx.compose.material3.Icon
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.R
import com.cbtipul.app.ui.theme.Theme

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun RequiredQuestion(requester: BringIntoViewRequester, missing: Boolean, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().bringIntoViewRequester(requester)) {
        if (missing) Text(stringResource(R.string.questionnaire_missing_help), color = Theme.colors.error, modifier = Modifier.padding(horizontal = 16.dp))
        content()
    }
}

@Composable
fun QuestionnaireProgress(completed: Int, total: Int, enabled: Boolean, onShowMissing: () -> Unit, compact: Boolean = false) {
    if (compact) {
        if (completed < total) {
            TextButton(onClick = onShowMissing, enabled = enabled,
                modifier = Modifier.fillMaxWidth(), contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp)) {
                Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.questionnaire_progress, completed, total), modifier = Modifier.weight(1f), fontSize = 13.sp, lineHeight = 18.sp)
                    Icon(Icons.Outlined.ArrowDownward, contentDescription = stringResource(R.string.questionnaire_show_missing), modifier = Modifier.size(20.dp))
                }
            }
        } else {
            Text(stringResource(R.string.questionnaire_progress, completed, total), color = Theme.colors.success,
                fontSize = 13.sp, lineHeight = 18.sp, modifier = Modifier.padding(vertical = 8.dp))
        }
        return
    }
    Text(stringResource(R.string.questionnaire_progress, completed, total), color = Theme.colors.textBody)
    LinearProgressIndicator(progress = { completed.toFloat() / total }, modifier = Modifier.fillMaxWidth())
    if (completed < total) TextButton(onClick = onShowMissing, enabled = enabled) {
        Text(stringResource(R.string.questionnaire_show_missing))
    }
}
