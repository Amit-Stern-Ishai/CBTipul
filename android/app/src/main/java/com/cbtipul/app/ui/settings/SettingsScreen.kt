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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.HelpOutline
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.FormatSize
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material.icons.outlined.PrivacyTip
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.cbtipul.app.BuildConfig
import com.cbtipul.app.CbTipulApp
import com.cbtipul.app.R
import com.cbtipul.app.data.TherapistProfile
import com.cbtipul.app.debug.DebugPushTestSection
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.legal.TermsScreen
import com.cbtipul.app.ui.patients.ConfirmDeleteOverlay
import com.cbtipul.app.ui.patients.DeleteCodeDialog
import com.cbtipul.app.ui.patients.MessageOverlay
import com.cbtipul.app.ui.theme.BusyOverlay
import com.cbtipul.app.ui.theme.GroupedListCard
import com.cbtipul.app.ui.theme.GroupedListDivider
import com.cbtipul.app.ui.theme.Theme
import com.cbtipul.app.ui.theme.dismissKeyboardOnTap
import com.cbtipul.app.ui.theme.themedScreen
import kotlinx.coroutines.launch

private sealed class SettingsPage {
    data object Main : SettingsPage()
    data object TextSize : SettingsPage()
    data object Terms : SettingsPage()
    data object DisplayName : SettingsPage()
    data class Web(val title: String, val url: String) : SettingsPage()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    email: String?,
    textSize: AppTextSize,
    aiConsentAccepted: Boolean,
    displayName: String?,
    displayNameLoadFailed: Boolean,
    isDeleting: Boolean,
    deleteError: String?,
    onTextSize: (AppTextSize) -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
    onClearDeleteError: () -> Unit,
    onLoadDisplayName: suspend () -> String?,
    onSaveDisplayName: suspend (String) -> Unit,
    onGettingStartedGuide: () -> Unit = {},
    onDone: () -> Unit,
) {
    val colors = Theme.colors
    var page by remember { mutableStateOf<SettingsPage>(SettingsPage.Main) }
    var confirmDelete by remember { mutableStateOf(false) }
    var codeChallenge by remember { mutableStateOf(false) }
    val displayNameValue = when {
        displayNameLoadFailed && displayName.isNullOrBlank() -> {
            stringResource(R.string.therapist_display_name_load_error)
        }
        TherapistProfile.isValid(displayName.orEmpty()) -> TherapistProfile.normalized(displayName.orEmpty())
        else -> stringResource(R.string.settings_therapist_display_name_unset)
    }

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
        SettingsPage.DisplayName -> DisplayNameEditor(
            initialName = displayName.orEmpty(),
            onLoad = onLoadDisplayName,
            onSave = onSaveDisplayName,
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
                            icon = Icons.Outlined.Assignment,
                            onClick = onGettingStartedGuide,
                        )
                    }

                    Text(
                        stringResource(R.string.settings_accessibility_section_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                    )
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.settings_text_size_title),
                            trailing = stringResource(textSize.labelRes()),
                            icon = Icons.Outlined.FormatSize,
                            onClick = { page = SettingsPage.TextSize },
                        )
                    }

                    val privacy = stringResource(R.string.privacy_policy_title)
                    val support = stringResource(R.string.settings_support_title)
                    val choices = stringResource(R.string.settings_privacy_choices_title)
                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.terms_title),
                            icon = Icons.Outlined.Description,
                            onClick = { page = SettingsPage.Terms },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = privacy,
                            icon = Icons.Outlined.PrivacyTip,
                            external = true,
                            onClick = { page = SettingsPage.Web(privacy, "https://cbtipul.com/privacy") },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = support,
                            icon = Icons.Outlined.HelpOutline,
                            external = true,
                            onClick = { page = SettingsPage.Web(support, "https://cbtipul.com/support") },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = choices,
                            icon = Icons.Outlined.Tune,
                            external = true,
                            onClick = { page = SettingsPage.Web(choices, "https://cbtipul.com/privacy-choices") },
                        )
                    }

                    if (aiConsentAccepted) {
                        GroupedListCard(accent = colors.gold) {
                            SettingsRow(
                                title = stringResource(R.string.settings_ai_consent_title),
                                trailing = stringResource(R.string.settings_ai_consent_approved_status),
                                icon = Icons.Outlined.AutoAwesome,
                                onClick = null,
                            )
                        }
                    }

                    Text(
                        stringResource(R.string.settings_account_section_title),
                        color = colors.textBright,
                        fontWeight = FontWeight.SemiBold,
                    )
                    GroupedListCard(accent = colors.gold) {
                        if (!email.isNullOrBlank()) {
                            SettingsRow(
                                title = email,
                                icon = Icons.Outlined.AccountCircle,
                                titleColor = colors.textBody,
                                onClick = null,
                            )
                            GroupedListDivider()
                        }
                        SettingsRow(
                            title = stringResource(R.string.settings_therapist_display_name_title),
                            trailing = displayNameValue,
                            icon = Icons.Outlined.Badge,
                            onClick = { page = SettingsPage.DisplayName },
                        )
                        GroupedListDivider()
                        SettingsRow(
                            title = stringResource(R.string.sign_out_action),
                            destructive = true,
                            enabled = !isDeleting,
                            onClick = onSignOut,
                        )
                    }

                    GroupedListCard(accent = colors.gold) {
                        SettingsRow(
                            title = stringResource(R.string.delete_account_action),
                            destructive = true,
                            enabled = !isDeleting,
                            onClick = { confirmDelete = true },
                        )
                    }

                    if (BuildConfig.DEBUG) {
                        DebugPushTestSection(
                            (LocalContext.current.applicationContext as CbTipulApp)
                                .authRepository.supabaseClient,
                        )
                    }

                    Text(
                        stringResource(
                            R.string.app_version_label,
                            BuildConfig.VERSION_NAME,
                            BuildConfig.VERSION_CODE.toString(),
                        ),
                        color = colors.textBody,
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center,
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
private fun SettingsGlyph(icon: ImageVector) {
    val colors = Theme.colors
    Box(
        modifier = Modifier
            .size(28.dp)
            .background(colors.goldGhost, RoundedCornerShape(7.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = colors.gold, modifier = Modifier.size(16.dp))
    }
}

@Composable
internal fun SettingsRow(
    title: String,
    subtitle: String? = null,
    trailing: String? = null,
    icon: ImageVector? = null,
    selected: Boolean = false,
    external: Boolean = false,
    destructive: Boolean = false,
    enabled: Boolean = true,
    titleColor: Color? = null,
    onClick: (() -> Unit)?,
) {
    val colors = Theme.colors
    val clickable = onClick != null && enabled
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (clickable) Modifier.clickable(onClick = onClick!!) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (destructive) {
            Text(
                title,
                color = colors.error,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            if (icon != null) {
                SettingsGlyph(icon)
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = if (icon != null) 12.dp else 0.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(title, color = titleColor ?: colors.textBright)
                if (subtitle != null) {
                    Text(subtitle, color = colors.textBody, fontSize = 13.sp)
                }
            }
            when {
                selected -> Icon(Icons.Outlined.Check, contentDescription = null, tint = colors.gold)
                external -> Icon(
                    Icons.Outlined.OpenInNew,
                    contentDescription = null,
                    tint = colors.textBody,
                    modifier = Modifier.size(16.dp),
                )
                trailing != null -> Text(
                    trailing,
                    color = colors.textBody,
                    modifier = Modifier.padding(start = 8.dp),
                    maxLines = 1,
                )
            }
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
private fun DisplayNameEditor(
    initialName: String,
    onLoad: suspend () -> String?,
    onSave: suspend (String) -> Unit,
    onBack: () -> Unit,
) {
    val colors = Theme.colors
    val scope = rememberCoroutineScope()
    var draft by remember { mutableStateOf(initialName) }
    var isLoading by remember { mutableStateOf(true) }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val emptyError = stringResource(R.string.therapist_display_name_empty)
    val saveError = stringResource(R.string.therapist_display_name_save_error)
    val loadError = stringResource(R.string.therapist_display_name_load_error)
    val canSave = TherapistProfile.isValid(draft) && !isSaving && !isLoading

    LaunchedEffect(Unit) {
        try {
            val loaded = onLoad()
            if (!loaded.isNullOrBlank()) draft = loaded
        } catch (_: Exception) {
            errorMessage = loadError
        } finally {
            isLoading = false
        }
    }

    Scaffold(
        modifier = Modifier
            .themedScreen(colors.gold)
            .dismissKeyboardOnTap()
            .imePadding(),
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(stringResource(R.string.therapist_display_name_prompt_title), color = colors.textBright)
                },
                navigationIcon = {
                    IconButton(onClick = onBack, enabled = !isSaving) {
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
            Button(
                onClick = {
                    val trimmed = TherapistProfile.normalized(draft)
                    if (!TherapistProfile.isValid(trimmed)) {
                        errorMessage = emptyError
                        return@Button
                    }
                    isSaving = true
                    errorMessage = null
                    scope.launch {
                        try {
                            onSave(trimmed)
                            onBack()
                        } catch (_: Exception) {
                            errorMessage = saveError
                            isSaving = false
                        }
                    }
                },
                enabled = canSave,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 16.dp)
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = colors.gold,
                    contentColor = colors.textOnAccent,
                    disabledContainerColor = colors.goldDim,
                ),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(stringResource(R.string.save), fontWeight = FontWeight.SemiBold)
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    stringResource(R.string.therapist_display_name_prompt_explanation),
                    color = colors.textBody,
                )
                GroupedListCard(accent = colors.gold) {
                    OutlinedTextField(
                        value = draft,
                        onValueChange = { draft = it },
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
                        enabled = !isLoading && !isSaving,
                        singleLine = true,
                        placeholder = {
                            Text(
                                stringResource(R.string.therapist_display_name_placeholder),
                                color = colors.textFaint,
                            )
                        },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Color.Transparent,
                            unfocusedBorderColor = Color.Transparent,
                            disabledBorderColor = Color.Transparent,
                            cursorColor = colors.gold,
                            focusedTextColor = colors.textBright,
                            unfocusedTextColor = colors.textBright,
                        ),
                    )
                }
                errorMessage?.let { Text(it, color = colors.error, fontSize = 13.sp) }
            }
            BusyOverlay(isBusy = isSaving || isLoading)
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
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
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
