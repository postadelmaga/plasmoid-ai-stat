#!/usr/bin/env python3
# Parses local Claude Code data and outputs JSON for the plasmoid
# Sources: ~/.claude/.credentials.json, telemetry/, history.jsonl, sessions/

import json, os, glob, sys
from datetime import datetime, timedelta, timezone
json_loads = json.loads

# Simple arg parsing (avoids ~60ms argparse import)
input_limit_m = 0
output_limit_m = 0
i = 1
while i < len(sys.argv):
    if sys.argv[i] == "--input-limit" and i + 1 < len(sys.argv):
        input_limit_m = int(sys.argv[i + 1]); i += 2
    elif sys.argv[i] == "--output-limit" and i + 1 < len(sys.argv):
        output_limit_m = int(sys.argv[i + 1]); i += 2
    else:
        i += 1

claude_dir = os.path.expanduser("~/.claude")
creds_file = os.path.join(claude_dir, ".credentials.json")
history_file = os.path.join(claude_dir, "history.jsonl")
telemetry_dir = os.path.join(claude_dir, "telemetry")
sessions_dir = os.path.join(claude_dir, "sessions")
projects_dir = os.path.join(claude_dir, "projects")

cache_dir = os.path.expanduser("~/.cache/ai-stat")
daily_cache_file = os.path.join(cache_dir, "daily_tokens.json")
jsonl_cache_file = os.path.join(cache_dir, "jsonl_cache.json")

TIER_LIMITS = {
    "default_claude_max_5x": {"label": "Max 5x", "input_tokens_per_day": 1_500_000_000, "output_tokens_per_day": 150_000_000},
    "default_claude_max":    {"label": "Max",    "input_tokens_per_day": 300_000_000, "output_tokens_per_day": 30_000_000},
    "default_claude_pro":    {"label": "Pro",    "input_tokens_per_day": 100_000_000, "output_tokens_per_day": 10_000_000},
    "default_claude_team":   {"label": "Team",   "input_tokens_per_day": 200_000_000, "output_tokens_per_day": 20_000_000},
}

now_utc = datetime.now(timezone.utc)
now_ms = now_utc.timestamp() * 1000
now_local = datetime.now()

RL_DAY_START_HOUR_UTC = 2
rl_day_start = now_utc.replace(hour=RL_DAY_START_HOUR_UTC, minute=0, second=0, microsecond=0)
if now_utc < rl_day_start:
    rl_day_start -= timedelta(days=1)
rl_day_start_ms = rl_day_start.timestamp() * 1000

local_midnight = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
today_ts = local_midnight.timestamp() * 1000
week_ts = (local_midnight - timedelta(days=7)).timestamp() * 1000
month_ts = (local_midnight - timedelta(days=30)).timestamp() * 1000

WINDOW_HOURS = [5, 5, 5, 5, 4]
window_boundaries = []
cum_h = 0
for wh in WINDOW_HOURS:
    ws_ts = (rl_day_start + timedelta(hours=cum_h)).timestamp() * 1000
    cum_h += wh
    we_ts = (rl_day_start + timedelta(hours=cum_h)).timestamp() * 1000
    window_boundaries.append((ws_ts, we_ts))

current_window_idx = 0
for i, (ws, we) in enumerate(window_boundaries):
    if ws <= now_ms < we:
        current_window_idx = i
        break

cur_win_start = window_boundaries[current_window_idx][0]
cur_win_end = window_boundaries[current_window_idx][1]

# --- Credentials & tier ---
sub_type = "unknown"
tier = "unknown"
limits = None
try:
    with open(creds_file) as f:
        creds = json.load(f)
    oauth = creds.get("claudeAiOauth", {})
    sub_type = oauth.get("subscriptionType", "unknown")
    tier = oauth.get("rateLimitTier", "unknown")
    if tier in TIER_LIMITS:
        limits = TIER_LIMITS[tier]
    else:
        for k, v in TIER_LIMITS.items():
            if k in tier or tier in k:
                limits = v
                break
except:
    pass

if input_limit_m > 0:
    daily_in = input_limit_m * 1_000_000
elif limits:
    daily_in = limits["input_tokens_per_day"]
else:
    daily_in = 0

if output_limit_m > 0:
    daily_out = output_limit_m * 1_000_000
elif limits:
    daily_out = limits["output_tokens_per_day"]
else:
    daily_out = 0

# --- Accumulators ---
tok_today = {"input": 0, "output": 0, "cache_read": 0, "cache_create": 0}
tok_week = {"input": 0, "output": 0, "cache_read": 0, "cache_create": 0}
tok_month = {"input": 0, "output": 0, "cache_read": 0, "cache_create": 0}
tok_total = {"input": 0, "output": 0, "cache_read": 0, "cache_create": 0}
cost_today = 0.0
cost_week = 0.0
cost_total = 0.0
win_input = 0
win_output = 0

daily_token_cache = {}
try:
    with open(daily_cache_file) as f:
        daily_token_cache = json.load(f)
except:
    pass

jsonl_cache = {}
try:
    with open(jsonl_cache_file) as f:
        jsonl_cache = json.load(f)
except:
    pass

daily_token_map = {}
fine_token_map = {}
models_used = {}
prompts = {"today": 0, "week": 0, "month": 0, "total": 0}

HOURLY_WINDOW = 12
hourly_cutoff_ts = (now_utc - timedelta(hours=HOURLY_WINDOW)).timestamp() * 1000

RATE_WINDOW_SHORT = 5 * 60 * 1000
RATE_WINDOW_LONG = 30 * 60 * 1000
rate_cutoff_ts = now_ms - RATE_WINDOW_LONG
recent_events = []  # [(ts_ms, inp, out, cr, cc)]

def add_tokens_by_ts(ts_ms, inp, out, cr, cc):
    global win_input, win_output
    total_in = inp + cr + cc
    # Daily bucket (local time)
    try:
        dt = datetime.fromtimestamp(ts_ms / 1000)
        day = dt.strftime("%Y-%m-%d")
        if day not in daily_token_map:
            daily_token_map[day] = {"input": 0, "output": 0}
        daily_token_map[day]["input"] += total_in
        daily_token_map[day]["output"] += out
        # 5-minute bucket (only for recent hours)
        if ts_ms >= hourly_cutoff_ts:
            minute = (dt.minute // 5) * 5
            fine_key = f"{day} {dt.hour:02d}:{minute:02d}"
            if fine_key not in fine_token_map:
                fine_token_map[fine_key] = {"input": 0, "output": 0}
            fine_token_map[fine_key]["input"] += total_in
            fine_token_map[fine_key]["output"] += out
    except:
        pass
    # Period accumulators — early exit for old timestamps
    if ts_ms >= month_ts:
        tok_month["input"] += inp; tok_month["output"] += out
        tok_month["cache_read"] += cr; tok_month["cache_create"] += cc
        if ts_ms >= week_ts:
            tok_week["input"] += inp; tok_week["output"] += out
            tok_week["cache_read"] += cr; tok_week["cache_create"] += cc
            if ts_ms >= today_ts:
                tok_today["input"] += inp; tok_today["output"] += out
                tok_today["cache_read"] += cr; tok_today["cache_create"] += cc
    tok_total["input"] += inp; tok_total["output"] += out
    tok_total["cache_read"] += cr; tok_total["cache_create"] += cc
    # Session window
    if cur_win_start <= ts_ms < cur_win_end:
        win_input += total_in; win_output += out
    # Rate tracking — keep components separate for per-type rates
    if ts_ms >= rate_cutoff_ts:
        recent_events.append((ts_ms, inp, out, cr, cc))

def _parse_iso_ts(ts_str):
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp() * 1000
    except:
        return 0

# Compiled regexes for JSONL hot path (C engine, much faster than json.loads or char-by-char)
import re, calendar
_re_it = re.compile(r'"input_tokens"\s*:\s*(\d+)')
_re_ot = re.compile(r'"output_tokens"\s*:\s*(\d+)')
_re_cr = re.compile(r'"cache_read_input_tokens"\s*:\s*(\d+)')
_re_cc = re.compile(r'"cache_creation_input_tokens"\s*:\s*(\d+)')
_re_ts = re.compile(r'"timestamp"\s*:\s*"([^"]+)"')

def _re_int(m):
    return int(m.group(1)) if m else 0

def _fast_iso_epoch_ms(ts_str):
    """Parse ISO timestamp to epoch ms. Manual, no datetime.fromisoformat."""
    try:
        return int(calendar.timegm((int(ts_str[0:4]), int(ts_str[5:7]), int(ts_str[8:10]),
                                    int(ts_str[11:13]), int(ts_str[14:16]), int(ts_str[17:19]),
                                    0, 0, 0)) * 1000)
    except:
        return 0

def _parse_jsonl_to_days(fpath):
    """Parse a JSONL file → {day: [inp, out, cr, cc]}."""
    days = {}
    try:
        with open(fpath) as jf:
            for jline in jf:
                if '"usage"' not in jline:
                    continue
                m_inp = _re_int(_re_it.search(jline))
                m_out = _re_int(_re_ot.search(jline))
                m_cr = _re_int(_re_cr.search(jline))
                m_cc = _re_int(_re_cc.search(jline))
                if m_inp + m_out + m_cr + m_cc == 0:
                    continue
                ts_m = _re_ts.search(jline)
                ts_ms = _fast_iso_epoch_ms(ts_m.group(1)) if ts_m else now_ms
                add_tokens_by_ts(ts_ms, m_inp, m_out, m_cr, m_cc)
                # Accumulate per-day for cache
                try:
                    day = datetime.fromtimestamp(ts_ms / 1000).strftime("%Y-%m-%d")
                except:
                    continue
                if day not in days:
                    days[day] = [0, 0, 0, 0]
                d = days[day]
                d[0] += m_inp; d[1] += m_out; d[2] += m_cr; d[3] += m_cc
    except:
        pass
    return days

def _replay_cached_days(days_dict):
    """Replay cached per-day totals into global accumulators."""
    for day, vals in days_dict.items():
        # Use midday timestamp for period bucketing
        try:
            ts_ms = datetime.strptime(day, "%Y-%m-%d").replace(hour=12).timestamp() * 1000
        except:
            continue
        add_tokens_by_ts(ts_ms, vals[0], vals[1], vals[2], vals[3])

def _process_jsonl_cached(fpath):
    """Parse JSONL with file-level cache. Returns True if processed."""
    global jsonl_cache
    try:
        st = os.stat(fpath)
        mt = st.st_mtime
        sz = st.st_size
    except:
        return False
    cache_key = fpath
    cached = jsonl_cache.get(cache_key)
    if cached and cached.get("mt") == mt and cached.get("sz") == sz:
        _replay_cached_days(cached["d"])
        return True
    days = _parse_jsonl_to_days(fpath)
    jsonl_cache[cache_key] = {"mt": mt, "sz": sz, "d": days}
    return True

def _process_subagents_cached(proj_path, sid):
    """Parse all subagent JSONLs for a session, with cache."""
    sa_dir = os.path.join(proj_path, sid, "subagents")
    if os.path.isdir(sa_dir):
        for sa_fname in os.listdir(sa_dir):
            if sa_fname.endswith(".jsonl"):
                _process_jsonl_cached(os.path.join(sa_dir, sa_fname))

# --- Active sessions ---
active_session_ids = set()
active_sessions = []
active_count = 0
try:
    for fpath in glob.glob(os.path.join(sessions_dir, "*.json")):
        try:
            pid = int(os.path.basename(fpath).replace(".json", ""))
            if not os.path.exists(f"/proc/{pid}"):
                continue
            with open(fpath) as f:
                sess = json.load(f)
            sid = sess.get("sessionId", "")
            if sid:
                active_session_ids.add(sid)
            active_count += 1

            cwd = sess.get("cwd", "")
            started_at = sess.get("startedAt", 0)
            escaped_cwd = cwd.replace("/", "-")
            jsonl_path = os.path.join(projects_dir, escaped_cwd, sid + ".jsonl")

            sess_input = sess_output = sess_cr = sess_cc = sess_msgs = 0
            if os.path.exists(jsonl_path):
                with open(jsonl_path) as jf:
                    for jline in jf:
                        # No json.loads — compiled regex extraction (C engine)
                        if '"user"' in jline:
                            sess_msgs += 1
                            continue
                        if '"usage"' not in jline:
                            continue
                        m_inp = _re_int(_re_it.search(jline))
                        m_out = _re_int(_re_ot.search(jline))
                        m_cr = _re_int(_re_cr.search(jline))
                        m_cc = _re_int(_re_cc.search(jline))
                        if m_inp + m_out + m_cr + m_cc == 0:
                            continue
                        sess_input += m_inp; sess_output += m_out
                        sess_cr += m_cr; sess_cc += m_cc
                        ts_m = _re_ts.search(jline)
                        ts_ms = _fast_iso_epoch_ms(ts_m.group(1)) if ts_m else now_ms
                        add_tokens_by_ts(ts_ms, m_inp, m_out, m_cr, m_cc)

            # Subagent tokens for this active session
            sa_dir = os.path.join(projects_dir, escaped_cwd, sid, "subagents")
            if os.path.isdir(sa_dir):
                for sa_fname in os.listdir(sa_dir):
                    if not sa_fname.endswith(".jsonl"):
                        continue
                    sa_path = os.path.join(sa_dir, sa_fname)
                    sa_days = _parse_jsonl_to_days(sa_path)
                    for vals in sa_days.values():
                        sess_input += vals[0]; sess_output += vals[1]
                        sess_cr += vals[2]; sess_cc += vals[3]

            duration_min = round((now_ms - started_at) / 60000, 1) if started_at else 0
            jsonl_size = os.path.getsize(jsonl_path) if os.path.exists(jsonl_path) else 0
            active_sessions.append({
                "id": sid[:8],
                "tokens": sess_input + sess_output + sess_cr + sess_cc,
                "input": sess_input, "output": sess_output,
                "cache_read": sess_cr, "cache_create": sess_cc,
                "jsonl_path": jsonl_path,
                "jsonl_size": jsonl_size,
                "messages": sess_msgs,
                "duration_min": duration_min,
                "cwd": os.path.basename(cwd),
                "pid": pid,
            })
        except:
            pass
except:
    pass

# --- Completed sessions (JSONL scan — supplements broken/missing telemetry) ---
_month_cutoff_epoch = (now_utc - timedelta(days=30)).timestamp()
completed_session_ids = set()
try:
    for proj_dir in os.listdir(projects_dir):
        proj_path = os.path.join(projects_dir, proj_dir)
        if not os.path.isdir(proj_path):
            continue
        for fname in os.listdir(proj_path):
            if not fname.endswith(".jsonl"):
                continue
            sid = fname[:-6]
            if sid in active_session_ids:
                continue
            fpath = os.path.join(proj_path, fname)
            try:
                if os.path.getmtime(fpath) < _month_cutoff_epoch:
                    continue
            except:
                continue
            completed_session_ids.add(sid)
            _process_jsonl_cached(fpath)
            _process_subagents_cached(proj_path, sid)
except:
    pass

# --- History (prompt counts) — single pass ---
try:
    with open(history_file, "rb") as f:
        for line in f:
            prompts["total"] += 1
            # Only parse if line could contain a recent timestamp
            # History timestamps are ms epoch ints. We extract with rfind to avoid full JSON parse.
            line_s = line.strip()
            if not line_s:
                continue
            # Fast extraction: find "timestamp": in the line and parse just the number
            idx = line.find(b'"timestamp"')
            if idx < 0:
                continue
            # Extract digits after "timestamp":
            colon = line.find(b':', idx + 11)
            if colon < 0:
                continue
            # Find the number
            num_start = colon + 1
            while num_start < len(line) and line[num_start:num_start+1] in (b' ', b'\t'):
                num_start += 1
            num_end = num_start
            while num_end < len(line) and line[num_end:num_end+1].isdigit():
                num_end += 1
            if num_end == num_start:
                continue
            try:
                ts = int(line[num_start:num_end])
            except:
                continue
            if ts >= today_ts:
                prompts["today"] += 1
            if ts >= week_ts:
                prompts["week"] += 1
            if ts >= month_ts:
                prompts["month"] += 1
except:
    pass

# --- Telemetry (completed sessions) ---
seen_sessions = {}
try:
    for fpath in glob.glob(os.path.join(telemetry_dir, "*.json")):
        with open(fpath) as f:
            for line in f:
                if '"last_session_id"' not in line:
                    continue
                line = line.strip().rstrip(",")
                if not line or line in ("[", "]"):
                    continue
                try:
                    ev = json_loads(line)
                except:
                    continue
                ed = ev.get("event_data", {})
                meta_str = ed.get("additional_metadata", "")
                if not meta_str or '"last_session_id"' not in meta_str:
                    continue
                try:
                    meta = json_loads(meta_str)
                except:
                    continue
                session_id = meta.get("last_session_id", "")
                if not session_id or session_id in active_session_ids or session_id in completed_session_ids:
                    continue
                cost = meta.get("last_session_cost", 0)
                inp = meta.get("last_session_total_input_tokens", 0)
                out = meta.get("last_session_total_output_tokens", 0)
                cr = meta.get("last_session_total_cache_read_input_tokens", 0)
                cc = meta.get("last_session_total_cache_creation_input_tokens", 0)
                if not cost and not inp and not out:
                    continue
                total_tok = inp + out + cr + cc
                if session_id in seen_sessions:
                    if total_tok <= seen_sessions[session_id]["_total_tok"]:
                        continue
                seen_sessions[session_id] = {
                    "_total_tok": total_tok,
                    "cost": cost, "input": inp, "output": out,
                    "cache_read": cr, "cache_create": cc,
                    "model": ed.get("model", ""),
                    "timestamp": ed.get("client_timestamp", ""),
                    "duration": meta.get("last_session_duration", 0),
                    "lines_added": meta.get("last_session_lines_added", 0),
                    "lines_removed": meta.get("last_session_lines_removed", 0),
                }
except:
    pass

recent_sessions = []
for sid, s in seen_sessions.items():
    ev_ts = _parse_iso_ts(s["timestamp"]) if s["timestamp"] else now_ms
    add_tokens_by_ts(ev_ts, s["input"], s["output"], s["cache_read"], s["cache_create"])
    cost = s["cost"]
    if ev_ts >= today_ts:
        cost_today += cost
    if ev_ts >= week_ts:
        cost_week += cost
    cost_total += cost
    model = s["model"]
    if model:
        if model not in models_used:
            models_used[model] = {"input": 0, "output": 0, "cost": 0}
        models_used[model]["input"] += s["input"]
        models_used[model]["output"] += s["output"]
        models_used[model]["cost"] += cost
    if cost > 0:
        recent_sessions.append({
            "id": sid[:8], "cost": round(cost, 4), "tokens": s["_total_tok"],
            "duration_min": round(s["duration"] / 60000, 1) if s["duration"] else 0,
            "model": model, "timestamp": s["timestamp"],
            "lines_added": s["lines_added"], "lines_removed": s["lines_removed"],
        })

recent_sessions.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

# --- Merge daily data with cache ---
for day, vals in daily_token_cache.items():
    if day not in daily_token_map:
        daily_token_map[day] = vals

cutoff_day = (now_local - timedelta(days=90)).strftime("%Y-%m-%d")
daily_token_map = {d: v for d, v in daily_token_map.items() if d >= cutoff_day}

try:
    os.makedirs(cache_dir, exist_ok=True)
    with open(daily_cache_file, "w") as f:
        json.dump(daily_token_map, f)
    # Prune stale entries from jsonl_cache (files older than 90 days or deleted)
    _prune_cutoff = (now_utc - timedelta(days=90)).timestamp()
    jsonl_cache = {k: v for k, v in jsonl_cache.items()
                   if v.get("mt", 0) >= _prune_cutoff}
    with open(jsonl_cache_file, "w") as f:
        json.dump(jsonl_cache, f)
except:
    pass

# --- Build charts ---
daily_tokens = []
for i in range(7, -1, -1):
    d = (now_local - timedelta(days=i)).strftime("%Y-%m-%d")
    entry = daily_token_map.get(d, {"input": 0, "output": 0})
    daily_tokens.append({"day": d, "input": entry["input"], "output": entry["output"]})

# Fine-grained chart: pre-compute bucket keys in batch
FINE_BUCKET_MIN = 5
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

# --- Throughput (per-type rates) ---
# recent_events = [(ts_ms, inp, out, cr, cc), ...]
def calc_rate(window_ms, extract_fn):
    cutoff_r = now_ms - window_ms
    filtered = [(ts, extract_fn(inp, out, cr, cc))
                for ts, inp, out, cr, cc in recent_events if ts >= cutoff_r]
    total = sum(v for _, v in filtered)
    if total == 0:
        return 0.0
    earliest = min(ts for ts, _ in filtered)
    span_h = max(now_ms - earliest, 60_000) / 3_600_000
    return total / span_h

if recent_events:
    # Input non-cached: input + cache_create (work Claude does reading new context)
    rate_input_5m  = calc_rate(RATE_WINDOW_SHORT, lambda i,o,cr,cc: i + cc)
    rate_input_30m = calc_rate(RATE_WINDOW_LONG,  lambda i,o,cr,cc: i + cc)
    # Output: actual generated text
    rate_output_5m  = calc_rate(RATE_WINDOW_SHORT, lambda i,o,cr,cc: o)
    rate_output_30m = calc_rate(RATE_WINDOW_LONG,  lambda i,o,cr,cc: o)
    # All tokens (for quota tracking)
    rate_all_5m  = calc_rate(RATE_WINDOW_SHORT, lambda i,o,cr,cc: i + o + cr + cc)
    rate_all_30m = calc_rate(RATE_WINDOW_LONG,  lambda i,o,cr,cc: i + o + cr + cc)
else:
    rate_input_5m = rate_input_30m = 0.0
    rate_output_5m = rate_output_30m = 0.0
    rate_all_5m = rate_all_30m = 0.0

print(json.dumps({
    "subscription": {"type": sub_type, "tier": tier},
    "limits": limits,
    "sessions": {"active": active_count},
    "prompts": prompts,
    "tokens": {"today": tok_today, "week": tok_week, "month": tok_month, "total": tok_total},
    "est_cost": {"today": round(cost_today, 4), "week": round(cost_week, 4), "total": round(cost_total, 4)},
    "session_window": {
        "number": current_window_idx + 1, "total": len(WINDOW_HOURS),
        "end_ts": int(cur_win_end),
        "input_limit": daily_in // 5, "output_limit": daily_out // 5,
        "input_used": win_input, "output_used": win_output,
    },
    "daily_tokens": daily_tokens,
    "fine_tokens": fine_tokens,
    "throughput": {
        "rate_input_5m": round(rate_input_5m), "rate_input_30m": round(rate_input_30m),
        "rate_output_5m": round(rate_output_5m), "rate_output_30m": round(rate_output_30m),
        "rate_all_5m": round(rate_all_5m), "rate_all_30m": round(rate_all_30m),
    },
    "recent_sessions": recent_sessions[:8],
    "active_sessions": active_sessions,
    "models_used": models_used,
}))
