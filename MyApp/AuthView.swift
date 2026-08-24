import SwiftUI

/// Sign-in / sign-up screen using email and password.
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
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        card
                    }
                    .padding(24)
                    .padding(.top, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .contentShape(Rectangle())
            .dismissesKeyboardOnTap()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.18),
                Color.accentColor.opacity(0.05),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 26)
                )
                .shadow(color: Color.accentColor.opacity(0.35), radius: 16, y: 10)

            Text(L10n.appTitle)
                .font(.largeTitle.bold())

            Text(mode == .signIn
                 ? L10n.authWelcomeSignIn
                 : L10n.authWelcomeSignUp)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Picker(L10n.authModePickerTitle, selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                inputRow(systemImage: "envelope") { emailField }
                inputRow(systemImage: "lock") { passwordField }
            }

            if let errorMessage {
                message(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
            }

            if let infoMessage {
                message(infoMessage, systemImage: "checkmark.circle.fill", color: .green)
            }

            Button(action: submit) {
                Group {
                    if isWorking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(mode.rawValue)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.pressableProminent)
            .disabled(email.isEmpty || password.isEmpty || isWorking)

            if mode == .signIn {
                Button(L10n.forgotPasswordAction, action: forgotPassword)
                    .font(.footnote)
                    .disabled(isWorking)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 12)
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: infoMessage)
    }

    private func inputRow(systemImage: String, @ViewBuilder field: () -> some View) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            field()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func message(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var emailField: some View {
        let field = TextField(L10n.emailPlaceholder, text: $email)
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
        let field = SecureField(L10n.passwordPlaceholder, text: $password)
        #if os(iOS)
        return field
            .textContentType(mode == .signUp ? .newPassword : .password)
        #else
        return field
        #endif
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
                    ? L10n.accountCreatedMessage
                    : nil
            }
        }
    }

    private func forgotPassword() {
        guard !email.isEmpty else {
            errorMessage = L10n.enterEmailFirstMessage
            return
        }
        authenticate {
            try await auth.resetPassword(email: email)
            return L10n.passwordResetSentMessage
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
