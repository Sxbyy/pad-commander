#!/usr/bin/env python3
"""Waehlt einen verfuegbaren iPad-Simulator und gibt seine UDID aus."""
import json
import subprocess
import sys

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
best = None
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    version = runtime.split("iOS-")[-1].replace("-", ".")
    try:
        vkey = tuple(int(x) for x in version.split("."))
    except ValueError:
        vkey = (0,)
    for d in devices:
        name = d.get("name", "")
        if not name.startswith("iPad"):
            continue
        score = 0
        if "iPad Air" in name:
            score = 3
        elif "iPad Pro 11" in name:
            score = 2
        elif "iPad (" in name or name.startswith("iPad ("):
            score = 1
        key = (vkey, score)
        if best is None or key > best[0]:
            best = (key, d["udid"], name, runtime)
if not best:
    print("kein iPad-Simulator gefunden", file=sys.stderr)
    sys.exit(1)
print(f"{best[2]} / {best[3]}", file=sys.stderr)
print(best[1])
