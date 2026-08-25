import SwiftUI

@main
struct MyApp: App {
    @State private var auth: AuthManager
    @State private var store: PatientStore

    init() {
        let auth = AuthManager()
        _auth = State(initialValue: auth)
        _store = State(initialValue: PatientStore(client: auth.client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(store)
        }
    }
}

/// Root view that shows the sign-in screen or the patient list depending on
/// authentication state.
struct ContentView: View {
    @Environment(AuthManager.self) private var auth

    @State private var isShowingSplash = true
    @State private var hasAcceptedTerms = false

    var body: some View {
        ZStack {
            if auth.isAuthenticated {
                if hasAcceptedTerms {
                    PatientListView()
                } else {
                    // Signed in but not yet agreed: the app stays blocked
                    // behind the terms until the user accepts.
                    NavigationStack {
                        TermsView {
                            if let email = auth.currentUserEmail {
                                TermsAcceptance.setAccepted(email: email)
                            }
                            hasAcceptedTerms = true
                        }
                    }
                }
            } else {
                AuthView()
            }

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .appTextSize()
        .onChange(of: auth.currentUserEmail, initial: true) { _, email in
            hasAcceptedTerms = email.map(TermsAcceptance.hasAccepted) ?? false
        }
        .task {
            // Keep the splash up briefly so the session can be restored
            // without flashing the sign-in screen.
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.4)) {
                isShowingSplash = false
            }
        }
    }
}

#Preview {
    let auth = AuthManager()
    ContentView()
        .environment(auth)
        .environment(PatientStore(client: auth.client))
}
