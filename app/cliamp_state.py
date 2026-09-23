#!/usr/bin/env python3
"""Publish a small, local-only cliamp snapshot for the desktop widget."""

import json
import subprocess
import time


def snapshot():
    try:
        result = subprocess.run(
            ["cliamp", "remote", "state"],
            capture_output=True,
            text=True,
            timeout=2,
            check=True,
        )
        data = json.loads(result.stdout).get("snapshot") or {}
        track = data.get("track") or {}
        effects = ""
        try:
            active = subprocess.run(
                ["systemctl", "--user", "is-active", "night-circuit-effects.service"],
                capture_output=True, text=True, timeout=1,
            ).stdout.strip() == "active"
            if active:
                effects = subprocess.run(["easyeffects", "-a", "output"], capture_output=True,
                                         text=True, timeout=2, check=True).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            pass
        return {
            "connected": True,
            "state": data.get("state", "stopped"),
            "title": track.get("title") or "Nothing playing",
            "artist": track.get("artist") or track.get("station") or "cliamp",
            "station": track.get("station") or "",
            "shuffle": bool(data.get("shuffle")),
            "repeat": data.get("repeat", "Off"),
            "eq": data.get("eq_preset", "Flat"),
            "effect": effects.removeprefix("Night Circuit - ") or "Clean",
            "index": int(data.get("index", 0)) + 1,
            "total": int(data.get("total", 0)),
        }
    except (OSError, ValueError, subprocess.SubprocessError, json.JSONDecodeError):
        return {"connected": False, "state": "stopped", "title": "Open cliamp to play",
                "artist": "Music is ready", "station": "", "shuffle": False,
                "repeat": "Off", "eq": "Flat", "effect": "Clean", "index": 0, "total": 0}


while True:
    print(json.dumps(snapshot(), ensure_ascii=False), flush=True)
    time.sleep(2)
