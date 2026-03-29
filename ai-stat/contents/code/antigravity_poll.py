#!/usr/bin/env python3
"""Lightweight poll for Antigravity activity status (~20ms).
Called every 2s by QML for tachometer. Returns running status + step delta."""

import json, os, subprocess, sys, re
from urllib.request import Request, urlopen

CACHE_DIR = os.path.expanduser("~/.cache/ai-stat")
CACHE_FILE = os.path.join(CACHE_DIR, "ag_poll_state.json")
CONN_CACHE = os.path.join(CACHE_DIR, "ag_conn.json")

def _api_call(port, csrf, method, body=None):
    url = f"http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/{method}"
    data = json.dumps(body or {}).encode()
    req = Request(url, data=data, headers={
        "Content-Type": "application/json",
        "X-Codeium-Csrf-Token": csrf,
    })
    try:
        with urlopen(req, timeout=3) as resp:
            return json.loads(resp.read())
    except:
        return None

# Find language server — use cached connection if available
csrf = ""
port = 0

def _discover():
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
            m = re.search(r'--csrf_token\s+(\S+)', cmdline)
            if not m:
                continue
            _csrf = m.group(1)
            ss_result = subprocess.run(["ss", "-tlnp"], capture_output=True, text=True, timeout=2)
            for sl in ss_result.stdout.strip().split("\n"):
                if f"pid={ls_pid}" in sl:
                    pm = re.search(r':(\d+)\s', sl)
                    if pm:
                        _port = int(pm.group(1))
                        resp = _api_call(_port, _csrf, "GetUserStatus")
                        if resp and "userStatus" in resp:
                            os.makedirs(CACHE_DIR, exist_ok=True)
                            with open(CONN_CACHE, "w") as f:
                                json.dump({"port": _port, "csrf": _csrf}, f)
                            return _port, _csrf
    except:
        pass
    return 0, ""

# Try cached connection first
try:
    with open(CONN_CACHE) as f:
        cc = json.load(f)
    port, csrf = cc["port"], cc["csrf"]
    resp = _api_call(port, csrf, "GetAllCascadeTrajectories")
    if not resp or "trajectorySummaries" not in resp:
        port, csrf = 0, ""
except:
    pass

if not port:
    port, csrf = _discover()

if not port or not csrf:
    print(json.dumps({"running": False, "rate": 0}))
    sys.exit(0)

# Get trajectories status
resp = _api_call(port, csrf, "GetAllCascadeTrajectories")
if not resp:
    print(json.dumps({"running": False, "rate": 0}))
    sys.exit(0)

# Check if any trajectory is running and track step counts
is_running = False
total_steps = 0
active_id = ""
for cid, traj in resp.get("trajectorySummaries", {}).items():
    status = traj.get("status", "")
    steps = int(traj.get("stepCount", 0))
    total_steps += steps
    if "RUNNING" in status:
        is_running = True
        active_id = cid

# Load previous state for delta calculation
prev_steps = 0
try:
    with open(CACHE_FILE) as f:
        prev = json.load(f)
    prev_steps = prev.get("total_steps", 0)
except:
    pass

# Save current state
try:
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump({"total_steps": total_steps}, f)
except:
    pass

# Rate: steps added since last poll (higher = more active)
step_delta = max(0, total_steps - prev_steps)

# Get token delta from the active conversation's latest checkpoint
tok_delta = 0
if active_id and step_delta > 0:
    steps_resp = _api_call(port, csrf, "GetCascadeTrajectorySteps", {
        "cascadeId": active_id,
        "startIndex": max(0, int(resp["trajectorySummaries"][active_id].get("stepCount", 0)) - step_delta - 2),
        "endIndex": int(resp["trajectorySummaries"][active_id].get("stepCount", 0)),
    })
    if steps_resp:
        for s in steps_resp.get("steps", []):
            usage = (s.get("metadata") or {}).get("modelUsage")
            if usage:
                tok_delta += int(usage.get("inputTokens", 0)) + int(usage.get("outputTokens", 0))

print(json.dumps({
    "running": is_running,
    "step_delta": step_delta,
    "tok_delta": tok_delta,
    "rate": min(1.0, step_delta / 5.0) if is_running else (0.3 if step_delta > 0 else 0),
}))
