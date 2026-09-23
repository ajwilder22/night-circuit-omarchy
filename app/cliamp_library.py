#!/usr/bin/env python3
"""Small safe adapter from the widget to cliamp's documented local IPC commands."""

import json
import subprocess
import sys


def call(operation, params):
    result = subprocess.run(
        ["cliamp", "remote", "call", operation, "--params", json.dumps(params), "--wait"],
        capture_output=True, text=True, timeout=12, check=True,
    )
    envelope = json.loads(result.stdout)
    job = envelope.get("job") or {}
    if not envelope.get("ok") or job.get("state") != "succeeded":
        raise RuntimeError(str(job.get("error") or envelope.get("error") or "cliamp request failed"))
    return job.get("result") or {}


def main():
    action = sys.argv[1]
    if action == "search":
        provider, query = sys.argv[2:4]
        if provider not in {"radio", "local"}:
            raise ValueError("Unsupported provider")
        result = call("provider.search", {"provider": provider, "query": query, "offset": 0, "limit": 30})
        print(json.dumps({"items": result.get("tracks") or [], "kind": "search"}), flush=True)
    elif action == "queue":
        result = call("queue.list", {"offset": 0, "limit": 50})
        print(json.dumps({"items": result.get("tracks") or [], "kind": "queue"}), flush=True)
    elif action == "playlists":
        provider = sys.argv[2]
        if provider not in {"radio", "local"}:
            raise ValueError("Unsupported provider")
        result = call("provider.playlists", {"provider": provider, "offset": 0, "limit": 50})
        print(json.dumps({"items": result.get("playlists") or [], "kind": "playlists"}), flush=True)
    elif action == "play":
        track = json.loads(sys.argv[2])
        call("track.play", {"track": track})
    elif action == "add":
        track = json.loads(sys.argv[2])
        call("track.queue", {"track": track})
    elif action == "play-index":
        call("queue.play", {"index": int(sys.argv[2])})
    elif action == "load-playlist":
        provider, playlist = sys.argv[2:4]
        if provider not in {"radio", "local"}:
            raise ValueError("Unsupported provider")
        call("provider.load", {"provider": provider, "playlist": playlist})
    else:
        raise ValueError("Unknown action")


if __name__ == "__main__":
    try:
        main()
    except (IndexError, ValueError, OSError, subprocess.SubprocessError, RuntimeError, json.JSONDecodeError) as error:
        print(json.dumps({"error": str(error), "items": []}), flush=True)
        raise SystemExit(1)
