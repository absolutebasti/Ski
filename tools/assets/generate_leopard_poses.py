#!/usr/bin/env python3
"""Pose set for the chosen snow-leopard mascot (geometric style), using the head mark as image reference."""
import os, sys, base64
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download

ENDPOINT = "https://queue.fal.run/fal-ai/flux-pro/v1.1-ultra"
OUT = os.path.join(HERE, "out", "poses")
REF = os.path.join(HERE, "out", "leopard-geometric.png")
STYLE = ("Same character and same flat geometric vector style as the reference image: snow leopard mascot with big ski goggles "
         "on the forehead, cream fur, champagne (E3C88C) goggle strap, tiny grey spots, minimal rounded shapes, no outlines, "
         "solid near-black graphite background (0B0C0E), no text, calm confident expression, square composition, centered.")
POSES = {
    "hero": "Full body, standing relaxed on skis, both poles planted, looking slightly to the right, small smirk.",
    "wave": "Half body, one paw raised in a casual wave, goggles on forehead.",
    "celebrate": "Full body, both ski poles raised above the head in victory, chest out, goggles on forehead.",
    "think": "Head and shoulders, one paw at the chin, eyes looking up-left, thinking.",
    "thumbs": "Half body, thumbs up with one paw, confident nod.",
    "point": "Half body, pointing forward with one paw toward the viewer, inviting.",
    "lean": "Full body, leaning on crossed ski poles, one leg crossed, relaxed and cool.",
    "goggles-down": "Head only, goggles pulled down over the eyes, ready to race, focused.",
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    with open(REF, "rb") as f:
        ref_data = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    only = sys.argv[1:] or list(POSES)
    for key in only:
        try:
            res = run_queue(ENDPOINT, {"prompt": f"{POSES[key]} {STYLE}", "image_url": ref_data, "image_prompt_strength": 0.35,
                                       "aspect_ratio": "1:1", "output_format": "png", "safety_tolerance": "2"},
                            label=f"pose-{key}", timeout_s=6 * 60, poll_s=4)
            download(res["images"][0]["url"], os.path.join(OUT, f"{key}.png"))
        except Exception as e:
            print(f"FAIL {key}: {e}", flush=True)
