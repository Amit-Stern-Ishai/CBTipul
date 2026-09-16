package com.cbtipul.app

import android.app.Application
import com.cbtipul.app.auth.AuthRepository
import com.cbtipul.app.data.AiConsentStore
import com.cbtipul.app.data.AiService
import com.cbtipul.app.data.ClinicalTextAnonymizer
import com.cbtipul.app.data.ClinicalTextGate
import com.cbtipul.app.data.DemoClinicStore
import com.cbtipul.app.data.OnboardingStore
import com.cbtipul.app.data.PatientCache
import com.cbtipul.app.data.PatientIdentityStore
import com.cbtipul.app.data.PatientRepository
import com.cbtipul.app.data.WhisperService
import com.cbtipul.app.data.createCbTipulSupabaseClient
import com.cbtipul.app.settings.AppPreferences

class CbTipulApp : Application() {
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

    override fun onCreate() {
        super.onCreate()
        preferences = AppPreferences(this)
        val client = createCbTipulSupabaseClient()
        authRepository = AuthRepository(client)
        aiConsentStore = AiConsentStore(preferences)
        onboardingStore = OnboardingStore(this)
        demoClinicStore = DemoClinicStore(this)
        val anonymizer = ClinicalTextAnonymizer(client, aiConsentStore)
        patientRepository = PatientRepository(
            client = client,
            identityStore = PatientIdentityStore(this),
            cache = PatientCache(this),
            textGate = ClinicalTextGate { anonymizer.anonymize(it) },
            whisper = WhisperService(client, aiConsentStore),
            ai = AiService(client, aiConsentStore),
            demoClinicStore = demoClinicStore,
        )
    }
}
