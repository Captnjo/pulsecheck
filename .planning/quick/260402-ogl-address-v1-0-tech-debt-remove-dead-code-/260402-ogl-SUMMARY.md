---
phase: quick
plan: 260402-ogl
subsystem: credentials, usage-store, planning
tags: [tech-debt, dead-code, cleanup, expired-token, mock-removal]
dependency_graph:
  requires: []
  provides: [clean-credential-pipeline, correct-expired-token-behavior, phase4-verification]
  affects: [CredentialsService, UsageStore, AppError, phase4-artifacts]
tech_stack:
  added: []
  patterns: [keychain-only-credentials, expired-token-guard]
key_files:
  modified:
    - PulseCheck/Models/AppError.swift
    - PulseCheck/Services/CredentialsService.swift
    - PulseCheck/Store/UsageStore.swift
  created:
    - .planning/phases/04-launch-readiness/04-VERIFICATION.md
decisions:
  - File-based credential fallback removed entirely; Keychain is the sole credential source
  - Expired tokens set credentials to nil so fetchUsage() guard check prevents doomed API calls
metrics:
  duration: "~10 minutes"
  completed: "2026-04-02"
  tasks: 3
  files: 4
---

# Quick Task 260402-ogl: Address v1.0 Tech Debt — Remove Dead Code Summary

**One-liner:** Removed file-based credential fallback, two dead AppError cases, mock data method, and fixed expired-token handling to nil credentials before polling fires.

## Tasks Completed

| # | Task | Commit | Files Changed |
|---|------|--------|---------------|
| 1 | Remove dead credential code (file fallback + dead enum cases) | c296e14 | AppError.swift, CredentialsService.swift |
| 2 | Fix expired token handling to prevent doomed polling | 5213fe6 | UsageStore.swift |
| 3 | Remove mock code and create Phase 4 verification | ce3a389 | UsageStore.swift, 04-VERIFICATION.md |

## Changes Made

### AppError.swift
- Removed `case credentialsFileNotFound` and its `errorDescription` switch arm
- Removed `case credentialsFileMalformed(Error)` and its `errorDescription` switch arm

### CredentialsService.swift
- Deleted `readCredentialsFromFile()` method (~15 lines)
- Replaced the 3-step `loadCredentials()` (Keychain → file → failure) with a single Keychain-only implementation

### UsageStore.swift
- Fixed `loadCredentials()` expired-token branch: sets `self.credentials = nil` and `self.credentialError = .apiUnauthorized` so polling never fires with an expired token
- Deleted `mockUsage()` method and its TODO comment
- Removed the two commented-out mock lines at the top of `fetchUsage()`

### .planning/phases/04-launch-readiness/04-VERIFICATION.md (created)
- Retroactive verification record documenting Phase 04 was verified via SMAppService binding review and Login Items confirmation

## Deviations from Plan

None — plan executed exactly as written.

## Verification

1. `xcodebuild` build: SUCCEEDED (all three tasks verified individually)
2. Dead code grep (`credentialsFileNotFound|credentialsFileMalformed|readCredentialsFromFile|mockUsage`): No matches
3. `04-VERIFICATION.md` exists: Confirmed

## Self-Check: PASSED

- PulseCheck/Models/AppError.swift: exists, credentialsFile cases removed
- PulseCheck/Services/CredentialsService.swift: exists, file fallback removed
- PulseCheck/Store/UsageStore.swift: exists, mock and expired-token fix applied
- .planning/phases/04-launch-readiness/04-VERIFICATION.md: exists
- Commits c296e14, 5213fe6, ce3a389: all present in git log
