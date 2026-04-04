# OhMyToken

Real-time KDE Plasma 6 widget for monitoring AI coding assistants — Claude Code, Gemini CLI, Antigravity IDE, and Gemini API. Token quotas, session throughput, cost tracking, and more.

<p align="center">
  <img src="screenshots/main.png" alt="OhMyToken widget" width="420"/>
</p>

## Features

- **Four Tabs** — Claude Code, Gemini CLI, Antigravity, Gemini API
- **Live Tachometer** — car-style gauge with animated needle, engine vibration, and adaptive max scale (1s polling)
- **Dual Quota Rings** — concentric input/output rings with glow effects and color thresholds
- **Dashboard Layout** — Quota ring | Tachometer | Token ring side by side
- **12h Hourly Chart** — smooth Catmull-Rom curves with adaptive bucket aggregation
- **Daily History** — 8-day stacked bar chart (input/output)
- **Active Sessions** — live session cards with token counts, duration, message count
- **Model Breakdown** — per-model token usage with proportional bars
- **Panel Indicator** — configurable: quota ring or mini tachometer
- **Cost Tracking** — estimated API costs (weekly/total)

### Per-tool features

| Tool | Data source | Tachometer | Quotas |
|------|------------|------------|--------|
| **Claude Code** | `~/.claude/` telemetry, sessions, history | `/proc/pid/io` polling | Session window + daily limits (auto-detected tier) |
| **Gemini CLI** | `~/.gemini/` chat sessions | `/proc/pid/io` polling (child worker) | Requests/day (1000/1500/2000 by tier) |
| **Antigravity** | Language server local API | `GetAllCascadeTrajectories` status polling | Prompt + Flow credits, per-model quota |
| **Gemini API** | `countTokens` endpoint | — | Rate limits (requests + tokens) |

<p align="center">
  <img src="screenshots/dashboard.png" alt="Dashboard with tachometer and quota rings" width="380"/>
</p>

## Installation

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -i ohmytoken.plasmoid
```

### Upgrade

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -u ohmytoken.plasmoid
```

## Configuration

Right-click the widget and select **Configure...** to set:

| Setting | Description |
|---------|-------------|
| Refresh interval | How often to poll data (60-900s) |
| Panel indicator | Quota ring or Tachometer in panel mode |
| Show costs | Toggle estimated cost display |
| Monthly budget | Budget threshold for cost tracking |
| Daily input/output limits | Override auto-detected Claude tier limits (0 = auto) |
| Gemini API key | Enable the Gemini API tab (get yours at [ai.google.dev](https://ai.google.dev)) |

Claude tier limits are auto-detected from `~/.claude/.credentials.json`. Supported tiers: Pro, Max, Max 5x, Team.
Gemini CLI tier is detected from `~/.gemini/settings.json` auth type.
Antigravity connects automatically when the IDE is running (discovers the local language server).

## How It Works

```
local_stats.py        ──> JSON ──> main.qml (Claude tab)
gemini_local_stats.py ──> JSON ──> main.qml (Gemini CLI tab)
antigravity_stats.py  ──> JSON ──> main.qml (Antigravity tab)
gemini_stats.py       ──> JSON ──> main.qml (Gemini API tab)
/proc/pid/io          ──> grep ──> main.qml (Claude/Gemini CLI tachometers)
curl localhost:PORT   ──> JSON ──> main.qml (Antigravity tachometer)
```

- **Backend**: Python scripts parse local data files and query local APIs, output JSON
- **Realtime**: `/proc/pid/io` polling for Claude/Gemini CLI; language server API polling for Antigravity
- **Rendering**: Split Canvas layers (static background / dynamic arcs) + GPU-composited needle rotation for minimal CPU impact

## Requirements

- KDE Plasma 6
- Python 3
- One or more of: Claude Code, Gemini CLI, Antigravity IDE

## Credits

Built with [Claude Code](https://claude.ai/code)
