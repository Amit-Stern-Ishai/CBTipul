package com.cbtipul.app
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.cbtipul.app.data.PatientAssignment
import com.cbtipul.app.data.PatientAssignmentType
import com.cbtipul.app.settings.AppAppearance
import com.cbtipul.app.ui.patient.PatientHomeContent
import com.cbtipul.app.ui.patient.TasksLoadState
import com.cbtipul.app.ui.theme.CbTipulTheme
import java.util.Date
/** Synthetic presentation only; no network requests. Debug APK only. */
class PatientHomeReviewActivity : ComponentActivity() {
 override fun onCreate(savedInstanceState: Bundle?) {
  super.onCreate(savedInstanceState)
  com.cbtipul.app.data.Entitlements.apply(com.cbtipul.app.data.AppContext(role=com.cbtipul.app.data.AppRole.Therapist, entitlement=com.cbtipul.app.data.AppEntitlement(com.cbtipul.app.data.EntitlementAccess.Full)))
  val assignments = listOf(PatientAssignmentType.Questionnaire, PatientAssignmentType.DiaryOne, PatientAssignmentType.DiaryTwo).map {
   PatientAssignment("review-${it.raw}", "synthetic-patient-home", null, null, it.raw, Date(), null, null)
  }
  setContent {
   CbTipulTheme(appearance = if (intent.getBooleanExtra("dark", false)) AppAppearance.Dark else AppAppearance.Light) {
    PatientHomeContent(TasksLoadState.Loaded, assignments, emptyList(), emptyList(), false, {},
     "synthetic-patient-home", null, emptyMap(), emptySet(), {}, {}, false, {}, {}, {}, {}, {}, {}, {}, {})
   }
  }
 }
}
