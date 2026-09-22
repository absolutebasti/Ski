#!/usr/bin/env python3
"""Generate the ski-guide "coach" videos and a still portrait via fal.ai.

Same recipe as ShapeMe's onboarding coach: photorealistic, calm, brand-coloured
(snow-cream + ink, no red jackets), no text, static camera.

Outputs (tools/assets/out/):
  guide-hero.mp4   9:16 full-screen welcome loop
  guide-card.mp4   16:9 onboarding coach card loop
  guide-still.png  square portrait for in-app use (empty states, tips)

Usage: python3 generate_mascot.py [--only hero|card|still]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fal_client import run_queue, download  # noqa: E402

OUT = os.path.join(HERE, "out")
VIDEO_ENDPOINT = "https://queue.fal.run/bytedance/seedance-2.0/mini/text-to-video"
IMAGE_ENDPOINT = "https://queue.fal.run/fal-ai/flux-pro/v1.1-ultra"

CHARACTER = (
    "a friendly athletic woman in her early thirties, ski guide, wind-tanned face, "
    "wearing a matte charcoal-black ski shell jacket and a cream wool beanie, mirrored ski goggles "
    "pushed up on the beanie, holding ski poles"
)
SETTING = (
    "on a sunlit alpine ridge with fresh untouched snow, soft early-morning light, pale blue sky, "
    "distant snow-covered peaks softly out of focus"
)
STYLE = (
    "Photorealistic cinematic footage, static locked-off camera, shallow depth of field, calm and "
    "confident mood, natural colours, no text, no overlays, no logos."
)

PROMPTS = {
    "hero": (
        f"{STYLE} Vertical full-body shot of {CHARACTER} {SETTING}. She stands relaxed with skis on, "
        "looks toward the valley, then turns her head slightly toward the camera and smiles warmly. "
        "Gentle wind moves loose snow around her boots."
    ),
    "card": (
        f"{STYLE} Medium shot from the waist up of {CHARACTER} {SETTING}. She faces the camera, "
        "nods once, and speaks calmly as if giving advice, small natural hand gestures with one pole. "
        "Subtle breath visible in cold air."
    ),
    "still": (
        f"Photorealistic portrait photo, square format, of {CHARACTER} {SETTING}. Medium close-up, "
        "looking at the camera with a warm confident smile, soft natural light, shallow depth of field, "
        "clean composition, no text, no logos."
    ),
}


def gen_video(name, aspect):
    for duration in ("10", "5"):
        try:
            res = run_queue(VIDEO_ENDPOINT, {
                "prompt": PROMPTS[name],
                "resolution": "720p",
                "duration": duration,
                "aspect_ratio": aspect,
                "generate_audio": False,
            }, label=f"guide-{name}")
            return download(res["video"]["url"], os.path.join(OUT, f"guide-{name}.mp4"))
        except Exception as e:  # noqa: BLE001
            print(f"guide-{name} {duration}s failed: {e}", flush=True)
    raise SystemExit(f"guide-{name}: all attempts failed")


def gen_still():
    res = run_queue(IMAGE_ENDPOINT, {
        "prompt": PROMPTS["still"],
        "aspect_ratio": "1:1",
        "output_format": "png",
        "safety_tolerance": "2",
    }, label="guide-still", timeout_s=5 * 60)
    return download(res["images"][0]["url"], os.path.join(OUT, "guide-still.png"))


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    os.makedirs(OUT, exist_ok=True)
    if only in (None, "still"):
        gen_still()
    if only in (None, "card"):
        gen_video("card", "16:9")
    if only in (None, "hero"):
        gen_video("hero", "9:16")
