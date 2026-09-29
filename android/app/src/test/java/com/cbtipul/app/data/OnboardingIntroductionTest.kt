package com.cbtipul.app.data

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.booleanPreferencesKey
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

@OptIn(ExperimentalCoroutinesApi::class)
class OnboardingIntroductionTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    @Test fun completionAndSkipPersistAcrossReleaseRelaunch() = runTest {
        val data = PreferenceDataStoreFactory.create(scope = backgroundScope) { temporaryFolder.newFile("intro.preferences_pb") }
        val store = OnboardingStore(data, repeatIntroductionEachLaunch = false)
        store.setActiveUser("therapist-a")
        assertTrue(store.shouldShowIntroduction.value)
        // Skip and regular completion both use this same completion path.
        store.completeIntroduction()
        assertFalse(store.shouldShowIntroduction.value)
        assertEquals(true, data.data.first()[booleanPreferencesKey(OnboardingStore.introductionKey("therapist-a"))])
        val relaunched = OnboardingStore(data, repeatIntroductionEachLaunch = false)
        relaunched.setActiveUser("therapist-a")
        assertFalse(relaunched.shouldShowIntroduction.value)
    }

    @Test fun debugReplaysOnlyOnNewProcessStore() = runTest {
        val data = PreferenceDataStoreFactory.create(scope = backgroundScope) { temporaryFolder.newFile("intro.preferences_pb") }
        val store = OnboardingStore(data, repeatIntroductionEachLaunch = true)
        store.setActiveUser("therapist-a")
        store.completeIntroduction()
        store.setActiveUser("therapist-a") // Activity recreation must not replay.
        assertFalse(store.shouldShowIntroduction.value)
        val relaunched = OnboardingStore(data, repeatIntroductionEachLaunch = true)
        relaunched.setActiveUser("therapist-a")
        assertTrue(relaunched.shouldShowIntroduction.value)
    }

    @Test fun switchingAccountsAndSigningOutDoNotLeakCompletion() = runTest {
        val data = PreferenceDataStoreFactory.create(scope = backgroundScope) { temporaryFolder.newFile("intro.preferences_pb") }
        val store = OnboardingStore(data, repeatIntroductionEachLaunch = false)
        store.setActiveUser("therapist-a")
        store.completeIntroduction()
        store.setActiveUser("therapist-b")
        assertTrue(store.shouldShowIntroduction.value)
        assertEquals("therapist-b", store.hydratedIdentity.value)
        store.setActiveUser(null)
        assertFalse(store.shouldShowIntroduction.value)
        assertFalse(store.isHydrated.value)
        assertNull(store.hydratedIdentity.value)
        store.setActiveUser("therapist-a")
        assertFalse(store.shouldShowIntroduction.value)
    }

    @Test fun oldWelcomeDoesNotSkipTheNewIntroduction() = runTest {
        val data = PreferenceDataStoreFactory.create(scope = backgroundScope) { temporaryFolder.newFile("intro.preferences_pb") }
        val store = OnboardingStore(data, repeatIntroductionEachLaunch = false)
        store.setActiveUser("therapist-a")
        store.dismissWelcome()
        assertTrue(store.shouldShowIntroduction.value)
    }

    @Test fun accountDeletionClearsIntroductionAfterLogout() = runTest {
        val data = PreferenceDataStoreFactory.create(scope = backgroundScope) { temporaryFolder.newFile("intro.preferences_pb") }
        val store = OnboardingStore(data, repeatIntroductionEachLaunch = false)
        store.setActiveUser("therapist-a")
        store.completeIntroduction()
        store.setActiveUser(null)
        store.clearPersistedState("therapist-a")
        store.setActiveUser("therapist-a")
        assertTrue(store.shouldShowIntroduction.value)
    }
}
