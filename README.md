# PulseCheck

A macOS menu bar app that shows your Claude Code usage at a glance. Displays your current usage percentage in the menu bar with a dropdown panel showing daily and weekly limits, progress bars, and reset times.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green)

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

### Download DMG

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **PulseCheck** to your Applications folder
3. Launch the app — on first run, right-click > **Open** (or System Settings > Privacy & Security > Open Anyway) since the app is not notarized

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
