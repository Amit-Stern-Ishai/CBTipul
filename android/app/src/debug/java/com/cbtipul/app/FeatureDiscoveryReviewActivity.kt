package com.cbtipul.app
import android.os.Bundle
import androidx.compose.foundation.background
import com.cbtipul.app.ui.theme.Theme
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.cbtipul.app.ui.patients.*
import com.cbtipul.app.ui.theme.CbTipulTheme
import com.cbtipul.app.settings.AppAppearance

/** Synthetic debug-only presentation; no account, preferences or backend requests. */
class FeatureDiscoveryReviewActivity: ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent.getBooleanExtra("activities", false)) com.cbtipul.app.data.Entitlements.apply(com.cbtipul.app.data.AppContext(role = com.cbtipul.app.data.AppRole.Therapist, entitlement = com.cbtipul.app.data.AppEntitlement(com.cbtipul.app.data.EntitlementAccess.Full)))
        setContent {
            CbTipulTheme(appearance = if (intent.getBooleanExtra("dark", false)) AppAppearance.Dark else AppAppearance.Light) {
                if (intent.getBooleanExtra("activities", false)) {
                    val density = androidx.compose.ui.platform.LocalDensity.current
                    CompositionLocalProvider(androidx.compose.ui.platform.LocalLayoutDirection provides androidx.compose.ui.unit.LayoutDirection.Rtl,
                        androidx.compose.ui.platform.LocalDensity provides androidx.compose.ui.unit.Density(density.density,
                            if (intent.getBooleanExtra("largeText", false)) 1.6f else density.fontScale)) {
                        Column(Modifier.fillMaxSize().background(Theme.colors.base).safeDrawingPadding().padding(16.dp)) {
                            PatientConnectionActions(com.cbtipul.app.model.Patient(com.cbtipul.app.model.DatabaseId.Text("77777777-7777-4777-8777-777777777777"), localName = "מטופל/ת לדוגמה"),
                                "מטופל/ת לדוגמה", null, false, false, {}, {}, {}, initialSheet = "send", review = true)
                        }
                    }
                } else {
                var kind by remember { mutableStateOf(intent.getIntExtra("kind", 0)) }; var closed by remember { mutableStateOf(false) }
                Column(Modifier.fillMaxSize().background(Theme.colors.base).safeDrawingPadding().verticalScroll(rememberScrollState()).padding(20.dp)) {
                    Row { listOf("הזמנה","הקלטה","מחשב").forEachIndexed { i,label -> TextButton(onClick = {kind=i;closed=false}) { Text(label) } } }
                    if (kind == 1) {
                        var notes by remember { mutableStateOf("") }
                        OutlinedTextField(notes, { notes = it }, label = { Text("סיכום הפגישה") }, modifier = Modifier.fillMaxWidth())
                        if (!closed && notes.isNotEmpty()) VoiceDiscoveryHint(onPresented = {}, onDismiss = { closed = true })
                    } else if (!closed) FeatureDiscoveryCard(
                        if(kind==0) DiscoveryCopy.inviteTitle else if(kind==1) DiscoveryCopy.voiceTitle else if(kind==3) getString(R.string.discovery_activities_title) else DiscoveryCopy.webTitle,
                        if(kind==0) DiscoveryCopy.inviteBody else if(kind==1) DiscoveryCopy.voiceBody else if(kind==3) getString(R.string.discovery_diary_one_body) else DiscoveryCopy.webBody,
                        web=kind==2, invite=if(kind==0 || kind==3) {{closed=true}} else null,
                        actionLabel=if(kind==3) getString(R.string.discovery_activities_action) else null, onSuppress=if(kind==2) ({closed=true}) else null, onDismiss={closed=true})
                    else Text("ההסבר נסגר")
                }
                }
            }
        }
    }
}
