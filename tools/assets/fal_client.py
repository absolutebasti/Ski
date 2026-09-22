#!/usr/bin/env python3
"""Tiny fal.ai queue client shared by the asset generators.

Reads FAL_KEY from the environment, or from a .env next to this file, or
(for local dev) from the sibling ShapeMe project's tools/falgen/.env.
Never commit a .env with the key — this repo is public.
"""
import json
import os
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


def _load_key():
    key = os.environ.get("FAL_KEY")
    if key:
        return key
    for path in (
        os.path.join(HERE, ".env"),
        os.path.expanduser("~/Dev/shapeme/tools/falgen/.env"),
    ):
        if os.path.exists(path):
            for line in open(path):
                line = line.strip()
                if line.startswith("FAL_KEY="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit("FAL_KEY not found (env, tools/assets/.env, or ShapeMe .env)")


KEY = _load_key()


def api(url, payload=None):
    req = urllib.request.Request(url, headers={
        "Authorization": f"Key {KEY}",
        "Content-Type": "application/json",
    }, data=json.dumps(payload).encode() if payload is not None else None)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def run_queue(endpoint, payload, timeout_s=15 * 60, poll_s=5, label="job"):
    """Submit to a fal queue endpoint and block until the result is ready."""
    sub = api(endpoint, payload)
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        st = api(sub["status_url"])
        if st["status"] == "COMPLETED":
            return api(sub["response_url"])
        if st["status"] in ("FAILED", "ERROR"):
            raise RuntimeError(f"{label}: generation failed: {st}")
        time.sleep(poll_s)
    raise RuntimeError(f"{label}: timed out after {timeout_s}s")


def download(url, dest):
    req = urllib.request.Request(url, headers={"Authorization": f"Key {KEY}"})
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with urllib.request.urlopen(req, timeout=300) as r, open(dest, "wb") as f:
        f.write(r.read())
    print(f"OK {os.path.relpath(dest)} {os.path.getsize(dest)/1e6:.1f} MB", flush=True)
    return dest
