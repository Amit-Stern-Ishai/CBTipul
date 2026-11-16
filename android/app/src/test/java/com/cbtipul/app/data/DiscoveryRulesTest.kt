package com.cbtipul.app.data
import org.junit.Test
import org.junit.Assert.*
class DiscoveryRulesTest {
    @Test fun accountAndFeatureIsolation() {
        assertEquals(DiscoveryRules.key("A", "voice"), DiscoveryRules.key("a", "voice"))
        assertNotEquals(DiscoveryRules.key("a", "voice"), DiscoveryRules.key("b", "voice"))
        assertNotEquals(DiscoveryRules.key("a", "voice"), DiscoveryRules.key("a", "web"))
    }
    @Test fun typingExcludesLoadingTranscriptionDemoAndPatient() {
        assertTrue(DiscoveryRules.voice(true,true,true,false,false))
        assertFalse(DiscoveryRules.voice(false,true,true,false,false))
        assertFalse(DiscoveryRules.voice(true,true,false,false,false))
        assertFalse(DiscoveryRules.voice(true,true,true,true,false))
        assertFalse(DiscoveryRules.voice(true,true,true,false,true))
        assertFalse(DiscoveryRules.voice(true,false,true,false,false))
    }
    @Test fun saveFeedbackAndOtherPromptsTakePriority() {
        for (busy in listOf(false,true)) for (feedback in listOf(false,true)) for (modal in listOf(false,true)) for (valid in listOf(false,true)) {
            assertEquals(!busy && !feedback && !modal && valid, DiscoveryRules.present(true,busy,feedback,modal,valid))
        }
        assertFalse(DiscoveryRules.present(false,false,false,false,true))
    }
    @Test fun sharedDiaryMilestonesBeatSecondSessionOnlyForFirstTypedSession() {
        val one = com.cbtipul.app.model.SessionType.DiaryOne
        val two = com.cbtipul.app.model.SessionType.DiaryTwo
        assertEquals(PatientMilestone.DiaryOne, DiscoveryRules.sessionMilestone(one, 1, 2))
        assertEquals(PatientMilestone.DiaryTwo, DiscoveryRules.sessionMilestone(two, 1, 2))
        assertEquals(PatientMilestone.SecondSession, DiscoveryRules.sessionMilestone(one, 2, 2))
        assertNull(DiscoveryRules.sessionMilestone(two, 2, 3))
        assertNull(DiscoveryRules.sessionMilestone(null, 1, 1))
        val key = DiscoveryRules.patientFeature("p", PatientMilestone.DiaryOne.name)
        assertEquals(key, DiscoveryRules.patientFeature("P", PatientMilestone.DiaryOne.name))
        assertNotEquals(key, DiscoveryRules.patientFeature("p", PatientMilestone.DiaryTwo.name))
        assertNotEquals(key, DiscoveryRules.patientFeature("q", PatientMilestone.DiaryOne.name))
        assertNotEquals(DiscoveryRules.key("a", key), DiscoveryRules.key("b", key))
    }
    @Test fun suggestionsNeverGuessConnectionOrActivityState() {
        assertEquals(true, DiscoveryRules.suggestion(false, null))
        assertEquals(false, DiscoveryRules.suggestion(true, false))
        assertNull(DiscoveryRules.suggestion(true, true))
        assertNull(DiscoveryRules.suggestion(true, null))
        assertNull(DiscoveryRules.suggestion(null, false))
    }

}
