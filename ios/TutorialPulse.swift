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

/// Visual style for the walkthrough glow.
enum TutorialPulseStyle {
    /// List rows / wide controls — rounded rectangle fill + stroke.
    case card
    /// Nav-bar icon buttons — circular halo (toolbar clips rect overlays).
    case toolbar
}

/// Soft repeating glow used to coach the therapist toward the next control.
struct TutorialPulseModifier: ViewModifier {
    let isActive: Bool
    var style: TutorialPulseStyle = .card
    @State private var pulsing = false

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.warning.opacity(pulsing ? 0.32 : 0.1))
                    }
                }
                .overlay {
                    if isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.warning, lineWidth: 3)
                            .opacity(pulsing ? 1 : 0.35)
                    }
                }
                .onAppear { restartPulse(isActive) }
                .onChange(of: isActive) { _, active in
                    restartPulse(active)
                }
        case .toolbar:
            // Overlay only — do not pad/resize the system bar button.
            content
                .overlay {
                    if isActive {
                        Circle()
                            .fill(Theme.warning.opacity(pulsing ? 0.45 : 0.15))
                            .frame(width: 36, height: 36)
                            .opacity(pulsing ? 1 : 0.85)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if isActive {
                        Circle()
                            .strokeBorder(Theme.warning, lineWidth: 2.5)
                            .frame(width: 36, height: 36)
                            .opacity(pulsing ? 1 : 0.4)
                            .allowsHitTesting(false)
                    }
                }
                .onAppear { restartPulse(isActive) }
                .onChange(of: isActive) { _, active in
                    restartPulse(active)
                }
        }
    }

    private func restartPulse(_ active: Bool) {
        if active {
            pulsing = false
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        } else {
            pulsing = false
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
