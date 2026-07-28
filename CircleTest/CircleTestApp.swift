import SwiftUI

@main
struct CircleTestApp: App {
    @StateObject private var auth = SupabaseService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}

// MARK: - Root gate

struct RootView: View {
    @EnvironmentObject var auth: SupabaseService

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                AuthView()
            } else if auth.profileLoadFailed {
                profileRetryView
            } else if let profile = auth.currentProfile {
                MainAppView(profile: profile, auth: auth)
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: auth.currentProfile == nil)
    }

    private var profileRetryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.cTextTertiary)
            Text("Couldn't load your profile")
                .font(.cBodyEmphasis)
                .foregroundStyle(Color.cTextPrimary)
            Button {
                Task { await auth.loadProfile() }
            } label: {
                Text("Try Again")
                    .font(.cBodyEmphasis)
                    .foregroundStyle(Color.cAccentTileBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cBg.ignoresSafeArea())
    }
}

// MARK: - Main app (owns AppState lifetime)

private struct MainAppView: View {
    @StateObject private var appState: AppState

    init(profile: UserProfile, auth: SupabaseService) {
        _appState = StateObject(wrappedValue: AppState(profile: profile, supabase: auth.client))
    }

    var body: some View {
        ContentView()
            .environmentObject(appState)
    }
}
