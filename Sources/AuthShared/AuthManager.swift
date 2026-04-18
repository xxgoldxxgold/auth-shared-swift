import Foundation
import Supabase
import AuthenticationServices

/// 全サービス共通の認証マネージャー
/// Supabase認証 + Google/Apple OAuth + shared_profiles連携
@MainActor
public class AuthManager: NSObject, ObservableObject {
    @Published public var user: User?
    @Published public var displayName: String = ""
    @Published public var avatarUrl: String = ""
    @Published public var isLoading: Bool = true

    private let supabase: SupabaseClient
    private let config: AuthConfig

    public init(supabase: SupabaseClient, config: AuthConfig) {
        self.supabase = supabase
        self.config = config
        super.init()
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
        try await supabase.auth.signInWithOAuth(provider: .google) { [weak self] url in
            guard let self else { return }
            await self.openAuthURL(url)
        }
    }

    public func signInWithApple() async throws {
        try await supabase.auth.signInWithOAuth(provider: .apple) { [weak self] url in
            guard let self else { return }
            await self.openAuthURL(url)
        }
    }

    private func openAuthURL(_ url: URL) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: config.callbackURLScheme
            ) { [weak self] callbackURL, _ in
                Task { @MainActor in
                    if let callbackURL {
                        do {
                            try await self?.supabase.auth.session(from: callbackURL)
                        } catch {
                            // セッション確立失敗は無視 (呼び出し元の observer で検知)
                        }
                    }
                    continuation.resume()
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            _ = session.start()
        }
    }

    // MARK: - Sign Out

    public func signOut() async throws {
        try await supabase.auth.signOut()
        user = nil
        displayName = ""
        avatarUrl = ""
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    public nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // 最前面の key window を返す
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? scenes.compactMap { $0 as? UIWindowScene }.first
        return windowScene?.keyWindow ?? ASPresentationAnchor()
    }
}
