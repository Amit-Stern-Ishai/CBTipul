package com.cbtipul.app.ui.patient

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
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
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cbtipul.app.R
import com.cbtipul.app.data.DiaryOneEntry
import com.cbtipul.app.data.PatientDiaryOneHistory
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.hebrewDateTime
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

private enum class DiaryHubLoadState { Loading, Loaded, Failed }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryOneHubScreen(
    loadEntries: suspend () -> List<DiaryOneEntry>,
    onAddEntry: () -> Unit,
    onOpenEntry: (DiaryOneEntry) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    var loadState by remember { mutableStateOf(DiaryHubLoadState.Loading) }
    var entries by remember { mutableStateOf<List<DiaryOneEntry>>(emptyList()) }

    suspend fun reload() {
        if (entries.isEmpty()) loadState = DiaryHubLoadState.Loading
        try {
            entries = PatientDiaryOneHistory.visible(loadEntries())
            loadState = DiaryHubLoadState.Loaded
        } catch (_: Exception) {
            loadState = DiaryHubLoadState.Failed
        }
    }

    LaunchedEffect(Unit) { reload() }
    LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
        scope.launch { reload() }
    }

    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.diary_one_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Outlined.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = colors.gold,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
        bottomBar = {
            if (loadState == DiaryHubLoadState.Loaded || entries.isNotEmpty()) {
                Surface(color = colors.base) {
                    Box(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                        Button(
                            onClick = onAddEntry,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = colors.accentFill,
                                contentColor = colors.textOnAccent,
                            ),
                            shape = RoundedCornerShape(14.dp),
                        ) {
                            Text(
                                stringResource(
                                    if (entries.isEmpty()) R.string.empty_diary_one_primary_action
                                    else R.string.diary_one_add_entry,
                                ),
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }
        },
    ) { padding ->
        when {
            loadState == DiaryHubLoadState.Loading && entries.isEmpty() ->
                Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = colors.gold)
                }
            loadState == DiaryHubLoadState.Failed && entries.isEmpty() ->
                Column(
                    Modifier.fillMaxSize().padding(padding).padding(24.dp),
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(stringResource(R.string.diary_one_load_failed), color = colors.textBody)
                    TextButton(onClick = { scope.launch { reload() } }) {
                        Text(stringResource(R.string.retry_action), color = colors.gold)
                    }
                }
            else -> Column(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 12.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    stringResource(R.string.diary_one_my_entries),
                    color = colors.textBright,
                    fontWeight = FontWeight.SemiBold,
                )
                if (entries.isEmpty()) {
                    Text(stringResource(R.string.diary_one_empty_title), color = colors.textBody)
                } else {
                    entries.forEach { entry ->
                        GroupedListCard(accent = colors.gold) {
                            Column(
                                Modifier
                                    .fillMaxWidth()
                                    .clickable { onOpenEntry(entry) }
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    hebrewDateTime(entry.createdAt),
                                    color = colors.textBright,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(entry.event, color = colors.textBody, maxLines = 2)
                                if (entry.automaticThoughtsPreview.isNotEmpty()) {
                                    Text(
                                        entry.automaticThoughtsPreview,
                                        color = colors.textBody,
                                        fontSize = 14.sp,
                                        maxLines = 2,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientDiaryOneDetailScreen(
    entry: DiaryOneEntry,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.diary_one_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Outlined.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = colors.gold,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                hebrewDateTime(entry.createdAt),
                color = colors.textBright,
                fontWeight = FontWeight.SemiBold,
            )
            DetailBlock(stringResource(R.string.diary_one_event_title), entry.event)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    stringResource(R.string.diary_one_thought_title),
                    color = colors.textBody,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                )
                entry.automaticThoughts.forEach { thought ->
                    Text(thought, color = colors.textBright)
                }
            }
            DetailBlock(
                stringResource(R.string.diary_feelings_title),
                entry.feelings.joinToString(" · ") { "${it.name} ${it.intensity}%" },
            )
            DetailBlock(stringResource(R.string.diary_one_behaviour_title), entry.behaviour)
            entry.physicalSymptoms?.takeIf { it.isNotBlank() }?.let {
                DetailBlock(stringResource(R.string.diary_one_physical_title), it)
            }
        }
    }
}

@Composable
private fun DetailBlock(title: String, value: String) {
    val colors = Theme.colors
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, color = colors.textBody, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        Text(value, color = colors.textBright)
    }
}
