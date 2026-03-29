#!/usr/bin/env python3
# Parses local Gemini CLI data (~/.gemini/) and outputs JSON for the plasmoid
# Mirrors the structure of local_stats.py for Claude

import json, os, glob, sys
from datetime import datetime, timedelta, timezone

gemini_dir = os.path.expanduser("~/.gemini")
tmp_dir = os.path.join(gemini_dir, "tmp")
projects_file = os.path.join(gemini_dir, "projects.json")
accounts_file = os.path.join(gemini_dir, "google_accounts.json")

now_utc = datetime.now(timezone.utc)
now_ms = now_utc.timestamp() * 1000
now_local = datetime.now()

local_midnight = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
today_ts = local_midnight.timestamp() * 1000
week_ts = (local_midnight - timedelta(days=7)).timestamp() * 1000
month_ts = (local_midnight - timedelta(days=30)).timestamp() * 1000

HOURLY_WINDOW = 12
hourly_cutoff_ts = (now_utc - timedelta(hours=HOURLY_WINDOW)).timestamp() * 1000

# --- Account ---
account = ""
try:
    with open(accounts_file) as f:
        acc = json.load(f)
    if isinstance(acc, dict):
        account = acc.get("email", "")
    elif isinstance(acc, list) and acc:
        account = acc[0] if isinstance(acc[0], str) else acc[0].get("email", "")
except:
    pass

# --- Accumulators ---
tok_today = {"input": 0, "output": 0, "cached": 0, "thoughts": 0, "tool": 0, "total": 0}
tok_week = {"input": 0, "output": 0, "cached": 0, "thoughts": 0, "tool": 0, "total": 0}
tok_month = {"input": 0, "output": 0, "cached": 0, "thoughts": 0, "tool": 0, "total": 0}
tok_all = {"input": 0, "output": 0, "cached": 0, "thoughts": 0, "tool": 0, "total": 0}

daily_token_map = {}
fine_token_map = {}
models_used = {}
prompts = {"today": 0, "week": 0, "month": 0, "total": 0}
session_count = 0
recent_sessions = []

FINE_BUCKET_MIN = 5

def _parse_iso_ts(ts_str):
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp() * 1000
    except:
        return 0

def add_tokens(ts_ms, tokens):
    """Add token counts to accumulators by timestamp."""
    inp = tokens.get("input", 0)
    out = tokens.get("output", 0)
    cached = tokens.get("cached", 0)
    thoughts = tokens.get("thoughts", 0)
    tool = tokens.get("tool", 0)
    total = tokens.get("total", 0)

    tok_all["input"] += inp; tok_all["output"] += out; tok_all["cached"] += cached
    tok_all["thoughts"] += thoughts; tok_all["tool"] += tool; tok_all["total"] += total

    if ts_ms >= month_ts:
        tok_month["input"] += inp; tok_month["output"] += out; tok_month["cached"] += cached
        tok_month["thoughts"] += thoughts; tok_month["tool"] += tool; tok_month["total"] += total
        if ts_ms >= week_ts:
            tok_week["input"] += inp; tok_week["output"] += out; tok_week["cached"] += cached
            tok_week["thoughts"] += thoughts; tok_week["tool"] += tool; tok_week["total"] += total
            if ts_ms >= today_ts:
                tok_today["input"] += inp; tok_today["output"] += out; tok_today["cached"] += cached
                tok_today["thoughts"] += thoughts; tok_today["tool"] += tool; tok_today["total"] += total

    # Daily bucket
    try:
        dt = datetime.fromtimestamp(ts_ms / 1000)
        day = dt.strftime("%Y-%m-%d")
        if day not in daily_token_map:
            daily_token_map[day] = {"input": 0, "output": 0}
        daily_token_map[day]["input"] += inp + cached + thoughts + tool
        daily_token_map[day]["output"] += out

        # Fine bucket (5-min)
        if ts_ms >= hourly_cutoff_ts:
            minute = (dt.minute // FINE_BUCKET_MIN) * FINE_BUCKET_MIN
            fine_key = f"{day} {dt.hour:02d}:{minute:02d}"
            if fine_key not in fine_token_map:
                fine_token_map[fine_key] = {"input": 0, "output": 0}
            fine_token_map[fine_key]["input"] += inp + cached + thoughts + tool
            fine_token_map[fine_key]["output"] += out
    except:
        pass

# --- Parse all chat sessions ---
try:
    for chat_file in glob.glob(os.path.join(tmp_dir, "*/chats/session-*.json")):
        try:
            with open(chat_file) as f:
                session = json.load(f)

            messages = session.get("messages", [])
            if not messages:
                continue

            session_count += 1
            sess_tokens = 0
            sess_model = ""
            sess_start = session.get("startTime", "")
            sess_updated = session.get("lastUpdated", "")
            sess_project = ""

            # Extract project name from path
            parts = chat_file.split("/chats/")
            if parts:
                sess_project = os.path.basename(parts[0])

            for msg in messages:
                msg_type = msg.get("type", "")
                ts_str = msg.get("timestamp", "")
                ts_ms = _parse_iso_ts(ts_str) if ts_str else 0

                if msg_type == "user":
                    prompts["total"] += 1
                    if ts_ms >= today_ts: prompts["today"] += 1
                    if ts_ms >= week_ts: prompts["week"] += 1
                    if ts_ms >= month_ts: prompts["month"] += 1
                    continue

                if msg_type != "gemini":
                    continue

                tokens = msg.get("tokens")
                if not tokens:
                    continue

                model = msg.get("model", "")
                if model:
                    sess_model = model
                    if model not in models_used:
                        models_used[model] = {"input": 0, "output": 0, "total": 0, "cached": 0, "thoughts": 0}
                    models_used[model]["input"] += tokens.get("input", 0)
                    models_used[model]["output"] += tokens.get("output", 0)
                    models_used[model]["total"] += tokens.get("total", 0)
                    models_used[model]["cached"] += tokens.get("cached", 0)
                    models_used[model]["thoughts"] += tokens.get("thoughts", 0)

                sess_tokens += tokens.get("total", 0)
                add_tokens(ts_ms, tokens)

            # Add to recent sessions
            if sess_tokens > 0:
                start_ts = _parse_iso_ts(sess_start)
                updated_ts = _parse_iso_ts(sess_updated)
                duration_min = (updated_ts - start_ts) / 60000 if start_ts and updated_ts else 0
                recent_sessions.append({
                    "id": session.get("sessionId", "")[:8],
                    "tokens": sess_tokens,
                    "model": sess_model,
                    "timestamp": sess_updated or sess_start,
                    "duration_min": round(duration_min, 1),
                    "project": sess_project,
                })
        except:
            pass
except:
    pass

recent_sessions.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

# --- Build daily chart (last 8 days) ---
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

# --- Active sessions (check for running gemini processes) ---
active_sessions = []
active_count = 0
try:
    import subprocess
    result = subprocess.run(["pgrep", "-af", "gemini"], capture_output=True, text=True, timeout=2)
    for line in result.stdout.strip().split("\n"):
        if line and "gemini" in line.lower() and "pgrep" not in line and "gemini_local_stats" not in line:
            parts = line.split(None, 1)
            if parts:
                try:
                    pid = int(parts[0])
                    if os.path.exists(f"/proc/{pid}"):
                        active_count += 1
                        active_sessions.append({"pid": pid, "cmd": parts[1] if len(parts) > 1 else ""})
                except:
                    pass
except:
    pass

print(json.dumps({
    "account": account,
    "sessions": {"active": active_count, "total": session_count},
    "prompts": prompts,
    "tokens": {
        "today": tok_today,
        "week": tok_week,
        "month": tok_month,
        "total": tok_all,
    },
    "daily_tokens": daily_tokens,
    "fine_tokens": fine_tokens,
    "recent_sessions": recent_sessions[:8],
    "active_sessions": active_sessions,
    "models_used": models_used,
}))
