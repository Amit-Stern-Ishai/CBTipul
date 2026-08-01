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

    var body: some View {
        if auth.isAuthenticated {
            PatientListView()
        } else {
            AuthView()
        }
    }
}

#Preview {
    let auth = AuthManager()
    ContentView()
        .environment(auth)
        .environment(PatientStore(client: auth.client))
}
