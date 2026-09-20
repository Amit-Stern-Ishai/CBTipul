package com.cbtipul.app.ui.patient

import android.annotation.SuppressLint
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.cbtipul.app.BuildConfig
import com.cbtipul.app.R
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.legal.TermsScreen
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

private sealed class PatientSettingsPage {
    data object Main : PatientSettingsPage()
    data object TextSize : PatientSettingsPage()
    data object Appearance : PatientSettingsPage()
    data object Terms : PatientSettingsPage()
    data class Web(val title: String, val url: String) : PatientSettingsPage()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PatientSettingsScreen(
    textSize: AppTextSize,
    appearance: AppAppearance,
    onTextSize: (AppTextSize) -> Unit,
    onAppearance: (AppAppearance) -> Unit,
    isLeaving: Boolean,
    leaveError: String?,
    onLeavePatientMode: () -> Unit,
    onClearLeaveError: () -> Unit,
    onDone: () -> Unit,
) {
    val colors = Theme.colors
    var page by remember { mutableStateOf<PatientSettingsPage>(PatientSettingsPage.Main) }
    var confirmLeave by remember { mutableStateOf(false) }

    when (val current = page) {
        PatientSettingsPage.Terms -> TermsScreen(onBack = { page = PatientSettingsPage.Main })
        is PatientSettingsPage.Web -> OfficialLinkScreen(
            title = current.title,
            url = current.url,
            onBack = { page = PatientSettingsPage.Main },
        )
        PatientSettingsPage.TextSize -> OptionPicker(
            title = stringResource(R.string.settings_text_size_title),
            options = AppTextSize.entries,
            selected = textSize,
            label = { stringResource(it.labelRes()) },
            onSelect = onTextSize,
            onBack = { page = PatientSettingsPage.Main },
        )
        PatientSettingsPage.Appearance -> OptionPicker(
            title = stringResource(R.string.settings_appearance_title),
            options = AppAppearance.entries,
            selected = appearance,
            label = {
                stringResource(
                    if (it == AppAppearance.Light) R.string.appearance_light else R.string.appearance_dark,
                )
            },
            onSelect = onAppearance,
            onBack = { page = PatientSettingsPage.Main },
        )
        PatientSettingsPage.Main -> Scaffold(
            modifier = Modifier.themedScreen(colors.gold),
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.settings_title), color = colors.textBright) },
                    actions = {
                        TextButton(onClick = onDone, enabled = !isLeaving) {
                            Text(stringResource(R.string.settings_done_action), color = colors.gold)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                )
            },
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    Text(
                        stringResource(R.string.settings_accessibility_section_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                    )
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.settings_text_size_title),
                            trailing = stringResource(textSize.labelRes()),
                            onClick = { page = PatientSettingsPage.TextSize },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = stringResource(R.string.settings_appearance_title),
                            trailing = stringResource(
                                if (appearance == AppAppearance.Light) {
                                    R.string.appearance_light
                                } else {
                                    R.string.appearance_dark
                                },
                            ),
                            onClick = { page = PatientSettingsPage.Appearance },
                        )
                    }

                    val privacy = stringResource(R.string.privacy_policy_title)
                    val support = stringResource(R.string.settings_support_title)
                    val choices = stringResource(R.string.settings_privacy_choices_title)
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.terms_title),
                            onClick = { page = PatientSettingsPage.Terms },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = privacy,
                            onClick = { page = PatientSettingsPage.Web(privacy, "https://cbtipul.com/privacy") },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = support,
                            onClick = { page = PatientSettingsPage.Web(support, "https://cbtipul.com/support") },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = choices,
                            onClick = {
                                page = PatientSettingsPage.Web(choices, "https://cbtipul.com/privacy-choices")
                            },
                        )
                    }

                    Button(
                        onClick = { confirmLeave = true },
                        enabled = !isLeaving,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = colors.error,
                            contentColor = colors.textBright,
                        ),
                    ) {
                        Text(stringResource(R.string.patient_leave_mode_action))
                    }

                    Text(
                        stringResource(
                            R.string.app_version_label,
                            BuildConfig.VERSION_NAME,
                            BuildConfig.VERSION_CODE.toString(),
                        ),
                        color = colors.textFaint,
                        fontSize = 13.sp,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                BusyOverlay(isBusy = isLeaving)
            }
        }
    }

    ConfirmDeleteOverlay(
        visible = confirmLeave,
        title = stringResource(R.string.patient_leave_mode_confirm_title),
        message = stringResource(R.string.patient_leave_mode_confirm_message),
        confirmLabel = stringResource(R.string.patient_leave_mode_confirm_action),
        onConfirm = {
            confirmLeave = false
            onLeavePatientMode()
        },
        onDismiss = { confirmLeave = false },
    )
    MessageOverlay(
        visible = leaveError != null,
        title = stringResource(R.string.patient_leave_mode_failed),
        message = leaveError.orEmpty(),
        onDismiss = onClearLeaveError,
    )
}

@Composable
private fun SettingsRow(
    title: String,
    trailing: String? = null,
    selected: Boolean = false,
    onClick: (() -> Unit)?,
) {
    val colors = Theme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = colors.textBright, modifier = Modifier.weight(1f))
        when {
            selected -> Icon(Icons.Outlined.Check, contentDescription = null, tint = colors.gold)
            trailing != null -> Text(trailing, color = colors.textBody)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> OptionPicker(
    title: String,
    options: List<T>,
    selected: T,
    label: @Composable (T) -> String,
    onSelect: (T) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(title, color = colors.textBright) },
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
        Column(Modifier.fillMaxSize().padding(padding).padding(24.dp)) {
            GroupedListCard(accent = colors.gold) {
                options.forEachIndexed { index, option ->
                    SettingsRow(
                        title = label(option),
                        selected = selected == option,
                        onClick = { onSelect(option) },
                    )
                    if (index < options.lastIndex) GroupedListDivider()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OfficialLinkScreen(title: String, url: String, onBack: () -> Unit) {
    var loading by remember { mutableStateOf(true) }
    Scaffold(
        containerColor = Color.White,
        topBar = {
            TopAppBar(
                title = { Text(title, color = Color.Black) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Outlined.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = Color.Black,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White),
            )
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding).background(Color.White)) {
            OfficialWebView(url = url, onFinished = { loading = false })
            if (loading) {
                CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.Gray)
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun OfficialWebView(url: String, onFinished: () -> Unit) {
    AndroidView(
        factory = { context ->
            WebView(context).apply {
                layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                layoutDirection = View.LAYOUT_DIRECTION_LTR
                settings.javaScriptEnabled = true
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, loaded: String?) {
                        onFinished()
                    }
                }
                loadUrl(url)
            }
        },
        modifier = Modifier.fillMaxSize(),
        onRelease = { it.destroy() },
    )
}

private fun AppTextSize.labelRes(): Int = when (this) {
    AppTextSize.Small -> R.string.settings_text_size_small
    AppTextSize.Standard -> R.string.settings_text_size_standard
    AppTextSize.Large -> R.string.settings_text_size_large
    AppTextSize.ExtraLarge -> R.string.settings_text_size_extra_large
    AppTextSize.Huge -> R.string.settings_text_size_huge
}
