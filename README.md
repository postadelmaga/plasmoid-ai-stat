# AI Stat

Real-time KDE Plasma 6 widget for monitoring AI coding assistants — Claude Code, Gemini CLI, and Gemini API. Token quotas, session throughput, cost tracking, and more.

<p align="center">
  <img src="screenshots/main.png" alt="AI Stat widget" width="420"/>
</p>

## Features

- **Three Tabs** — Claude Code, Gemini CLI, Gemini API
- **Live Tachometer** — car-style gauge with animated needle, engine vibration, and adaptive max scale driven by `/proc/pid/io` polling (1s resolution)
- **Dual Quota Rings** — concentric input/output rings for session and daily limits with glow effects and color thresholds (green/yellow/red)
- **Dashboard Layout** — Session ring | Tachometer | Daily ring side by side
- **12h Hourly Chart** — smooth Catmull-Rom curves with adaptive bucket aggregation based on widget width
- **Daily History** — 8-day stacked bar chart (input/output)
- **Active Sessions** — live session cards with token counts, duration, message count
- **Model Breakdown** — per-model token usage with proportional bars
- **Gemini CLI** — local usage from `~/.gemini/`, tier detection (Free/Standard/Enterprise), request quota tracking
- **Gemini API** — rate limits and available models via `countTokens` endpoint (no quota impact)
- **Panel Indicator** — configurable: quota ring or mini tachometer
- **Cost Tracking** — estimated API costs (weekly/total)

<p align="center">
  <img src="screenshots/dashboard.png" alt="Dashboard with tachometer and quota rings" width="380"/>
</p>

## Installation

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -i ai-stat.plasmoid
```

### Upgrade

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -u ai-stat.plasmoid
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

## How It Works

```
local_stats.py        ──> JSON ──> main.qml (Claude tab)
gemini_local_stats.py ──> JSON ──> main.qml (Gemini CLI tab)
gemini_stats.py       ──> JSON ──> main.qml (Gemini API tab)
/proc/pid/io          ──> grep ──> main.qml (instantRate) ──> Tachometers
```

- **Backend**: Python scripts parse `~/.claude/` and `~/.gemini/` data and output JSON
- **Realtime**: `/proc/pid/io` polling detects streaming activity with adaptive peak tracking for both Claude and Gemini CLI processes
- **Rendering**: Split Canvas layers (static background / dynamic arcs) + GPU-composited needle rotation for minimal CPU impact

## Requirements

- KDE Plasma 6
- Python 3
- Claude Code and/or Gemini CLI installed locally

## Credits

Built with [Claude Code](https://claude.ai/code)
