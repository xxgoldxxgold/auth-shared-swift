import Foundation
import Supabase
import AuthenticationServices

/// 全サービス共通の認証マネージャー
/// Supabase認証 + Google/Apple OAuth + shared_profiles自動作成
@MainActor
public class AuthManager: ObservableObject {
    @Published public var user: User?
    @Published public var displayName: String = ""
    @Published public var avatarUrl: String = ""
    @Published public var isLoading: Bool = true

    private let supabase: SupabaseClient

    public init(supabase: SupabaseClient) {
        self.supabase = supabase
        Task { await initialize() }
    }

    private func initialize() async {
        do {
            let session = try await supabase.auth.session
            user = session.user
            await loadProfile(userId: session.user.id)
        } catch {
            user = nil
        }
        isLoading = false
    }

    // MARK: - Profile

    public func loadProfile(userId: UUID) async {
        do {
            struct Profile: Decodable {
                let display_name: String?
                let avatar_url: String?
            }
            let profile: Profile = try await supabase
                .from("shared_profiles")
                .select("display_name, avatar_url")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            displayName = profile.display_name ?? ""
            avatarUrl = profile.avatar_url ?? ""
        } catch {
            displayName = ""
            avatarUrl = ""
        }
    }

    // MARK: - Email Auth

    public func signInWithEmail(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
        if let userId = try? await supabase.auth.session.user.id {
            await loadProfile(userId: userId)
        }
    }

    public func signUpWithEmail(email: String, password: String, name: String? = nil) async throws {
        try await supabase.auth.signUp(
            email: email,
            password: password,
            data: name != nil ? ["display_name": .string(name!)] : nil
        )
    }

    public func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    // MARK: - OAuth

    public func signInWithGoogle() async throws {
        try await supabase.auth.signInWithOAuth(provider: .google) { url in
            // URLを開く処理（ASWebAuthenticationSessionで実装）
            await self.openAuthURL(url)
        }
    }

    public func signInWithApple() async throws {
        try await supabase.auth.signInWithOAuth(provider: .apple) { url in
            await self.openAuthURL(url)
        }
    }

    private func openAuthURL(_ url: URL) async {
        // ASWebAuthenticationSession等で実装
        // サービス側で上書き可能
    }

    // MARK: - Sign Out

    public func signOut() async throws {
        try await supabase.auth.signOut()
        user = nil
        displayName = ""
        avatarUrl = ""
    }
}
