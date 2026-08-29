import SwiftUI

/// Sign-in / sign-up screen using email and password.
struct AuthView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "התחבר/י"
        case signUp = "הרשמ/י"
    }

    @Environment(AuthManager.self) private var auth

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    /// When set, the screen shows the "check your email" state for this
    /// address instead of the sign-in/sign-up form.
    @State private var verificationEmail: String?

    /// Sign-up requires a minimum length and a matching confirmation;
    /// sign-in accepts whatever the account was created with.
    private var isPasswordValidForSubmit: Bool {
        mode == .signIn || (password.count >= 6 && password == confirmPassword)
    }
    /// Blocks repeated resend taps for a short cooldown.
    @State private var isResendBlocked = false

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        if verificationEmail != nil {
                            verificationCard
                        } else {
                            card
                        }
                    }
                    .padding(24)
                    .padding(.top, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Gold — the app color — carries the atmosphere on screens
                // that belong to no single patient.
                .patientAtmosphere(Theme.gold)
            }
            .contentShape(Rectangle())
            .dismissesKeyboardOnTap()
            .animation(.easeInOut(duration: 0.2), value: verificationEmail)
        }
    }

    private var background: some View {
        Theme.base
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .shadow(color: Theme.accentFill.opacity(0.35), radius: 16, y: 10)

            Text(L10n.appTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textBright)

            if verificationEmail == nil {
                Text(mode == .signIn
                     ? L10n.authWelcomeSignIn
                     : L10n.authWelcomeSignUp)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The post-sign-up "check your email" state: where the link was sent,
    /// a resend action, and the way back to sign-in.
    private var verificationCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 36))
                .foregroundStyle(Theme.gold)
                .padding(20)
                .background(Theme.goldGhost, in: Circle())

            Text(L10n.verifyEmailTitle)
                .font(.title3.bold())

            Text(L10n.verifyEmailMessage(email: verificationEmail ?? ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                message(errorMessage, systemImage: "exclamationmark.triangle.fill", color: Theme.error)
            }

            if let infoMessage {
                message(infoMessage, systemImage: "checkmark.circle.fill", color: Theme.positive)
            }

            Button(action: resendVerification) {
                Group {
                    if isWorking {
                        ProgressView()
                            .tint(Theme.textOnAccent)
                    } else {
                        Text(L10n.resendVerificationAction)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.pressableProminent)
            .disabled(isWorking || isResendBlocked)

            Button(L10n.backToSignInAction) {
                verificationEmail = nil
                errorMessage = nil
                infoMessage = nil
                mode = .signIn
            }
            .font(.footnote)
            .disabled(isWorking)
        }
        .padding(20)
        .themedCard(cornerRadius: 28)
        .overlay(RoundedRectangle(cornerRadius: 28)
            .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 12)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: infoMessage)
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
                if mode == .signUp {
                    inputRow(systemImage: "lock") { confirmPasswordField }
                }
            }

            if mode == .signUp, !password.isEmpty, password.count < 6 {
                message(L10n.passwordTooShortError,
                        systemImage: "exclamationmark.triangle.fill", color: Theme.error)
            }

            // Only flagged once the confirmation is as long as the password,
            // so it doesn't nag on every keystroke.
            if mode == .signUp, !confirmPassword.isEmpty,
               confirmPassword.count >= password.count, password != confirmPassword {
                message(L10n.passwordsDontMatchError,
                        systemImage: "exclamationmark.triangle.fill", color: Theme.error)
            }

            if let errorMessage {
                message(errorMessage, systemImage: "exclamationmark.triangle.fill", color: Theme.error)
            }

            // A failed email-verification deep link surfaces here, since the
            // sign-in screen is where the user lands afterwards.
            if let callbackError = auth.callbackError {
                message(callbackError, systemImage: "exclamationmark.triangle.fill", color: Theme.error)
            }

            if let infoMessage {
                message(infoMessage, systemImage: "checkmark.circle.fill", color: Theme.positive)
            }

            Button(action: submit) {
                Group {
                    if isWorking {
                        ProgressView()
                            .tint(Theme.textOnAccent)
                    } else {
                        Text(mode.rawValue)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.pressableProminent)
            .disabled(email.isEmpty || password.isEmpty || !isPasswordValidForSubmit || isWorking)

            if mode == .signIn {
                Button(L10n.forgotPasswordAction, action: forgotPassword)
                    .font(.footnote)
                    .disabled(isWorking)
            }
        }
        .padding(20)
        .themedCard(cornerRadius: 28)
        .overlay(RoundedRectangle(cornerRadius: 28)
            .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 12)
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .animation(.easeInOut(duration: 0.2), value: infoMessage)
        .onChange(of: mode) { confirmPassword = "" }
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
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
    }

    private func message(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var emailField: some View {
        let field = TextField(L10n.emailPlaceholder, text: $email, prompt: Text(""))
            .stablePlaceholder(L10n.emailPlaceholder, isShown: email.isEmpty)
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
        let field = SecureField(L10n.passwordPlaceholder, text: $password, prompt: Text(""))
            .stablePlaceholder(L10n.passwordPlaceholder, isShown: password.isEmpty)
        #if os(iOS)
        return field
            .textContentType(mode == .signUp ? .newPassword : .password)
        #else
        return field
        #endif
    }

    private var confirmPasswordField: some View {
        let field = SecureField(L10n.confirmPasswordPlaceholder, text: $confirmPassword, prompt: Text(""))
            .stablePlaceholder(L10n.confirmPasswordPlaceholder, isShown: confirmPassword.isEmpty)
        #if os(iOS)
        return field
            .textContentType(.newPassword)
        #else
        return field
        #endif
    }

    private func submit() {
        guard isPasswordValidForSubmit else { return }
        authenticate {
            switch mode {
            case .signIn:
                try await auth.signIn(email: email, password: password)
                return nil
            case .signUp:
                let needsConfirmation = try await auth.signUp(email: email, password: password)
                if needsConfirmation {
                    // Signed up but not signed in: switch to the dedicated
                    // "check your email" state until the link is opened.
                    verificationEmail = email
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                }
                return nil
            }
        }
    }

    /// Re-sends the confirmation email, then blocks the button briefly so
    /// repeated taps don't hammer the rate limit.
    private func resendVerification() {
        guard let verificationEmail else { return }
        authenticate {
            try await auth.resendSignUpConfirmation(email: verificationEmail)
            isResendBlocked = true
            Task {
                try? await Task.sleep(for: .seconds(30))
                isResendBlocked = false
            }
            return L10n.verificationResentMessage
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

/// Presented after a password-recovery link signs the user in, so the reset
/// actually ends with a new password. The recovery session only proves
/// access to the email inbox, so leaving without setting a password signs
/// the user out instead of letting the temporary session become a login.
struct NewPasswordView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PatientStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    /// True once both entries are long enough and identical.
    private var passwordsMatch: Bool {
        password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(L10n.passwordPlaceholder, text: $password)
                        .textContentType(.newPassword)
                        .listRowBackground(groupBorderedRow(.first, accent: Theme.gold))
                    SecureField(L10n.confirmPasswordPlaceholder, text: $confirmPassword)
                        .textContentType(.newPassword)
                        .listRowBackground(groupBorderedRow(.last, accent: Theme.gold))
                } footer: {
                    Text(L10n.newPasswordMessage)
                }

                // Only flagged once the confirmation is as long as the
                // password, so it doesn't nag on every keystroke.
                if !confirmPassword.isEmpty, confirmPassword.count >= password.count,
                   password != confirmPassword {
                    Section {
                        Text(L10n.passwordsDontMatchError)
                            .font(.footnote)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(groupBorderedRow(.only, accent: Theme.gold))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(groupBorderedRow(.only, accent: Theme.gold))
                }
            }
            .patientAtmosphere(Theme.gold)
            .themedScreen()
            .navigationTitle(L10n.newPasswordTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { cancelRecovery() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { save() }
                        .disabled(!passwordsMatch || isWorking)
                }
            }
            .busyOverlay(isWorking)
        }
        // Swiping the sheet away would leave the recovery session signed in
        // without a new password; the only ways out are Save and Cancel.
        .interactiveDismissDisabled()
        .appTextSize()
    }

    /// Abandoning the reset discards the temporary recovery session — the
    /// link only proved inbox access, not a completed sign-in.
    private func cancelRecovery() {
        store.clearAllCaches()
        auth.signOut()
        dismiss()
    }

    private func save() {
        guard passwordsMatch else { return }
        errorMessage = nil
        isWorking = true
        Task {
            do {
                try await auth.updatePassword(password)
                dismiss()
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
