import SwiftUI

/// Identifiable wrapper so the result can be presented with `.sheet(item:)`.
struct WhatAmIMissingResult: Identifiable {
    let id = UUID()
    let response: WhatAmIMissingResponse
}

/// "What Am I Missing?" — the AI's independent look across the patient's
/// longitudinal history for patterns the therapist might be overlooking.
/// Read-only supervision: hypotheses for reflection, never written back
/// into `PatientFormulation`. A short (or empty) list of findings is a
/// valid, reassuring result, not an error. Uses the same card language as
/// the other supervision screens.
struct WhatAmIMissingView: View {
    let response: WhatAmIMissingResponse

    @Environment(\.dismiss) private var dismiss

    /// Normalized priority/confidence level for display.
    private enum Level {
        case high, medium, low

        init?(_ raw: String) {
            let lowered = raw.lowercased()
            if lowered.contains("high") || lowered.contains("גבוה") {
                self = .high
            } else if lowered.contains("med") || lowered.contains("בינוני") {
                self = .medium
            } else if lowered.contains("low") || lowered.contains("נמוך") {
                self = .low
            } else {
                return nil
            }
        }

        var label: String {
            switch self {
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    disclaimerHeader

                    if response.findings.isEmpty {
                        emptyResultCard
                    } else {
                        ForEach(response.findings.indices, id: \.self) { index in
                            findingCard(response.findings[index])
                        }
                    }

                    Text("AI-generated clinical support. Use your professional judgment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("🔎 What Am I Missing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    // MARK: - Header and empty state

    private var disclaimerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI-generated supervision")
                .font(.footnote.weight(.semibold))
            Text("These are hypotheses for clinical reflection, not established conclusions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.tint.opacity(0.08))
        )
    }

    /// Finding nothing is a valid outcome, presented as reassurance.
    private var emptyResultCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.green)
            Text("No additional significant patterns were identified from the available information.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Finding card

    /// Title and observation lead, the reflective question draws the eye in
    /// the tinted inset, and evidence stays one tap away.
    private func findingCard(_ finding: MissingFinding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryLabel(finding.category))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(finding.title)
                        .font(.headline)
                }
                Spacer()
                priorityBadge(finding.priority)
            }
            if !finding.observation.isEmpty {
                Text(finding.observation)
                    .font(.subheadline)
            }
            if !finding.whyItMightMatter.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Why this might matter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(finding.whyItMightMatter)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !finding.questionForTherapist.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Question for therapist", systemImage: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(finding.questionForTherapist)
                        .font(.body.weight(.medium).italic())
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.tint.opacity(0.08))
                )
            }
            evidenceDisclosure(finding.evidence)
            HStack {
                confidenceText(finding.confidence)
                Spacer()
                hypothesisBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Friendly label for a machine category; raw values are never shown.
    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "recurring_nat": return "Recurring Automatic Thought"
        case "cognitive_pattern": return "Thinking Pattern"
        case "maintaining_behavior": return "Maintaining Behavior"
        case "cbt_cycle": return "CBT Cycle"
        case "discrepancy": return "Possible Discrepancy"
        case "persistent_symptom": return "Persistent Symptom"
        case "repeated_situation": return "Repeated Situation"
        case "unexplored_theme": return "Possible Unexplored Theme"
        case "possible_connection": return "Possible Connection"
        case "treatment_opportunity": return "Possible Treatment Opportunity"
        case "risk_review": return "Risk Review"
        default:
            return category
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    // MARK: - Small helpers

    /// Marks content the AI inferred, so hypotheses never read as facts.
    private var hypothesisBadge: some View {
        Label("Hypothesis", systemImage: "lightbulb")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.orange.opacity(0.12)))
    }

    /// High priority stands out; medium and low stay quiet.
    @ViewBuilder
    private func priorityBadge(_ raw: String) -> some View {
        switch Level(raw) {
        case .high:
            Text("High")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.orange))
        case .medium:
            Text("Medium")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
        case .low:
            Text("Low")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case nil:
            if !raw.isEmpty {
                Text(raw.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func confidenceText(_ raw: String) -> some View {
        if let level = Level(raw) {
            Text("Confidence: \(level.label)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if !raw.isEmpty {
            Text("Confidence: \(raw.capitalized)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Evidence stays one tap away so cards remain scannable.
    @ViewBuilder
    private func evidenceDisclosure(_ evidence: String) -> some View {
        if !evidence.isEmpty {
            DisclosureGroup {
                Text(evidence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } label: {
                Text("Evidence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
