import SwiftUI

/// A full-width prominent button that gently scales down while pressed.
/// Visual stand-in for `.borderedProminent` + `.controlSize(.large)`, which
/// cannot be composed with a press-scale effect.
struct PressableProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Theme.textOnAccent : Theme.textFaint)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(
                isEnabled ? (configuration.isPressed ? Theme.accentFillPressed : Theme.accentFill) : Theme.elevated,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableProminentButtonStyle {
    static var pressableProminent: PressableProminentButtonStyle { .init() }
}
