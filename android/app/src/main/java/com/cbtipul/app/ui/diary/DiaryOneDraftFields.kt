package com.cbtipul.app.ui.diary

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryOneEntryDraft
import com.cbtipul.app.ui.patients.NotesField
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme

@Composable
fun DiaryOneDraftFields(
    draft: DiaryOneEntryDraft,
    didAttemptSave: Boolean,
    errorMessage: String? = null,
    onChange: (DiaryOneEntryDraft) -> Unit,
) {
    val colors = Theme.colors
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        DraftStepCard(
            title = stringResource(R.string.diary_one_event_title),
            question = stringResource(R.string.diary_one_event_question),
            value = draft.event,
            onValueChange = { onChange(draft.copy(event = it)) },
            incompleteMessage = if (didAttemptSave && draft.event.trim().isEmpty()) {
                stringResource(R.string.diary_one_validation_event)
            } else {
                null
            },
        )
        DraftStepCard(
            title = stringResource(R.string.diary_one_thought_title),
            question = stringResource(R.string.diary_one_thought_question),
            value = draft.thought,
            onValueChange = { onChange(draft.copy(thought = it)) },
            incompleteMessage = if (didAttemptSave && draft.thought.trim().isEmpty()) {
                stringResource(R.string.diary_one_validation_thought)
            } else {
                null
            },
        )
        GroupedListCard(accent = colors.gold) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    stringResource(R.string.diary_feelings_title),
                    color = colors.textBright,
                    fontWeight = FontWeight.SemiBold,
                )
                DiaryFeelingsEditor(
                    drafts = draft.feelings,
                    highlightIncomplete = didAttemptSave,
                    onChange = { onChange(draft.copy(feelings = it)) },
                )
                if (didAttemptSave && draft.feelings.isEmpty()) {
                    Text(
                        stringResource(R.string.diary_one_validation_feelings),
                        color = colors.error,
                        fontSize = 13.sp,
                    )
                }
            }
        }
        DraftStepCard(
            title = stringResource(R.string.diary_one_behaviour_title),
            question = stringResource(R.string.diary_one_behaviour_question),
            value = draft.behaviour,
            onValueChange = { onChange(draft.copy(behaviour = it)) },
            incompleteMessage = if (didAttemptSave && draft.behaviour.trim().isEmpty()) {
                stringResource(R.string.diary_one_validation_behaviour)
            } else {
                null
            },
        )
        DraftStepCard(
            title = stringResource(R.string.diary_one_physical_title),
            question = stringResource(R.string.diary_one_physical_question),
            value = draft.physicalSymptoms,
            onValueChange = { onChange(draft.copy(physicalSymptoms = it)) },
            optionalHint = stringResource(R.string.diary_one_optional_hint),
        )
        errorMessage?.let {
            Text(it, color = colors.error, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 4.dp))
        }
    }
}

@Composable
private fun DraftStepCard(
    title: String,
    question: String,
    value: String,
    onValueChange: (String) -> Unit,
    optionalHint: String? = null,
    incompleteMessage: String? = null,
) {
    val colors = Theme.colors
    GroupedListCard(accent = colors.gold) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                if (optionalHint != null) {
                    Text(
                        optionalHint,
                        color = colors.textFaint,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }
            Text(question, color = colors.textBody, fontSize = 14.sp)
            NotesField(value = value, onValueChange = onValueChange, placeholder = question)
            incompleteMessage?.let {
                Text(it, color = colors.error, fontSize = 13.sp)
            }
        }
    }
}
