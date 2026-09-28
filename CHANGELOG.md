# Changelog

## 1.4.4 — 2026-09-28

- Fix Claude Code incorrectly showing "not logged in" while the CLI is authenticated. The v1.4.3 duplicate-item query combined `kSecReturnData` with `kSecMatchLimitAll`, which macOS rejects for passwords with `errSecParam` (`-50`).
- Enumerate Keychain references, read each item's data separately, and select the freshest decodable credentials. Skip unreadable or malformed duplicates when another valid item is available.
- Preserve access and decoding errors within the Keychain reader when no item can be used. Diagnostics contain status codes and structural metadata, never credential values.
- Keep Claude Code's refresh tokens untouched; PulseCheck never consumes another CLI's refresh token.

Validation: a clean build and the full 48-test suite passed, including seven new Keychain regression tests. The initial five regression tests failed against the original query before the fix.
