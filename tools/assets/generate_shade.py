#!/usr/bin/env python3
"""Mascot v3 "Shade": faceless charcoal figure with white eyes (Calist-style), skiing.
candidates → out/shade/cand-*.png · poses → out/shade/<pose>.png · cut → app/assets/mascot/rider-<pose>.png
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fal_client import run_queue, download
from generate_rider import data_url, FLUX, CUT, ROOT, DST

OUT = os.path.join(HERE, "out", "shade"); os.makedirs(OUT, exist_ok=True)
SEED = 20260927

CHARACTER = ("A stylised mascot character: the whole body and head are matte charcoal black like a living shadow, "
             "smooth skin without any facial features except two narrow glowing white eyes, athletic muscular build, "
             "clean comic cel-shading with bold dark outlines and one flat highlight tone, slight anime proportions. "
             "Ski outfit: black ski helmet, mirrored gold ski goggles pushed up on the helmet (eyes visible), "
             "fitted black ski jacket with thin gold accent lines, black ski pants, black gloves, black ski boots on black skis "
             "with gold details, black ski poles. Plain flat light warm off-white background (F2EFE8), soft grey ground shadow, "
             "no text, no logo, centered, full figure visible, square composition, vector illustration.")

POSES = {
    "hero": "Standing tall on skis facing the viewer, one thumb up, relaxed confident stance.",
    "reach": "Low crouch on skis, one hand reaching toward the camera with open fingers, dynamic, like lunging at the viewer.",
    "carve": "Side view, deep carving turn, body angulated, inside hand near the snow, skis on edge, powder spray in flat shapes.",
    "celebrate": "Both arms raised in a V with the ski poles, chest out, victory after a race.",
    "point": "Upper body, pointing a gloved index finger directly at the viewer, arm fully extended toward the camera.",
    "look": "Upper body, arms crossed, goggles pushed up, head slightly tilted, cool and calm.",
}

def gen(prompt, out, seed=SEED):
    res = run_queue(FLUX, {"prompt": prompt, "aspect_ratio": "1:1", "output_format": "png", "safety_tolerance": "2", "seed": seed},
                    label=os.path.basename(out), timeout_s=6 * 60, poll_s=4)
    download(res["images"][0]["url"], out)

def candidates():
    variants = {
        "a": "",
        "b": " Style of a modern fitness-app mascot, thick outlines, minimal shading.",
        "c": " Slightly more realistic proportions, subtle gradients, premium look.",
        "d": " Extra bold, chunky silhouette, very few details, poster style.",
    }
    for k, v in variants.items():
        try: gen(POSES["hero"] + " " + CHARACTER + v, os.path.join(OUT, f"cand-{k}.png"), seed=SEED + ord(k))
        except Exception as e: print("FAIL", k, e, flush=True)

def poses(suffix=""):
    for key, pose in POSES.items():
        try: gen(pose + " " + CHARACTER + suffix, os.path.join(OUT, f"{key}.png")); print("gen", key, flush=True)
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
        im.thumbnail((1024, 1024)); im.save(os.path.join(DST, f"rider-{key}.png"), "PNG", optimize=True); print("wrote", key, im.size, flush=True)

def sheet(pattern, name, cols=3):
    from PIL import Image
    import glob
    files = sorted(glob.glob(os.path.join(OUT if pattern.startswith("cand") else DST, pattern)))
    rows = (len(files) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * 340, rows * 340), (11, 12, 14, 255))
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGBA"); im.thumbnail((320, 320)); sh.alpha_composite(im, ((i % cols) * 340 + 10, (i // cols) * 340 + 10))
    sh.save(os.path.join(ROOT, ".context", "shots", name)); print("sheet", name, len(files))

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "candidates"
    if cmd == "candidates": candidates(); sheet("cand-*.png", "shade-candidates.png", cols=2)
    elif cmd == "poses": poses(sys.argv[2] if len(sys.argv) > 2 else ""); 
    elif cmd == "cut": cut(); sheet("rider-*.png", "shade-poses.png")
