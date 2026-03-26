# Claude Topbar

**Stop refreshing the usage page. Start vibing.**

Claude Topbar lives in your macOS menu bar and gives you a real-time view of your Claude session usage — so you can pace yourself through conversations without nervously checking the settings page every five minutes.

The usage bar shows how much you've consumed. The tick marker shows how far through the 5-hour window you are. If the bar is behind the tick, you're golden. If it's ahead, maybe let Claude finish its thought before asking it to refactor your entire codebase.

Built for Claude Pro and Max plan users.

## What it looks like

The menu bar shows:
- The Claude logo in terracotta
- A usage bar with a tick marker showing your position in the 5-hour session window
- Time remaining until the session resets

Click the menu bar item for a detailed breakdown of session, weekly, and per-model usage.

The bar turns **green** when you're under-pacing the clock, **orange** when you're over-pacing, and **red** above 95%.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.10+ (included with Xcode Command Line Tools)
- A Claude Pro or Max subscription

## Installation

### From source

```bash
git clone https://github.com/alexreardon/claude-usage-topbar-macos.git
cd claude-usage-topbar-macos
make install
```

This builds a release binary and installs it to `~/Applications/ClaudeTopbar.app`.

To launch it:

```bash
open ~/Applications/ClaudeTopbar.app
```

### During development

```bash
make run
```

Builds, bundles, and launches the app in one step.

## Setup

1. Launch the app — it appears in your menu bar
2. Click the menu bar item and press **"Sign in with Claude..."**
3. Log in with your Claude account in the window that opens
4. The app automatically detects your session and starts showing usage

That's it. The app polls every 60 seconds and the time indicator updates in real time.

## Uninstall

```bash
make uninstall
```

To also remove stored credentials:

```bash
rm ~/.claude/topbar-session-key
```

## How it works

The app reads usage data from the same internal API that the [claude.ai/settings/usage](https://claude.ai/settings/usage) page uses. Authentication is via your session cookie, extracted automatically when you sign in through the app.

## Building

```bash
make build    # Build release binary
make run      # Build + launch
make clean    # Clean build artifacts
make install  # Build + install to ~/Applications
```

## License

MIT
