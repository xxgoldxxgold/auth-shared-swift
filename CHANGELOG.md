# CHANGELOG

## v2.1.0 — deleteAccount (アプリ個別 opt-out) 追加

非破壊変更:

- `AuthConfig` に `signupSource` / `deleteUserFunctionName` (両方 optional) を追加
- `AuthManager.deleteAccount()` を新設。Edge Function 名は `deleteUserFunctionName` を優先、無ければ `delete-{signupSource}-user`
- 成功時は自動 signOut、失敗時は throw
- `AuthSharedError` に `.deleteAccountNotConfigured` / `.notAuthenticated` を追加

既存 API の breaking change なし。v2.0.x から upgrade する consumer は `AuthConfig(callbackURLScheme:)` のまま変更不要。

モノレポ `xxgoldxxgold/auth-shared` v2.1.0 と同時タグ。

## v2.0.0 — モノレポ構造化に合わせた同時リリース

破壊的変更:

- `AuthManager.init(supabase:)` → `AuthManager.init(supabase:, config: AuthConfig)` に変更
- `AuthConfig(callbackURLScheme:)` が必須パラメータとして新設
- `openAuthURL` の空実装を `ASWebAuthenticationSession` 経由の実装に置き換え (v1 は OAuth が動作しなかった)
- `ASWebAuthenticationPresentationContextProviding` を内部で実装 (consumer 側の追加実装不要)

モノレポ `xxgoldxxgold/auth-shared` の `web` / `reactnative` / `flutter` / `supabase` と同一バージョンで同時リリース。

Product name (`AuthShared`) は v1.0.0 から変更なし。`.product(name: "AuthShared", package: "auth-shared-swift")` は変わらず動作する。

## v1.0.0

初版。`AuthManager` の骨格のみ (OAuth は未実装)。
