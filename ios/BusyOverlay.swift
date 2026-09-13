import SwiftUI

/// A centered spinner on a material card that fades and scales in, shown
/// over a form while it is saving. Replaces bare `ProgressView` overlays so
/// the busy state appears smoothly instead of popping in.
private struct BusyOverlay: ViewModifier {
    let isBusy: Bool
    var label: String? = nil

    func body(content: Content) -> some View {
        content
            .overlay {
                if isBusy {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        if let label {
                            Text(label)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(22)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.borderDefault))
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isBusy)
    }
}

extension View {
    /// Shows an animated busy spinner over the view while `isBusy` is true,
    /// optionally with a short status line under the spinner.
    func busyOverlay(_ isBusy: Bool, label: String? = nil) -> some View {
        modifier(BusyOverlay(isBusy: isBusy, label: label))
    }
}
