#!/usr/bin/env python3
"""Parses ~/.pi/agent/sessions/ JSONL files for pi coding agent usage stats."""

import json, os, subprocess, sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

PI_DIR = Path.home() / ".pi" / "agent"
SESSIONS_DIR = PI_DIR / "sessions"

now_utc = datetime.now(timezone.utc)
now_ms = now_utc.timestamp() * 1000
now_local = datetime.now()

local_midnight = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
today_ts = local_midnight.timestamp() * 1000
week_ts = (local_midnight - timedelta(days=7)).timestamp() * 1000
month_ts = (local_midnight - timedelta(days=30)).timestamp() * 1000

HOURLY_WINDOW = 12
hourly_cutoff_ts = (now_utc - timedelta(hours=HOURLY_WINDOW)).timestamp() * 1000
FINE_BUCKET_MIN = 5
RATE_WINDOW_SHORT = 5 * 60 * 1000
RATE_WINDOW_LONG = 30 * 60 * 1000
rate_cutoff_ts = now_ms - RATE_WINDOW_LONG
recent_events = []  # [(ts_ms, inp, out)]

tok_today = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
tok_week = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
tok_month = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
tok_total = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}

cost_today = 0.0
cost_week = 0.0
cost_month = 0.0
cost_total = 0.0

daily_token_map = {}
fine_token_map = {}
models_used = {}
prompts_today = 0
prompts_week = 0
prompts_month = 0
session_count = 0
recent_sessions = []

# Read settings
settings = {}
try:
    with open(PI_DIR / "settings.json") as f:
        settings = json.load(f)
except:
    pass

default_provider = settings.get("defaultProvider", "unknown")
default_model = settings.get("defaultModel", "unknown")
thinking_level = settings.get("defaultThinkingLevel", "")


def add_tokens(acc, inp, out, cr, cw):
    acc["input"] += inp
    acc["output"] += out
    acc["cache_read"] += cr
    acc["cache_write"] += cw


def parse_session_file(filepath):
    """Parse a single pi session JSONL file."""
    global prompts_today, prompts_week, prompts_month
    global cost_today, cost_week, cost_month, cost_total

    session_info = None
    session_tokens = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
    session_cost = 0.0
    session_model = default_model
    session_provider = default_provider
    session_start_ts = 0
    session_last_ts = 0
    session_title = ""
    model_counts = {}
    provider_map = {}
    prompt_count = 0

    try:
        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except:
                    continue

                msg_type = obj.get("type", "")
                ts_str = obj.get("timestamp", "")

                if msg_type == "session":
                    session_info = obj
                    session_start_ts = _parse_ts(ts_str)
                    cwd = obj.get("cwd", "")
                    session_title = os.path.basename(cwd) if cwd else filepath.stem[:20]
                    continue

                if msg_type == "model_change":
                    session_model = obj.get("modelId", session_model)
                    session_provider = obj.get("provider", session_provider)
                    continue

                if msg_type != "message":
                    continue

                message = obj.get("message", {})
                role = message.get("role", "")
                ts_ms = _parse_ts(ts_str)
                if ts_ms > session_last_ts:
                    session_last_ts = ts_ms

                # Count user prompts
                if role == "user":
                    prompt_count += 1
                    if ts_ms >= today_ts:
                        prompts_today += 1
                    if ts_ms >= week_ts:
                        prompts_week += 1
                    if ts_ms >= month_ts:
                        prompts_month += 1
                    # Try to get title from first user message
                    if not session_title or session_title == filepath.stem[:20]:
                        content = message.get("content", [])
                        if isinstance(content, list):
                            for item in content:
                                if isinstance(item, dict) and item.get("type") == "text":
                                    text = item.get("text", "")
                                    if text:
                                        session_title = text[:80]
                                    break
                        elif isinstance(content, str) and content:
                            session_title = content[:80]

                if role != "assistant":
                    continue

                usage = message.get("usage")
                if not usage:
                    continue

                inp = usage.get("input", 0)
                out = usage.get("output", 0)
                cr = usage.get("cacheRead", 0)
                cw = usage.get("cacheWrite", 0)
                model = message.get("model", session_model)
                provider = message.get("provider", session_provider)

                cost_info = usage.get("cost", {})
                msg_cost = cost_info.get("total", 0.0) if isinstance(cost_info, dict) else 0.0

                # Track models
                model_counts[model] = model_counts.get(model, 0) + 1
                provider_map[model] = provider

                # Accumulate session tokens
                add_tokens(session_tokens, inp, out, cr, cw)
                session_cost += msg_cost

                # Accumulate global tokens
                add_tokens(tok_total, inp, out, cr, cw)
                cost_total += msg_cost

                if ts_ms >= month_ts:
                    add_tokens(tok_month, inp, out, cr, cw)
                    cost_month += msg_cost
                if ts_ms >= week_ts:
                    add_tokens(tok_week, inp, out, cr, cw)
                    cost_week += msg_cost
                if ts_ms >= today_ts:
                    add_tokens(tok_today, inp, out, cr, cw)
                    cost_today += msg_cost

                # Model aggregation (global)
                if model not in models_used:
                    models_used[model] = {"input": 0, "output": 0, "cost": 0.0, "provider": provider}
                models_used[model]["input"] += inp + cr + cw
                models_used[model]["output"] += out
                models_used[model]["cost"] += msg_cost

                # Rate tracking
                if ts_ms >= rate_cutoff_ts:
                    recent_events.append((ts_ms, inp + cr + cw, out))

                # Daily bucket
                dt = datetime.fromtimestamp(ts_ms / 1000.0)
                day = dt.strftime("%Y-%m-%d")
                if day not in daily_token_map:
                    daily_token_map[day] = {"input": 0, "output": 0}
                daily_token_map[day]["input"] += inp + cr + cw
                daily_token_map[day]["output"] += out

                # Fine bucket (5-min)
                if ts_ms >= hourly_cutoff_ts:
                    minute = (dt.minute // FINE_BUCKET_MIN) * FINE_BUCKET_MIN
                    fine_key = f"{day} {dt.hour:02d}:{minute:02d}"
                    if fine_key not in fine_token_map:
                        fine_token_map[fine_key] = {"input": 0, "output": 0}
                    fine_token_map[fine_key]["input"] += inp + cr + cw
                    fine_token_map[fine_key]["output"] += out

    except Exception as e:
        pass

    # Determine dominant model
    dominant_model = session_model
    dominant_provider = session_provider
    if model_counts:
        dominant_model = max(model_counts.items(), key=lambda x: x[1])[0]
        dominant_provider = provider_map.get(dominant_model, session_provider)

    duration_min = (session_last_ts - session_start_ts) / 60000.0 if session_last_ts > session_start_ts else 0

    return {
        "id": session_info.get("id", "")[:12] if session_info else filepath.stem[:12],
        "title": session_title,
        "tokens": sum(session_tokens.values()),
        "input": session_tokens["input"] + session_tokens["cache_read"] + session_tokens["cache_write"],
        "output": session_tokens["output"],
        "cost": round(session_cost, 6),
        "model": dominant_model,
        "provider": dominant_provider,
        "duration_min": round(duration_min, 1),
        "start_ts": session_start_ts,
        "last_ts": session_last_ts,
        "prompts": prompt_count,
    }


def _parse_ts(ts_str):
    """Parse ISO timestamp to epoch ms."""
    try:
        if isinstance(ts_str, (int, float)):
            return float(ts_str)
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp() * 1000
    except:
        return 0


# --- Parse all session files ---
if SESSIONS_DIR.exists():
    for cwd_dir in sorted(SESSIONS_DIR.iterdir()):
        if not cwd_dir.is_dir():
            continue
        for session_file in sorted(cwd_dir.glob("*.jsonl")):
            session_count += 1
            info = parse_session_file(session_file)
            if info["tokens"] > 0:
                recent_sessions.append(info)

# Sort recent sessions by last activity, take top 8
recent_sessions.sort(key=lambda s: s.get("last_ts", 0), reverse=True)
recent_sessions = recent_sessions[:8]

# --- Build daily chart (8 days) ---
daily_tokens = []
for i in range(7, -1, -1):
    d = (now_local - timedelta(days=i)).strftime("%Y-%m-%d")
    entry = daily_token_map.get(d, {"input": 0, "output": 0})
    daily_tokens.append({"day": d, "input": entry["input"], "output": entry["output"]})

# --- Build fine chart (12h) ---
fine_tokens = []
base_dt = now_local.replace(second=0, microsecond=0)
base_minute = (base_dt.minute // FINE_BUCKET_MIN) * FINE_BUCKET_MIN
base_dt = base_dt.replace(minute=base_minute)
total_buckets = (HOURLY_WINDOW * 60) // FINE_BUCKET_MIN
for i in range(total_buckets - 1, -1, -1):
    dt_b = base_dt - timedelta(minutes=i * FINE_BUCKET_MIN)
    fine_key = f"{dt_b.strftime('%Y-%m-%d')} {dt_b.hour:02d}:{dt_b.minute:02d}"
    label = f"{dt_b.hour:02d}:{dt_b.minute:02d}"
    entry = fine_token_map.get(fine_key, {"input": 0, "output": 0})
    fine_tokens.append({"t": label, "input": entry["input"], "output": entry["output"]})

# --- Active sessions (check for running pi processes) ---
active_sessions = []
active_count = 0
try:
    # pi binary is a symlink to pi-coding-agent's cli.js, process name is just "pi"
    result = subprocess.run(["pgrep", "-x", "pi"], capture_output=True, text=True, timeout=2)
    seen_pids = set()
    for line in result.stdout.strip().split("\n"):
        if not line:
            continue
        try:
            pid = int(line.strip())
            if not os.path.exists(f"/proc/{pid}"):
                continue
            if pid in seen_pids:
                continue
            seen_pids.add(pid)
            active_count += 1
            # Collect child pids for I/O polling
            all_pids = [pid]
            try:
                children = subprocess.run(["pgrep", "-P", str(pid)], capture_output=True, text=True, timeout=1)
                for cline in children.stdout.strip().split("\n"):
                    if cline.strip():
                        cpid = int(cline.strip())
                        all_pids.append(cpid)
                        # Also get grandchildren (pi spawns node which spawns workers)
                        try:
                            grandchildren = subprocess.run(["pgrep", "-P", str(cpid)], capture_output=True, text=True, timeout=1)
                            for gline in grandchildren.stdout.strip().split("\n"):
                                if gline.strip():
                                    all_pids.append(int(gline.strip()))
                        except:
                            pass
            except:
                pass
            active_sessions.append({"pid": pid, "pids": all_pids, "cmd": "pi"})
        except:
            pass
except:
    pass

# --- Throughput rates ---
def calc_rate(window_ms, extract_fn):
    cutoff_r = now_ms - window_ms
    filtered = [(ts, extract_fn(inp, out)) for ts, inp, out in recent_events if ts >= cutoff_r]
    total = sum(v for _, v in filtered)
    if total == 0:
        return 0.0
    earliest = min(ts for ts, _ in filtered)
    span_h = max(now_ms - earliest, 60_000) / 3_600_000
    return total / span_h

if recent_events:
    rate_output_5m = calc_rate(RATE_WINDOW_SHORT, lambda i, o: o)
    rate_output_30m = calc_rate(RATE_WINDOW_LONG, lambda i, o: o)
    rate_all_5m = calc_rate(RATE_WINDOW_SHORT, lambda i, o: i + o)
    rate_all_30m = calc_rate(RATE_WINDOW_LONG, lambda i, o: i + o)
else:
    rate_output_5m = rate_output_30m = rate_all_5m = rate_all_30m = 0.0

print(json.dumps({
    "settings": {
        "provider": default_provider,
        "model": default_model,
        "thinking_level": thinking_level,
    },
    "sessions": {"active": active_count, "total": session_count},
    "prompts": {
        "today": prompts_today,
        "week": prompts_week,
        "month": prompts_month,
    },
    "tokens": {
        "today": tok_today,
        "week": tok_week,
        "month": tok_month,
        "total": tok_total,
    },
    "cost": {
        "today": round(cost_today, 4),
        "week": round(cost_week, 4),
        "month": round(cost_month, 4),
        "total": round(cost_total, 4),
    },
    "throughput": {
        "rate_output_5m": round(rate_output_5m),
        "rate_output_30m": round(rate_output_30m),
        "rate_all_5m": round(rate_all_5m),
        "rate_all_30m": round(rate_all_30m),
    },
    "daily_tokens": daily_tokens,
    "fine_tokens": fine_tokens,
    "recent_sessions": recent_sessions,
    "models_used": models_used,
    "active_sessions": active_sessions,
}))
