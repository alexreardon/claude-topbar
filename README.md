# Claude Topbar

> [!NOTE]
> This project was built entirely with [Claude Code](https://claude.ai/code).

A macOS menu bar app that shows your Claude session usage without needing to open the browser.

Displays a usage bar, a tick marker for your position in the 5-hour session window, and the time remaining until reset. Click for a full breakdown of session, weekly, and per-model usage.

The bar is **green** when usage is below your time position, **orange** when above, and **red** past 95%.

For Claude Pro and Max plan users.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.10+ (included with Xcode Command Line Tools)
- A Claude Pro or Max subscription

## Installation

### From source

```bash
git clone https://github.com/alexreardon/claude-topbar.git
cd claude-topbar
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
