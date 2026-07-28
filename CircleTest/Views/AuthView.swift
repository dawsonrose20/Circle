import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: SupabaseService

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.cBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CircleSpace.xl) {
                    Spacer().frame(height: CircleSpace.xxxl)

                    // Brand mark
                    VStack(spacing: CircleSpace.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.cAccent)
                        Text("Circle")
                            .font(.cTitleSub)
                            .foregroundStyle(Color.cTextPrimary)
                        Text("Fantasy Stock Trading")
                            .font(.cMeta)
                            .foregroundStyle(Color.cTextSecondary)
                    }

                    // Form card
                    VStack(spacing: CircleSpace.md) {
                        inputField("Email address", text: $email, secure: false)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        inputField("Password", text: $password, secure: true)

                        if isSignUp {
                            inputField("Confirm password", text: $confirmPassword, secure: true)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let msg = errorMessage {
                            Text(msg)
                                .font(.cMeta)
                                .foregroundStyle(Color.cLoss)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Submit button
                        Button(action: submit) {
                            ZStack {
                                RoundedRectangle(cornerRadius: CircleRadius.button, style: .continuous)
                                    .fill(Color.cAccent)
                                if isWorking {
                                    ProgressView().tint(Color.cTextOnAccent)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.cBodyEmphasis)
                                        .foregroundStyle(Color.cTextOnAccent)
                                }
                            }
                            .frame(height: 44)
                        }
                        .disabled(isWorking)
                    }
                    .padding(CircleSpace.lg)
                    .background(Color.cBgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panelLarge, style: .continuous))

                    // Sign in / sign up toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isSignUp.toggle() }
                        errorMessage = nil
                        password = ""
                        confirmPassword = ""
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "No account yet? Create one")
                            .font(.cMeta)
                            .foregroundStyle(Color.cAccent)
                    }

#if DEBUG
                    // Dev bypass — not compiled into release builds
                    Button { auth.bypassSignIn() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 11))
                            Text("Skip Sign In (Dev)")
                                .font(.cMeta)
                        }
                        .foregroundStyle(Color.cTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.cBgPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.cBorderChip, lineWidth: 1)
                        )
                    }
#endif

                    Spacer().frame(height: CircleSpace.xxxl)
                }
                .padding(.horizontal, CircleSpace.lg)
            }
        }
    }

    // MARK: Shared field style

    @ViewBuilder
    private func inputField(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        let base = secure
            ? AnyView(SecureField(placeholder, text: text))
            : AnyView(TextField(placeholder, text: text))

        base
            .font(.cBody)
            .foregroundStyle(Color.cTextPrimary)
            .padding(.horizontal, CircleSpace.md)
            .padding(.vertical, CircleSpace.smPlus)
            .background(Color.cBg)
            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CircleRadius.button, style: .continuous)
                    .stroke(Color.cBorderChip, lineWidth: 1)
            )
    }

    // MARK: Submit

    private func submit() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        if isSignUp, password != confirmPassword {
            errorMessage = "Passwords don't match."
            return
        }
        errorMessage = nil
        isWorking = true
        Task {
            do {
                if isSignUp {
                    try await auth.signUp(email: email, password: password)
                } else {
                    try await auth.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(SupabaseService())
        .preferredColorScheme(.dark)
}
