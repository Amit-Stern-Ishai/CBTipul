package com.cbtipul.app.data

import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.DatabaseId
import com.cbtipul.app.model.missingRequiredAnswers
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class AndroidParityTest {
    @Test fun requiredAnswersDifferBetweenPatientAndTherapist() {
        val complete = CombinedMoodQuestionnaire(gad7Answers = List(7) { 0 }, phq9Answers = List(9) { 0 })
        assertEquals(emptyList<Int>(), complete.missingRequiredAnswers(false))
        assertEquals(listOf(16), complete.missingRequiredAnswers(true))
        assertTrue(complete.copy(interferenceLevel = 0).missingRequiredAnswers(true).isEmpty())
    }

    @Test fun missingAndInvalidAnswersAreLocatedInDisplayOrder() {
        val draft = CombinedMoodQuestionnaire(gad7Answers = listOf(0, null, 4), phq9Answers = listOf(-1, 2))
        assertEquals(listOf(1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16), draft.missingRequiredAnswers(true))
    }

    @Test fun encryptedDraftKeysSeparateAccountsFormsAndTargets() {
        val base = DeviceFormDraftStore.key("account-a", "message", "patient-a")
        assertNotEquals(base, DeviceFormDraftStore.key("account-b", "message", "patient-a"))
        assertNotEquals(base, DeviceFormDraftStore.key("account-a", "diary", "patient-a"))
        assertNotEquals(base, DeviceFormDraftStore.key("account-a", "message", "patient-b"))
        assertNotEquals(DeviceFormDraftStore.key("a:b", "c", "d"), DeviceFormDraftStore.key("a", "b:c", "d"))
        assertFalse(base.contains("account-a"))
    }

    @Test fun partialQuestionnaireAndDiaryDraftsRoundTripWithoutLosingUnansweredFields() {
        val questionnaire = CombinedMoodQuestionnaire(gad7Answers = listOf(1, null, 0, null, null, null, null))
        assertEquals(questionnaire, Json.decodeFromString<CombinedMoodQuestionnaire>(Json.encodeToString(questionnaire)))
        val diary = DiaryOneEntryDraft(event = "אירוע", feelings = listOf(DiaryFeelingDraft(name = "עצב", intensity = null)))
        assertEquals(diary, Json.decodeFromString<DiaryOneEntryDraft>(Json.encodeToString(diary)))
    }

    @Test fun deletingAllSamplesDoesNotCauseReseeding() {
        val snapshot = DemoClinicStore.Snapshot(includesSampleData = true)
        assertTrue(Json.decodeFromString<DemoClinicStore.Snapshot>(Json.encodeToString(snapshot)).hasLoadedSampleData)
    }

    @Test fun legacySampleSnapshotIsRecognizedButTutorialOnlyNeedsSamples() {
        val sampleId = DemoData.makeBundle().patients.first { DemoData.isShowcaseId(it.id) }.id
        val sample = DemoClinicStore.PatientRecord(sampleId, "", "", true)
        assertTrue(DemoClinicStore.Snapshot(patients = listOf(sample)).hasLoadedSampleData)
        assertFalse(Json.decodeFromString<DemoClinicStore.Snapshot>("{}").hasLoadedSampleData)
    }
}
