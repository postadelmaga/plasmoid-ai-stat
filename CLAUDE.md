# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KDE Plasma 6 plasmoid (widget) — **OhMyToken** — that displays real-time usage stats for Claude Code, Gemini CLI, and Gemini API. It reads local data files (`~/.claude/`, `~/.gemini/`) and queries the Gemini API, then presents token usage, session info, throughput tachometers, and quota rings in a panel widget.

## Development Setup

The installed widget is a **symlink** to the source directory:
```
~/.local/share/plasma/plasmoids/ohmytoken -> /home/fra/Dev/Plasma/plasmoid-ClaudeStat/ohmytoken
```
**NEVER delete or `rm -rf` the installed path** — it would destroy the source files. Changes to source files are live immediately; just reload the widget.

```bash
# Build .plasmoid zip (for distribution only, not needed for dev)
bash build.sh

# Upgrade if not using symlink
kpackagetool6 -t Plasma/Applet -u ohmytoken.plasmoid

# Test in viewer
plasmoidviewer -a ohmytoken

# Refresh KDE cache after metadata changes
kbuildsycoca6

# Restart plasma shell (nuclear option)
plasmashell --replace &
```

## Architecture

### Data Flow
```
local_stats.py        ──→ JSON ──→ main.qml (updateClaude)
gemini_local_stats.py ──→ JSON ──→ main.qml (updateGeminiCli)
antigravity_stats.py  ──→ JSON ──→ main.qml (updateAntigravity)
opencode_stats.py     ──→ JSON ──→ main.qml (updateOpenCode)
copilot_stats.py      ──→ JSON ──→ main.qml (updateCopilot)
kiro_stats.py         ──→ JSON ──→ main.qml (updateKiro)
pi_stats.py           ──→ JSON ──→ main.qml (updatePi)
gemini_stats.py       ──→ JSON ──→ main.qml (updateGemini)
/proc/pid/io          ──→ grep ──→ main.qml (instantRate / gcliInstantRate / piInstantRate / ocInstantRate)
```

`main.qml` uses `Plasma5Support.DataSource` with engine `"executable"` to run the Python scripts on a timer (`refreshInterval`, default 300s). The scripts output JSON to stdout which gets parsed and mapped to QML properties.

### Backend Scripts (`contents/code/`)

- **`local_stats.py`** — Parses `~/.claude/` data:
  - `.credentials.json` → subscription type, tier, rate limits
  - `telemetry/*.json` → completed session token usage (deduplicated by session_id)
  - `sessions/*.json` + `projects/<cwd>/<sessionId>.jsonl` → active session real-time tokens
  - `history.jsonl` → prompt counts
  - Outputs session window info (5 windows/day starting 03:00 UTC)

- **`gemini_local_stats.py`** — Parses `~/.gemini/` data:
  - `settings.json` → auth type, tier detection (Free/Standard/Enterprise)
  - `tmp/*/chats/session-*.json` → per-message token usage (input, output, cached, thoughts, tool)
  - Counts API requests per day for quota tracking
  - Detects active processes via pgrep (parent + child PIDs)

- **`pi_stats.py`** — Parses `~/.pi/agent/` data:
  - `settings.json` → provider, model, thinking level
  - `sessions/*/*.jsonl` → per-message token usage (input, output, cacheRead, cacheWrite) and costs
  - Detects active processes via `pgrep -x pi` (parent + child PIDs)

- **`copilot_stats.py`** — Parses `~/.copilot/session-store.db`:
  - Session and turn totals (today/week/month/total)
  - Active sessions from recent turns for better accuracy
  - Recent session list with cwd metadata

- **`kiro_stats.py`** — Parses `~/.kiro/` and Kiro workspace storage:
  - Version/running state, powers, extensions
  - Credit usage and recent workspace directories

- **`gemini_stats.py`** — Uses `countTokens` endpoint (free, no quota impact) to check API availability

- **`formatters.js`** — Formatting helpers: `formatTokens()`, `formatCost()`, `formatDuration()`, `tierLabel()`, `shortModel()`

### UI Components (`contents/ui/`)

- **`main.qml`** — Root `PlasmoidItem` with compact/full representations, tabs (Summary/Claude/Gemini CLI/Antigravity/Pi/OpenCode/Copilot CLI/Kiro/Gemini API), all state properties, I/O polling
- **`ClaudeTab.qml`** — Claude dashboard with quota rings, tachometer, charts, sessions
- **`GeminiCliTab.qml`** — Gemini CLI dashboard (mirrors Claude layout)
- **`PiTab.qml`** — Pi dashboard with dual quota rings, tachometer, costs, charts, sessions
- **`GeminiTab.qml`** — Gemini API rate limits and models
- **`Tachometer.qml`** — Car-style gauge with split canvas (static bg / dynamic arc), animated needle with jitter
- **`DualQuotaRing.qml`** — Concentric input/output rings with glow
- **`QuotaRing.qml`** — Single ring progress indicator
- **`HourlyChart.qml`** — 12h Catmull-Rom curve chart with adaptive bucket aggregation
- **`DailyChart.qml`** — 8-day stacked bar chart
- **`StatCard.qml`**, `SessionRow.qml`, `ModelRow.qml`, `ActiveSessionCard.qml`, `SectionHeader.qml` — Reusable display components

### Key Domain Concepts

- **Session Window** (Claude): Rate limits reset in 5-hour windows starting from 03:00 UTC. Boundaries: 03:00, 08:00, 13:00, 18:00, 23:00 UTC.
- **Token types** (Claude): `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`.
- **Token types** (Gemini CLI): `input`, `output`, `cached`, `thoughts`, `tool`, `total`.
- **Tier limits** (Claude): Hardcoded in `TIER_LIMITS` dict. Per-window limit = daily limit / 5.
- **Tier limits** (Gemini CLI): Request-based (1000/1500/2000 per day depending on tier).
- **I/O Polling**: `/proc/pid/io` rchar polling at 1s for Claude, Gemini CLI, Pi, and OpenCode processes. Gemini CLI requires polling child processes (worker node) not just the launcher. Pi process name is `pi` (exact match via `pgrep -x`).

## Plasma 6 / QML Notes

- Root element must be `PlasmoidItem` (not `Item`)
- Use `Kirigami.Theme` for colors, `Kirigami.Units` for spacing
- `Kirigami.Theme.Complementary` forces dark colors; must be set on QQC2.TabBar individually (breeze style overrides parent colorSet)
- No emoji in widgets — use `Kirigami.Icon` with system icon names
- Config values via `plasmoid.configuration.propertyName`
- The widget supports both panel (compact) and desktop (full) form factors via `Plasmoid.formFactor`
- Token properties must be `double` not `int` (QML int is 32-bit signed, overflows at ~2.1B)
