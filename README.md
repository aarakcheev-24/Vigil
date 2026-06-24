# Vigil

**Keeps your Mac awake while your AI agents work — even with the lid closed.**

Vigil is a tiny macOS menu-bar app for people who run long AI coding sessions
(Claude Code, Codex CLI, OpenCode, Gemini CLI, Aider, Cursor). It detects when an
agent is actually working and prevents your Mac from sleeping until the job is
done — then lets it sleep again. No more lost progress because the lid dropped.

<p align="center">
  <em>Native SwiftUI · menu-bar only · zero config · open source</em>
</p>

---

## Features

- 🖥️ **Lid-proof** — stays awake even with the lid closed. On AC power via IOKit
  power-assertions; on battery via `pmset disablesleep` (asks for admin once).
- 🤖 **Agent-aware** — auto-detects running sessions of Claude Code, OpenAI Codex
  CLI, OpenCode, Gemini CLI, Aider and Cursor, with a live session count.
- ⚡ **Auto mode** — wakes only while an agent is working, sleeps when everything
  is idle. Set it and forget it.
- 🔋 **Battery floor** — automatically stops below a threshold you choose (5–50%),
  so it never drains your laptop flat.
- ⏸️ **Quick pause** — 30 min / 1 hour with one click.
- 🔔 **Notifications** when it pauses or stops on low battery.
- 🪶 Native, lightweight, no Dock icon, no telemetry.

## Install

### Download
Grab the latest `Vigil.app` from the [Releases](../../releases) page, move it to
`/Applications`, and launch it. The icon appears in your menu bar.

> The app is ad-hoc signed (not notarized). On first launch, right-click →
> **Open**, or allow it in **System Settings → Privacy & Security**.

### Build from source
Requires macOS 13+ and the Swift toolchain (Xcode command-line tools).

```bash
git clone https://github.com/<your-user>/Vigil.git
cd Vigil
./build.sh
open ./Vigil.app
```

## How it works

| Power state | Mechanism |
|-------------|-----------|
| Idle / display | `PreventUserIdleSystemSleep` IOKit assertion |
| Lid closed, on AC | `PreventSystemSleep` IOKit assertion |
| Lid closed, on battery | `pmset -a disablesleep 1` (admin prompt) |

Agent detection is read-only — Vigil scans the process list (`ps`) for known CLI
names. Adding a new agent is one line in
[`AgentMonitor.swift`](Sources/Vigil/AgentMonitor.swift).

## Roadmap

- [x] Launch at login
- [x] Custom menu-bar icon set
- [x] App icon + `.dmg`
- [ ] Per-project allowlist
- [ ] Notarized, signed build (needs an Apple Developer account)
- [ ] Homebrew cask

## License

[MIT](LICENSE) © Alex Arakcheev
