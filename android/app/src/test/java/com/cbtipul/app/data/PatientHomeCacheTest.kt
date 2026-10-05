package com.cbtipul.app.data

import com.cbtipul.app.model.*
import org.junit.Assert.*
import org.junit.After
import org.junit.Test
import java.util.Date

class PatientHomeCacheTest {
    @After fun cleanup() = PatientHomeCache.clear()

    @Test fun inactiveToolsRequireHistoryAndActiveToolsDoNot() {
        val patient = DatabaseId.Text("patient")
        val date = Date(0)
        val history = PatientHomeSnapshot(
            questionnaires = listOf(CompletedQuestionnaire(patient, null, date, CombinedMoodQuestionnaire())),
            diaryOne = listOf(DiaryOneEntry("one", patient, "therapist", DiaryOneEntryCreator.Patient, "", emptyList(), emptyList(), "", null, date, date)),
            diaryTwo = listOf(DiaryTwoEntry("two", patient, "therapist", DiaryOneEntryCreator.Patient, "", emptyList(), emptyList(), emptyList(), emptyList(), date, date)),
            diaryThree = listOf(DiaryThreeEntry("three", patient, "therapist", DiaryOneEntryCreator.Patient, "", emptyList(), emptyList(), emptyList(), emptyList(), date, date)),
        )
        val empty = PatientHomeSnapshot(questionnaires = emptyList(), diaryOne = emptyList(), diaryTwo = emptyList(), diaryThree = emptyList())
        for (type in PatientAssignmentType.entries) {
            assertFalse(PatientHomeSnapshot().isVisible(type, false))
            assertFalse(empty.isVisible(type, false))
            assertTrue(empty.isVisible(type, true))
            assertTrue(history.isVisible(type, false))
        }
    }

    @Test fun cacheRetainsEmptyResultsAndSeparatesPatientsAndAccounts() {
        val snapshot = PatientHomeSnapshot(assignments = emptyList(), diaryOne = emptyList())
        PatientHomeCache.read("account:patient")
        PatientHomeCache.save("account:patient", snapshot)
        assertEquals(snapshot, PatientHomeCache.read("account:patient"))
        assertNull(PatientHomeCache.read("account:other-patient").assignments)
        PatientHomeCache.save("account:patient", snapshot) // late response from previous patient
        assertNull(PatientHomeCache.read("account:other-patient").assignments)
        PatientHomeCache.save("account:other-patient", snapshot)
        assertNull(PatientHomeCache.read("other-account:other-patient").assignments)
        PatientHomeCache.save("other-account:other-patient", snapshot)
        PatientHomeCache.clear()
        assertNull(PatientHomeCache.read("other-account:other-patient").assignments)
    }
}
