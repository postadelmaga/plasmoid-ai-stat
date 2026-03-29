#!/usr/bin/env python3
"""Queries Antigravity IDE's local language server API for usage stats."""

import json, os, subprocess, sys, re
from datetime import datetime, timedelta, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError

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

def _parse_iso_ts(ts_str):
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp() * 1000
    except:
        return 0

def _api_call(port, csrf, method, body=None):
    url = f"http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/{method}"
    data = json.dumps(body or {}).encode()
    req = Request(url, data=data, headers={
        "Content-Type": "application/json",
        "X-Codeium-Csrf-Token": csrf,
    })
    try:
        with urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except:
        return None

# --- Find language server ---
csrf = ""
port = 0
ls_pid = 0
try:
    result = subprocess.run(["pgrep", "-af", "language_server_linux_x64"], capture_output=True, text=True, timeout=2)
    for line in result.stdout.strip().split("\n"):
        if not line or "pgrep" in line:
            continue
        parts = line.split(None, 1)
        if not parts:
            continue
        ls_pid = int(parts[0])
        cmdline = parts[1] if len(parts) > 1 else ""
        # Extract CSRF token
        m = re.search(r'--csrf_token\s+(\S+)', cmdline)
        if m:
            csrf = m.group(1)
        break
except:
    pass

if ls_pid and csrf:
    # Find HTTP port via ss
    try:
        result = subprocess.run(["ss", "-tlnp"], capture_output=True, text=True, timeout=2)
        for line in result.stdout.strip().split("\n"):
            if f"pid={ls_pid}" in line:
                m = re.search(r':(\d+)\s', line)
                if m:
                    test_port = int(m.group(1))
                    # Test if it responds to HTTP
                    try:
                        resp = _api_call(test_port, csrf, "GetUserStatus")
                        if resp and "userStatus" in resp:
                            port = test_port
                            break
                    except:
                        continue
    except:
        pass

if not port or not csrf:
    print(json.dumps({"error": "Antigravity not running or language server not found"}))
    sys.exit(0)

# --- Get user status ---
status_resp = _api_call(port, csrf, "GetUserStatus")
user_status = (status_resp or {}).get("userStatus", {})
plan_status = user_status.get("planStatus", {})
plan_info = plan_status.get("planInfo", {})

plan_name = plan_info.get("planName", "")
prompt_credits = plan_status.get("availablePromptCredits", 0)
prompt_credits_max = plan_info.get("monthlyPromptCredits", 0)
flow_credits = plan_status.get("availableFlowCredits", 0)
flow_credits_max = plan_info.get("monthlyFlowCredits", 0)
email = user_status.get("email", "")

# Model quotas
models = []
for mc in user_status.get("cascadeModelConfigData", {}).get("clientModelConfigs", []):
    qi = mc.get("quotaInfo", {})
    models.append({
        "label": mc.get("label", ""),
        "remaining": qi.get("remainingFraction", 0),
        "reset": qi.get("resetTime", ""),
    })

# --- Get conversations and token usage ---
trajs_resp = _api_call(port, csrf, "GetAllCascadeTrajectories")
trajectories = (trajs_resp or {}).get("trajectorySummaries", {})

tok_today = {"input": 0, "output": 0}
tok_week = {"input": 0, "output": 0}
tok_month = {"input": 0, "output": 0}
tok_all = {"input": 0, "output": 0}
daily_token_map = {}
fine_token_map = {}
models_used = {}
recent_sessions = []

for cascade_id, traj in trajectories.items():
    steps_resp = _api_call(port, csrf, "GetCascadeTrajectorySteps", {
        "cascadeId": cascade_id,
        "startIndex": 0,
        "endIndex": int(traj.get("stepCount", 100)),
    })
    if not steps_resp:
        continue

    sess_input = 0
    sess_output = 0
    sess_model = ""

    for step in steps_resp.get("steps", []):
        usage = (step.get("metadata") or {}).get("modelUsage")
        if not usage:
            continue

        inp = int(usage.get("inputTokens", 0))
        out = int(usage.get("outputTokens", 0))
        model = usage.get("model", "")
        ts_str = (step.get("metadata") or {}).get("createdAt", "")
        ts_ms = _parse_iso_ts(ts_str)

        sess_input += inp
        sess_output += out
        if model:
            sess_model = model
            if model not in models_used:
                models_used[model] = {"input": 0, "output": 0}
            models_used[model]["input"] += inp
            models_used[model]["output"] += out

        tok_all["input"] += inp
        tok_all["output"] += out

        if ts_ms >= rate_cutoff_ts:
            recent_events.append((ts_ms, inp, out))

        if ts_ms >= month_ts:
            tok_month["input"] += inp; tok_month["output"] += out
            if ts_ms >= week_ts:
                tok_week["input"] += inp; tok_week["output"] += out
                if ts_ms >= today_ts:
                    tok_today["input"] += inp; tok_today["output"] += out

        # Daily/fine buckets
        if ts_ms > 0:
            try:
                dt = datetime.fromtimestamp(ts_ms / 1000)
                day = dt.strftime("%Y-%m-%d")
                if day not in daily_token_map:
                    daily_token_map[day] = {"input": 0, "output": 0}
                daily_token_map[day]["input"] += inp
                daily_token_map[day]["output"] += out

                if ts_ms >= hourly_cutoff_ts:
                    minute = (dt.minute // FINE_BUCKET_MIN) * FINE_BUCKET_MIN
                    fine_key = f"{day} {dt.hour:02d}:{minute:02d}"
                    if fine_key not in fine_token_map:
                        fine_token_map[fine_key] = {"input": 0, "output": 0}
                    fine_token_map[fine_key]["input"] += inp
                    fine_token_map[fine_key]["output"] += out
            except:
                pass

    if sess_input + sess_output > 0:
        recent_sessions.append({
            "id": cascade_id[:8],
            "title": traj.get("summary", ""),
            "tokens": sess_input + sess_output,
            "input": sess_input,
            "output": sess_output,
            "model": sess_model,
            "timestamp": traj.get("lastModifiedTime", ""),
        })

recent_sessions.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

# --- Build charts ---
daily_tokens = []
for i in range(7, -1, -1):
    d = (now_local - timedelta(days=i)).strftime("%Y-%m-%d")
    entry = daily_token_map.get(d, {"input": 0, "output": 0})
    daily_tokens.append({"day": d, "input": entry["input"], "output": entry["output"]})

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
    "ok": True,
    "email": email,
    "plan": plan_name,
    "credits": {
        "prompt": prompt_credits,
        "prompt_max": prompt_credits_max,
        "flow": flow_credits,
        "flow_max": flow_credits_max,
    },
    "models": models,
    "tokens": {
        "today": tok_today,
        "week": tok_week,
        "month": tok_month,
        "total": tok_all,
    },
    "throughput": {
        "rate_output_5m": round(rate_output_5m),
        "rate_output_30m": round(rate_output_30m),
        "rate_all_5m": round(rate_all_5m),
        "rate_all_30m": round(rate_all_30m),
    },
    "daily_tokens": daily_tokens,
    "fine_tokens": fine_tokens,
    "recent_sessions": recent_sessions[:8],
    "models_used": models_used,
    "pid": ls_pid,
    "port": port,
    "csrf": csrf,
}))
