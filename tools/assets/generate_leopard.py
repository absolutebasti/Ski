#!/usr/bin/env python3
"""Snow leopard mascot candidates — cool, not cute. Three style families × 2 variants."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download

ENDPOINT = "https://queue.fal.run/fal-ai/flux-pro/v1.1-ultra"
OUT = os.path.join(HERE, "out")
BASE = ("A snow leopard mascot wearing ski goggles pushed up on its forehead, calm confident expression, slight smirk, "
        "no cuteness, no big baby eyes, athletic and cool like a freeride athlete. Square composition, centered, "
        "solid near-black graphite background (hex 0B0C0E), no text, no logos, generous negative space. ")
STYLES = {
    "flat-emblem": "Flat vector emblem, bust from the chest up, bold clean shapes, only cream (F6F4EE), soft grey (A2A7B0) and champagne gold (E3C88C) plus black; rosette spots as simple shapes; premium sports brand mark.",
    "line-art": "Single-weight champagne (E3C88C) line art on graphite, minimal continuous strokes, spots as small open rings, goggles as two clean ellipses, the face reads at 24 px; Swiss minimalism, no fill.",
    "flat-full": "Flat vector illustration, full body, relaxed pose leaning on ski poles with skis, limited palette cream/champagne/grey on graphite, geometric spots, thick outline-free shapes, editorial poster style.",
    "sticker-cool": "Die-cut sticker style with a thin cream outline, head-and-shoulders, bold flat shading in two tones, confident three-quarter view, streetwear-cool, restrained colours (cream, champagne, graphite).",
    "geometric": "Low-detail geometric mascot made of a few rounded shapes, symmetrical front view, big goggles as the main element, cream fur, champagne goggle strap, tiny spots, ultra minimal, works as an app icon.",
    "mono-badge": "Monochrome cream badge illustration inside a rounded shield, snow leopard head with goggles, engraved-line texture kept minimal, champagne accent only on the goggle lens; premium, timeless.",
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:] or list(STYLES)
    for key in only:
        try:
            res = run_queue(ENDPOINT, {"prompt": BASE + STYLES[key], "aspect_ratio": "1:1", "output_format": "png", "safety_tolerance": "2"},
                            label=f"leopard-{key}", timeout_s=6 * 60, poll_s=4)
            download(res["images"][0]["url"], os.path.join(OUT, f"leopard-{key}.png"))
        except Exception as e:
            print(f"FAIL {key}: {e}", flush=True)
