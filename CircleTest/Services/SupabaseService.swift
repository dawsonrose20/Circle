import Combine
import Foundation
import Supabase

// MARK: - UserProfile

struct UserProfile: Codable, Sendable, Identifiable {
    let id: UUID
    let username: String
    let teamName: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case teamName = "team_name"
    }
}

// MARK: - SupabaseService

@MainActor
final class SupabaseService: ObservableObject {

    let client = SupabaseClient(
        supabaseURL: URL(string: "https://zoiwopnvwvrcxdkrgadx.supabase.co")!,
        supabaseKey: "sb_publishable_LropT1WxTv3LYgdqn9V8DQ_Gnmg3kdh"
    )

    @Published var isAuthenticated = false
    @Published var currentProfile: UserProfile? = nil
    @Published var currentUserID: UUID? = nil
    @Published var profileLoadFailed = false

    init() {
        Task { await observeAuthState() }
    }

    // MARK: Auth state

    private func observeAuthState() async {
        for await (_, session) in client.auth.authStateChanges {
            isAuthenticated = session != nil
            currentUserID = session?.user.id
            if session != nil {
                await loadProfile()
            } else {
                currentProfile = nil
                profileLoadFailed = false
            }
        }
    }

    // MARK: Profile

    func loadProfile() async {
        guard let userID = currentUserID else { return }
        profileLoadFailed = false
        do {
            let profiles: [UserProfile] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .execute()
                .value
            currentProfile = profiles.first
        } catch {
            profileLoadFailed = true
        }
    }

    func updateProfile(username: String, teamName: String) async throws {
        guard let userID = currentUserID else { return }
        let profile = UserProfile(id: userID, username: username, teamName: teamName)
        try await client.from("profiles").upsert(profile).execute()
        currentProfile = profile
    }

    func createProfile(username: String, teamName: String) async throws {
        guard let userID = currentUserID else { return }
        let profile = UserProfile(id: userID, username: username, teamName: teamName)
        try await client
            .from("profiles")
            .upsert(profile)
            .execute()
        currentProfile = profile
    }

    // MARK: Auth actions

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentProfile = nil
    }

    // MARK: Dev bypass (DEBUG only — stripped from release builds)

#if DEBUG
    /// Fakes an authenticated user without creating a Supabase session. Every
    /// screen works because the app's state is local, but anything that needs a
    /// real access token does not: `refreshPrices()` calls `auth.session`, which
    /// throws, so live prices never load and the draft-pool placeholders persist.
    func bypassSignIn() {
        let devID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        currentUserID = devID
        currentProfile = UserProfile(id: devID, username: "devuser", teamName: "Dev Team")
        profileLoadFailed = false
        isAuthenticated = true
        print("""
        ⚠️ bypassSignIn: no real Supabase session was created. Market data will \
        NOT load and every price stays at its draft-pool placeholder. Sign in \
        with a real account to fetch live prices.
        """)
    }
#endif
}
