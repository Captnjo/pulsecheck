# PulseCheck

**Claude Code doesn't surface your usage limits in the UI — PulseCheck fixes that.**

A macOS menu bar app that shows your Claude Code usage at a glance. Displays your current usage percentage in the menu bar with a dropdown panel showing daily and weekly limits, progress bars, and reset times.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green)

<img src="screenshot.png" alt="PulseCheck screenshot showing 57% daily usage, 12% weekly usage, reset countdowns, and Launch at Login toggle in the menu bar dropdown" width="360">

> Menu bar shows your current usage percentage. Click to see daily (5-hour) and weekly (7-day) usage with progress bars, reset countdowns, and a Launch at Login toggle.

## Features

- Usage percentage in the menu bar with adaptive icon (auto-tints for light/dark mode)
- Daily (5-hour window) and weekly (7-day window) usage with progress bars
- Reset countdown for daily, date/time for weekly
- Last-updated timestamp showing when data was last fetched
- Manual refresh button to fetch usage on demand
- Polls every 60 seconds with automatic backoff on rate limits
- Automatic OAuth token refresh — keeps working beyond the ~8-hour token lifetime
- Launch at Login toggle
- Quick-launch button to open the Claude desktop app
- Zero configuration — reads your existing Claude Code OAuth token from the macOS Keychain

## Install

Requires macOS 14 (Sonoma) or later. Pick one:

---

### Option A: Homebrew (recommended)

```bash
brew install --cask captnjo/tap/pulsecheck
```

---

### Option B: Download DMG

**[Download PulseCheck-1.1.dmg](https://github.com/Captnjo/pulsecheck/releases/download/v1.1/PulseCheck-1.1.dmg)**

1. Open the downloaded DMG
2. Drag **PulseCheck** into your **Applications** folder
3. Launch PulseCheck from Applications
4. macOS will warn the app is from an unidentified developer — click **Cancel**, then:
   - Go to **System Settings > Privacy & Security**
   - Scroll down to the security section — you'll see "PulseCheck was blocked"
   - Click **Open Anyway** and confirm

---

### Option C: Build from source

Requires Xcode 16.3+.

```bash
git clone https://github.com/Captnjo/pulsecheck.git
cd pulsecheck
xcodebuild -project PulseCheck.xcodeproj -scheme PulseCheck -configuration Release build
```

Or open `PulseCheck.xcodeproj` in Xcode and hit Cmd+R.

To produce a DMG with drag-to-install: `./scripts/build-dmg.sh`

---

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) must be installed and authenticated (`claude auth login`). The app reads your existing login — no separate API key needed.

## How it works

The app reads your Claude Code OAuth credentials from the macOS Keychain (service: `Claude Code-credentials`), then polls the `/api/oauth/usage` endpoint every 60 seconds. No API key setup is needed — it piggybacks on your existing Claude Code login.

When your access token expires (~8 hours), the app silently refreshes it using the OAuth refresh token and stores the new credentials in its own Keychain item (`PulseCheck-claude-credentials`) — your Claude Code credentials are never modified.

If you see "No credentials", run `claude auth login` in your terminal.

## License

[GPL v3](LICENSE) — free to use, modify, and distribute. Derivative works must also be open source under the same license.

## Contributing

Issues and PRs welcome. If you hit a bug or have a feature idea, [open an issue](https://github.com/Captnjo/pulsecheck/issues).
