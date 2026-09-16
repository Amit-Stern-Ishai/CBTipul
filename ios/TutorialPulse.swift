import SwiftUI

/// Which control the demo tutorial is currently pointing at.
enum TutorialHighlight: Equatable {
    case addPatient
    /// The therapist-created tutorial patient row on the patients list.
    case tutorialPatient
    case sessionsEntry
    case addSession
    /// Latest session row on the sessions list (open it to continue).
    case latestSession
    case fillQuestionnaire
    case recordNotes
    case aiSummary
}

/// Kept for call-site compatibility; attention is color-only either way.
enum TutorialPulseStyle {
    case card
    case toolbar
}

/// Walkthrough attention: flash tint / text color only — no shapes or padding.
struct TutorialPulseModifier: ViewModifier {
    let isActive: Bool
    var style: TutorialPulseStyle = .card
    @State private var flashOn = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content
                .foregroundStyle(flashOn ? Theme.warning : Color.primary)
                .tint(flashOn ? Theme.warning : Color.accentColor)
                .symbolEffect(
                    .pulse,
                    options: .repeating.speed(0.8),
                    isActive: style == .toolbar
                )
                .onAppear { startFlashing() }
                .onChange(of: isActive) { _, active in
                    if active { startFlashing() } else { flashOn = false }
                }
        } else {
            content
        }
    }

    private func startFlashing() {
        flashOn = false
        withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
            flashOn = true
        }
    }
}

extension View {
    func tutorialPulse(
        _ isActive: Bool,
        style: TutorialPulseStyle = .card
    ) -> some View {
        modifier(TutorialPulseModifier(isActive: isActive, style: style))
    }
}
