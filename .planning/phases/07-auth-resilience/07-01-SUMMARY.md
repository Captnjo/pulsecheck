---
phase: 07-auth-resilience
plan: 01
subsystem: auth
tags: [token-refresh, keychain, swift-actor, oauth, error-handling]
dependency_graph:
  requires: []
  provides: [TokenRefreshService, shadow-keychain-crud, oauth-token-response-model, 403-scope-loss-detection]
  affects: [KeychainService, AnthropicAPIClient, AppError]
tech_stack:
  added: []
  patterns: [swift-actor-task-dedup, keychain-upsert-secitemadd-secitemupdate, oauth-wire-format-mapping]
key_files:
  created:
    - PulseCheck/Services/TokenRefreshService.swift
  modified:
    - PulseCheck/Models/AppError.swift
    - PulseCheck/Services/KeychainService.swift
    - PulseCheck/Services/AnthropicAPIClient.swift
    - PulseCheck.xcodeproj/project.pbxproj
decisions:
  - defer-refreshTask-nil-inside-task-closure: defer { refreshTask = nil } placed inside Task closure so concurrent callers holding a reference continue receiving the result after the property is cleared
  - shadow-account-pulsecheck: kSecAttrAccount set to "pulsecheck" for shadow item to disambiguate from other PulseCheck-claude-credentials items on multi-user systems
  - scope-preservation: OAuthTokenResponse.toCredentials(preservingScopes:) carries scopes forward from pre-refresh credentials since OAuth refresh response omits scopes field
metrics:
  duration_minutes: 8
  tasks_completed: 2
  tasks_total: 2
  files_changed: 5
  completed_date: "2026-04-02"
---

# Phase 07 Plan 01: Token Refresh Infrastructure Summary

**One-liner:** Swift actor `TokenRefreshService` with Task-based dedup, shadow Keychain CRUD for PulseCheck-claude-credentials, and 403 scope-loss detection routing to apiUnauthorized.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Add AppError cases and make ClaudeOAuthCredentials Codable | f902b4e | AppError.swift, KeychainService.swift |
| 2 | Shadow Keychain CRUD, TokenRefreshService actor, 403 detection | d52eec4 | KeychainService.swift, TokenRefreshService.swift, AnthropicAPIClient.swift, project.pbxproj |

## What Was Built

**TokenRefreshService actor** (`PulseCheck/Services/TokenRefreshService.swift`):
- Swift actor with `refreshTask: Task<ClaudeOAuthCredentials, Error>?` property
- `refresh(using:preservingScopes:)` — creates Task only if `refreshTask == nil`; all concurrent callers await the same Task instance
- `performRefresh(refreshToken:scopes:)` — POSTs to `https://console.anthropic.com/v1/oauth/token` with `application/x-www-form-urlencoded`, decodes `OAuthTokenResponse`, maps to `ClaudeOAuthCredentials`
- `OAuthTokenResponse` Decodable struct maps snake_case OAuth wire fields (`access_token`, `refresh_token`, `expires_in`) to Swift camelCase
- `toCredentials(preservingScopes:)` converts `expires_in` (seconds) to `expiresAt` (milliseconds) and preserves scopes from pre-refresh credentials

**Shadow Keychain CRUD** (`PulseCheck/Services/KeychainService.swift`):
- `shadowServiceName = "PulseCheck-claude-credentials"` — PulseCheck-owned item, never Claude Code's item
- `readShadowCredentials()` — queries with `kSecAttrAccount: "pulsecheck"`, decodes via `KeychainWrapper`
- `writeShadowCredentials(_:)` — encodes `KeychainWrapper` via `JSONEncoder`, upserts via `SecItemAdd` + `SecItemUpdate` on `errSecDuplicateItem`
- `deleteShadowCredentials()` — deletes shadow item, ignores `errSecItemNotFound`
- `ClaudeOAuthCredentials` and `KeychainWrapper` changed from `Decodable` to `Codable` to support encoding

**AppError additions** (`PulseCheck/Models/AppError.swift`):
- `tokenRefreshFailed(Int, String)` — HTTP status code + body snippet
- `keychainWriteFailed(OSStatus)` — with matching `errorDescription` entries

**403 scope-loss detection** (`PulseCheck/Services/AnthropicAPIClient.swift`):
- New `case 403:` branch before `default:` in status code switch
- Inspects body for `"scope"` or `"user:profile"` keywords
- Routes to `.apiUnauthorized` (same recovery path as 401) with a warning log

## Decisions Made

- **`defer { refreshTask = nil }` inside Task closure** — not outside. Outer defer would clear the property before awaiting the value, breaking concurrent callers. Inner defer clears after Task completes while callers with held references still receive the result.
- **`kSecAttrAccount: "pulsecheck"` on shadow item** — added for precision on multi-user systems; omitted from primary read per existing pattern.
- **Scope preservation in OAuthTokenResponse** — OAuth refresh response does not include scopes. `toCredentials(preservingScopes:)` carries them forward to prevent 403 scope-loss false positives.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all methods are fully implemented. Plan 02 will wire `TokenRefreshService` and shadow Keychain reads into `CredentialsService` and `UsageStore`.

## Self-Check: PASSED

- PulseCheck/Services/TokenRefreshService.swift: FOUND
- PulseCheck/Services/KeychainService.swift: FOUND
- PulseCheck/Models/AppError.swift: FOUND
- PulseCheck/Services/AnthropicAPIClient.swift: FOUND
- Commit f902b4e: FOUND
- Commit d52eec4: FOUND
- xcodebuild BUILD SUCCEEDED
