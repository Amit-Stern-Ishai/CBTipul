package com.cbtipul.app.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*

/** Domain content only. Draft and published documents share this type, not mutable state. */
data class CoreBeliefWorksheet(
    val oldBelief: Belief = Belief(),
    val balancedBelief: Belief = Belief(),
    val oldEvidence: String = "",
    val alternativeInterpretations: String = "",
    val balancedEvidence: String = "",
    val experiments: String = "",
    val finalOldRating: Int? = null,
    val finalBalancedRating: Int? = null,
) {
    data class Belief(val text: String = "", val feelings: String = "", val now: Int? = null, val most: Int? = null, val least: Int? = null)
}
data class CoreBeliefWorksheetRecord(
    val patientId: String, val document: CoreBeliefWorksheet?, val revision: String?,
    val updatedAt: String?, val publishedRevision: String?, val publishedAt: String?,
)

object CoreBeliefWorksheetCodec {
    private val json = Json { explicitNulls = true; encodeDefaults = true }
    fun encodeDocument(value: CoreBeliefWorksheet): String = json.encodeToString(CoreBeliefWorksheetDTO.from(value).also { it.validate() })
    fun decodeDocument(value: String): CoreBeliefWorksheet {
        val wire = json.parseToJsonElement(value)
        validateWireDocument(wire)
        return json.decodeFromJsonElement<CoreBeliefWorksheetDTO>(wire).also { it.validate() }.model()
    }
    private fun validateWireDocument(value: JsonElement) {
        val row = value as? JsonObject ?: error("invalid_core_belief_document")
        val texts = setOf("old_belief", "old_feelings", "balanced_belief", "balanced_feelings", "old_evidence", "alternative_interpretations", "balanced_evidence", "experiments")
        val ratings = setOf("old_now", "old_most", "old_least", "balanced_now", "balanced_most", "balanced_least", "old_final", "balanced_final")
        require(row.keys == texts + ratings)
        require(texts.all { (row[it] as? JsonPrimitive)?.isString == true })
        require(ratings.all { key ->
            val rating = row[key]
            rating == JsonNull || rating is JsonPrimitive && !rating.isString && rating.intOrNull?.let { it in 0..100 } == true
        })
    }
    fun decodeRecord(value: String): CoreBeliefWorksheetRecord {
        val wire = json.parseToJsonElement(value).jsonObject
        val document = requireNotNull(wire["document"])
        if (document != JsonNull) validateWireDocument(document)
        require((wire["patient_id"] as? JsonPrimitive)?.isString == true)
        for (key in listOf("revision", "published_at", "updated_at", "published_revision")) {
            val field = wire[key]
            require(field == null || field == JsonNull || field is JsonPrimitive && field.isString)
        }
        val dto = json.decodeFromJsonElement<CoreBeliefWorksheetRecordDTO>(wire)
        dto.document?.validate()
        return CoreBeliefWorksheetRecord(dto.patient_id, dto.document?.model(), dto.revision, dto.updated_at, dto.published_revision, dto.published_at)
    }
}

@Serializable
private data class CoreBeliefWorksheetDTO(
    val old_belief: String,
    val old_feelings: String,
    val old_now: Int?,
    val old_most: Int?,
    val old_least: Int?,
    val balanced_belief: String,
    val balanced_feelings: String,
    val balanced_now: Int?,
    val balanced_most: Int?,
    val balanced_least: Int?,
    val old_evidence: String,
    val alternative_interpretations: String,
    val balanced_evidence: String,
    val experiments: String,
    val old_final: Int?,
    val balanced_final: Int?,
) {
    fun model() = CoreBeliefWorksheet(
        oldBelief = CoreBeliefWorksheet.Belief(old_belief, old_feelings, old_now, old_most, old_least),
        balancedBelief = CoreBeliefWorksheet.Belief(balanced_belief, balanced_feelings, balanced_now, balanced_most, balanced_least),
        oldEvidence = old_evidence,
        alternativeInterpretations = alternative_interpretations,
        balancedEvidence = balanced_evidence,
        experiments = experiments,
        finalOldRating = old_final,
        finalBalancedRating = balanced_final,
    )
    fun validate() {
        require(listOf(old_belief, old_feelings, balanced_belief, balanced_feelings, old_evidence, alternative_interpretations, balanced_evidence, experiments).all { it.length <= 10000 })
        require(listOf(old_now, old_most, old_least, balanced_now, balanced_most, balanced_least, old_final, balanced_final).all { it == null || it in 0..100 })
    }
    companion object {
        fun from(value: CoreBeliefWorksheet) = CoreBeliefWorksheetDTO(
            old_belief = value.oldBelief.text,
            old_feelings = value.oldBelief.feelings,
            old_now = value.oldBelief.now,
            old_most = value.oldBelief.most,
            old_least = value.oldBelief.least,
            balanced_belief = value.balancedBelief.text,
            balanced_feelings = value.balancedBelief.feelings,
            balanced_now = value.balancedBelief.now,
            balanced_most = value.balancedBelief.most,
            balanced_least = value.balancedBelief.least,
            old_evidence = value.oldEvidence,
            alternative_interpretations = value.alternativeInterpretations,
            balanced_evidence = value.balancedEvidence,
            experiments = value.experiments,
            old_final = value.finalOldRating,
            balanced_final = value.finalBalancedRating,
        )
    }
}
@Serializable
private data class CoreBeliefWorksheetRecordDTO(
    val patient_id: String,
    val document: CoreBeliefWorksheetDTO?,
    val revision: String?,
    val published_at: String?,
    val updated_at: String? = null,
    val published_revision: String? = null,
)
