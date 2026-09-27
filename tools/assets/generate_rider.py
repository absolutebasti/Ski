#!/usr/bin/env python3
"""Rider mascot (replaces the leopard): all-black skier, mirrored gold visor.

Step 1 `candidates`: four style candidates of the hero pose → out/rider/cand-*.png
Step 2 `poses <cand>`: pose set from the chosen candidate as image reference → out/rider/<pose>.png
Step 3 `cut`: birefnet cut-outs → app/assets/mascot/rider-<pose>.png
"""
import base64, io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out", "rider"); os.makedirs(OUT, exist_ok=True)
DST = os.path.join(ROOT, "app", "assets", "mascot")
FLUX = "https://queue.fal.run/fal-ai/flux-pro/v1.1-ultra"
CUT = "https://queue.fal.run/fal-ai/birefnet/v2"

BASE = ("A skier in an all-black outfit: matte black shell jacket, black pants, black gloves, black helmet, "
        "mirrored goggles with a reflective gold lens, thin gold accent lines on the jacket. No face visible. "
        "Adult, athletic, calm and confident posture. Premium, minimal, sleek. "
        "Solid near-black graphite background (0B0C0E), no text, no logo, centered, full figure visible, square composition.")

CANDIDATES = {
    "flat":   "Flat vector illustration, geometric shapes, no outlines, 5 tones of black and one gold, clean silhouette.",
    "mono":   "Monochrome ink illustration with subtle gold highlights, soft studio lighting, matte surfaces, editorial minimalism.",
    "render": "Stylised 3D render, matte black materials, physically based lighting, one rim light, gold visor reflection, cinematic.",
    "line":   "Minimal line art with solid black fills and a single gold accent, poster style, very few details.",
}
POSES = {
    "hero": "Full body, standing on skis facing the viewer, both poles planted, weight relaxed.",
    "lean": "Full body, leaning on crossed ski poles, one leg crossed over the other, relaxed and cool.",
    "carve": "Full body, mid carve turn from the side, angulated, snow spray minimal, dynamic.",
    "celebrate": "Full body, both poles raised above the head, chest out, victory.",
    "point": "Half body, pointing forward toward the viewer with one gloved hand, inviting.",
    "look": "Head and shoulders, helmet and mirrored gold visor filling the frame, slight turn.",
}

def data_url(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()

def gen(prompt, out, ref=None, strength=0.35):
    payload = {"prompt": prompt, "aspect_ratio": "1:1", "output_format": "png", "safety_tolerance": "2"}
    if ref:
        payload["image_url"] = data_url(ref); payload["image_prompt_strength"] = strength
    res = run_queue(FLUX, payload, label=os.path.basename(out), timeout_s=6 * 60, poll_s=4)
    download(res["images"][0]["url"], out)

def candidates():
    for key, style in CANDIDATES.items():
        try: gen(f"{POSES['hero']} {BASE} {style}", os.path.join(OUT, f"cand-{key}.png"))
        except Exception as e: print("FAIL", key, e, flush=True)

def poses(cand):
    ref = os.path.join(OUT, f"cand-{cand}.png"); style = CANDIDATES[cand]
    for key, pose in POSES.items():
        if key == "hero":
            import shutil; shutil.copy(ref, os.path.join(OUT, "hero.png")); continue
        try: gen(f"{pose} Same character, same outfit and same style as the reference image. {BASE} {style}", os.path.join(OUT, f"{key}.png"), ref=ref)
        except Exception as e: print("FAIL", key, e, flush=True)

def cut():
    from PIL import Image
    for key in POSES:
        src = os.path.join(OUT, f"{key}.png")
        if not os.path.exists(src): print("skip", key); continue
        res = run_queue(CUT, {"image_url": data_url(src), "model": "General Use (Heavy)", "operating_resolution": "1024x1024",
                              "output_format": "png", "refine_foreground": True}, label=f"cut-{key}")
        tmp = os.path.join(OUT, f"cut-{key}.png"); download(res["image"]["url"], tmp)
        im = Image.open(tmp).convert("RGBA")
        bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if bbox:
            pad = int(0.04 * max(im.size))
            im = im.crop((max(0, bbox[0]-pad), max(0, bbox[1]-pad), min(im.width, bbox[2]+pad), min(im.height, bbox[3]+pad)))
        im.thumbnail((1024, 1024)); os.makedirs(DST, exist_ok=True)
        im.save(os.path.join(DST, f"rider-{key}.png"), "PNG", optimize=True); print("wrote", key, im.size, flush=True)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "candidates"
    {"candidates": candidates, "poses": lambda: poses(sys.argv[2]), "cut": cut}[cmd]()
