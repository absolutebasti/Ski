#!/usr/bin/env python3
"""Mascot character candidates via fal.ai (flux-pro ultra for consistent, clean flat character art).
Outputs out/mascot-<name>.png. Style: minimal flat vector, few shapes, cream/champagne on graphite."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download

ENDPOINT = "https://queue.fal.run/fal-ai/flux-pro/v1.1-ultra"
OUT = os.path.join(HERE, "out")
STYLE = ("Minimal flat vector mascot character, sticker style, thick clean outlines, only 3 colours: near-black graphite "
         "background (hex 0B0C0E), warm cream (F6F4EE) and champagne gold (E3C88C). Friendly, confident, slightly cheeky "
         "expression, wearing small ski goggles pushed up on the forehead. Front-facing bust, centered, lots of negative "
         "space, no text, no gradients, no shading, premium sports-app brand mascot, square composition.")
CHARACTERS = {
    "steinbock": "An alpine ibex with elegant curved horns",
    "murmel": "A chubby alpine marmot",
    "gams": "A chamois with short hooked horns and a dark face stripe",
    "schneehase": "A mountain hare with long ears and a scarf",
    "yeti": "A small round yeti with fluffy cream fur",
    "eule": "A snowy owl with round eyes",
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:] or list(CHARACTERS)
    for key in only:
        prompt = f"{CHARACTERS[key]}. {STYLE}"
        try:
            res = run_queue(ENDPOINT, {"prompt": prompt, "aspect_ratio": "1:1", "output_format": "png", "safety_tolerance": "2", "raw": False},
                            label=f"mascot-{key}", timeout_s=6 * 60, poll_s=4)
            download(res["images"][0]["url"], os.path.join(OUT, f"mascot-{key}.png"))
        except Exception as e:
            print(f"FAIL {key}: {e}", flush=True)
