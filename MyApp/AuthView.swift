import SwiftUI

/// Sign-in / sign-up screen offering email, Google, and Facebook.
struct AuthView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    @Environment(AuthManager.self) private var auth

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)

                Text("Therapy Notes")
                    .font(.largeTitle.bold())

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    emailField
                    passwordField
                }
                .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                Button(action: submit) {
                    Text(mode.rawValue)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || password.isEmpty || isWorking)

                labelledDivider

                VStack(spacing: 12) {
                    providerButton("Continue with Google", systemImage: "globe", provider: .google)
                    providerButton("Continue with Facebook", systemImage: "f.cursive.circle", provider: .facebook)
                }

                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .dismissesKeyboardOnTap()
            .overlay {
                if isWorking { ProgressView() }
            }
        }
    }

    private var emailField: some View {
        let field = TextField("Email", text: $email)
            .autocorrectionDisabled()
        #if os(iOS)
        return field
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        return field
        #endif
    }

    private var passwordField: some View {
        let field = SecureField("Password", text: $password)
        #if os(iOS)
        return field
            .textContentType(mode == .signUp ? .newPassword : .password)
        #else
        return field
        #endif
    }

    private var labelledDivider: some View {
        HStack {
            VStack { Divider() }
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack { Divider() }
        }
    }

    private func providerButton(_ title: String, systemImage: String, provider: AuthProvider) -> some View {
        Button {
            authenticate {
                try await auth.signIn(with: provider)
                return nil
            }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isWorking)
    }

    private func submit() {
        authenticate {
            switch mode {
            case .signIn:
                try await auth.signIn(email: email, password: password)
                return nil
            case .signUp:
                let needsConfirmation = try await auth.signUp(email: email, password: password)
                return needsConfirmation
                    ? "Account created. Check your email to confirm your address, then sign in."
                    : nil
            }
        }
    }

    /// Runs an async auth action, surfacing errors and toggling the busy state.
    /// The action may return an informational message to display on success.
    private func authenticate(_ action: @escaping () async throws -> String?) {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            do {
                infoMessage = try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthManager())
}
