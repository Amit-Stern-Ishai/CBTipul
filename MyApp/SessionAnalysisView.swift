import SwiftUI

/// Identifiable wrapper so the analysis can be presented with `.sheet(item:)`.
struct SessionAnalysisResult: Identifiable {
    let id = UUID()
    let analysis: WhisperService.CBTSessionAnalysis
}

/// Read-only presentation of an AI session analysis, one section per part
/// of the response. Empty sections are hidden.
struct SessionAnalysisView: View {
    let analysis: WhisperService.CBTSessionAnalysis

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    Text(analysis.sessionSummary)
                }

                if !analysis.keySituations.isEmpty {
                    Section("Key Situations") {
                        ForEach(analysis.keySituations.indices, id: \.self) { index in
                            let item = analysis.keySituations[index]
                            entry(title: item.situation, details: [
                                ("Importance", item.importance)
                            ])
                        }
                    }
                }

                if !analysis.emotions.isEmpty {
                    Section("Emotions") {
                        ForEach(analysis.emotions.indices, id: \.self) { index in
                            let item = analysis.emotions[index]
                            entry(title: item.emotion, details: [
                                ("Context", item.context),
                                ("Evidence", item.evidence)
                            ])
                        }
                    }
                }

                if !analysis.possibleNats.isEmpty {
                    Section("Possible Negative Automatic Thoughts") {
                        ForEach(analysis.possibleNats.indices, id: \.self) { index in
                            let item = analysis.possibleNats[index]
                            entry(title: item.thought, details: [
                                ("Situation", item.situation),
                                ("Emotion", item.emotion),
                                ("Behavior", item.behavior),
                                ("Source", item.source),
                                ("Confidence", item.confidence),
                                ("Possible cognitive patterns",
                                 item.possibleCognitivePatterns.joined(separator: ", "))
                            ])
                        }
                    }
                }

                if !analysis.behaviors.isEmpty {
                    Section("Behaviors") {
                        ForEach(analysis.behaviors.indices, id: \.self) { index in
                            let item = analysis.behaviors[index]
                            entry(title: item.behavior, details: [
                                ("Type", item.type),
                                ("Context", item.context),
                                ("Possible function", item.possibleFunction)
                            ])
                        }
                    }
                }

                if !analysis.cbtPatterns.isEmpty {
                    Section("CBT Patterns") {
                        ForEach(analysis.cbtPatterns.indices, id: \.self) { index in
                            let item = analysis.cbtPatterns[index]
                            entry(title: item.pattern, details: [
                                ("Evidence", item.evidence),
                                ("Confidence", item.confidence)
                            ])
                        }
                    }
                }

                if !analysis.maintainingCycles.isEmpty {
                    Section("Maintaining Cycles") {
                        ForEach(analysis.maintainingCycles.indices, id: \.self) { index in
                            let item = analysis.maintainingCycles[index]
                            entry(title: item.cycle, details: [
                                ("Evidence", item.evidence),
                                ("Confidence", item.confidence)
                            ])
                        }
                    }
                }

                if !analysis.developments.isEmpty {
                    Section("Developments") {
                        ForEach(analysis.developments.indices, id: \.self) { index in
                            let item = analysis.developments[index]
                            entry(title: item.development, details: [
                                ("Significance", item.significance)
                            ])
                        }
                    }
                }

                if !analysis.therapistHypotheses.isEmpty {
                    Section("Therapist Hypotheses") {
                        ForEach(analysis.therapistHypotheses.indices, id: \.self) { index in
                            let item = analysis.therapistHypotheses[index]
                            entry(title: item.hypothesis, details: [
                                ("Evidence", item.evidence),
                                ("Confidence", item.confidence)
                            ])
                        }
                    }
                }

                if !analysis.therapistReflections.isEmpty {
                    Section("Therapist Reflections") {
                        ForEach(analysis.therapistReflections.indices, id: \.self) { index in
                            let item = analysis.therapistReflections[index]
                            entry(title: item.observation, details: [
                                ("Why it may matter", item.whyItMayMatter),
                                ("Question to explore", item.questionToExplore),
                                ("Confidence", item.confidence)
                            ])
                        }
                    }
                }

                if !analysis.followUpQuestions.isEmpty {
                    Section("Follow-up Questions") {
                        ForEach(analysis.followUpQuestions.indices, id: \.self) { index in
                            let item = analysis.followUpQuestions[index]
                            entry(title: item.question, details: [
                                ("Reason", item.reason),
                                ("Category", item.category),
                                ("Priority", item.priority)
                            ])
                        }
                    }
                }

                if !analysis.unresolvedIssues.isEmpty {
                    Section("Unresolved Issues") {
                        ForEach(analysis.unresolvedIssues.indices, id: \.self) { index in
                            Text(analysis.unresolvedIssues[index])
                        }
                    }
                }
            }
            .navigationTitle("AI Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    /// A titled row followed by labeled detail lines; empty details are hidden.
    private func entry(title: String, details: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            ForEach(details.indices, id: \.self) { index in
                let detail = details[index]
                if !detail.1.isEmpty {
                    Text("\(detail.0): \(detail.1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
