#!/usr/bin/python3
# Parses GitHub Copilot CLI data and outputs JSON for the plasmoid
# Sources: ~/.copilot/session-store.db, ~/.copilot/config.json

import json
import os
import sqlite3
from datetime import datetime, timedelta, timezone


copilot_dir = os.path.expanduser("~/.copilot")
db_path = os.path.join(copilot_dir, "session-store.db")
config_path = os.path.join(copilot_dir, "config.json")

now_utc = datetime.now(timezone.utc)
today_start_utc = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)
week_ago_utc = today_start_utc - timedelta(days=7)
month_ago_utc = today_start_utc - timedelta(days=30)
active_cutoff_utc = now_utc - timedelta(minutes=30)
hourly_cutoff_utc = now_utc - timedelta(hours=12)
FINE_BUCKET_MIN = 5


def iso_utc(dt):
    return dt.replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z")


def parse_iso(ts):
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def short_project_label(cwd, repo):
    if repo:
        return repo
    if not cwd:
        return ""
    parts = cwd.rstrip("/").split("/")
    if len(parts) >= 2:
        return "…/" + "/".join(parts[-2:])
    return parts[-1] if parts else cwd


result = {
    "user": "",
    "sessions": {"active": 0, "today": 0, "week": 0, "month": 0, "total": 0},
    "turns": {"today": 0, "week": 0, "month": 0, "total": 0},
    "daily_turns": [],
    "fine_turns": [],
    "recent_sessions": [],
}


# Read config for user info
try:
    with open(config_path, encoding="utf-8") as f:
        config = json.load(f)
    user_info = config.get("last_logged_in_user", {})
    result["user"] = user_info.get("login", "")
except (OSError, json.JSONDecodeError, TypeError):
    pass


if os.path.exists(db_path):
    try:
        conn = sqlite3.connect(db_path)
        c = conn.cursor()

        c.execute("SELECT COUNT(*) FROM sessions")
        result["sessions"]["total"] = c.fetchone()[0]

        c.execute("SELECT COUNT(*) FROM sessions WHERE created_at >= ?", (iso_utc(today_start_utc),))
        result["sessions"]["today"] = c.fetchone()[0]

        c.execute("SELECT COUNT(*) FROM sessions WHERE created_at >= ?", (iso_utc(week_ago_utc),))
        result["sessions"]["week"] = c.fetchone()[0]

        c.execute("SELECT COUNT(*) FROM sessions WHERE created_at >= ?", (iso_utc(month_ago_utc),))
        result["sessions"]["month"] = c.fetchone()[0]

        active_sessions = 0
        try:
            c.execute("SELECT COUNT(DISTINCT session_id) FROM turns WHERE timestamp >= ?", (iso_utc(active_cutoff_utc),))
            active_sessions = c.fetchone()[0] or 0
        except sqlite3.Error:
            c.execute("SELECT COUNT(*) FROM sessions WHERE updated_at >= ?", (iso_utc(active_cutoff_utc),))
            active_sessions = c.fetchone()[0] or 0
        result["sessions"]["active"] = active_sessions

        c.execute("SELECT COUNT(*) FROM turns")
        result["turns"]["total"] = c.fetchone()[0]

        c.execute("SELECT COUNT(*) FROM turns WHERE timestamp >= ?", (iso_utc(today_start_utc),))
        result["turns"]["today"] = c.fetchone()[0]

        c.execute("SELECT COUNT(*) FROM turns WHERE timestamp >= ?", (iso_utc(week_ago_utc),))
        result["turns"]["week"] = c.fetchone()[0]

        c.execute("SELECT COUNT(*) FROM turns WHERE timestamp >= ?", (iso_utc(month_ago_utc),))
        result["turns"]["month"] = c.fetchone()[0]

        daily_turns = []
        for i in range(7, -1, -1):
            day_start = today_start_utc - timedelta(days=i)
            day_end = day_start + timedelta(days=1)
            c.execute(
                "SELECT COUNT(*) FROM turns WHERE timestamp >= ? AND timestamp < ?",
                (iso_utc(day_start), iso_utc(day_end)),
            )
            daily_turns.append({"day": day_start.strftime("%Y-%m-%d"), "turns": c.fetchone()[0]})
        result["daily_turns"] = daily_turns

        fine_turn_map = {}
        try:
            c.execute("SELECT timestamp FROM turns WHERE timestamp >= ?", (iso_utc(hourly_cutoff_utc),))
            for (ts,) in c.fetchall():
                dt = parse_iso(ts)
                if not dt:
                    continue
                dt_local = dt.astimezone()
                minute = (dt_local.minute // FINE_BUCKET_MIN) * FINE_BUCKET_MIN
                key = f"{dt_local.strftime('%Y-%m-%d')} {dt_local.hour:02d}:{minute:02d}"
                fine_turn_map[key] = fine_turn_map.get(key, 0) + 1
        except sqlite3.Error:
            pass

        fine_turns = []
        base_dt = datetime.now().replace(second=0, microsecond=0)
        base_dt = base_dt.replace(minute=(base_dt.minute // FINE_BUCKET_MIN) * FINE_BUCKET_MIN)
        total_buckets = (12 * 60) // FINE_BUCKET_MIN
        for i in range(total_buckets - 1, -1, -1):
            dt_b = base_dt - timedelta(minutes=i * FINE_BUCKET_MIN)
            key = f"{dt_b.strftime('%Y-%m-%d')} {dt_b.hour:02d}:{dt_b.minute:02d}"
            label = f"{dt_b.hour:02d}:{dt_b.minute:02d}"
            turns = fine_turn_map.get(key, 0)
            fine_turns.append({"t": label, "input": turns, "output": 0})
        result["fine_turns"] = fine_turns

        recent = []
        recent_queries = [
            """
            SELECT
                s.id,
                s.cwd,
                s.repository,
                s.branch,
                s.host_type,
                s.created_at,
                s.updated_at,
                COUNT(*) AS turns
            FROM sessions s
            LEFT JOIN turns t ON t.session_id = s.id
            GROUP BY s.id, s.cwd, s.repository, s.branch, s.host_type, s.created_at, s.updated_at
            ORDER BY COALESCE(s.updated_at, s.created_at) DESC
            LIMIT 8
            """,
            """
            SELECT
                s.id,
                s.cwd,
                s.repository,
                s.branch,
                '' AS host_type,
                s.created_at,
                s.updated_at,
                COUNT(*) AS turns
            FROM sessions s
            LEFT JOIN turns t ON t.session_id = s.id
            GROUP BY s.id, s.cwd, s.repository, s.branch, s.created_at, s.updated_at
            ORDER BY COALESCE(s.updated_at, s.created_at) DESC
            LIMIT 8
            """,
        ]
        rows = []
        for query in recent_queries:
            try:
                c.execute(query)
                rows = c.fetchall()
                break
            except sqlite3.Error:
                continue

        for row in rows:
            sid, cwd, repo, branch, host_type, created_at, updated_at, turns = row
            created_dt = parse_iso(created_at)
            updated_dt = parse_iso(updated_at) or created_dt
            duration_min = 0.0
            if created_dt and updated_dt:
                duration_min = max(0.0, (updated_dt - created_dt).total_seconds() / 60.0)

            recent.append(
                {
                    "id": (sid or "")[:8],
                    "project": short_project_label(cwd, repo),
                    "cwd": cwd or "",
                    "model": host_type or branch or "",
                    "turns": int(turns or 0),
                    "duration_min": round(duration_min, 1),
                    "timestamp": updated_at or created_at or "",
                }
            )
        result["recent_sessions"] = recent

        conn.close()
    except (sqlite3.Error, OSError, TypeError, ValueError):
        pass


print(json.dumps(result))
