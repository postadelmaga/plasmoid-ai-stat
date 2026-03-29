# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KDE Plasma 6 plasmoid (widget) that displays real-time Claude and Gemini API usage stats. It reads local Claude Code data files (`~/.claude/`) and queries the Gemini API, then presents token usage, session info, and quota rings in a panel widget.

## Development Setup

The installed widget is a **symlink** to the source directory:
```
~/.local/share/plasma/plasmoids/claude-stat -> /home/fra/Dev/Plasma/plasmoid-ClaudeStat/claude-stat
```
**NEVER delete or `rm -rf` the installed path** — it would destroy the source files. Changes to source files are live immediately; just reload the widget.

```bash
# Build .plasmoid zip (for distribution only, not needed for dev)
bash build.sh

# Upgrade if not using symlink
kpackagetool6 -t Plasma/Applet -u claude-stat.plasmoid

# Test in viewer
plasmoidviewer -a claude-stat

# Refresh KDE cache after metadata changes
kbuildsycoca6

# Restart plasma shell (nuclear option)
plasmashell --replace &
```

## Architecture

### Data Flow
```
local_stats.py ──→ JSON ──→ main.qml (updateClaude)
gemini_stats.py ──→ JSON ──→ main.qml (updateGemini)
```

`main.qml` uses `Plasma5Support.DataSource` with engine `"executable"` to run the Python scripts on a timer (`refreshInterval`, default 300s). The scripts output JSON to stdout which gets parsed and mapped to QML properties.

### Backend Scripts (`contents/code/`)

- **`local_stats.py`** — Python script that parses `~/.claude/` data:
  - `.credentials.json` → subscription type, tier, rate limits
  - `telemetry/*.json` → completed session token usage (deduplicated by session_id)
  - `sessions/*.json` + `projects/<cwd>/<sessionId>.jsonl` → active session real-time tokens (per-message timestamps for correct daily attribution)
  - `history.jsonl` → prompt counts
  - Outputs session window info (5 windows/day starting 03:00 UTC, windows of 5,5,5,5,4 hours)
  - Active session IDs are excluded from telemetry aggregation to prevent double-counting

- **`gemini_stats.py`** — Uses `countTokens` endpoint (free, no quota impact) to check API availability without consuming quota

- **`anthropic.js`** — Formatting helpers: `formatTokens()`, `formatCost()`, `formatDuration()`, `tierLabel()`, `shortModel()`

### UI Components (`contents/ui/`)

- **`main.qml`** — Root `PlasmoidItem` with compact/full representations, two tabs (Claude/Gemini), all state properties
- **`QuotaRing.qml`** — Canvas-based circular progress indicator with color thresholds (green <70%, yellow 70-90%, red >90%)
- **`DailyChart.qml`** — Stacked bar chart (input/output per day, last 8 days)
- **`StatCard.qml`**, `SessionRow.qml`, `ModelRow.qml`, `SectionHeader.qml` — Reusable display components

### Key Domain Concepts

- **Session Window**: Claude rate limits reset in 5-hour windows starting from 03:00 UTC (not midnight). Boundaries: 03:00, 08:00, 13:00, 18:00, 23:00 UTC.
- **Token types**: `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`. All are included in quota tracking.
- **Tier limits**: Hardcoded in `TIER_LIMITS` dict. Per-window limit = daily limit / 5.
- **Active vs completed sessions**: Active sessions are parsed from JSONL with per-message timestamps; completed sessions come from telemetry with only session-level totals.

## Plasma 6 / QML Notes

- Root element must be `PlasmoidItem` (not `Item`)
- Use `Kirigami.Theme` for colors, `Kirigami.Units` for spacing
- No emoji in widgets — use `Kirigami.Icon` with system icon names
- Config values via `plasmoid.configuration.propertyName`
- The widget supports both panel (compact) and desktop (full) form factors via `Plasmoid.formFactor`
