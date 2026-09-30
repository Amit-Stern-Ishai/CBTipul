package com.cbtipul.app.data

import com.cbtipul.app.model.CombinedMoodQuestionnaire
import com.cbtipul.app.model.CompletedQuestionnaire
import com.cbtipul.app.model.DatabaseId
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.SupabaseClient
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Answers only: no notes, AI fields, or therapist cache. Uses the patient's authenticated client. */
@Serializable
internal data class PatientQuestionnaireHistoryRow(
    val id: DatabaseId,
    @SerialName("patient_id") val patientId: String,
    @SerialName("created_by") val createdBy: String,
    @SerialName("assignment_id") val assignmentId: String? = null,
    @SerialName("answered_date") val answeredDate: String,
    @SerialName("gad7_answers") val gad7Answers: List<Int>,
    @SerialName("phq9_answers") val phq9Answers: List<Int>,
    @SerialName("interference_level") val interferenceLevel: Int? = null,
) {
    fun completed() = CompletedQuestionnaire(id, null, if (answeredDate.length == 10) java.util.Date.from(java.time.LocalDate.parse(answeredDate).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant())
        else PatientAssignmentRepository.parseAssignmentTimestamp(answeredDate),
        CombinedMoodQuestionnaire(
            gad7Answers = List(7) { gad7Answers.getOrNull(it) },
            phq9Answers = List(9) { phq9Answers.getOrNull(it) }, interferenceLevel = interferenceLevel))
}

class PatientQuestionnaireHistoryRepository(private val client: SupabaseClient) {
    suspend fun history(patientId: String): List<CompletedQuestionnaire> = client.from(CombinedMoodQuestionnaire.TABLE)
        .select(Columns.raw("id, patient_id, created_by, assignment_id, answered_date, gad7_answers, phq9_answers, interference_level")) {
            filter { eq("patient_id", patientId); eq("created_by", "patient") }
            order("answered_date", Order.DESCENDING)
            order("id", Order.DESCENDING)
        }.decodeList<PatientQuestionnaireHistoryRow>()
        .filter { it.patientId.equals(patientId, true) && it.createdBy == "patient" }
        .map { it.completed() }.sortedWith(compareByDescending<CompletedQuestionnaire> { it.answeredDate }
            .thenByDescending { it.databaseId.queryValue.toLongOrNull() ?: 0 })
}
