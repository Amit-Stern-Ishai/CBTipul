package com.cbtipul.app.ui.patients

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.window.Dialog
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Laptop
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.ui.Alignment
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.*
import com.cbtipul.app.ui.theme.Theme

object DiscoveryCopy {
    const val inviteTitle = "אפשר להזמין את המטופל/ת"
    const val inviteBody = "שלחו הזמנה לאפליקציה כדי שהמטופל/ת יוכל/תוכל למלא את הפעילויות שתפעילו עבורו/ה."
    const val voiceTitle = "אפשר גם להקליט"
    const val voiceBody = "אפשר גם להקליט את רשימות הפגישה. הדיבור מתומלל אוטומטית לטקסט, ואפשר לערוך אותו לאחר מכן."
    const val webTitle = "אפשר לעבוד גם מהמחשב"
    const val webBody = "פתחו במחשב הנייד או השולחני את:"
    const val webDetail = "התחברו עם אותו חשבון ובחרו מטופל/ת. אפשר לתעד פגישות ולמלא יחד שאלונים ויומנים, גם במהלך פגישת Zoom."
    const val url = "https://cbtipul.com/app"
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FeatureDiscoveryCard(title: String, body: String, web: Boolean = false, invite: (() -> Unit)? = null, actionLabel: String? = null, onPresented: () -> Unit = {}, onSuppress: (() -> Unit)? = null, onDismiss: () -> Unit) {
    val colors = Theme.colors
    val clipboard = LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }
    Dialog(onDismissRequest = onDismiss) {
    PresentedDiscoveryEffect(onPresented)
    Surface(color = colors.surface, shape = RoundedCornerShape(24.dp), modifier = Modifier.fillMaxWidth().heightIn(max = 640.dp)) {
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
            Column(Modifier.padding(if (web) 20.dp else 24.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(if (web) 12.dp else 16.dp)) {
                Surface(color = colors.accentFill, shape = RoundedCornerShape(20.dp), modifier = Modifier.size(if (web) 48.dp else 64.dp)) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(if (web) Icons.Outlined.Laptop else if (invite != null) Icons.Outlined.PersonAdd else Icons.Outlined.Mic,
                            null, tint = colors.textOnAccent, modifier = Modifier.size(32.dp))
                    }
                }
                Text(title, style = MaterialTheme.typography.headlineSmall, color = colors.textBright, modifier = Modifier.semantics { heading() })
                Text(body, style = MaterialTheme.typography.bodyLarge, color = colors.textBody)
                if (web) {
                    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                        SelectionContainer { Text("cbtipul.com/app", style = MaterialTheme.typography.titleLarge, color = colors.textBright) }
                    }
                    Text(DiscoveryCopy.webDetail, style = MaterialTheme.typography.bodyLarge, color = colors.textBody)
                    if (copied) Text("הכתובת הועתקה", color = colors.textBody, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (web) Button(onClick = { clipboard.setText(AnnotatedString(DiscoveryCopy.url)); copied = true }) { Text("העתקת כתובת") }
                if (invite != null) Button(onClick = invite) { Text(actionLabel ?: "הזמנת המטופל/ת") }
                if (!web && invite == null) Button(onClick = onDismiss) { Text("הבנתי") }
                else TextButton(onClick = onDismiss) { Text("הבנתי", color = colors.gold) }
                }
                if (web && onSuppress != null) TextButton(onClick = onSuppress) { Text("הבנתי, אל תציגו שוב") }
            }
        }
    }
    }
}

@Composable
private fun PresentedDiscoveryEffect(onPresented: () -> Unit) {
    val view = androidx.compose.ui.platform.LocalView.current
    val latest by rememberUpdatedState(onPresented)
    LaunchedEffect(view) {
        // The dialog/inline content must be attached and visible, not just its host composed.
        do { withFrameNanos { } } while (!view.isShown || !view.hasWindowFocus())
        latest()
    }
}

@Composable
fun VoiceDiscoveryHint(onPresented: () -> Unit, onDismiss: () -> Unit) {
    PresentedDiscoveryEffect(onPresented)
    Surface(color = Theme.colors.elevated, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
            Icon(Icons.Outlined.Mic, null, tint = Theme.colors.gold, modifier = Modifier.size(20.dp))
            Text(DiscoveryCopy.voiceBody, style = MaterialTheme.typography.bodySmall, color = Theme.colors.textBody, modifier = Modifier.weight(1f))
            TextButton(onClick = onDismiss) { Text("הבנתי") }
        }
    }
}
