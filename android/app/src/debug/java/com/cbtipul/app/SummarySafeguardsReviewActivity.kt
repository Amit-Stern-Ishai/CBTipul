package com.cbtipul.app

import android.os.Bundle
import androidx.compose.foundation.background
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.cbtipul.app.data.*
import com.cbtipul.app.model.*
import com.cbtipul.app.ui.patients.*
import com.cbtipul.app.ui.theme.CbTipulTheme

/** Debug-only synthetic review screen. No server calls or real account data. */
class SummarySafeguardsReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Entitlements.apply(AppContext(role=AppRole.Therapist, entitlement=AppEntitlement(EntitlementAccess.Full)))
        val app = application as CbTipulApp
        val key = DeviceFormDraftStore.key("synthetic-summary-review", "therapist-session", "synthetic:new")
        if (intent.getBooleanExtra("reset", false)) app.formDrafts.clear(key)
        val draft=SessionEditorDraft(Session())
        draft.configureRecovery(app.formDrafts,key)
        val mode=intent.getStringExtra("mode") ?: "available"
        setContent {
            var error by remember { mutableStateOf<String?>(null) }
            var checking by remember { mutableStateOf(false) }
            var attempts by remember { mutableIntStateOf(0) }
            CbTipulTheme(appearance = if (intent.getBooleanExtra("light", false)) com.cbtipul.app.settings.AppAppearance.Light else com.cbtipul.app.settings.AppAppearance.Dark) {
                Box(Modifier.fillMaxSize().background(com.cbtipul.app.ui.theme.Theme.colors.base).safeDrawingPadding()) {
                    if (checking) Column {
                        Text("מפגשי בדיקה בלבד — ללא גישה לשרת")
                        TextButton(onClick={checking=false}) { Text("חזרה לטיוטה") }
                    } else SessionEditorScreen(
                        session=draft.initial, patient=Patient(DatabaseId.Text("synthetic"),localName="בדיקה סינתטית"),
                        unnamed="בדיקה",isNew=false,isSaving=false,isTranscribing=false,isAnonymizingTranscription=false,isAnalyzing=false,
                        errorMessage=error,onBack={finish()}, onCheckSessions={draft.persistRecovery();checking=true},
                        onSave={ _, _ ->
                            attempts++; error="ניסיונות בדיקה: $attempts"
                            if(mode=="uncertain") { draft.pendingCreation=true;draft.persistRecovery() }
                            else { error=SummaryFailure.Kind.Tokens.message;draft.persistRecovery() }
                        }, onDelete={}, onTranscribe={ _, _, _, _, _ -> }, onAnalyze={ _, _, _ -> },onOpenAnalysis={},
                        questionnaire=null,previousQuestionnaire=null,atmosphere=null,onOpenQuestionnaire={},onMarkFollowUpDiscussed={_,_->},
                        editorDraft=draft,
                        allowanceLookup={
                            if(mode=="unknown") throw SummaryFailure(SummaryFailure.Kind.Lookup)
                            val balance=if(mode=="exhausted") 0.0 else if(mode=="low") 100.0 else 1000.0
                            SummaryAllowance("2026-10-22T10:00:00Z","2026-10","2026-11-01T00:00:00Z",
                                SummaryAllowance.Balance(1000.0,1000.0-balance,balance,balance==0.0),
                                SummaryAllowance.Balance(1000.0,0.0,1000.0,false))
                        })
                }
            }
        }
    }
}
