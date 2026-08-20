import SwiftUI

/// A centered spinner on a material card that fades and scales in, shown
/// over a form while it is saving. Replaces bare `ProgressView` overlays so
/// the busy state appears smoothly instead of popping in.
private struct BusyOverlay: ViewModifier {
    let isBusy: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(22)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isBusy)
    }
}

extension View {
    /// Shows an animated busy spinner over the view while `isBusy` is true.
    func busyOverlay(_ isBusy: Bool) -> some View {
        modifier(BusyOverlay(isBusy: isBusy))
    }
}
