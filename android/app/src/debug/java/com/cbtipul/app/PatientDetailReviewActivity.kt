package com.cbtipul.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.cbtipul.app.model.*
import com.cbtipul.app.ui.patients.PatientDetailScreen
import com.cbtipul.app.ui.theme.CbTipulTheme
import com.cbtipul.app.settings.AppAppearance
import java.util.Date

/** Offline synthetic review; all mutation callbacks are inert. */
class PatientDetailReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        com.cbtipul.app.data.Entitlements.apply(com.cbtipul.app.data.AppContext(role=com.cbtipul.app.data.AppRole.Therapist, entitlement=com.cbtipul.app.data.AppEntitlement(com.cbtipul.app.data.EntitlementAccess.Full)))
        val patient = Patient(DatabaseId.Text("demo-patient-review"), localName = "מטופלת לדוגמה", sessions =
            (if (intent.getBooleanExtra("singleJourney", false)) listOf(SessionType.Intake) else
                listOf(SessionType.Intake, SessionType.Intake, SessionType.DiaryOne, SessionType.DiaryOne, SessionType.DiaryTwo)).mapIndexed { i, type ->
                Session(date = Date(System.currentTimeMillis() - (6-i)*86400000L), type = type)
            })
        setContent { CbTipulTheme(appearance = if (intent.getBooleanExtra("dark", false)) AppAppearance.Dark else AppAppearance.Light) {
            PatientDetailScreen(patient=patient, unnamed="", onBack={finish()}, onRename={_,_->},
                lastQuestionnaire=null, previousQuestionnaire=null, lastSessionType=null, onStatusChange={}, onSaveGoal={}, isSavingGoal=false,
                onOpenSessions={}, onOpenQuestionnaires={}, onOpenChat={}, isPreparing=false, savedPreparationDate=null,
                isPreparationOutdated=false, prepareError=null, onPrepare={}, onOpenLastPreparation={}, notesError=null,
                isSavingNotes=false, isTranscribing=false, isAnonymizingTranscription=false, onSaveNotes={_,_->},
                onTranscribe={_,_,_,_->}, onDelete={}, isDemo=true)
        } }
    }
}
