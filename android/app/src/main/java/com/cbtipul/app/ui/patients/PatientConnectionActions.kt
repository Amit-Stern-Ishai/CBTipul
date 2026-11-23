package com.cbtipul.app.ui.patients

import com.cbtipul.app.ui.entitlementCreateControl
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.HourglassEmpty
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.filled.CheckCircle
import com.cbtipul.app.ui.theme.IconLabel
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.Icons
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.cbtipul.app.R
import com.cbtipul.app.data.*
import com.cbtipul.app.model.Patient
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.Theme
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

internal enum class ConnectionUi { Checking, Connected, NotConnected, Unavailable, Failed }

@Composable
internal fun rememberPatientConnection(patient: Patient?, repository: PatientAssignmentRepository?, isDemo: Boolean, requireFresh: Boolean = false): Pair<ConnectionUi, () -> Unit> {
    val id = patient?.id?.let(PatientAssignmentRepository::uuidOrNull)
    val available = patient != null && !isDemo && !DemoData.isDemoId(patient.id) && id != null && repository != null
    fun cachedState(): ConnectionUi? = if (available) repository?.cachedPatientConnection(id!!)?.let {
        if (it) ConnectionUi.Connected else ConnectionUi.NotConnected
    } else ConnectionUi.Unavailable
    var state by remember(id, isDemo, repository) { mutableStateOf(if (requireFresh && available) ConnectionUi.Checking else cachedState() ?: ConnectionUi.Checking) }
    var revision by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { revision++ }
    LaunchedEffect(id, isDemo, repository, revision) {
        if (!available) {
            state = ConnectionUi.Unavailable
        } else {
            if (state == ConnectionUi.Failed) state = ConnectionUi.Checking
            try {
                state = if (kotlinx.coroutines.withTimeout(15_000) { repository!!.isPatientConnected(id!!) }) ConnectionUi.Connected else ConnectionUi.NotConnected
            } catch (_: kotlinx.coroutines.TimeoutCancellationException) {
                state = ConnectionUi.Failed
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Unknown is not disconnected; preserve the destination and offer a fresh check.
                state = ConnectionUi.Failed
            }
        }
    }
    return state to { revision++ }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
internal fun PatientConnectionActions(patient: Patient, name: String, repository: PatientAssignmentRepository?, isDemo: Boolean,
    busy: Boolean, onInvite: () -> Unit, onMessage: () -> Unit, onNewSession: () -> Unit, initialSheet: String? = null, onSheetChanged: (Boolean) -> Unit = {}, review: Boolean = false) {
    val colors = Theme.colors
    val (connection, refresh) = if (com.cbtipul.app.BuildConfig.DEBUG && review) ConnectionUi.Connected to {} else rememberPatientConnection(patient, repository, isDemo, requireFresh = initialSheet != null)
    var sheet by androidx.compose.runtime.saveable.rememberSaveable(patient.id.queryValue, initialSheet) {
        mutableStateOf(initialSheet?.takeIf { !isDemo && it in listOf("send", "invite") })
    }
    var sending by remember { mutableStateOf(false) }
    val appContext = (androidx.compose.ui.platform.LocalContext.current.applicationContext as com.cbtipul.app.CbTipulApp).appContext
    val contextState by appContext.loadState.collectAsState()
    val retryScope = rememberCoroutineScope()
    LaunchedEffect(sheet, patient.id, connection) {
        if (sheet == "invite" && !isDemo && connection in listOf(ConnectionUi.Connected, ConnectionUi.NotConnected)) {
            sheet = null
            onSheetChanged(false)
            onInvite()
            return@LaunchedEffect
        }
        onSheetChanged(sheet != null)
        // Recover unresolved/restored access through the existing bounded check.
        if (sheet == "send" && !isDemo && !review) appContext.refreshOnForeground()
    }
    DisposableEffect(Unit) { onDispose { onSheetChanged(false) } }
    // Keep the card footprint stable while cached status refreshes, including larger text.
    val textScale = LocalDensity.current.fontScale.coerceAtLeast(1f)
    val statusColor = when (connection) {
        ConnectionUi.Connected -> colors.success
        ConnectionUi.Failed -> colors.error
        else -> colors.textBody
    }
    val statusIcon = when (connection) {
        ConnectionUi.Connected -> Icons.Filled.CheckCircle
        ConnectionUi.Checking -> Icons.Outlined.HourglassEmpty
        ConnectionUi.Failed -> Icons.Outlined.ErrorOutline
        else -> Icons.Outlined.Lock
    }
    val statusLabel = when (connection) {
        ConnectionUi.Connected -> R.string.patient_connected_status
        ConnectionUi.Checking -> R.string.patient_connection_checking
        ConnectionUi.Failed -> R.string.patient_connection_unavailable_status
        ConnectionUi.Unavailable -> R.string.patient_invitation_demo_status
        ConnectionUi.NotConnected -> R.string.patient_not_connected_status
    }
    GroupedListCard(accent = PatientAvatarColor.background(patient.id)) {
        androidx.compose.foundation.layout.FlowRow(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
            maxItemsInEachRow = if (textScale > 1.3f) 1 else 2,
            horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                Modifier.weight(1f).heightIn(min = 48.dp * textScale),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(statusIcon, contentDescription = null, tint = statusColor, modifier = Modifier.size(20.dp))
                Text(stringResource(statusLabel), color = statusColor,
                    style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold,
                    maxLines = 2, modifier = Modifier.weight(1f))
                if (connection == ConnectionUi.Connected) {
                    TextButton(onClick = { onInvite() },
                        enabled = !busy && !sending, modifier = Modifier.entitlementCreateControl()) {
                        Text(stringResource(R.string.patient_reinvite_action), color = colors.gold)
                    }
                }
            }
            val checking = connection == ConnectionUi.Checking
            val actionLabel = when (connection) {
                ConnectionUi.Connected, ConnectionUi.Checking -> R.string.activities_title
                ConnectionUi.Failed -> R.string.retry
                else -> R.string.patient_invite_to_app_action
            }
            // Keep the action slot present before the first result, without a misleading action.
            Box(Modifier.weight(1f).heightIn(min = 48.dp * textScale)) {
                if (!checking) OutlinedButton(
                    onClick = {
                        when (connection) {
                            ConnectionUi.Connected -> sheet = "send"
                            ConnectionUi.Failed -> refresh()
                            else -> onInvite()
                        }
                    },
                    enabled = !busy && !sending,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp * textScale).then(if (connection == ConnectionUi.Failed) Modifier else Modifier.entitlementCreateControl()),
                    shape = RoundedCornerShape(10.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = colors.gold),
                ) {
                    Icon(when (connection) {
                        ConnectionUi.Connected -> Icons.Outlined.Assignment
                        ConnectionUi.Failed -> Icons.Outlined.Refresh
                        else -> Icons.Outlined.PersonAdd
                    },
                        contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(actionLabel), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, maxLines = 2)
                }
            }
        }
    }
    if (sheet != null) ModalBottomSheet(onDismissRequest = { if (!sending) sheet = null },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true, confirmValueChange = { !sending })) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { sheet = null }, enabled = !sending) {
                Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = null)
                Spacer(Modifier.width(6.dp))
                Text(stringResource(if (sheet == "send") R.string.close_action else R.string.back))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(if (sheet == "send") stringResource(R.string.activities_title) else name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                if (sheet == "send") Text(name, style = MaterialTheme.typography.bodySmall, color = colors.textBody)
            }
        }
        HorizontalDivider()
        Column(Modifier.fillMaxWidth().weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(if (sheet == "send") 0.dp else 16.dp)) {
            if (contextState is AppContextLoadState.Failed) {
                Text("לא ניתן לבדוק כרגע את ההרשאות.", color = colors.error)
                TextButton(onClick = { retryScope.launch { appContext.refreshOnForeground(); refresh() } }) { Text(stringResource(R.string.retry)) }
            } else if (contextState is AppContextLoadState.Loading && sheet == "send") {
                CircularProgressIndicator()
            } else if (connection == ConnectionUi.Failed) {
                Text("לא ניתן לבדוק כרגע את החיבור. אפשר לנסות שוב.", color = colors.error)
                TextButton(onClick = { refresh() }) { Text(stringResource(R.string.retry)) }
            } else if (connection == ConnectionUi.Checking) {
                CircularProgressIndicator()
            } else if (sheet == "invite") {
                val connected = connection == ConnectionUi.Connected
                Text(stringResource(if (connected) R.string.patient_reinvite_action else R.string.patient_connect_description))
                if (connection == ConnectionUi.NotConnected || connected) {
                    Text(stringResource(if (connected) R.string.patient_reinvite_explanation else R.string.patient_share_invitation_explanation))
                    Button(onClick = { sheet = null; onInvite() }, enabled = !busy && !sending,
                        modifier = Modifier.fillMaxWidth().entitlementCreateControl(),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accentFill, contentColor = colors.textOnAccent)) { IconLabel(stringResource(R.string.patient_share_invitation_action), Icons.Outlined.Share) }
                } else Text(stringResource(R.string.patient_invitation_unavailable_explanation))
                if (!connected) Text(stringResource(R.string.patient_connection_optional_explanation))
            } else if (connection == ConnectionUi.Connected) {
                val tools = listOf(PatientAssignmentType.Questionnaire, PatientAssignmentType.DiaryOne, PatientAssignmentType.DiaryTwo) +
                    if (PatientAssignmentType.diaryThreeSendingEnabled) listOf(PatientAssignmentType.DiaryThree) else emptyList()
                tools.forEachIndexed { index, type ->
                    key(type) {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp)) {
                            PatientToolAccessControl(patient, repository, isDemo, type, busy || sending,
                                onBusyChanged = { sending = it }, reviewEnabled = if (com.cbtipul.app.BuildConfig.DEBUG && review) type != PatientAssignmentType.DiaryOne else null,
                                listRow = true)
                        }
                        if (index < tools.lastIndex) HorizontalDivider(color = colors.borderFaint)
                    }
                }
            } else if (connection == ConnectionUi.Checking) {
                CircularProgressIndicator()
                Text(stringResource(R.string.patient_connection_checking))
            } else Text(stringResource(R.string.patient_not_connected_body))
            if (sheet == "invite") TextButton(onClick = { sheet = null }, enabled = !sending) { Text(stringResource(R.string.cancel)) }
        }
    }

}

@Composable
private fun SendChoice(icon: ImageVector, title: Int, description: Int, enabled: Boolean, onClick: () -> Unit) {
    OutlinedCard(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth().entitlementCreateControl()) {
        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
            Box(Modifier.size(40.dp).background(Theme.colors.goldGhost, RoundedCornerShape(11.dp)), contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = null, tint = Theme.colors.gold, modifier = Modifier.size(22.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(stringResource(title), fontWeight = FontWeight.SemiBold)
                Text(stringResource(description), style = MaterialTheme.typography.bodyMedium, color = Theme.colors.textBody)
            }
        }
    }
}
