import Foundation

/// AuthManager の初期化に必要な設定。
///
/// - `callbackURLScheme`: ASWebAuthenticationSession に渡す scheme。
///   Supabase の Redirect URLs に登録されている URL の scheme 部分 (例: `com.example.yourapp`)。
///   `Info.plist` の `CFBundleURLTypes` にも同じ scheme を登録しておくこと。
public struct AuthConfig {
    public let callbackURLScheme: String

    public init(callbackURLScheme: String) {
        self.callbackURLScheme = callbackURLScheme
    }
}
