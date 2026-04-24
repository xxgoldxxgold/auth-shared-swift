import Foundation

/// AuthManager の初期化に必要な設定。
///
/// - `callbackURLScheme`: ASWebAuthenticationSession に渡す scheme。
///   Supabase の Redirect URLs に登録されている URL の scheme 部分 (例: `com.example.yourapp`)。
///   `Info.plist` の `CFBundleURLTypes` にも同じ scheme を登録しておくこと。
/// - `signupSource`: signup_source 識別子 (サービス名)。deleteAccount のデフォルト EF 名解決に使う。
/// - `deleteUserFunctionName`: 退会用 Edge Function 名。省略時 `delete-{signupSource}-user`。
public struct AuthConfig {
    public let callbackURLScheme: String
    public let signupSource: String?
    public let deleteUserFunctionName: String?

    public init(
        callbackURLScheme: String,
        signupSource: String? = nil,
        deleteUserFunctionName: String? = nil
    ) {
        self.callbackURLScheme = callbackURLScheme
        self.signupSource = signupSource
        self.deleteUserFunctionName = deleteUserFunctionName
    }
}
