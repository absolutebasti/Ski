#!/usr/bin/env python3
"""App Store screenshots: takes the raw 6.9" simulator captures from
.context/shots/store/*.png and composes captioned frames (1320×2868) into
.context/shots/store/framed/<n>-<name>-<lang>.png. Dark graphite background,
headline in InterDisplay, the screenshot rounded with a hairline and a soft glow.
"""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, ".context", "shots", "store")
DST = os.path.join(SRC, "framed"); os.makedirs(DST, exist_ok=True)
FONT_DIR = os.path.join(ROOT, "app", "assets", "fonts")
W, H = 1320, 2868
BG, INK, MUTED, ACCENT, HAIR = (11, 12, 14), (244, 241, 234), (169, 171, 178), (227, 200, 140), (42, 45, 51)

ORDER = [
    ("heute",       {"de": ("Ein Tipp. Der ganze Skitag.", "Läuft weiter, wenn das iPhone in der Jacke steckt."),
                     "en": ("One tap. The whole ski day.", "Keeps going with the iPhone in your jacket.")}),
    ("rangliste",   {"de": ("Level, Punkte, Rangliste.", "Pro Land, pro Skigebiet – Saison, Monat, Woche."),
                     "en": ("Levels, points, leaderboards.", "Per country, per resort – season, month, week.")}),
    ("medals",      {"de": ("Medaillen, die du dir verdienst.", "48 Medaillen für Tage, Streaks, Höhenmeter und Tempo."),
                     "en": ("Medals you earn on snow.", "48 medals for days, streaks, vertical and speed.")}),
    ("tag-detail",  {"de": ("Jede Abfahrt auf der Karte.", "Höhenprofil, Zeiten, Tempo – ehrlich gemessen."),
                     "en": ("Every run on the map.", "Altitude profile, times, speed – honestly measured.")}),
    ("tagesbilanz", {"de": ("Die Tagesbilanz zum Teilen.", "Rekorde, beste Abfahrt, neue Medaillen."),
                     "en": ("A day summary worth sharing.", "Records, best run, new medals.")}),
    ("tage",        {"de": ("Deine Saison im Blick.", "Skitage, Bestwerte, Ziel."),
                     "en": ("Your season at a glance.", "Ski days, personal bests, goal.")}),
]

def font(name, size):
    for cand in (f"InterDisplay-{name}.ttf", f"InterDisplay-{name}.otf", f"Inter-{name}.ttf", f"Inter-{name}.otf"):
        p = os.path.join(FONT_DIR, cand)
        if os.path.exists(p): return ImageFont.truetype(p, size)
    for p in glob.glob(os.path.join(FONT_DIR, "*.ttf")) + glob.glob(os.path.join(FONT_DIR, "*.otf")):
        if name.lower() in os.path.basename(p).lower(): return ImageFont.truetype(p, size)
    return ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)

def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=radius, fill=255)
    out = im.copy(); out.putalpha(mask); return out

def compose(shot_path, headline, sub, out_path):
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    # champagne glow behind the device
    glow = Image.new("RGB", (W, H), BG)
    ImageDraw.Draw(glow).ellipse((W*0.15, H*0.32, W*0.85, H*0.95), fill=(48, 42, 28))
    glow = glow.filter(ImageFilter.GaussianBlur(160)); canvas = Image.blend(canvas, glow, 0.9)
    d = ImageDraw.Draw(canvas)
    # headline + sub
    f1, f2 = font("Bold", 92), font("Regular", 44)
    y = 190
    for line in wrap(d, headline, f1, W - 200):
        d.text((100, y), line, font=f1, fill=INK); y += 104
    y += 12
    for line in wrap(d, sub, f2, W - 200):
        d.text((100, y), line, font=f2, fill=MUTED); y += 58
    # screenshot
    shot = Image.open(shot_path).convert("RGB")
    target_w = 1080; scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    shot = rounded(shot, 76)
    x = (W - target_w) // 2; top = max(y + 70, 620)
    # hairline
    frame = Image.new("RGBA", (target_w + 4, shot.height + 4), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, target_w + 3, shot.height + 3), radius=78, outline=HAIR + (255,), width=2)
    canvas.paste(frame, (x - 2, top - 2), frame)
    canvas.paste(shot, (x, top), shot)
    canvas = canvas.crop((0, 0, W, H))
    canvas.save(out_path, "PNG", optimize=True)

def wrap(d, text, f, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) <= max_w: cur = t
        else: lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines

if __name__ == "__main__":
    n = 0
    for i, (name, caps) in enumerate(ORDER, 1):
        src = os.path.join(SRC, f"{name}.png")
        if not os.path.exists(src): print("missing", name); continue
        for lang, (h, s) in caps.items():
            out = os.path.join(DST, f"{i}-{name}-{lang}.png"); compose(src, h, s, out); n += 1
    print("framed", n, "→", DST)
