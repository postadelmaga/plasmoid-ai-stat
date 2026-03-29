#!/usr/bin/env python3
# Queries Gemini API status and model list without consuming quota
# Uses countTokens (free, no quota impact) instead of generateContent
# Usage: python3 gemini_stats.py <GEMINI_API_KEY>

import json, sys, urllib.request, urllib.error

if len(sys.argv) < 2 or not sys.argv[1]:
    print('{"error":"no_api_key"}')
    sys.exit(0)

api_key = sys.argv[1]
base_url = "https://generativelanguage.googleapis.com/v1beta"

result = {
    "ok": False,
    "plan": "unknown",
    "rate_limits": {},
    "rate_limited": False,
    "models": [],
}

# 1. Use countTokens to check API status (free, no quota impact)
url = f"{base_url}/models/gemini-2.0-flash:countTokens?key={api_key}"
payload = json.dumps({
    "contents": [{"parts": [{"text": "hi"}]}]
}).encode()

try:
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    resp = urllib.request.urlopen(req)

    # Extract any rate limit headers (may not always be present)
    rl = {}
    for k, v in resp.headers.items():
        kl = k.lower()
        if "ratelimit" in kl:
            try:
                rl[kl] = int(v)
            except:
                rl[kl] = v

    result["rate_limits"] = rl
    result["ok"] = True

except urllib.error.HTTPError as e:
    if e.code == 429:
        result["rate_limited"] = True
        result["ok"] = True
        # Try to extract rate limit headers from 429
        if e.headers:
            rl = {}
            for k, v in e.headers.items():
                kl = k.lower()
                if "ratelimit" in kl:
                    try:
                        rl[kl] = int(v)
                    except:
                        rl[kl] = v
            result["rate_limits"] = rl
    else:
        result["error"] = f"HTTP {e.code}"
except Exception as e:
    result["error"] = str(e)

# 2. List models (lightweight, no quota impact)
try:
    models_url = f"{base_url}/models?key={api_key}"
    req2 = urllib.request.Request(models_url)
    resp2 = urllib.request.urlopen(req2)
    models_data = json.loads(resp2.read().decode())

    seen = {}
    for m in models_data.get("models", []):
        name = m.get("name", "").replace("models/", "")
        if "gemini" not in name:
            continue
        if not any(x in name for x in ("flash", "pro")):
            continue
        base = "-".join(name.split("-")[0:3])
        seen[base] = {
            "name": name,
            "input_limit": m.get("inputTokenLimit", 0),
            "output_limit": m.get("outputTokenLimit", 0),
        }
    result["models"] = list(seen.values())[:6]

    # Detect plan from model availability
    if any("pro" in m["name"] for m in result["models"]):
        result["plan"] = "developer"
    else:
        result["plan"] = "free"
except:
    pass

print(json.dumps(result))
