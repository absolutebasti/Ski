#!/usr/bin/env python3
"""Mascot v4 — the founder picked rider-point ("extremst gut"): black outfit, gold mirrored
goggles, no visible skin. Pose set via FLUX Kontext edits of the original point image.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download
from generate_rider import data_url, CUT, ROOT, DST
from PIL import Image

OUT = os.path.join(HERE, "out", "pointer"); os.makedirs(OUT, exist_ok=True)
KONTEXT = "https://queue.fal.run/fal-ai/flux-pro/kontext"
SRC = os.path.join(HERE, "out", "rider", "point.png")   # the image the founder liked
KEEP = (" Keep exactly the same character: matte black ski jacket with thin gold seams, black helmet, mirrored gold goggles covering the eyes, "
        "no visible skin, same illustration style and lighting, same plain dark background. Full figure visible, centered.")
POSES = {
    "hero": "Change the pose: the character stands upright on black skis facing the viewer, both ski poles planted beside him, relaxed confident stance, arms down." + KEEP,
    "celebrate": "Change the pose: the character raises both arms with the ski poles high above his head in a V, chest out, victory." + KEEP,
    "carve": "Change the pose to a side view: the character is mid carving turn on skis, body strongly angulated, inside hand near the snow, dynamic." + KEEP,
    "lean": "Change the pose: the character leans casually on his crossed ski poles, one leg crossed over the other, relaxed and cool." + KEEP,
    "look": "Crop to a close-up portrait: only the black helmet and the mirrored gold goggles fill the frame, a mountain ridge reflected in the lens, jacket collar at the bottom." + KEEP.replace("Full figure visible, centered.", "Centered."),
}

def poses(only=None):
    src = data_url(SRC)
    for key, prompt in POSES.items():
        if only and key not in only: continue
        try:
            res = run_queue(KONTEXT, {"prompt": prompt, "image_url": src, "output_format": "png", "safety_tolerance": "2", "seed": 7}, label=key, timeout_s=360, poll_s=4)
            download(res["images"][0]["url"], os.path.join(OUT, f"{key}.png")); print("gen", key, flush=True)
        except Exception as e: print("FAIL", key, e, flush=True)

def cut(only=None):
    keys = list(POSES) + ["point"]
    for key in keys:
        if only and key not in only: continue
        src = SRC if key == "point" else os.path.join(OUT, f"{key}.png")
        if not os.path.exists(src): print("skip", key); continue
        res = run_queue(CUT, {"image_url": data_url(src), "model": "General Use (Heavy)", "operating_resolution": "1024x1024", "output_format": "png", "refine_foreground": True}, label=f"cut-{key}")
        tmp = os.path.join(OUT, f"cut-{key}.png"); download(res["image"]["url"], tmp)
        im = Image.open(tmp).convert("RGBA")
        bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if bbox:
            pad = int(0.04 * max(im.size))
            im = im.crop((max(0, bbox[0]-pad), max(0, bbox[1]-pad), min(im.width, bbox[2]+pad), min(im.height, bbox[3]+pad)))
        im.thumbnail((1024, 1024)); im.save(os.path.join(DST, f"rider-{key}.png"), "PNG", optimize=True); print("wrote", key, im.size, flush=True)

def sheet():
    import glob
    files = sorted(glob.glob(os.path.join(DST, "rider-*.png")))
    sh = Image.new("RGBA", (3*340, 2*340), (11,12,14,255))
    for i,f in enumerate(files):
        im = Image.open(f).convert("RGBA"); im.thumbnail((320,320)); sh.alpha_composite(im, ((i%3)*340+10, (i//3)*340+10))
    sh.save(os.path.join(ROOT, ".context", "shots", "pointer-poses.png")); print("sheet", len(files))

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poses"
    only = set(sys.argv[2:]) or None
    if cmd == "poses": poses(only)
    elif cmd == "cut": cut(only); sheet()
    elif cmd == "sheet": sheet()
