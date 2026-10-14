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

/// Google's unmodified SDK logo in a full-width native button. The light
/// branding palette keeps the mark and Hebrew label clear in either app theme.
struct NativeGoogleSignInButton: View {
    @ScaledMetric(relativeTo: .body) private var labelSize = 16.0
    var isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleSignInLogo")
                    .renderingMode(.original)
                    .accessibilityHidden(true)
                Text(L10n.googleSignInAction)
                    .font(.system(size: labelSize, weight: .medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(GoogleSignInButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(L10n.googleSignInAction)
        .accessibilityIdentifier("auth.google")
    }
}

private struct GoogleSignInButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255))
            .background(
                configuration.isPressed ? Color(white: 0.94) : .white,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(red: 116 / 255, green: 119 / 255, blue: 117 / 255), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.55)
    }
}
