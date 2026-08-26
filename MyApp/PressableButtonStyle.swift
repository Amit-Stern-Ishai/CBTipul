import SwiftUI

/// A full-width prominent button that gently scales down while pressed.
/// Visual stand-in for `.borderedProminent` + `.controlSize(.large)`, which
/// cannot be composed with a press-scale effect.
struct PressableProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Theme.textOnAccent : Theme.textFaint)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                isEnabled ? (configuration.isPressed ? Theme.goldDim : Theme.accentFill) : Theme.elevated,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableProminentButtonStyle {
    static var pressableProminent: PressableProminentButtonStyle { .init() }
}
