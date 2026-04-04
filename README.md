# OhMyToken

**Real-time token dashboard for AI coding assistants** -- a KDE Plasma 6 widget that tracks usage, quotas, throughput, costs, and sessions across multiple AI tools, right from your desktop panel.

<p align="center">
  <img src="screenshots/main.png" alt="OhMyToken — KDE Plasma 6 AI token dashboard" width="480"/>
</p>

## Supported Tools

| Tool | Data Source | Real-time | Quotas |
|------|-----------|-----------|--------|
| **Claude Code** | `~/.claude/` telemetry, sessions, JSONL | `/proc/pid/io` 1s polling | Session window + daily (auto-detected tier) |
| **Gemini CLI** | `~/.gemini/` chat sessions | `/proc/pid/io` child worker polling | Requests/day by tier |
| **OpenCode** | `~/.local/share/opencode/` SQLite DB | `/proc/pid/io` polling | Token tracking |
| **Antigravity IDE** | Language server local API | Status endpoint polling | Prompt + Flow credits |
| **Gemini API** | `countTokens` endpoint (free) | -- | Rate limits (requests + tokens) |

Each tool can be individually enabled or disabled. The widget gracefully handles tools that aren't installed or aren't running.

## Features

### Live Tachometer
Car-style animated gauge with rotating needle, engine vibration jitter, three color zones (green/yellow/red), and adaptive max scale. Responds in real-time to streaming activity via `/proc/pid/io` polling at 1-second intervals.

### Dual Quota Rings
Concentric input/output progress rings with color-coded thresholds -- green under 70%, yellow 70-90%, red above 90%. Session window quotas on the left, daily totals on the right.

### Dashboard Layout
Session Ring | Tachometer | Daily Ring side by side, with session countdown timer below. Falls back to a standalone tachometer when quota data isn't available.

### Hourly & Daily Charts
- **Hourly**: 12-hour smooth Catmull-Rom curves with adaptive bucket aggregation (5/10/15/20/30/60/120 min)
- **Daily**: 8-day stacked bar chart (input + output)

### Active Sessions
Live session cards with token counts, duration, message count, and pulsing glow animation that reflects streaming activity per-session.

### Model Breakdown
Per-model token usage with proportional bars and cost estimates.

### Summary Tab
Aggregated view across all enabled providers -- total tokens today/week/month, combined sessions, merged throughput rates.

### Panel Indicator
Two modes for the system tray:
- **Quota Ring** -- mini session progress ring with percentage label
- **Mini Tachometer** -- animated gauge showing real-time throughput across all active tools

### Cost Tracking
Estimated API costs (weekly and total) with configurable monthly budget threshold.

<p align="center">
  <img src="screenshots/dashboard.png" alt="Dashboard with tachometer and dual quota rings" width="420"/>
</p>

## Installation

### From .plasmoid file

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -i ohmytoken.plasmoid
```

### From GitHub Releases

Download the latest `ohmytoken.plasmoid` from [Releases](https://github.com/postadelmaga/plasmoid-ohmytoken/releases), then:

```bash
kpackagetool6 -t Plasma/Applet -i ohmytoken.plasmoid
```

### Upgrade

```bash
bash build.sh
kpackagetool6 -t Plasma/Applet -u ohmytoken.plasmoid
```

### Development (symlink)

```bash
ln -s /path/to/plasmoid-ohmytoken/ohmytoken ~/.local/share/plasma/plasmoids/ohmytoken
```

Changes to source files are live immediately -- just reload the widget.

## Configuration

Right-click the widget and select **Configure...**.

### Services

| Setting | Default | Description |
|---------|---------|-------------|
| Claude Code | On | Monitor `~/.claude/` telemetry and sessions |
| Gemini CLI | On | Monitor `~/.gemini/` chat sessions |
| OpenCode | On | Monitor `~/.local/share/opencode/` SQLite database |
| Antigravity | On | Monitor via language server API (auto-discovered) |
| Gemini API | Off | Requires API key -- get one at [ai.google.dev](https://ai.google.dev) |

### Display

| Setting | Default | Description |
|---------|---------|-------------|
| Refresh interval | 300s | Data polling interval (60--900s) |
| Panel indicator | Ring | Quota ring or mini tachometer in panel mode |
| Show costs | On | Display estimated API costs |
| Monthly budget | $100 | Budget threshold for cost tracking |

### Claude Limits

| Setting | Default | Description |
|---------|---------|-------------|
| Daily input limit | Auto | Override auto-detected tier limit (0 = auto) |
| Daily output limit | Auto | Override auto-detected tier limit (0 = auto) |

Tier limits are auto-detected from `~/.claude/.credentials.json`:

| Tier | Input/day | Output/day |
|------|----------|------------|
| Max 5x | 1.665B | 166.5M |
| Max | 300M | 30M |
| Team | 200M | 20M |
| Pro | 100M | 10M |

Gemini CLI tier is detected from `~/.gemini/settings.json` (Free: 1000, Standard: 1500, Enterprise: 2000 requests/day).

## Architecture

```
local_stats.py        ----> JSON ----> main.qml (Claude)
gemini_local_stats.py ----> JSON ----> main.qml (Gemini CLI)
opencode_stats.py     ----> JSON ----> main.qml (OpenCode)
antigravity_stats.py  ----> JSON ----> main.qml (Antigravity)
gemini_stats.py       ----> JSON ----> main.qml (Gemini API)
/proc/pid/io          ----> grep ----> main.qml (tachometers)
```

- **Backend**: Python scripts parse local data files, SQLite databases, and local APIs. Output JSON to stdout.
- **Real-time**: `/proc/pid/io` rchar polling at 1s for Claude, Gemini CLI, and OpenCode processes. Language server endpoint polling for Antigravity.
- **Rendering**: Split Canvas layers (static background / dynamic arcs) with GPU-composited needle rotation for minimal CPU impact. Jitter animation only runs during active streaming.

## Requirements

- KDE Plasma 6
- Python 3
- Linux (requires `/proc` filesystem for real-time I/O monitoring)
- One or more of: Claude Code, Gemini CLI, OpenCode, Antigravity IDE

## License

GPL-3.0+

## Credits

Built with [Claude Code](https://claude.ai/code)
