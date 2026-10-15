package com.cbtipul.app.ui.patients

import com.cbtipul.app.data.*
import com.cbtipul.app.model.*
import com.cbtipul.app.settings.AppTextSize
import com.cbtipul.app.ui.patient.featuredPatientDraft
import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class RecentActivityParityTest {
    private val disk = mutableMapOf<String, Set<String>>()
    private fun store() = RecentActivityDismissals({ disk[it].orEmpty() }, { key, value -> disk[key] = value })
    private val patient = Patient(DatabaseId.Text("patient"))
    private fun entry(id: String, date: Long, creator: DiaryOneEntryCreator = DiaryOneEntryCreator.Patient) =
        DiaryOneEntry(id, patient.id, "owner", creator, "private event", listOf("private thought"), emptyList(), "private action", null, Date(date), Date(date))
    @Test fun dismissalsSurviveRecreationAndStayScopedToOwnerAndPatient() {
        val s = store()
        s.dismiss(listOf("DIARY-ONE-A", "diary-one-a"), "OWNER", "PATIENT")
        assertTrue(store().contains("diary-one-A", "owner", "patient"))
        assertFalse(s.contains("diary-one-a", "another-owner", "patient"))
        assertFalse(s.contains("diary-one-a", "owner", "another-patient"))
        assertFalse(s.contains("diary-one-a", "local-demo", "patient"))
        s.dismiss(listOf("diary-one-b"), null, "patient")
        assertFalse(s.contains("diary-one-b", null, "patient"))
        assertEquals(1, disk.size)
        assertEquals(setOf("diary-one-a"), disk.values.single())
    }
    @Test fun dismissalScopeCannotCollideOnDelimiters() {
        val s = store()
        s.dismiss(listOf("item"), "a:b", "c")
        assertFalse(s.contains("item", "a", "b:c"))
    }
    @Test fun newSubmissionsReappearAndTherapistEntriesNeverIncreaseBadge() {
        val s = store()
        val entries = listOf(entry("b", 20), entry("a", 20), entry("therapist", 30, DiaryOneEntryCreator.Therapist))
        val first = recentSubmissions(patient, entries, emptyList(), emptyList(), emptyList(), s, "owner", Date(100))
        assertEquals(listOf("diary-one-a", "diary-one-b"), first.map { it.id })
        s.dismiss(first.map { it.id }, "owner", "patient")
        assertTrue(recentSubmissions(patient, entries, emptyList(), emptyList(), emptyList(), store(), "owner", Date(100)).isEmpty())
        val newItems = recentSubmissions(patient, entries + entry("c", 40), emptyList(), emptyList(), emptyList(), s, "owner", Date(100))
        assertEquals(listOf("diary-one-c"), newItems.map { it.id })
        assertEquals("patient/patient/diary-one?entry=c", newItems.single().route)
    }
    @Test fun lastPastSessionIsCutoffAndFutureAppointmentDoesNotHideSubmissions() {
        val p = patient.copy(sessions = listOf(Session(date = Date(20), type = SessionType.DiaryOne), Session(date = Date(200), type = SessionType.DiaryOne)))
        val questionnaire = CompletedQuestionnaire(DatabaseId.Text("9007199254740993"), null, Date(40), CombinedMoodQuestionnaire(), "patient")
        val items = recentSubmissions(p, listOf(entry("old", 10), entry("at-session", 20), entry("new", 30)), emptyList(), emptyList(), listOf(questionnaire), store(), "owner", Date(100))
        assertEquals(listOf("questionnaire-9007199254740993", "diary-one-new"), items.map { it.id })
        assertTrue(items.first().route.endsWith("9007199254740993"))
    }
    @Test fun diaryTypesHaveIndependentDismissalIdsAndCorrectRoutes() {
        val two = DiaryTwoEntry("same", patient.id, "owner", DiaryOneEntryCreator.Patient, "event", emptyList(), emptyList(), emptyList(), emptyList(), Date(20), Date(20))
        val three = DiaryThreeEntry("same", patient.id, "owner", DiaryOneEntryCreator.Patient, "event", emptyList(), emptyList(), emptyList(), emptyList(), Date(30), Date(30))
        val s = store()
        s.dismiss(listOf("diary-two-same"), "owner", "patient")
        val rows = recentSubmissions(patient, listOf(entry("same", 10)), listOf(two), listOf(three), emptyList(), s, "owner", Date(100))
        assertEquals(listOf("diary-three-same", "diary-one-same"), rows.map { it.id })
        assertEquals("patient/patient/diary-three?entry=same", rows.first().route)
    }
    @Test fun textSizeDefaultsToDeviceAndExplicitSavedPreferencesRemainSelectable() {
        assertEquals(AppTextSize.System, AppTextSize.fromStorage(null))
        assertEquals(1.7f, AppTextSize.System.resolvedScale(1.7f))
        assertEquals(AppTextSize.Large, AppTextSize.fromStorage("large"))
        assertEquals(1.15f, AppTextSize.Large.resolvedScale(1.7f))
    }
    @Test fun featuredDraftUsesNewestEnabledTypeWithStableTieBreak() {
        fun draft(id: String, time: Long, type: String) = PatientAssignment(id, "p", "t", null, type, Date(time), null, null)
        val a = draft("a", 20, "diary_one")
        val b = draft("b", 20, "diary_two")
        val older = draft("old", 10, "questionnaire")
        assertEquals(a, featuredPatientDraft(listOf(b, older, a, draft("invalid", 30, "unknown"))))
        assertNull(featuredPatientDraft(emptyList()))
    }
}
