# Summon

> Instantly launch terminal apps on macOS with global hotkeys — no terminal window needed.

## The problem

Using tools like `claude`, `lazygit`, or `k9s` requires two steps: open a terminal, *then* launch the app. Summon eliminates the first step.

## How it works

Summon runs as a menu bar app (no Dock icon). You configure **slots** — each slot binds a terminal command to a global hotkey. Press the hotkey from anywhere and the app appears in a floating window with a **persistent session**. Press it again to hide it.

```
⌘⇧C  →  claude    (Claude Code)
⌘⇧G  →  lazygit
⌘⇧K  →  k9s
```

Each app lives in its own window. Sessions persist in the background — hide and re-show without losing state.

## Status

Early development. Current milestone: MVP with static slot configuration and embedded terminal.

- [x] Project scaffold
- [ ] SwiftTerm integration (embedded terminal emulator)
- [ ] Carbon global hotkey registration
- [ ] Session persistence (hide/show without killing process)
- [ ] Settings UI (add/edit/remove slots)
- [ ] Hotkey recorder widget

## Requirements

- macOS 13 Ventura or later
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

## Development setup

```bash
# Install xcodegen
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open Summon.xcodeproj
```

## Architecture

| Layer | Technology |
|---|---|
| Menu bar + Settings UI | SwiftUI |
| Terminal emulation | [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) |
| Global hotkeys | Carbon Event API / [HotKey](https://github.com/soffes/HotKey) |
| Window management | AppKit (`NSWindowController`, `.floating` level) |
| Config persistence | JSON in `~/Library/Application Support/Summon/` |

```
Sources/Summon/
├── App/          SummonApp.swift, AppDelegate.swift
├── Models/       SlotConfig.swift
├── Managers/     SessionManager.swift, HotKeyManager.swift
├── Terminal/     TerminalSession.swift, TerminalWindowController.swift
├── Views/        SettingsView.swift
└── Resources/    Info.plist, entitlements, assets
```

## License

MIT
