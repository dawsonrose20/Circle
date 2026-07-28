import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var auth: SupabaseService
    @Binding var isPresented: Bool

    @State private var username = ""
    @State private var teamName = ""
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showSignOutConfirm = false

    private var hasChanges: Bool {
        username != (auth.currentProfile?.username ?? "") ||
        teamName != (auth.currentProfile?.teamName ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: — Account

                    sectionLabel("Account")

                    settingsGroup {
                        settingsRow("Username") {
                            TextField("Username", text: $username)
                                .font(.cBodyEmphasis)
                                .foregroundStyle(Color.cTextPrimary)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        CircleDivider(weight: .row).padding(.leading, CircleSpace.lg)
                        settingsRow("Team Name") {
                            TextField("Team Name", text: $teamName)
                                .font(.cBodyEmphasis)
                                .foregroundStyle(Color.cTextPrimary)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                        }
                    }

                    if let error = saveError {
                        Text(error)
                            .font(.cMeta)
                            .foregroundStyle(Color.cLoss)
                            .padding(.horizontal, CircleSpace.lg)
                            .padding(.top, CircleSpace.sm)
                    }

                    if hasChanges {
                        Button {
                            Task { await save() }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(Color.cAccentTileBg)
                                } else {
                                    Text("Save Changes")
                                        .font(.cBodyEmphasis)
                                        .foregroundStyle(Color.cAccentTileBg)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cAccent)
                            .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, CircleSpace.lg)
                        .padding(.top, CircleSpace.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasChanges)
                    }

                    // MARK: — League

                    sectionLabel("League")

                    settingsGroup {
                        settingsRow("Status") {
                            Text(appState.hasLeague ? (appState.isCommissioner ? "Commissioner" : "Member") : "No league")
                                .font(.cBody)
                                .foregroundStyle(Color.cTextSecondary)
                        }
                        if appState.hasLeague {
                            CircleDivider(weight: .row).padding(.leading, CircleSpace.lg)
                            settingsRow("League Name") {
                                Text(appState.league.name)
                                    .font(.cBody)
                                    .foregroundStyle(Color.cTextSecondary)
                            }
                        }
                    }

                    // MARK: — Sign Out

                    sectionLabel("Account Actions")

                    settingsGroup {
                        Button {
                            showSignOutConfirm = true
                        } label: {
                            HStack {
                                Text("Sign Out")
                                    .font(.cBodyEmphasis)
                                    .foregroundStyle(Color.cLoss)
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.cTextTertiary)
                            }
                            .padding(.horizontal, CircleSpace.lg)
                            .padding(.vertical, CircleSpace.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: — Footer

                    Text("Circle v1.0")
                        .font(.cMeta)
                        .foregroundStyle(Color.cTextQuaternary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, CircleSpace.xl)
                        .padding(.bottom, CircleSpace.xxxl)
                }
            }
            .background(Color.cBg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.cBodyEmphasis)
                        .foregroundStyle(Color.cAccent)
                }
            }
            .toolbarBackground(Color.cBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            username = auth.currentProfile?.username ?? ""
            teamName = auth.currentProfile?.teamName ?? ""
        }
        .confirmationDialog(
            "Sign out of Circle?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await auth.signOut()
                    isPresented = false
                }
            }
        }
    }

    // MARK: - Layout helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.cMeta)
            .tracking(CircleTracking.eyebrow)
            .foregroundStyle(Color.cTextTertiary)
            .padding(.horizontal, CircleSpace.lg)
            .padding(.top, CircleSpace.xl)
            .padding(.bottom, CircleSpace.xs)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.cBgPanel)
        .clipShape(RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CircleRadius.panel, style: .continuous)
                .strokeBorder(Color.cBorderChip, lineWidth: CircleStroke.hairline)
        )
        .padding(.horizontal, CircleSpace.lg)
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.cBody)
                .foregroundStyle(Color.cTextPrimary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, CircleSpace.lg)
        .padding(.vertical, CircleSpace.md)
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        saveError = nil
        do {
            try await auth.updateProfile(username: username, teamName: teamName)
            appState.updateCurrentUserProfile(username: username, teamName: teamName)
            isPresented = false
        } catch {
            saveError = "Couldn't save. Check your connection and try again."
        }
        isSaving = false
    }
}

#Preview {
    SettingsView(isPresented: .constant(true))
        .environmentObject(AppState.preview)
        .environmentObject(SupabaseService())
}
