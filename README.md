# auth-shared-swift

iOS / Swift 用の共通認証マネージャー。Supabase + Google/Apple OAuth + メール認証 + 共通プロフィール (`shared_profiles`)。

本リポジトリは `xxgoldxxgold/auth-shared` モノレポの **Swift 版** だが、Swift Package Manager の制約 (1 リポ 1 `Package.swift`) により別リポジトリで維持されている。モノレポと**同一バージョンで同時タグ**を切る運用。

## インストール

consumer の `Package.swift` の `dependencies` に:

- `.package(url: "https://github.com/xxgoldxxgold/auth-shared-swift.git", from: "2.0.0")`

target の `dependencies` に:

- `.product(name: "AuthShared", package: "auth-shared-swift")`

## セットアップ

### 1. URL scheme の決定と登録

サービス固有の custom scheme (例: `com.example.yourapp`) を決める。`Info.plist` の `CFBundleURLTypes` に登録:

- `CFBundleURLSchemes`: [`com.example.yourapp`]
- `CFBundleURLName`: (任意の識別子)

### 2. Supabase Redirect URLs に登録

Supabase Dashboard → Auth → URL Configuration → Redirect URLs に、`com.example.yourapp://login-callback` のような URL を追加。scheme 部分が 1 と一致すること。

### 3. AuthManager を生成

`SwiftUI` の `App` もしくは ルート View で:

- `supabase`: `SupabaseClient(supabaseURL: ..., supabaseKey: ...)` で作ったクライアント
- `config`: `AuthConfig(callbackURLScheme: "com.example.yourapp")` を渡す (scheme 部分のみ、`://...` は含めない)

`@StateObject` で保持し、`.environmentObject(authManager)` で下層に配る。

## 提供 API

- `AuthManager(supabase: SupabaseClient, config: AuthConfig)`
- `@Published` プロパティ: `user`, `displayName`, `avatarUrl`, `isLoading`
- 非同期メソッド: `signInWithGoogle()`, `signInWithApple()`, `signInWithEmail(email:password:)`, `signUpWithEmail(email:password:name:)`, `resetPassword(email:)`, `signOut()`, `loadProfile(userId:)`

## v1.0.0 からの破壊的変更

- `AuthManager(supabase:)` → `AuthManager(supabase:, config: AuthConfig)` に変更。`AuthConfig(callbackURLScheme:)` が必須化。
- `openAuthURL` を `ASWebAuthenticationSession` で実装 (v1 では空だった)。
- `ASWebAuthenticationPresentationContextProviding` を内部実装。consumer 側での追加実装は不要。

## 同時リリース

モノレポ `xxgoldxxgold/auth-shared` の `web` / `reactnative` / `flutter` / `supabase` と同一バージョン (v2.0.0) で同時タグ。
