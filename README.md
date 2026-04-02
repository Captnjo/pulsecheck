# PulseCheck

**Claude Code doesn't surface your usage limits in the UI — PulseCheck fixes that.**

A macOS menu bar app that shows your Claude Code usage at a glance. Displays your current usage percentage in the menu bar with a dropdown panel showing daily and weekly limits, progress bars, and reset times.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green)

<img src="screenshot.png" alt="PulseCheck screenshot showing 57% daily usage, 12% weekly usage, reset countdowns, and Launch at Login toggle in the menu bar dropdown" width="360">

> Menu bar shows your current usage percentage. Click to see daily (5-hour) and weekly (7-day) usage with progress bars, reset countdowns, and a Launch at Login toggle.

## Features

- Usage percentage in the menu bar with Claude icon
- Daily (5-hour window) and weekly (7-day window) usage with progress bars
- Reset countdown for daily, date/time for weekly
- Polls every 60 seconds with automatic backoff on rate limits
- Launch at Login toggle
- Quick-launch button to open the Claude desktop app
- Zero configuration — reads your existing Claude Code OAuth token from the macOS Keychain

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated (`claude auth login`)

## Install

### Homebrew (recommended)

```bash
brew install --cask captnjo/tap/pulsecheck
```

### Download

**[Download PulseCheck-1.0.dmg](https://github.com/Captnjo/pulsecheck/releases/download/v1.0/PulseCheck-1.0.dmg)**

### Setup

1. Make sure [Claude Code](https://docs.anthropic.com/en/docs/claude-code) is installed and you've logged in (`claude auth login`)
2. Open the downloaded DMG
3. Drag **PulseCheck** into your **Applications** folder
4. Launch PulseCheck from Applications
5. macOS will warn the app is from an unidentified developer — click **Cancel**, then:
   - Go to **System Settings > Privacy & Security**
   - Scroll down to the security section — you'll see "PulseCheck was blocked"
   - Click **Open Anyway** and confirm
6. The PulseCheck icon and your usage percentage will appear in the menu bar

### Build from source

Requires Xcode 16.3+.

```bash
git clone https://github.com/Captnjo/pulsecheck.git
cd pulsecheck
xcodebuild -project PulseCheck.xcodeproj -scheme PulseCheck -configuration Release build
```

Or open `PulseCheck.xcodeproj` in Xcode and hit Cmd+R.

### Build DMG

A script is included to produce a DMG with drag-to-install:

```bash
./scripts/build-dmg.sh
```

This archives the app and creates `PulseCheck-1.0.dmg` in the project root.

## How it works

The app reads your Claude Code OAuth credentials from the macOS Keychain (service: `Claude Code-credentials`), then polls the `/api/oauth/usage` endpoint every 60 seconds. No API key setup is needed — it piggybacks on your existing Claude Code login.

If you see "No credentials", run `claude auth login` in your terminal.

## License

[GPL v3](LICENSE) — free to use, modify, and distribute. Derivative works must also be open source under the same license.

## Contributing

Issues and PRs welcome. If you hit a bug or have a feature idea, [open an issue](https://github.com/Captnjo/pulsecheck/issues).
