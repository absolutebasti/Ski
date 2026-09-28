#!/usr/bin/env python3
"""Build app/assets/data/resorts.json from OpenSkiMap (OpenStreetMap + Skimap.org, ODbL).

Source: https://tiles.openskimap.org/geojson/ski_areas.geojson (cached in tools/data/cache,
re-download at most once a day). Keeps operating downhill areas with a name, derives
centre, radius (polygon area or run length), base/summit from run statistics, and keeps the
52 hand-curated ids of the first release stable by matching name + country within 15 km.
"""
import json, math, os, re, sys, unicodedata, uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "cache", "ski_areas.geojson")
DST = os.path.join(ROOT, "app", "assets", "data", "resorts.json")

def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:40]

# OpenSkiMap id prefix → curated id where the token match cannot see it
# (KitzSki is Kitzbühel, Corviglia is St. Moritz's main area).
ALIASES = {"1eeb56": "kitzbuehel", "f9beaf": "st-moritz"}

STOP = {"ski", "skigebiet", "arena", "resort", "am", "im", "in", "an", "der", "die", "das", "und", "und", "bahn", "bahnen", "lifte", "lift", "gletscher", "glacier", "tal", "berg", "alm", "see", "st", "sankt", "mountain", "park", "area", "amade", "space", "snow", "circus", "welt", "world", "arlberg"}
def tokens(name):
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    toks = set()
    for w in re.split(r"[^a-z0-9]+", s):
        if len(w) < 4 or w in STOP: continue
        toks.add(w); toks.add(w[:5])   # 'kitzbuhel' ~ 'kitzski' via the 5-char stem
    return toks

def haversine_km(a, b, c, d):
    p = math.pi / 180
    x = 0.5 - math.cos((c - a) * p) / 2 + math.cos(a * p) * math.cos(c * p) * (1 - math.cos((d - b) * p)) / 2
    return 12742 * math.asin(math.sqrt(x))

def centroid_and_area(geom):
    """Returns (lat, lon, area_km2) for Point/Polygon/MultiPolygon in lon/lat."""
    t = geom["type"]
    if t == "Point":
        lon, lat = geom["coordinates"][:2]
        return lat, lon, 0.0
    polys = [geom["coordinates"]] if t == "Polygon" else geom["coordinates"]
    sx = sy = sa = 0.0
    for poly in polys:
        ring = poly[0]
        lat0 = sum(p[1] for p in ring) / len(ring)
        kx = 111.32 * math.cos(lat0 * math.pi / 180); ky = 110.57
        a = cx = cy = 0.0
        for i in range(len(ring) - 1):
            x1, y1 = ring[i][0] * kx, ring[i][1] * ky
            x2, y2 = ring[i + 1][0] * kx, ring[i + 1][1] * ky
            cross = x1 * y2 - x2 * y1
            a += cross; cx += (x1 + x2) * cross; cy += (y1 + y2) * cross
        a *= 0.5
        if abs(a) < 1e-9:
            continue
        cx /= (6 * a); cy /= (6 * a)
        sx += cx / kx * abs(a); sy += cy / ky * abs(a); sa += abs(a)
    if sa == 0:
        ring = polys[0][0]
        return sum(p[1] for p in ring) / len(ring), sum(p[0] for p in ring) / len(ring), 0.0
    return sy / sa, sx / sa, sa

def main():
    old = json.load(open(DST)) if os.path.exists(DST) else []
    d = json.load(open(SRC))
    out, seen_ids = [], set()
    kept = dropped = 0
    for f in d["features"]:
        p = f["properties"]; g = f.get("geometry")
        if not g or p.get("type") != "skiArea" or not p.get("name"): dropped += 1; continue
        if p.get("status") not in (None, "operating"): dropped += 1; continue
        acts = p.get("activities") or []
        if "downhill" not in acts: dropped += 1; continue
        places = p.get("places") or []
        country = next((pl.get("iso3166_1Alpha2") for pl in places if pl.get("iso3166_1Alpha2")), None)
        if not country: dropped += 1; continue
        lat, lon, area = centroid_and_area(g)
        stats = ((p.get("statistics") or {}).get("runs") or {}).get("byActivity", {}).get("downhill", {}).get("byDifficulty", {})
        run_km = sum((v or {}).get("lengthInKm", 0) or 0 for v in stats.values())
        mins = [v["minElevation"] for v in stats.values() if v and v.get("minElevation") is not None]
        maxs = [v["maxElevation"] for v in stats.values() if v and v.get("maxElevation") is not None]
        lifts = (p.get("statistics") or {}).get("lifts") or {}
        if area > 0:
            radius = math.sqrt(area / math.pi) * 1.4 + 1.0
        else:
            radius = 1.5 + 0.06 * run_km
        radius = round(min(max(radius, 1.5), 18.0), 1)
        if run_km > 400:  # marketing umbrellas (Ski amadé, Dolomiti Superski …) would swallow real resorts
            dropped += 1; continue
        # keep first-release ids (and display names) where a curated resort matches:
        # same country, within 12 km, and one shared name token ('kitz', 'ischgl', 'lech' …)
        rid, name = None, p["name"]
        alias = ALIASES.get(p["id"][:6])
        if alias and alias not in seen_ids:
            rid, name = alias, next(o["name"] for o in old if o["id"] == alias)
        for o in ([] if rid else old):
            if o["country"] != country or o["id"] in seen_ids: continue
            if haversine_km(o["lat"], o["lon"], lat, lon) > 12: continue
            if tokens(o["name"]) & tokens(p["name"]):
                rid, name = o["id"], o["name"]; break
        if rid is None:
            rid = f"{slug(p['name'])}-{country.lower()}-{p['id'][:6]}"
        if rid in seen_ids: rid = rid + "-" + p["id"][6:10]
        seen_ids.add(rid)
        entry = {"id": rid, "name": name, "country": country, "lat": round(lat, 4), "lon": round(lon, 4), "radiusKm": radius}
        if mins: entry["baseAltM"] = int(round(min(mins)))
        if maxs: entry["summitAltM"] = int(round(max(maxs)))
        if run_km: entry["runKm"] = round(run_km, 1)
        out.append(entry); kept += 1
    # curated resorts that OpenSkiMap did not match keep their entry
    for o in old:
        if o["id"] not in seen_ids:
            out.append(o); seen_ids.add(o["id"])
    out.sort(key=lambda e: (e["country"], e["name"].lower()))
    json.dump(out, open(DST, "w"), ensure_ascii=False, separators=(",", ":"))
    kb = os.path.getsize(DST) // 1024
    import collections
    print(f"kept {kept}, dropped {dropped}, curated carried over {len([o for o in old if o['id'] in seen_ids])}/{len(old)}, total {len(out)}, {kb} KB")
    print("by country:", collections.Counter(e["country"] for e in out).most_common(12))

if __name__ == "__main__":
    main()
