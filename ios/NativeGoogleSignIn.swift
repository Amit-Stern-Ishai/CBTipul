import GoogleSignIn
import SwiftUI

/// Google is only an identity provider; Supabase remains the session authority.
@MainActor
enum NativeGoogleSignIn {
    static var callbackScheme: String? {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else { return nil }
        return clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    static func handles(_ url: URL) -> Bool {
        guard let scheme = callbackScheme, url.scheme?.lowercased() == scheme.lowercased() else { return false }
        return GIDSignIn.sharedInstance.handle(url)
    }

    static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue
    }

    static func presenter() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var controller = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return nil }
        while let presented = controller.presentedViewController { controller = presented }
        return controller.isBeingDismissed ? nil : controller
    }
}

enum GoogleLoginError: LocalizedError {
    case failed, unavailable
    var errorDescription: String? {
        switch self {
        case .failed: L10n.googleSignInFailed
        case .unavailable: L10n.googleSignInUnavailable
        }
    }
}

/// Keep Google's supplied artwork, dimensions, and styling. The SDK draws its
/// accessibility label as the visible title; set it to the app's Hebrew copy.
struct NativeGoogleSignInButton: UIViewRepresentable {
    var isEnabled: Bool
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = .light
        button.semanticContentAttribute = .forceLeftToRight
        button.addTarget(context.coordinator, action: #selector(Coordinator.signIn), for: .touchUpInside)
        return button
    }
    func updateUIView(_ button: GIDSignInButton, context: Context) {
        context.coordinator.action = action
        button.isEnabled = isEnabled
        button.accessibilityLabel = L10n.googleSignInAction
        button.accessibilityIdentifier = "auth.google"
        button.setNeedsDisplay()
    }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func signIn() { action() }
    }
}
