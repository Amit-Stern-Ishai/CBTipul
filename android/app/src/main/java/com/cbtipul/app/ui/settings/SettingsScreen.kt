package com.cbtipul.app.ui.settings

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
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.legal.TermsScreen
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import com.cbtipul.app.ui.patients.DeleteCodeDialog
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.themedScreen

private sealed class SettingsPage {
    data object Main : SettingsPage()
    data object TextSize : SettingsPage()
    data object Terms : SettingsPage()
    data class Web(val title: String, val url: String) : SettingsPage()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    email: String?,
    textSize: AppTextSize,
    aiConsentAccepted: Boolean,
    isDeleting: Boolean,
    deleteError: String?,
    onTextSize: (AppTextSize) -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
    onClearDeleteError: () -> Unit,
    onGettingStartedGuide: () -> Unit = {},
    onDone: () -> Unit,
) {
    val colors = Theme.colors
    var page by remember { mutableStateOf<SettingsPage>(SettingsPage.Main) }
    var confirmDelete by remember { mutableStateOf(false) }
    var codeChallenge by remember { mutableStateOf(false) }

    when (val current = page) {
        SettingsPage.Terms -> TermsScreen(onBack = { page = SettingsPage.Main })
        is SettingsPage.Web -> OfficialLinkScreen(
            title = current.title,
            url = current.url,
            onBack = { page = SettingsPage.Main },
        )
        SettingsPage.TextSize -> TextSizePicker(
            selected = textSize,
            onSelect = onTextSize,
            onBack = { page = SettingsPage.Main },
        )
        SettingsPage.Main -> Scaffold(
            modifier = Modifier.themedScreen(colors.gold),
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.settings_title), color = colors.textBright) },
                    navigationIcon = {
                        IconButton(onClick = onDone, enabled = !isDeleting) {
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
            Box(Modifier.fillMaxSize().padding(padding)) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp),
                ) {
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.getting_started_guide_settings_title),
                            subtitle = stringResource(R.string.getting_started_guide_settings_subtitle),
                            onClick = onGettingStartedGuide,
                        )
                    }

                    Text(stringResource(R.string.settings_accessibility_section_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.settings_text_size_title),
                            trailing = stringResource(textSize.labelRes()),
                            onClick = { page = SettingsPage.TextSize },
                        )
                    }

                    val privacy = stringResource(R.string.privacy_policy_title)
                    val support = stringResource(R.string.settings_support_title)
                    val choices = stringResource(R.string.settings_privacy_choices_title)
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.terms_title),
                            onClick = { page = SettingsPage.Terms },
                        )
                        GroupedListDivider()
                        SettingsRow(title = privacy, onClick = { page = SettingsPage.Web(privacy, "https://cbtipul.com/privacy") })
                        GroupedListDivider()
                        SettingsRow(title = support, onClick = { page = SettingsPage.Web(support, "https://cbtipul.com/support") })
                        GroupedListDivider()
                        SettingsRow(title = choices, onClick = { page = SettingsPage.Web(choices, "https://cbtipul.com/privacy-choices") })
                        if (aiConsentAccepted) {
                            GroupedListDivider()
                            SettingsRow(
                                title = stringResource(R.string.settings_ai_consent_title),
                                trailing = stringResource(R.string.settings_ai_consent_approved_status),
                                onClick = null,
                            )
                        }
                    }

                    Text(stringResource(R.string.settings_account_section_title), color = colors.textBright, fontWeight = FontWeight.SemiBold)
                    if (!email.isNullOrBlank()) {
                        Text(email, color = colors.textBody)
                    }
                    Button(
                        onClick = onSignOut,
                        enabled = !isDeleting,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.error, contentColor = colors.textBright),
                    ) {
                        Text(stringResource(R.string.sign_out_action))
                    }
                    Button(
                        onClick = { confirmDelete = true },
                        enabled = !isDeleting,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.error, contentColor = colors.textBright),
                    ) {
                        Text(stringResource(R.string.delete_account_action))
                    }

                    Text(
                        stringResource(R.string.app_version_label, BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toString()),
                        color = colors.textFaint,
                        fontSize = 13.sp,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (isDeleting) {
                    BusyOverlay(true)
                }
            }
        }
    }

    if (confirmDelete) {
        ConfirmDeleteOverlay(
            visible = true,
            title = stringResource(R.string.delete_account_confirm_title),
            message = stringResource(R.string.delete_account_confirm_message),
            confirmLabel = stringResource(R.string.delete_account_action),
            onConfirm = {
                confirmDelete = false
                codeChallenge = true
            },
            onDismiss = { confirmDelete = false },
        )
    }
    DeleteCodeDialog(
        visible = codeChallenge,
        onConfirm = {
            codeChallenge = false
            onDeleteAccount()
        },
        onDismiss = { codeChallenge = false },
    )
    MessageOverlay(
        visible = deleteError != null,
        title = stringResource(R.string.delete_account_failed_title),
        message = deleteError.orEmpty(),
        onDismiss = onClearDeleteError,
    )
}

@Composable
private fun SettingsRow(
    title: String,
    subtitle: String? = null,
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
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = colors.textBright)
            if (subtitle != null) {
                Text(subtitle, color = colors.textBody, fontSize = 13.sp)
            }
        }
        when {
            selected -> Icon(Icons.Outlined.Check, contentDescription = null, tint = colors.gold)
            trailing != null -> Text(trailing, color = colors.textBody)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TextSizePicker(
    selected: AppTextSize,
    onSelect: (AppTextSize) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    Scaffold(
        modifier = Modifier.themedScreen(colors.gold),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_text_size_title), color = colors.textBright) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = colors.gold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(24.dp)) {
            GroupedListCard(accent = colors.gold) {
                AppTextSize.entries.forEachIndexed { index, size ->
                    SettingsRow(
                        title = stringResource(size.labelRes()),
                        selected = selected == size,
                        onClick = { onSelect(size) },
                    )
                    if (index < AppTextSize.entries.lastIndex) GroupedListDivider()
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
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = stringResource(R.string.back), tint = Color.Black)
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
