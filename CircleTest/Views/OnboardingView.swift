import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: SupabaseService

    @State private var step = 1
    @State private var username = ""
    @State private var teamName = ""
    @State private var isWorking = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.cBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: CircleSpace.xs) {
                    ForEach(1...2, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Color.cAccent : Color.cBorderChip)
                            .frame(width: i == step ? 28 : 8, height: 4)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: step)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CircleSpace.lg)
                .padding(.top, 72)

                Spacer()

                Group {
                    if step == 1 {
                        stepView(
                            heading: "What should we\ncall you?",
                            subheading: "Your handle in leagues and leaderboards.",
                            fieldPlaceholder: "username",
                            helperText: "3–20 chars · letters, numbers, underscores",
                            text: $username,
                            secure: false,
                            keyboardType: .asciiCapable,
                            autocap: .never,
                            primaryLabel: "Continue →",
                            primaryAction: validateUsername,
                            backAction: nil
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    } else {
                        stepView(
                            heading: "Name your\nteam.",
                            subheading: "What other players see in matchups and standings.",
                            fieldPlaceholder: "e.g. Bullish Bears",
                            helperText: "2–30 characters",
                            text: $teamName,
                            secure: false,
                            keyboardType: .default,
                            autocap: .words,
                            primaryLabel: "Start Playing →",
                            primaryAction: submit,
                            backAction: { withAnimation { step = 1 }; errorMessage = nil }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: step)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, CircleSpace.lg)
        }
    }

    // MARK: Shared step layout

    private func stepView(
        heading: String,
        subheading: String,
        fieldPlaceholder: String,
        helperText: String,
        text: Binding<String>,
        secure: Bool,
        keyboardType: UIKeyboardType,
        autocap: TextInputAutocapitalization,
        primaryLabel: String,
        primaryAction: @escaping () -> Void,
        backAction: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: CircleSpace.xl) {
            // Heading
            VStack(alignment: .leading, spacing: CircleSpace.sm) {
                Text(heading)
                    .font(.cTitle)
                    .foregroundStyle(Color.cTextPrimary)
                Text(subheading)
                    .font(.cBody)
                    .foregroundStyle(Color.cTextSecondary)
            }

            // Field + helper
            VStack(alignment: .leading, spacing: CircleSpace.xs) {
                TextField(fieldPlaceholder, text: text)
                    .font(.cBody)
                    .foregroundStyle(Color.cTextPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(autocap)
                    .keyboardType(keyboardType)
                    .padding(.horizontal, CircleSpace.md)
                    .padding(.vertical, CircleSpace.smPlus)
                    .background(Color.cBgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: CircleRadius.button, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CircleRadius.button, style: .continuous)
                            .stroke(Color.cBorderChip, lineWidth: 1)
                    )

                Text(helperText)
                    .font(.cTiny)
                    .foregroundStyle(Color.cTextTertiary)
            }

            // Error
            if let msg = errorMessage {
                Text(msg)
                    .font(.cMeta)
                    .foregroundStyle(Color.cLoss)
            }

            // Primary CTA
            Button(action: primaryAction) {
                ZStack {
                    RoundedRectangle(cornerRadius: CircleRadius.button, style: .continuous)
                        .fill(Color.cAccent)
                    if isWorking {
                        ProgressView().tint(Color.cTextOnAccent)
                    } else {
                        Text(primaryLabel)
                            .font(.cBodyEmphasis)
                            .foregroundStyle(Color.cTextOnAccent)
                    }
                }
                .frame(height: 44)
            }
            .disabled(isWorking)

            // Back link
            if let backAction {
                Button(action: backAction) {
                    Text("← Back")
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextSecondary)
                }
            }
        }
    }

    // MARK: Validation

    private func validateUsername() {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard (3...20).contains(trimmed.count),
              trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            errorMessage = "3–20 characters: letters, numbers, underscores only."
            return
        }
        username = trimmed
        errorMessage = nil
        withAnimation { step = 2 }
    }

    private func submit() {
        let trimmed = teamName.trimmingCharacters(in: .whitespaces)
        guard (2...30).contains(trimmed.count) else {
            errorMessage = "Team name must be 2–30 characters."
            return
        }
        errorMessage = nil
        isWorking = true
        Task {
            do {
                try await auth.createProfile(username: username, teamName: trimmed)
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SupabaseService())
        .preferredColorScheme(.dark)
}
