#!/usr/bin/env python3
"""App-icon candidates via fal.ai Recraft v3 (vector-style). Outputs out/icon-<n>.png."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download

ENDPOINT = "https://queue.fal.run/fal-ai/recraft/v3/text-to-image"
OUT = os.path.join(HERE, "out")
BASE = ("Flat vector app icon filling the entire square edge to edge, no border, no rounded corners, "
        "no drop shadow, no text, no letters. ")
PROMPTS = [
    BASE + "Solid cream background (hex F4F1EA). One bold ink-black (0A0B0E) stroke: a mountain summit whose right flank "
           "flows into a long carving ski turn, drawn as a single continuous brush line with round ends. Minimal, premium, Swiss design.",
    BASE + "Solid near-black background (0A0B0E). A single cream (F4F1EA) S-shaped carving track in fresh snow seen from above, "
           "thick confident stroke, generous negative space, minimal, premium.",
    BASE + "Solid cream background (F4F1EA). A minimal geometric mountain made of two overlapping rounded triangles in ink black "
           "and warm champagne (D9C39A), with a tiny snow cap gap, flat, iconic, no text.",
    BASE + "Deep alpine blue-black background (0E1420). Two thin parallel cream ski tracks curving down from the top-left, "
           "leaving a small champagne dot at the end, ultra minimal, luxurious.",
    BASE + "Solid cream background (F4F1EA). Bold rounded ink-black chevron peak with a champagne (D9C39A) sun disc peeking behind it, "
           "flat, playful but premium, centered, no text.",
    BASE + "Solid ink-black background (0A0B0E). A cream circle (moon) with a single champagne diagonal line cutting through it like a piste, "
           "ultra minimal, iconic, no text.",
]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i, p in enumerate(PROMPTS, 1):
        try:
            res = run_queue(ENDPOINT, {"prompt": p, "image_size": "square_hd", "style": "vector_illustration"}, label=f"icon-{i}", timeout_s=6*60, poll_s=4)
            download(res["images"][0]["url"], os.path.join(OUT, f"icon-{i}.png"))
        except Exception as e:
            print(f"FAIL icon-{i}: {e}", flush=True)
