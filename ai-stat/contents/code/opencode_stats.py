#!/usr/bin/env python3
# Parses local OpenCode SQLite data and outputs JSON for the plasmoid

import json, os, sys, sqlite3
from datetime import datetime, timedelta, timezone

db_path = os.path.expanduser("~/.local/share/opencode/opencode.db")

now_utc = datetime.now(timezone.utc)
now_ms = now_utc.timestamp() * 1000
now_local = datetime.now()

local_midnight = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
today_ts = local_midnight.timestamp() * 1000
week_ts = (local_midnight - timedelta(days=7)).timestamp() * 1000
month_ts = (local_midnight - timedelta(days=30)).timestamp() * 1000

HOURLY_WINDOW = 12
hourly_cutoff_ts = (now_utc - timedelta(hours=HOURLY_WINDOW)).timestamp() * 1000

tok_today = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
tok_week = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
tok_month = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
tok_total = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}

daily_token_map = {}
fine_token_map = {}
models_used = {}
session_count = 0
recent_sessions = []

FINE_BUCKET_MIN = 5

RATE_WINDOW_SHORT = 5 * 60 * 1000
RATE_WINDOW_LONG = 30 * 60 * 1000
rate_cutoff_ts = now_ms - RATE_WINDOW_LONG
recent_events = []  # [(ts_ms, inp, out)]

def add_tokens(acc, inp, out, cr, cw):
    acc["input"] += inp
    acc["output"] += out
    acc["cache_read"] += cr
    acc["cache_write"] += cw

try:
    conn = sqlite3.connect('file:' + db_path + '?mode=ro', uri=True)
    conn.execute("PRAGMA busy_timeout=1000")
    conn.row_factory = sqlite3.Row

    # --- Parse messages ---
    cursor = conn.cursor()
    cursor.execute("""
        SELECT time_created, data 
        FROM message 
        WHERE json_extract(data,'$.role')='assistant' 
          AND json_extract(data,'$.tokens.total') > 0 
        ORDER BY time_created
    """)
    
    for row in cursor:
        try:
            ts_ms = row["time_created"]
            data = json.loads(row["data"])
            
            tokens = data.get("tokens", {})
            inp = tokens.get("input", 0)
            out = tokens.get("output", 0)
            cache = tokens.get("cache", {})
            cr = cache.get("read", 0)
            cw = cache.get("write", 0)
            
            model = data.get("modelID", "unknown")
            provider = data.get("providerID", "unknown")
            
            # Accumulate totals
            add_tokens(tok_total, inp, out, cr, cw)
            if ts_ms >= month_ts:
                add_tokens(tok_month, inp, out, cr, cw)
            if ts_ms >= week_ts:
                add_tokens(tok_week, inp, out, cr, cw)
            if ts_ms >= today_ts:
                add_tokens(tok_today, inp, out, cr, cw)
                
            # Model aggregation
            if model not in models_used:
                models_used[model] = {"input": 0, "output": 0, "provider": provider}
            models_used[model]["input"] += inp + cr + cw
            models_used[model]["output"] += out
            
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

    # --- Parse sessions ---
    cursor.execute("SELECT count(*) as cnt FROM session WHERE parent_id IS NULL")
    session_count = cursor.fetchone()["cnt"]
    
    cursor.execute("""
        SELECT id, title, time_created, time_updated 
        FROM session 
        WHERE parent_id IS NULL 
        ORDER BY time_updated DESC 
        LIMIT 8
    """)
    
    for row in cursor:
        try:
            session_id = row["id"]
            title = row["title"] or "Untitled"
            time_created = row["time_created"]
            time_updated = row["time_updated"]
            
            # Get tokens for this session
            cursor.execute("""
                SELECT data
                FROM message 
                WHERE session_id=? AND json_extract(data,'$.role')='assistant'
                  AND json_extract(data,'$.tokens.total') > 0
            """, (session_id,))
            
            s_inp = 0
            s_out = 0
            s_cr = 0
            s_cw = 0
            model_counts = {}
            provider_map = {}
            
            for msg_row in cursor:
                try:
                    data = json.loads(msg_row["data"])
                    tokens = data.get("tokens", {})
                    s_inp += tokens.get("input", 0)
                    s_out += tokens.get("output", 0)
                    cache = tokens.get("cache", {})
                    s_cr += cache.get("read", 0)
                    s_cw += cache.get("write", 0)
                    
                    model = data.get("modelID", "unknown")
                    provider = data.get("providerID", "unknown")
                    model_counts[model] = model_counts.get(model, 0) + 1
                    provider_map[model] = provider
                except:
                    pass
                    
            dominant_model = "unknown"
            dominant_provider = "unknown"
            if model_counts:
                dominant_model = max(model_counts.items(), key=lambda x: x[1])[0]
                dominant_provider = provider_map.get(dominant_model, "unknown")
                
            duration_min = (time_updated - time_created) / 60000.0
            
            recent_sessions.append({
                "id": session_id[:12],
                "title": title,
                "tokens": s_inp + s_out + s_cr + s_cw,
                "input": s_inp + s_cr + s_cw,
                "output": s_out,
                "model": dominant_model,
                "provider": dominant_provider,
                "duration_min": round(duration_min, 1)
            })
        except:
            pass
            
    conn.close()
except Exception as e:
    pass

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

# --- Active sessions (check for running opencode processes) ---
active_sessions = []
active_count = 0
try:
    import subprocess
    result = subprocess.run(["pgrep", "-af", "opencode"], capture_output=True, text=True, timeout=2)
    seen_pids = set()
    for line in result.stdout.strip().split("\n"):
        if not line or "pgrep" in line or "opencode_stats" in line:
            continue
        if "opencode" not in line.lower():
            continue
        parts = line.split(None, 1)
        if not parts:
            continue
        try:
            pid = int(parts[0])
            if not os.path.exists(f"/proc/{pid}"):
                continue
            # Skip child processes — only count the parent (ppid != another opencode pid)
            ppid_file = f"/proc/{pid}/stat"
            with open(ppid_file) as pf:
                stat_fields = pf.read().split()
                ppid = int(stat_fields[3])
            if ppid in seen_pids:
                continue  # child of another opencode process
            seen_pids.add(pid)
            active_count += 1
            # Collect this pid + all child pids for I/O polling
            all_pids = [pid]
            try:
                children = subprocess.run(["pgrep", "-P", str(pid)], capture_output=True, text=True, timeout=1)
                for cline in children.stdout.strip().split("\n"):
                    if cline.strip():
                        all_pids.append(int(cline.strip()))
            except:
                pass
            active_sessions.append({"pid": pid, "pids": all_pids, "cmd": parts[1] if len(parts) > 1 else ""})
        except:
            pass
except:
    pass

# --- Throughput rates ---
def calc_rate(window_ms, extract_fn):
    cutoff_r = now_ms - window_ms
    filtered = [(ts, extract_fn(inp, out)) for ts, inp, out in recent_events if ts >= cutoff_r]
    total = sum(v for _, v in filtered)
    if total == 0: return 0.0
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
    "sessions": {"active": active_count, "total": session_count},
    "tokens": {
        "today": tok_today,
        "week": tok_week,
        "month": tok_month,
        "total": tok_total,
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
