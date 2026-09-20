package com.cbtipul.app.ui.diary

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryFeelingDraft
import com.cbtipul.app.data.DiaryFeelingVocabulary
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import kotlin.math.roundToInt

@Composable
fun DiaryFeelingsEditor(
    drafts: List<DiaryFeelingDraft>,
    highlightIncomplete: Boolean,
    onChange: (List<DiaryFeelingDraft>) -> Unit,
) {
    val colors = Theme.colors
    var showPicker by remember { mutableStateOf(false) }
    val selectedNames = remember(drafts) {
        drafts.map { it.trimmedName }.filter { it.isNotEmpty() }.toSet()
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        drafts.forEach { draft ->
            key(draft.id) {
            val isIncomplete = highlightIncomplete &&
                (draft.trimmedName.isEmpty() || draft.intensity == null)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(colors.elevated, RoundedCornerShape(14.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        draft.name,
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    if (drafts.size > 1) {
                        IconButton(
                            onClick = { onChange(drafts.filterNot { it.id == draft.id }) },
                        ) {
                            Icon(
                                Icons.Outlined.Remove,
                                contentDescription = stringResource(R.string.diary_remove_feeling),
                                tint = colors.textBody,
                            )
                        }
                    }
                }
                DiaryFeelingIntensityControl(
                    intensity = draft.intensity,
                    onIntensityChange = { value ->
                        onChange(
                            drafts.map { current ->
                                if (current.id == draft.id) current.copy(intensity = value) else current
                            },
                        )
                    },
                )
                if (isIncomplete) {
                    Text(
                        if (draft.trimmedName.isEmpty()) {
                            stringResource(R.string.diary_one_validation_feeling_intensity)
                        } else {
                            stringResource(R.string.diary_one_validation_feeling_intensity_named, draft.trimmedName)
                        },
                        color = colors.error,
                        fontSize = 13.sp,
                    )
                }
            }
            }
        }
        TextButton(
            onClick = { showPicker = true },
            modifier = Modifier.padding(top = if (drafts.isEmpty()) 0.dp else 4.dp),
        ) {
            Icon(Icons.Outlined.Add, contentDescription = null, tint = colors.gold)
            Spacer(Modifier.padding(start = 8.dp))
            Text(
                stringResource(R.string.diary_add_feeling),
                color = colors.gold,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }

    if (showPicker) {
        DiaryFeelingPickerSheet(
            selectedNames = selectedNames,
            onPick = { name ->
                if (name.isNotEmpty() && name !in selectedNames) {
                    onChange(drafts + DiaryFeelingDraft(name = name))
                }
                showPicker = false
            },
            onDismiss = { showPicker = false },
        )
    }
}

@Composable
private fun DiaryFeelingIntensityControl(
    intensity: Int?,
    onIntensityChange: (Int) -> Unit,
) {
    val colors = Theme.colors
    val initial = intensity?.takeIf { it in 0..100 }
    var knob by remember { mutableFloatStateOf((initial ?: 50).toFloat()) }
    var hasExplicitValue by remember { mutableStateOf(initial != null) }
    val label = if (hasExplicitValue) {
        "${knob.roundToInt()}%"
    } else {
        stringResource(R.string.diary_one_intensity_unset)
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row {
            Spacer(Modifier.weight(1f))
            Text(
                label,
                color = if (hasExplicitValue) colors.textBright else colors.textFaint,
                fontWeight = FontWeight.SemiBold,
            )
        }
        Slider(
            value = knob,
            onValueChange = { value ->
                knob = value
                hasExplicitValue = true
                onIntensityChange(value.roundToInt())
            },
            onValueChangeFinished = {
                if (hasExplicitValue) onIntensityChange(knob.roundToInt())
            },
            valueRange = 0f..100f,
            steps = 99,
            colors = SliderDefaults.colors(
                thumbColor = colors.gold,
                activeTrackColor = colors.gold,
                inactiveTrackColor = colors.gold.copy(alpha = 0.24f),
            ),
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DiaryFeelingChip(
    title: String,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val colors = Theme.colors
    Text(
        title,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (enabled) colors.elevated else colors.elevated.copy(alpha = 0.5f))
            .border(1.dp, colors.borderDefault, RoundedCornerShape(50))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        color = if (enabled) colors.textBright else colors.textFaint,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
    )
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
private fun DiaryFeelingPickerSheet(
    selectedNames: Set<String>,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = Theme.colors
    var query by remember { mutableStateOf("") }
    var isEnteringCustom by remember { mutableStateOf(false) }
    var customText by remember { mutableStateOf("") }
    var customError by remember { mutableStateOf<String?>(null) }
    val emptyCustom = stringResource(R.string.diary_custom_feeling_empty)
    val alreadySelected = stringResource(R.string.diary_feeling_already_selected)
    val trimmedQuery = query.trim()

    fun pick(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || trimmed in selectedNames) return
        onPick(trimmed)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.base,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.diary_feeling_pick_title),
                    color = colors.textBright,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.cancel), color = colors.gold)
                }
            }
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                placeholder = {
                    Text(stringResource(R.string.diary_feeling_search), color = colors.textFaint)
                },
                colors = feelingFieldColors(),
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                if (trimmedQuery.isEmpty()) {
                    DiaryFeelingVocabulary.groups.forEach { group ->
                        val available = group.feelings.filter { it !in selectedNames }
                        if (available.isNotEmpty()) {
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text(group.title, color = colors.textBright, fontWeight = FontWeight.SemiBold)
                                FeelingChipFlow(names = available, onPick = ::pick)
                            }
                        }
                    }
                } else {
                    val matches = DiaryFeelingVocabulary.matching(query)
                        .filter { it !in selectedNames }
                    if (matches.isEmpty()) {
                        Text(stringResource(R.string.diary_feeling_search_empty), color = colors.textBody, fontSize = 14.sp)
                    } else {
                        FeelingChipFlow(names = matches, onPick = ::pick)
                    }
                }

                GroupedListCard(accent = colors.gold, modifier = Modifier.padding(top = 8.dp)) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        TextButton(onClick = { isEnteringCustom = true }) {
                            Icon(Icons.Outlined.Add, contentDescription = null, tint = colors.gold)
                            Spacer(Modifier.padding(start = 8.dp))
                            Text(
                                stringResource(R.string.diary_other_feeling),
                                color = colors.gold,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                        if (isEnteringCustom) {
                            OutlinedTextField(
                                value = customText,
                                onValueChange = {
                                    customText = it
                                    customError = null
                                },
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                                placeholder = {
                                    Text(
                                        stringResource(R.string.diary_custom_feeling_placeholder),
                                        color = colors.textFaint,
                                    )
                                },
                                colors = feelingFieldColors(),
                            )
                            customError?.let { Text(it, color = colors.error, fontSize = 13.sp) }
                            Button(
                                onClick = {
                                    val trimmed = customText.trim()
                                    customError = when {
                                        trimmed.isEmpty() -> emptyCustom
                                        trimmed in selectedNames -> alreadySelected
                                        else -> {
                                            onPick(trimmed)
                                            null
                                        }
                                    }
                                },
                                enabled = customText.trim().isNotEmpty(),
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = colors.gold,
                                    contentColor = colors.textOnAccent,
                                    disabledContainerColor = colors.goldDim,
                                ),
                                shape = RoundedCornerShape(14.dp),
                            ) {
                                Text(
                                    stringResource(R.string.diary_custom_feeling_confirm),
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FeelingChipFlow(
    names: List<String>,
    onPick: (String) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        names.forEach { name ->
            DiaryFeelingChip(title = name) { onPick(name) }
        }
    }
}

@Composable
private fun feelingFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Theme.colors.gold,
    unfocusedBorderColor = Theme.colors.borderDefault,
    cursorColor = Theme.colors.gold,
    focusedTextColor = Theme.colors.textBright,
    unfocusedTextColor = Theme.colors.textBright,
    focusedContainerColor = Theme.colors.elevated,
    unfocusedContainerColor = Theme.colors.elevated,
)
