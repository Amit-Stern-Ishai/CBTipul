package com.cbtipul.app.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import java.util.Calendar
import java.util.Date
import java.util.UUID

@Serializable(with = DatabaseIdSerializer::class)
sealed class DatabaseId {
    abstract val queryValue: String

    data class Integer(val value: Int) : DatabaseId() {
        override val queryValue: String get() = value.toString()
    }

    data class Text(val value: String) : DatabaseId() {
        override val queryValue: String get() = value
    }
}

object DatabaseIdSerializer : KSerializer<DatabaseId> {
    override val descriptor = PrimitiveSerialDescriptor("DatabaseId", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: DatabaseId) {
        when (value) {
            is DatabaseId.Integer -> {
                if (encoder is JsonEncoder) {
                    encoder.encodeJsonElement(JsonPrimitive(value.value))
                } else {
                    encoder.encodeInt(value.value)
                }
            }
            is DatabaseId.Text -> encoder.encodeString(value.value)
        }
    }

    override fun deserialize(decoder: Decoder): DatabaseId {
        if (decoder is JsonDecoder) {
            val primitive = decoder.decodeJsonElement().jsonPrimitive
            primitive.intOrNull?.let { return DatabaseId.Integer(it) }
            return DatabaseId.Text(primitive.content)
        }
        return DatabaseId.Text(decoder.decodeString())
    }
}

enum class PatientStatus(val storageActive: Boolean) {
    Active(true),
    Inactive(false),
    ;

    companion object {
        fun fromActive(active: Boolean?): PatientStatus =
            if (active != false) Active else Inactive
    }
}

@Serializable
enum class SessionType {
    @SerialName("first_phone_call") FirstPhoneCall,
    @SerialName("intake") Intake,
    @SerialName("psycho_education") PsychoEducation,
    @SerialName("diary_one") DiaryOne,
    @SerialName("diary_two") DiaryTwo,
    @SerialName("diary_three") DiaryThree,
    @SerialName("case_formulation") CaseFormulation,
    @SerialName("behavioral_interventions") BehavioralInterventions,
    @SerialName("relapse_prevention_and_termination") RelapsePreventionAndTermination,
}

data class Session(
    val id: UUID = UUID.randomUUID(),
    val databaseId: DatabaseId? = null,
    val date: Date = Date(),
    val notes: String = "",
    val type: SessionType? = null,
    val structuredNotes: CBTSessionAnalysis? = null,
)

enum class GAD7Severity {
    Minimal, Mild, Substantial, Extreme;

    companion object {
        fun from(score: Int) = when {
            score < 5 -> Minimal
            score < 10 -> Mild
            score < 15 -> Substantial
            else -> Extreme
        }
    }
}

enum class PHQ9Severity {
    Minimal, Mild, Moderate, ModeratelySevere, Severe;

    companion object {
        fun from(score: Int) = when {
            score < 5 -> Minimal
            score < 10 -> Mild
            score < 15 -> Moderate
            score < 20 -> ModeratelySevere
            else -> Severe
        }
    }
}

data class CombinedMoodQuestionnaire(
    val gad7Answers: List<Int?> = List(GAD7_COUNT) { null },
    val phq9Answers: List<Int?> = List(PHQ9_COUNT) { null },
    val interferenceLevel: Int? = null,
    val gad7Notes: List<String> = List(GAD7_COUNT) { "" },
    val phq9Notes: List<String> = List(PHQ9_COUNT) { "" },
    val interferenceNote: String = "",
) {
    val gad7Score: Int get() = gad7Answers.mapNotNull { it }.sum()
    val phq9Score: Int get() = phq9Answers.mapNotNull { it }.sum()
    val gad7Severity: GAD7Severity get() = GAD7Severity.from(gad7Score)
    val phq9Severity: PHQ9Severity get() = PHQ9Severity.from(phq9Score)
    val isComplete: Boolean get() = gad7Answers.none { it == null } && phq9Answers.none { it == null }
    val isEmpty: Boolean
        get() = gad7Answers.all { it == null } && phq9Answers.all { it == null } && interferenceLevel == null

    companion object {
        const val TABLE = "CombinedMood"
        const val GAD7_COUNT = 7
        const val PHQ9_COUNT = 9
    }
}

@Serializable
data class QuestionnaireNotes(
    val gad7: List<String> = emptyList(),
    val phq9: List<String> = emptyList(),
    val interference: String? = null,
)

data class CompletedQuestionnaire(
    val databaseId: DatabaseId,
    val sessionId: DatabaseId?,
    val answeredDate: Date,
    val questionnaire: CombinedMoodQuestionnaire,
)

@Serializable
data class PatientFormulation(
    val treatmentGoal: String? = null,
    val coreBelief: String? = null,
    val keyAutomaticThoughts: List<String> = emptyList(),
    val maintainingBehaviors: List<String> = emptyList(),
    val keyCBTCycle: CBTCycle? = null,
    val therapistHypothesis: String? = null,
) {
    fun hasContent(): Boolean {
        val texts = listOfNotNull(treatmentGoal, coreBelief, therapistHypothesis) +
            keyAutomaticThoughts + maintainingBehaviors
        if (texts.any { it.isNotBlank() }) return true
        val cycle = keyCBTCycle ?: return false
        return listOfNotNull(
            cycle.triggerSituation, cycle.automaticThought, cycle.emotion, cycle.behavior,
            cycle.shortTermConsequence, cycle.longTermConsequence,
        ).any { it.isNotBlank() } || cycle.evidence.isNotBlank()
    }
}

data class Patient(
    val id: DatabaseId,
    val firstName: String = "",
    val lastName: String = "",
    val status: PatientStatus = PatientStatus.Active,
    val notes: String = "",
    val sessions: List<Session> = emptyList(),
    val localName: String? = null,
    val formulation: PatientFormulation? = null,
) {
    val backendName: String
        get() = listOf(firstName, lastName)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .joinToString(" ")

    fun displayName(unnamed: String): String =
        localName?.takeIf { it.isNotEmpty() } ?: unnamed

    val sessionsUpToTodayCount: Int
        get() {
            val startOfToday = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.time
            val startOfTomorrow = Calendar.getInstance().apply {
                time = startOfToday
                add(Calendar.DAY_OF_YEAR, 1)
            }.time
            return sessions.count { it.date < startOfTomorrow }
        }
}

class PatientStoreException(val kind: Kind) : Exception() {
    enum class Kind { NotConfigured, UpdateRejected, PatientNotSaved, SessionNotSaved, AnonymizationFailed }
}

class ConsentDeclinedException : Exception()
