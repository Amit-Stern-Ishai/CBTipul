package com.cbtipul.app

import android.app.Application
import com.cbtipul.app.auth.AuthRepository
import com.cbtipul.app.data.AiConsentStore
import com.cbtipul.app.data.AiService
import com.cbtipul.app.data.AppContextRepository
import com.cbtipul.app.data.ClinicalTextAnonymizer
import com.cbtipul.app.data.ClinicalTextGate
import com.cbtipul.app.data.DemoClinicStore
import com.cbtipul.app.data.DiaryTwoRepository
import com.cbtipul.app.data.DiaryThreeRepository
import com.cbtipul.app.data.DiaryOneRepository
import com.cbtipul.app.data.NotificationRepository
import com.cbtipul.app.data.OnboardingStore
import com.cbtipul.app.data.PatientAssignmentRepository
import com.cbtipul.app.data.PatientMessageRepository
import com.cbtipul.app.data.PendingDestinationStore
import com.cbtipul.app.data.PatientCache
import com.cbtipul.app.data.PatientDiaryTwoService
import com.cbtipul.app.data.PatientDiaryOneService
import com.cbtipul.app.data.PatientIdentityStore
import com.cbtipul.app.data.PatientInvitationFlow
import com.cbtipul.app.data.PatientInvitationService
import com.cbtipul.app.data.PatientRepository
import com.cbtipul.app.data.TherapistProfileRepository
import com.cbtipul.app.data.WhisperService
import com.cbtipul.app.data.createCbTipulSupabaseClient
import com.cbtipul.app.push.PushNotificationManager
import com.cbtipul.app.settings.AppPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class CbTipulApp : Application() {
    val formDrafts by lazy { com.cbtipul.app.data.DeviceFormDraftStore(this) }
    lateinit var preferences: AppPreferences
        private set
    lateinit var authRepository: AuthRepository
        private set
    lateinit var patientRepository: PatientRepository
        private set
    lateinit var aiConsentStore: AiConsentStore
        private set
    lateinit var onboardingStore: OnboardingStore
        private set
    lateinit var demoClinicStore: DemoClinicStore
        private set
    lateinit var appContext: AppContextRepository
        private set
    lateinit var invitationFlow: PatientInvitationFlow
        private set
    lateinit var assignments: PatientAssignmentRepository
        private set
    lateinit var diaryThree: DiaryThreeRepository
        private set
    lateinit var diaryTwo: DiaryTwoRepository
        private set
    lateinit var diaryOne: DiaryOneRepository
        private set
    lateinit var patientDiaryTwo: PatientDiaryTwoService
        private set
    lateinit var patientDiaryOne: PatientDiaryOneService
        private set
    lateinit var therapistProfiles: TherapistProfileRepository
        private set
    lateinit var invitations: PatientInvitationService
        private set
    lateinit var pushManager: PushNotificationManager
        private set
    lateinit var notifications: NotificationRepository
        private set
    lateinit var messages: PatientMessageRepository
        private set
    lateinit var pendingDestinations: PendingDestinationStore
        private set

    val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onCreate() {
        super.onCreate()
        preferences = AppPreferences(this)
        val client = createCbTipulSupabaseClient()
        val identityStore = PatientIdentityStore(this)
        authRepository = AuthRepository(client) {
            if (::pushManager.isInitialized) pushManager.unregisterCurrentToken()
        }
        notifications = NotificationRepository(client)
        messages = PatientMessageRepository(client)
        pendingDestinations = PendingDestinationStore()
        pushManager = PushNotificationManager(
            appContext = this,
            client = client,
            auth = authRepository,
            identityStore = identityStore,
            scope = applicationScope,
            onPushReceived = { applicationScope.launch { notifications.refresh() } },
        )
        pushManager.start()
        aiConsentStore = AiConsentStore(preferences)
        onboardingStore = OnboardingStore(this)
        demoClinicStore = DemoClinicStore(this)
        val anonymizer = ClinicalTextAnonymizer(client, aiConsentStore)
        patientRepository = PatientRepository(
            client = client,
            identityStore = identityStore,
            cache = PatientCache(this),
            textGate = ClinicalTextGate { anonymizer.anonymize(it) },
            whisper = WhisperService(client, aiConsentStore),
            ai = AiService(client, aiConsentStore),
            demoClinicStore = demoClinicStore,
            aiConsentStore = aiConsentStore,
        )
        appContext = AppContextRepository(client)
        invitations = PatientInvitationService(client)
        assignments = PatientAssignmentRepository(client)
        diaryOne = DiaryOneRepository(client)
        diaryThree = DiaryThreeRepository(client)
        diaryTwo = DiaryTwoRepository(client)
        patientDiaryOne = PatientDiaryOneService(client, diaryOne)
        patientDiaryTwo = PatientDiaryTwoService(client)
        therapistProfiles = TherapistProfileRepository(client)
        invitationFlow = PatientInvitationFlow(
            invitations = invitations,
            auth = authRepository,
            appContext = appContext,
            patients = patientRepository,
            scope = applicationScope,
        )
    }
}
