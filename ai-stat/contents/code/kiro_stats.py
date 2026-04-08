#!/usr/bin/env python3
# Parses Kiro data and outputs JSON for the plasmoid
# Sources: ~/.kiro/powers/installed.json, extensions directory

import json, os, subprocess
from datetime import datetime

kiro_dir = os.path.expanduser("~/.kiro")
powers_dir = os.path.join(kiro_dir, "powers")
installed_path = os.path.join(powers_dir, "installed.json")
extensions_dir = os.path.join(kiro_dir, "extensions")

result = {
    "version": "",
    "powers_installed": 0,
    "powers": [],
    "extensions_count": 0,
    "is_running": False,
    "credits_used": 0,
    "credits_limit": 1000
}

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

# Note: Kiro credits tracking not available yet - would need --status when running
# For now, showing 0/1000 as placeholder

print(json.dumps(result))
