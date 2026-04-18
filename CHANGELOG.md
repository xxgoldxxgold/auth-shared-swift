# CHANGELOG

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
