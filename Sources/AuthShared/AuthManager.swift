import Foundation
import Supabase
import AuthenticationServices
import UIKit

/// 全サービス共通の認証マネージャー
/// Supabase認証 + Google/Apple OAuth + shared_profiles連携
@MainActor
public class AuthManager: NSObject, ObservableObject {
    @Published public var user: User?
    @Published public var displayName: String = ""
    @Published public var avatarUrl: String = ""
    @Published public var isLoading: Bool = true
    @Published public var lastOAuthError: Error?

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
        lastOAuthError = nil
        let errorBox = ErrorBox()
        try await supabase.auth.signInWithOAuth(provider: .google) { [weak self] url in
            guard let self else { return }
            do {
                try await self.openAuthURL(url)
            } catch {
                print("[auth-shared] OAuth error (google): \(error.localizedDescription)")
                await errorBox.set(error)
            }
        }
        if let captured = await errorBox.value {
            lastOAuthError = captured
            throw captured
        }
    }

    public func signInWithApple() async throws {
        lastOAuthError = nil
        let errorBox = ErrorBox()
        try await supabase.auth.signInWithOAuth(provider: .apple) { [weak self] url in
            guard let self else { return }
            do {
                try await self.openAuthURL(url)
            } catch {
                print("[auth-shared] OAuth error (apple): \(error.localizedDescription)")
                await errorBox.set(error)
            }
        }
        if let captured = await errorBox.value {
            lastOAuthError = captured
            throw captured
        }
    }

    private func openAuthURL(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: config.callbackURLScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error {
                        if let asError = error as? ASWebAuthenticationSessionError,
                           asError.code == .canceledLogin {
                            continuation.resume()
                            return
                        }
                        print("[auth-shared] ASWebAuthenticationSession error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL else {
                        let err = AuthSharedError.missingCallbackURL
                        print("[auth-shared] ASWebAuthenticationSession returned no callback URL")
                        continuation.resume(throwing: err)
                        return
                    }
                    do {
                        try await self?.supabase.auth.session(from: callbackURL)
                        continuation.resume()
                    } catch {
                        print("[auth-shared] supabase.auth.session(from:) failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
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

    // MARK: - Delete Account (per-app opt-out)

    /// このアプリだけの退会。対応する Edge Function を呼んだ後に signOut する。
    /// `AuthConfig.deleteUserFunctionName` 指定があれば優先、無ければ `delete-{signupSource}-user`。
    /// 失敗時は throw (signOut しない)。auth.users は触らない。
    public func deleteAccount() async throws {
        let fnName: String
        if let explicit = config.deleteUserFunctionName {
            fnName = explicit
        } else if let source = config.signupSource {
            fnName = "delete-\(source)-user"
        } else {
            throw AuthSharedError.deleteAccountNotConfigured
        }
        guard (try? await supabase.auth.session) != nil else {
            throw AuthSharedError.notAuthenticated
        }
        try await supabase.functions.invoke(fnName)
        try await signOut()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    public nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? scenes.compactMap { $0 as? UIWindowScene }.first
        return windowScene?.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - Supporting types

public enum AuthSharedError: Error, LocalizedError {
    case missingCallbackURL
    case deleteAccountNotConfigured
    case notAuthenticated

    public var errorDescription: String? {
        switch self {
        case .missingCallbackURL:
            return "OAuth finished without a callback URL"
        case .deleteAccountNotConfigured:
            return "deleteAccount requires AuthConfig.signupSource or AuthConfig.deleteUserFunctionName"
        case .notAuthenticated:
            return "deleteAccount requires an active session"
        }
    }
}

private actor ErrorBox {
    private(set) var value: Error?
    func set(_ error: Error) { value = error }
}
