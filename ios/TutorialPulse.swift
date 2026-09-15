import SwiftUI

/// Which control the demo tutorial is currently pointing at.
enum TutorialHighlight: Equatable {
    case addPatient
    case sessionsEntry
    case addSession
    case fillQuestionnaire
    case recordNotes
    case aiSummary
}

/// Soft repeating pulse used to coach the therapist toward the next control.
struct TutorialPulseModifier: ViewModifier {
    let isActive: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.warning, lineWidth: 2.5)
                        .padding(-5)
                        .opacity(pulsing ? 1 : 0.2)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(isActive && pulsing ? 1.05 : 1)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { pulsing = isActive }
            .onChange(of: isActive) { _, active in
                pulsing = active
            }
    }
}

extension View {
    func tutorialPulse(_ isActive: Bool) -> some View {
        modifier(TutorialPulseModifier(isActive: isActive))
    }
}
