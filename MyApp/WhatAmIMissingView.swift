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
            case .high: return L10n.priorityHigh
            case .medium: return L10n.priorityMedium
            case .low: return L10n.priorityLow
            }
        }
    }

    /// Only high-priority findings are surfaced; anything on screen is
    /// implicitly high, so no priority is displayed.
    private var highPriorityFindings: [MissingFinding] {
        response.findings.filter { Level($0.priority) == .high }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    disclaimerHeader

                    if highPriorityFindings.isEmpty {
                        emptyResultCard
                    } else {
                        ForEach(highPriorityFindings.indices, id: \.self) { index in
                            findingCard(highPriorityFindings[index])
                        }
                    }

                    Text(L10n.aiDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Theme.base)
            .navigationTitle(L10n.whatAmIMissingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .appTextSize()
    }

    // MARK: - Header and empty state

    private var disclaimerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.aiGeneratedSupervisionLabel)
                .font(.footnote.weight(.semibold))
            Text(L10n.supervisionDisclaimerBody)
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
            Text(L10n.noAdditionalPatternsMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
        )
    }

    // MARK: - Finding card

    /// Title and observation lead, the reflective question draws the eye in
    /// the tinted inset, and evidence stays one tap away.
    private func findingCard(_ finding: MissingFinding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(categoryLabel(finding.category))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(finding.title)
                    .font(.headline)
            }
            if !finding.observation.isEmpty {
                Text(finding.observation)
                    .font(.subheadline)
            }
            if !finding.whyItMightMatter.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.whyThisMightMatterLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(finding.whyItMightMatter)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !finding.questionForTherapist.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.questionForTherapistLabel, systemImage: "magnifyingglass")
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
                .fill(Theme.surface)
        )
    }

    /// Friendly label for a machine category; raw values are never shown.
    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "recurring_nat": return L10n.categoryRecurringNat
        case "cognitive_pattern": return L10n.categoryCognitivePattern
        case "maintaining_behavior": return L10n.categoryMaintainingBehavior
        case "cbt_cycle": return L10n.cbtCycleSection
        case "discrepancy": return L10n.categoryDiscrepancy
        case "persistent_symptom": return L10n.categoryPersistentSymptom
        case "repeated_situation": return L10n.categoryRepeatedSituation
        case "unexplored_theme": return L10n.categoryUnexploredTheme
        case "possible_connection": return L10n.categoryPossibleConnection
        case "treatment_opportunity": return L10n.categoryTreatmentOpportunity
        case "risk_review": return L10n.categoryRiskReview
        default:
            return category
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    // MARK: - Small helpers

    /// Marks content the AI inferred, so hypotheses never read as facts.
    private var hypothesisBadge: some View {
        Label(L10n.hypothesisBadge, systemImage: "lightbulb")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.warning.opacity(0.12)))
    }

    @ViewBuilder
    private func confidenceText(_ raw: String) -> some View {
        if let level = Level(raw) {
            Text(L10n.confidenceLine(level.label))
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if !raw.isEmpty {
            Text(L10n.confidenceLine(raw.capitalized))
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
                Text(L10n.evidenceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
