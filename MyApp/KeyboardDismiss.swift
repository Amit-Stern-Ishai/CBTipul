import SwiftUI

#if canImport(UIKit)
import UIKit

extension View {
    /// Closes the keyboard when tapping anywhere outside a text input.
    ///
    /// Installs a single window-level tap recognizer that only observes
    /// touches (`cancelsTouchesInView = false`), so buttons, list rows, and
    /// navigation links are never affected. Taps inside text fields are
    /// ignored so the cursor can be repositioned normally.
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller())
    }
}

/// Zero-size helper view whose only job is to install the window recognizer
/// once it lands in a window.
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window {
                KeyboardDismissGesture.shared.install(on: window)
            }
        }
    }
}

/// The shared window tap recognizer and its delegate.
private final class KeyboardDismissGesture: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGesture()

    private final class DismissTap: UITapGestureRecognizer {}

    func install(on window: UIWindow) {
        guard !(window.gestureRecognizers ?? []).contains(where: { $0 is DismissTap }) else { return }
        let tap = DismissTap(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    /// Ignore taps that land inside a text input so editing taps (moving the
    /// cursor, selecting text) don't close the keyboard.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }
        return true
    }
}

#else

extension View {
    func dismissesKeyboardOnTap() -> some View { self }
}

#endif
