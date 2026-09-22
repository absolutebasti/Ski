#!/usr/bin/env python3
"""Remove the flat studio background from the leopard pose PNGs via fal birefnet.

Input:  design/mascot/leopard/poses/<pose>.png (+ the geometric head)
Output: app/assets/mascot/leo-<pose>.png with a real alpha channel, trimmed
        to the subject and downscaled to 1024 px (assets stay small).
"""
import base64
import io
import os
import sys

from PIL import Image

from fal_client import run_queue, download

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "design", "mascot", "leopard", "poses")
DST = os.path.join(ROOT, "app", "assets", "mascot")
ENDPOINT = "https://queue.fal.run/fal-ai/birefnet/v2"

POSES = {
    "head": os.path.join(ROOT, "design", "mascot", "leopard", "leopard-geometric.png"),
    **{p: os.path.join(SRC, f"{p}.png") for p in
       ("hero", "wave", "celebrate", "think", "thumbs", "point", "lean", "goggles-down")},
}


def data_url(path):
    im = Image.open(path).convert("RGB")
    im.thumbnail((1536, 1536))
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def main(only=None):
    for pose, src in POSES.items():
        if only and pose not in only:
            continue
        if not os.path.exists(src):
            print(f"skip {pose}: {src} missing")
            continue
        res = run_queue(ENDPOINT, {
            "image_url": data_url(src),
            "model": "General Use (Heavy)",
            "operating_resolution": "1024x1024",
            "output_format": "png",
            "refine_foreground": True,
        }, label=pose)
        tmp = os.path.join(HERE, "out", f"cut-{pose}.png")
        download(res["image"]["url"], tmp)
        im = Image.open(tmp).convert("RGBA")
        bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if bbox:
            pad = int(0.04 * max(im.size))
            bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                    min(im.width, bbox[2] + pad), min(im.height, bbox[3] + pad))
            im = im.crop(bbox)
        im.thumbnail((1024, 1024))
        out = os.path.join(DST, f"leo-{pose}.png")
        im.save(out, "PNG", optimize=True)
        print(f"{pose}: {im.size} -> {out}")


if __name__ == "__main__":
    main(set(sys.argv[1:]) or None)
