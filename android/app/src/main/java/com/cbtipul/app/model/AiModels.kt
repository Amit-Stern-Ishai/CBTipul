package com.cbtipul.app.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class FollowUpStatus {
    @SerialName("discussed") Discussed,
    @SerialName("follow_up") FollowUp,
    @SerialName("not_relevant") NotRelevant,
}

@Serializable
data class AssignmentForNextWeek(
    val assignment: String,
    val details: String? = null,
)

@Serializable
data class CognitivePattern(
    val pattern: String,
    val evidence: String = "",
    val confidence: String = "",
)

@Serializable
data class KeySituation(
    var situation: String,
    @SerialName("why_it_matters") var whyItMatters: String,
)

@Serializable
data class PossibleNAT(
    var thought: String,
    var situation: String,
    var emotion: String? = null,
    var behavior: String? = null,
    val source: String = "",
    val confidence: String = "",
    @SerialName("cognitive_patterns") val cognitivePatterns: List<CognitivePattern> = emptyList(),
)

@Serializable
data class TherapistHypothesis(
    val hypothesis: String,
    val evidence: String,
    val confidence: String,
)

@Serializable
data class FollowUpQuestion(
    var question: String,
    var reason: String,
    var status: FollowUpStatus? = null,
)

@Serializable
data class CBTCycle(
    @SerialName("trigger_situation") var triggerSituation: String? = null,
    @SerialName("automatic_thought") var automaticThought: String? = null,
    var emotion: String? = null,
    var behavior: String? = null,
    @SerialName("short_term_consequence") var shortTermConsequence: String? = null,
    @SerialName("long_term_consequence") var longTermConsequence: String? = null,
    val evidence: String = "",
    val confidence: String = "",
)

@Serializable
data class CBTSessionAnalysis(
    @SerialName("session_summary") var sessionSummary: String = "",
    @SerialName("key_situations") var keySituations: List<KeySituation> = emptyList(),
    @SerialName("possible_nats") var possibleNats: List<PossibleNAT> = emptyList(),
    @SerialName("cbt_cycles") val cbtCycles: List<CBTCycle> = emptyList(),
    @SerialName("therapist_hypotheses") val therapistHypotheses: List<TherapistHypothesis> = emptyList(),
    @SerialName("follow_up_questions") var followUpQuestions: List<FollowUpQuestion> = emptyList(),
    @SerialName("assignments_for_next_week") val assignmentsForNextWeek: List<AssignmentForNextWeek> = emptyList(),
)

@Serializable
data class SessionReviewResponse(
    val analysis: CBTSessionAnalysis,
    val usage: TokenUsage = TokenUsage(),
)

@Serializable
data class TokenUsage(val totalTokens: Int = 0)

@Serializable
data class PriorityFollowUp(
    val item: String,
    val reason: String,
    val source: String = "",
)

@Serializable
data class RecurringNAT(
    val thought: String,
    val situations: List<String> = emptyList(),
    @SerialName("cognitive_patterns") val cognitivePatterns: List<CognitivePattern> = emptyList(),
    val evidence: String = "",
    val confidence: String = "",
)

@Serializable
data class CoreBeliefHypothesis(
    val belief: String,
    val evidence: List<String> = emptyList(),
    val confidence: String = "",
)

@Serializable
data class QuestionnaireInsight(
    val observation: String,
    val evidence: String = "",
    @SerialName("clinical_relevance") val clinicalRelevance: String = "",
)

@Serializable
data class TreatmentFocus(
    val focus: String,
    val rationale: String = "",
)

@Serializable
data class SuggestedQuestion(
    val question: String,
    val purpose: String = "",
    val priority: String = "",
)

@Serializable
data class NextSessionPreparation(
    @SerialName("executive_summary") val executiveSummary: String = "",
    @SerialName("priority_follow_ups") val priorityFollowUps: List<PriorityFollowUp> = emptyList(),
    @SerialName("recurring_nats") val recurringNats: List<RecurringNAT> = emptyList(),
    @SerialName("cbt_cycles") val cbtCycles: List<CBTCycle> = emptyList(),
    @SerialName("questionnaire_insights") val questionnaireInsights: List<QuestionnaireInsight> = emptyList(),
    @SerialName("treatment_focus") val treatmentFocus: TreatmentFocus? = null,
    @SerialName("suggested_questions") val suggestedQuestions: List<SuggestedQuestion> = emptyList(),
    @SerialName("core_belief_hypothesis") val coreBeliefHypothesis: CoreBeliefHypothesis? = null,
    @SerialName("assignments_to_check") val assignmentsToCheck: List<AssignmentForNextWeek> = emptyList(),
)

@Serializable
data class PrepareSessionResponse(
    val preparation: NextSessionPreparation,
    val usage: TokenUsage = TokenUsage(),
)

@Serializable
data class SavedPreparation(
    val generatedAtMillis: Long,
    val preparation: NextSessionPreparation,
)

data class ChatTurn(val role: String, val content: String)

class AiException(message: String) : Exception(message)

@Serializable
data class SupervisionPoint(
    val observation: String = "",
    val evidence: String = "",
    val confidence: String = "",
)

@Serializable
data class AlternativeFormulation(
    val formulation: String = "",
    val evidence: String = "",
    @SerialName("what_it_would_explain") val whatItWouldExplain: String = "",
    val confidence: String = "",
)

@Serializable
data class TreatmentImplication(
    val implication: String = "",
    val rationale: String = "",
    val priority: String = "",
)

@Serializable
data class FormulationSupervision(
    @SerialName("supporting_evidence") val supportingEvidence: List<SupervisionPoint> = emptyList(),
    @SerialName("challenging_evidence") val challengingEvidence: List<SupervisionPoint> = emptyList(),
    @SerialName("possible_blind_spots") val possibleBlindSpots: List<SupervisionPoint> = emptyList(),
    @SerialName("alternative_formulations") val alternativeFormulations: List<AlternativeFormulation> = emptyList(),
    @SerialName("questions_to_explore") val questionsToExplore: List<SuggestedQuestion> = emptyList(),
    @SerialName("treatment_implications") val treatmentImplications: List<TreatmentImplication> = emptyList(),
)

@Serializable
data class MissingFinding(
    val title: String = "",
    val observation: String = "",
    val evidence: String = "",
    @SerialName("why_it_might_matter") val whyItMightMatter: String = "",
    @SerialName("question_for_therapist") val questionForTherapist: String = "",
    val category: String = "",
    val confidence: String = "",
    val priority: String = "",
)

@Serializable
data class WhatAmIMissingResponse(
    val findings: List<MissingFinding> = emptyList(),
)

@Serializable
data class LongitudinalFinding(
    val observation: String = "",
    val evidence: String = "",
    val interpretation: String = "",
    val confidence: String = "",
)

@Serializable
data class TreatmentGoalProgress(
    val goal: String = "",
    val status: String = "",
    @SerialName("current_estimate") val currentEstimate: String = "",
    val evidence: String = "",
    val suggestion: String = "",
    val confidence: String = "",
)

@Serializable
data class LongitudinalCaseReviewResponse(
    @SerialName("overall_trajectory") val overallTrajectory: String = "",
    val improvements: List<LongitudinalFinding> = emptyList(),
    @SerialName("persistent_difficulties") val persistentDifficulties: List<LongitudinalFinding> = emptyList(),
    @SerialName("recurring_patterns") val recurringPatterns: List<LongitudinalFinding> = emptyList(),
    @SerialName("important_changes") val importantChanges: List<LongitudinalFinding> = emptyList(),
    @SerialName("treatment_goal_progress") val treatmentGoalProgress: List<TreatmentGoalProgress> = emptyList(),
    @SerialName("formulation_evolution") val formulationEvolution: List<LongitudinalFinding> = emptyList(),
    @SerialName("clinical_attention_points") val clinicalAttentionPoints: List<LongitudinalFinding> = emptyList(),
    @SerialName("questions_for_therapist") val questionsForTherapist: List<String> = emptyList(),
)
