package com.cbtipul.app.ui.forms

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Column
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
fun QuestionnaireProgress(completed: Int, total: Int, enabled: Boolean, onShowMissing: () -> Unit) {
    Text(stringResource(R.string.questionnaire_progress, completed, total), color = Theme.colors.textBody)
    LinearProgressIndicator(progress = { completed.toFloat() / total }, modifier = Modifier.fillMaxWidth())
    if (completed < total) TextButton(onClick = onShowMissing, enabled = enabled) {
        Text(stringResource(R.string.questionnaire_show_missing))
    }
}
