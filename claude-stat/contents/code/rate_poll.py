#!/usr/bin/env python3
"""Ultra-light rate poller. Avoids datetime import entirely.
Reads last 8KB of active session JONLs, outputs computed rate directly."""

import os, glob, time, calendar

now = time.time()
now_ms = int(now * 1000)
cutoff = now - 300  # 5 min ago (seconds)

sessions_dir = os.path.expanduser("~/.claude/sessions")
projects_dir = os.path.expanduser("~/.claude/projects")

total_tok = 0
earliest = now

def _extract(s, key):
    """Extract integer after "key": in string."""
    i = s.find(key)
    if i < 0: return 0
    i = s.find(":", i + len(key)) + 1
    while i < len(s) and s[i] in " \t": i += 1
    j = i
    while j < len(s) and s[j].isdigit(): j += 1
    return int(s[i:j]) if j > i else 0

def _iso_epoch(s):
    """Parse ISO timestamp to epoch seconds. Manual, no datetime."""
    # "2026-03-28T21:30:00.123Z" or "2026-03-28T21:30:00+00:00"
    try:
        return calendar.timegm((int(s[0:4]), int(s[5:7]), int(s[8:10]),
                                int(s[11:13]), int(s[14:16]), int(s[17:19]),
                                0, 0, 0))
    except:
        return 0

for sess_file in glob.glob(os.path.join(sessions_dir, "*.json")):
    try:
        pid = os.path.basename(sess_file)[:-5]
        if not pid.isdigit() or not os.path.exists("/proc/" + pid):
            continue
        with open(sess_file) as f:
            c = f.read()
        # Extract sessionId and cwd with string ops
        i = c.find('"sessionId":"')
        if i < 0: continue
        i += 14; j = c.find('"', i)
        sid = c[i:j]

        i = c.find('"cwd":"')
        if i < 0: continue
        i += 7; j = c.find('"', i)
        cwd = c[i:j].replace("/", "-")

        jsonl = os.path.join(projects_dir, cwd, sid + ".jsonl")
        if not os.path.exists(jsonl): continue

        fsize = os.path.getsize(jsonl)
        with open(jsonl) as jf:
            if fsize > 8192:
                jf.seek(fsize - 8192)
                jf.readline()
            for line in jf:
                if '"usage"' not in line: continue
                # Extract timestamp
                ti = line.find('"timestamp":"')
                if ti < 0: continue
                ti += 13
                tj = line.find('"', ti)
                ts = _iso_epoch(line[ti:tj])
                if ts < cutoff: continue
                if ts < earliest: earliest = ts

                tok = (_extract(line, '"input_tokens"') +
                       _extract(line, '"output_tokens"') +
                       _extract(line, '"cache_read_input_tokens"') +
                       _extract(line, '"cache_creation_input_tokens"'))
                total_tok += tok
    except:
        continue

# Compute rate directly
if total_tok > 0 and earliest < now:
    span_h = max(now - earliest, 60) / 3600
    rate = int(total_tok / span_h)
else:
    rate = 0

# Minimal JSON output — no json import needed
print('{"rate":' + str(rate) + '}')
