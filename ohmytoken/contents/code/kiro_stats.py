#!/usr/bin/env python3
# Parses Kiro data and outputs JSON for the plasmoid
# Sources: ~/.kiro/powers/installed.json, extensions directory, ~/.config/Kiro workspace storage

import json, os, subprocess
from urllib.parse import unquote, urlparse

kiro_dir = os.path.expanduser("~/.kiro")
powers_dir = os.path.join(kiro_dir, "powers")
installed_path = os.path.join(powers_dir, "installed.json")
extensions_dir = os.path.join(kiro_dir, "extensions")
config_dir = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "Kiro")
workspace_storage_dir = os.path.join(config_dir, "User", "workspaceStorage")

result = {
    "home_dir": kiro_dir,
    "version": "",
    "powers_installed": 0,
    "powers": [],
    "recent_directories": [],
    "extensions_count": 0,
    "is_running": False,
    "credits_used": 0,
    "credits_limit": 1000
}


def decode_folder_uri(folder_uri):
    if not folder_uri:
        return ""
    if folder_uri.startswith("file://"):
        parsed = urlparse(folder_uri)
        path = unquote(parsed.path or "")
        if os.name == "nt" and len(path) > 2 and path[0] == "/" and path[2] == ":":
            path = path[1:]
        return path
    return folder_uri

# Get Kiro version
try:
    version_output = subprocess.check_output(["kiro", "--version"], stderr=subprocess.DEVNULL).decode().strip()
    result["version"] = version_output.split('\n')[0] if version_output else ""
except:
    pass

# Check if Kiro is running
try:
    subprocess.check_output(["pgrep", "-x", "kiro"], stderr=subprocess.DEVNULL)
    result["is_running"] = True
except:
    pass

# Count installed powers
if os.path.exists(installed_path):
    try:
        with open(installed_path) as f:
            installed = json.load(f)
        powers = installed.get("installedPowers", [])
        result["powers_installed"] = len(powers)
        result["powers"] = [{"name": p.get("name", ""), "version": p.get("version", "")} for p in powers]
    except:
        pass

# Count extensions
if os.path.exists(extensions_dir):
    try:
        extensions = [d for d in os.listdir(extensions_dir) if os.path.isdir(os.path.join(extensions_dir, d))]
        result["extensions_count"] = len(extensions)
    except:
        pass

# Recent directories from VS Code-style workspace storage
if os.path.isdir(workspace_storage_dir):
    try:
        candidates = []
        for entry in os.listdir(workspace_storage_dir):
            workspace_json = os.path.join(workspace_storage_dir, entry, "workspace.json")
            if os.path.isfile(workspace_json):
                try:
                    candidates.append((os.path.getmtime(workspace_json), workspace_json))
                except OSError:
                    continue

        seen = set()
        recent_directories = []
        for _, workspace_json in sorted(candidates, key=lambda x: x[0], reverse=True):
            try:
                with open(workspace_json) as f:
                    workspace = json.load(f)
                folder_uri = ""
                if isinstance(workspace, dict):
                    folder_uri = workspace.get("folder", "")
                    if not folder_uri and isinstance(workspace.get("workspace"), str):
                        folder_uri = workspace.get("workspace")
                    if not folder_uri and isinstance(workspace.get("workspace"), dict):
                        ws_obj = workspace.get("workspace", {})
                        folder_uri = ws_obj.get("path", "") or ws_obj.get("configPath", "")
                path = decode_folder_uri(folder_uri)
                if not path or path in seen:
                    continue
                seen.add(path)
                recent_directories.append({
                    "name": os.path.basename(path.rstrip(os.sep)) or path,
                    "path": path,
                    "updated_ts": int(os.path.getmtime(workspace_json) * 1000),
                })
                if len(recent_directories) >= 8:
                    break
            except:
                continue
        result["recent_directories"] = recent_directories
    except:
        pass

# Note: Kiro credits tracking not available yet - would need --status when running
# For now, showing 0/1000 as placeholder

print(json.dumps(result))
