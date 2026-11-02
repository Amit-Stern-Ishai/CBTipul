package com.cbtipul.app.ui.patient

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.ui.diary.*
import com.cbtipul.app.ui.theme.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Editing is independent of assignments. Only authenticated UPDATE is used. */
@Composable
internal fun PatientDiaryOneEditScreen(entry: DiaryOneEntry, onSaved: (DiaryOneEntry) -> Unit, onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val failure = stringResource(R.string.diary_one_save_failed)
    DiaryOneEditorScreen(false, entry, "", Theme.colors.gold, onBack,
        onSave = { event, thoughts, feelings, behaviour, symptoms ->
            if (!busy && Entitlements.allowMutation()) {
                busy = true; error = null
                scope.launch {
                    try { onSaved(app.diaryOne.updateEntry(entry.id, entry.patientId, event, thoughts, feelings, behaviour, symptoms)) }
                    catch (e: CancellationException) { throw e }
                    catch (e: Exception) { error = SummaryFailure.from(e).message ?: failure }
                    finally { busy = false }
                }
            }
        }, isSaving = busy, error = error)
}

@Composable
internal fun PatientDiaryTwoEditScreen(entry: DiaryTwoEntry, onSaved: (DiaryTwoEntry) -> Unit, onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val initial = remember(entry.id) { DiaryTwoEntryDraft.from(entry) }
    HistoryEditor(entry.id, R.string.diary_two_title, initial, { it.validationError() }, onBack,
        save = { d -> app.diaryTwo.updateEntry(entry.id, entry.patientId, d.event.trim(), d.persistedAutomaticThoughts,
            d.persistedFeelings(), d.thinkingErrors, d.persistedAlternativeThoughts) }, onSaved = onSaved,
        fields = { d, attempted, error, change -> DiaryTwoDraftFields(d, attempted, error, onChange = change) })
}

@Composable
internal fun PatientDiaryThreeEditScreen(entry: DiaryThreeEntry, onSaved: (DiaryThreeEntry) -> Unit, onBack: () -> Unit) {
    val app = LocalContext.current.applicationContext as CbTipulApp
    val initial = remember(entry.id) { DiaryThreeEntryDraft.from(entry) }
    HistoryEditor(entry.id, R.string.diary_three_title, initial, { it.validationError() }, onBack,
        save = { d -> app.diaryThree.updateEntry(entry.id, entry.patientId, d.situation.trim(), d.persistedAutomaticThoughts,
            d.persistedFeelings(), d.thinkingErrors, d.persistedAlternativeThoughts) }, onSaved = onSaved,
        fields = { d, attempted, error, change -> DiaryThreeDraftFields(d, attempted, error, onChange = change) })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <D, E> HistoryEditor(id: String, title: Int, initial: D, validate: (D) -> Int?, onBack: () -> Unit,
    save: suspend (D) -> E, onSaved: (E) -> Unit,
    fields: @Composable (D, Boolean, Int?, (D) -> Unit) -> Unit) {
    var draft by remember(id) { mutableStateOf(initial) }
    var busy by remember(id) { mutableStateOf(false) }
    var attempted by remember(id) { mutableStateOf(false) }
    var error by remember(id) { mutableStateOf<Int?>(null) }
    var saveFailure by remember(id) { mutableStateOf<String?>(null) }
    var discard by remember(id) { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    fun close() { if (!busy) { if (draft != initial) discard = true else onBack() } }
    BackHandler { close() }
    Scaffold(modifier = Modifier.themedScreen(Theme.colors.gold).imePadding(),
        topBar = { TopAppBar(title = { Text(stringResource(title)) }, navigationIcon = {
            IconButton(onClick = ::close, enabled = !busy) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, stringResource(R.string.back)) }
        }) },
        bottomBar = {
            Button(onClick = {
                if (!busy && Entitlements.allowMutation()) {
                    attempted = true; saveFailure = null; error = validate(draft)
                    if (error == null) {
                        busy = true
                        scope.launch {
                            try { onSaved(save(draft)) }
                            catch (e: CancellationException) { throw e }
                            catch (e: Exception) { saveFailure = SummaryFailure.from(e).message }
                            finally { busy = false }
                        }
                    }
                }
            }, enabled = !busy, modifier = Modifier.navigationBarsPadding().padding(16.dp).fillMaxWidth()) {
                Text(stringResource(R.string.diary_one_save_entry))
            }
        }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).editorScroll().padding(20.dp)) {
            fields(draft, attempted, error) { if (!busy) draft = it }
            saveFailure?.let { Text(it, color = Theme.colors.error) }
            if (busy) CircularProgressIndicator()
        }
    }
    if (discard) AlertDialog(onDismissRequest = { discard = false }, title = { Text(stringResource(R.string.discard_changes_title)) },
        confirmButton = { TextButton(onClick = onBack) { Text(stringResource(R.string.discard_changes_action)) } },
        dismissButton = { TextButton(onClick = { discard = false }) { Text(stringResource(R.string.keep_editing_action)) } })
}
