# Claude Stat

Real-time KDE Plasma 6 widget for monitoring Claude and Gemini API usage — token quotas, session throughput, cost tracking, and more.

<p align="center">
  <img src="screenshots/main.png" alt="Claude Stat widget" width="420"/>
</p>

## Features

- **Live Tachometer** — car-style gauge with animated needle, engine vibration, and adaptive max scale driven by `/proc/pid/io` polling (1s resolution)
- **Dual Quota Rings** — concentric input/output rings for session and daily limits with glow effects and color thresholds (green/yellow/red)
- **Dashboard Layout** — Session ring | Tachometer | Daily ring side by side
- **12h Hourly Chart** — smooth Catmull-Rom curves with adaptive bucket aggregation based on widget width
- **Daily History** — 8-day stacked bar chart (input/output)
- **Active Sessions** — live session cards with token counts, duration, message count
- **Model Breakdown** — per-model token usage with proportional bars
- **Gemini Tab** — API rate limits and available models via `countTokens` endpoint (no quota impact)
- **Panel Indicator** — configurable: quota ring or mini tachometer
- **Cost Tracking** — estimated API costs (weekly/total)

<p align="center">
  <img src="screenshots/dashboard.png" alt="Dashboard with tachometer and quota rings" width="380"/>
</p>

## Installation

### Quick Install (symlink for development)

```bash
ln -s "$(pwd)/claude-stat" ~/.local/share/plasma/plasmoids/claude-stat
```

### Package Install

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -i claude-stat.plasmoid
```

### Upgrade

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -u claude-stat.plasmoid
```

## Configuration

Right-click the widget and select **Configure...** to set:

| Setting | Description |
|---------|-------------|
| Refresh interval | How often to poll Claude data (60–900s) |
| Panel indicator | Quota ring or Tachometer in panel mode |
| Show costs | Toggle estimated cost display |
| Monthly budget | Budget threshold for cost tracking |
| Daily input/output limits | Override auto-detected tier limits (0 = auto) |
| Gemini API key | Enable the Gemini tab (get yours at [ai.google.dev](https://ai.google.dev)) |

Tier limits are auto-detected from `~/.claude/.credentials.json`. Supported tiers: Pro, Max, Max 5x, Team.

## How It Works

```
local_stats.py ──> JSON ──> main.qml (updateClaude)
gemini_stats.py ──> JSON ──> main.qml (updateGemini)
/proc/pid/io ──> grep ──> main.qml (instantRate) ──> Tachometer
```

- **Backend**: Python scripts parse `~/.claude/` data (credentials, telemetry, sessions, history) and output JSON
- **Realtime**: `/proc/pid/io` polling detects streaming activity with adaptive peak tracking
- **Rendering**: Split Canvas layers (static background / dynamic arcs) + GPU-composited needle rotation for minimal CPU impact

## Requirements

- KDE Plasma 6
- Python 3
- A Claude Code subscription (reads local `~/.claude/` data)

## Credits

Built with [Claude Code](https://claude.ai/code)
