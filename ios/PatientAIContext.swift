import Foundation

/// Shared, complete therapist context used by chat and conceptualization suggestions.
enum PatientAIContext {
    // MARK: - Context building

    static func questionnairesContext(_ questionnaires: [CompletedQuestionnaire]) -> String {
        let records = questionnaires
            .sorted { $0.answeredDate < $1.answeredDate }
        guard !records.isEmpty else { return "No questionnaires have been filled in yet." }
        return records.map(context(for:)).joined(separator: "\n\n")
    }

    static func context(for record: CompletedQuestionnaire) -> String {
        let q = record.questionnaire
        var lines: [String] = []
        lines.append("Questionnaire answered on \(record.answeredDate.formatted(date: .numeric, time: .omitted)):")

        lines.append("GAD-7 (each answer 0-3):")
        lines.append(contentsOf: answerLines(
            questions: L10n.gad7Questions, answers: q.gad7Answers, notes: q.gad7Notes
        ))
        lines.append("GAD-7 total: \(q.gad7Score) (\(L10n.label(for: q.gad7Severity)))")

        lines.append("PHQ-9 (each answer 0-3):")
        lines.append(contentsOf: answerLines(
            questions: L10n.phq9Questions, answers: q.phq9Answers, notes: q.phq9Notes
        ))
        lines.append("PHQ-9 total: \(q.phq9Score) (\(L10n.label(for: q.phq9Severity)))")

        if let level = q.interferenceLevel,
           L10n.phq9InterferenceOptions.indices.contains(level) {
            var line = "Interference: \(L10n.phq9InterferenceOptions[level]) (\(level))"
            if !q.interferenceNote.isEmpty {
                line += " [note: \(q.interferenceNote)]"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    static func answerLines(questions: [String], answers: [Int?], notes: [String]) -> [String] {
        questions.indices.map { index in
            let answer = answers.indices.contains(index) ? answers[index] : nil
            var line = "- \(questions[index]): \(answer.map(String.init) ?? "unanswered")"
            if notes.indices.contains(index), !notes[index].isEmpty {
                line += " [note: \(notes[index])]"
            }
            return line
        }
    }

    /// Compact text digest of a session's saved structured AI review,
    /// mirroring the clinically relevant core that `PatientContext` sends
    /// to the Edge Functions.
    static func structuredContext(_ analysis: WhisperService.CBTSessionAnalysis) -> String {
        var lines = ["reviewProvenance: AI-generated origin; saved content may include therapist edits; field-level edit history is unavailable",
                     "Summary: \(analysis.sessionSummary)"]
        if !analysis.possibleNats.isEmpty {
            lines.append("Possible NATs:")
            for nat in analysis.possibleNats {
                var details = ["situation: \(nat.situation)"]
                if let emotion = nat.emotion, !emotion.isEmpty { details.append("emotion: \(emotion)") }
                if let behavior = nat.behavior, !behavior.isEmpty { details.append("behavior: \(behavior)") }
                details.append("confidence: \(nat.confidence)")
                lines.append("- \(nat.thought) (\(details.joined(separator: ", ")))")
            }
        }
        if !analysis.cbtCycles.isEmpty {
            lines.append("CBT cycles:")
            for cycle in analysis.cbtCycles {
                let stages = [cycle.triggerSituation, cycle.automaticThought, cycle.emotion,
                              cycle.behavior, cycle.shortTermConsequence, cycle.longTermConsequence]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                lines.append("- \(stages.joined(separator: " → ")) (confidence: \(cycle.confidence))")
            }
        }
        if !analysis.therapistHypotheses.isEmpty {
            lines.append("AI-generated hypotheses:")
            for hypothesis in analysis.therapistHypotheses {
                lines.append("- \(hypothesis.hypothesis) (confidence: \(hypothesis.confidence))")
            }
        }
        let openQuestions = analysis.followUpQuestions
            .filter { $0.status != .discussed && $0.status != .notRelevant }
        if !openQuestions.isEmpty {
            lines.append("Open follow-up questions:")
            for question in openQuestions {
                lines.append("- \(question.question) (\(question.reason))")
            }
        }
        if !analysis.assignmentsForNextWeek.isEmpty {
            lines.append("Assignments for next week:")
            for assignment in analysis.assignmentsForNextWeek {
                var line = "- \(assignment.assignment)"
                if let details = assignment.details, !details.isEmpty {
                    line += " (\(details))"
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    static func diaryContext(
        one: [DiaryOneEntry], two: [DiaryTwoEntry], three: [DiaryThreeEntry], unavailable: [String]
    ) -> String {
        func header(_ number: Int, _ date: Date, _ creator: DiaryOneEntryCreator) -> String {
            "Diary \(number)\nauthor: \(creator.rawValue)\nrecordedAt: \(date.ISO8601Format())\nrecordedAtMeaning: record creation time; the described event may have occurred at another time"
        }
        var entries: [String] = []
        for entry in one.sorted(by: { $0.createdAt < $1.createdAt }) {
            entries.append([
                header(1, entry.createdAt, entry.createdBy),
                "Event: \(entry.event)",
                "Automatic thoughts: \(entry.automaticThoughts.joined(separator: "; "))",
                "Feelings: \(entry.feelings.map { "\($0.name): \($0.intensity)%" }.joined(separator: "; "))",
                "Behaviour: \(entry.behaviour)",
                "Physical symptoms: \(entry.physicalSymptoms ?? "")"
            ].joined(separator: "\n"))
        }
        for entry in two.sorted(by: { $0.createdAt < $1.createdAt }) {
            entries.append([
                header(2, entry.createdAt, entry.createdBy),
                "Event: \(entry.event)",
                "Automatic thoughts: \(entry.automaticThoughts.joined(separator: "; "))",
                "Feelings: \(entry.feelings.map { "\($0.name): \($0.intensity)%" }.joined(separator: "; "))",
                "Thinking errors: \(entry.thinkingErrors.map(\.rawValue).joined(separator: "; "))",
                "Alternative thoughts: \(entry.alternativeThoughts.joined(separator: "; "))"
            ].joined(separator: "\n"))
        }
        for entry in three.sorted(by: { $0.createdAt < $1.createdAt }) {
            entries.append([
                header(3, entry.createdAt, entry.createdBy),
                "Situation: \(entry.situation)",
                "Automatic thoughts: \(entry.automaticThoughts.map { "\($0.text) (belief before: \($0.beliefBefore)%, after: \($0.beliefAfter)%)" }.joined(separator: "; "))",
                "Feelings: \(entry.feelings.map { "\($0.name) (intensity before: \($0.intensityBefore)%, after: \($0.intensityAfter)%)" }.joined(separator: "; "))",
                "Thinking errors: \(entry.thinkingErrors.map(\.rawValue).joined(separator: "; "))",
                "Alternative thoughts: \(entry.alternativeThoughts.map { "\($0.text) (belief: \($0.belief)%)" }.joined(separator: "; "))"
            ].joined(separator: "\n"))
        }
        return "Saved diary entries (intensity and belief use 0–100%; dates are record creation dates):\n" +
            (entries.isEmpty ? "No entries in successfully loaded diaries." : entries.joined(separator: "\n\n")) +
            "\n" + unavailable.joined(separator: "\n")
    }

    static func fullContext(patient: Patient, questionnaires: [CompletedQuestionnaire]) -> String {
        var parts: [String] = []

        let patientNotes = patient.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !patientNotes.isEmpty {
            parts.append("Patient notes (general, not tied to a session):\nsource: therapist\n\(patientNotes)")
        }

        if let formulation = patient.formulation {
            var lines: [String] = []
            func append(_ label: String, _ value: String?) {
                let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !text.isEmpty { lines.append("\(label): \(text)") }
            }
            append("Treatment goal", formulation.treatmentGoal)
            append("Core belief", formulation.coreBelief)
            append("Hypothesis", formulation.therapistHypothesis)
            let thoughts = formulation.keyAutomaticThoughts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !thoughts.isEmpty {
                lines.append("Key automatic thoughts:")
                lines.append(contentsOf: thoughts.map { "- \($0)" })
            }
            let behaviors = formulation.maintainingBehaviors
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !behaviors.isEmpty {
                lines.append("Maintaining behaviors:")
                lines.append(contentsOf: behaviors.map { "- \($0)" })
            }
            if let cycle = formulation.keyCBTCycle {
                let stages = [cycle.triggerSituation, cycle.automaticThought, cycle.emotion,
                              cycle.behavior, cycle.shortTermConsequence, cycle.longTermConsequence]
                    .compactMap { $0 }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                if !stages.isEmpty {
                    lines.append("Key CBT cycle: \(stages.joined(separator: " → "))")
                }
            }
            if !lines.isEmpty {
                parts.append((["Therapist formulation:\nsource: therapist\nmaterialType: therapist_formulation (clinical formulation, not established facts)"] + lines).joined(separator: "\n"))
            }
        }

        let sessions = patient.sessions.sorted { $0.date < $1.date }
        if sessions.isEmpty {
            parts.append("No sessions yet.")
        } else {
            var lines = ["Sessions:"]
            for session in sessions {
                var line = "- Session date: \(session.date.formatted(date: .numeric, time: .omitted))"
                if let type = session.type {
                    line += " (\(type.rawValue))"
                }
                if !session.notes.isEmpty {
                    line += "\n  Raw session notes (source: therapist): \(session.notes)"
                }
                if let analysis = session.structuredNotes {
                    let digest = structuredContext(analysis)
                        .split(separator: "\n")
                        .map { "  \($0)" }
                        .joined(separator: "\n")
                    line += "\n  Previous structured AI review (source: ai_generated; applies to all content in this review):\n\(digest)"
                }
                lines.append(line)
            }
            parts.append(lines.joined(separator: "\n"))
        }

        parts.append("Questionnaires:\nsource: patient_reported_measurement\n\(questionnairesContext(questionnaires))")
        return parts.joined(separator: "\n\n")
    }
}
