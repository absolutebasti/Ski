#!/usr/bin/env python3
"""Build app/assets/data/resorts.json from OpenSkiMap (OpenStreetMap + Skimap.org, ODbL).

Source: https://tiles.openskimap.org/geojson/ski_areas.geojson (cached in tools/data/cache;
downloaded when missing, re-downloaded with --refresh when older than a day). Keeps operating downhill areas with a name, derives
centre, radius (polygon area or run length) and base/summit from run statistics. The 52
hand-curated ids of the first release live in tools/data/curated.json; each one is pinned
to its OpenSkiMap feature by id prefix ("src"), so re-running never moves a curated id.

Dedup (DATA-RESORTS-2, rules and counts in tools/data/README.md):
  1. exact name + country duplicates: within 20 km → one entry, the larger one wins and the
     other becomes an alias; farther apart → both stay and get their locality appended;
  2. a smaller entry whose centre lies inside a larger entry (its radius or source polygon)
     and that shares an identifying name word becomes an alias of the larger one ("Verbund
     vor Teilgebiet"); the parent's radius grows to cover the child (cap 18 km);
  3. entries without base/summit altitude get the centre elevation from Open-Elevation
     (both fields, marked "altFromCentre": true; Open-Meteo's elevation API takes over once
     Open-Elevation's anonymous quota is used up); still-unknown ones carry no altitude.
A curated id never becomes the alias of a generated one: a group that contains a curated
id keeps it as the canonical id. Every id of the previous resorts.json survives as an id or
as an alias (the run fails otherwise).

    python3 tools/data/import_resorts.py [--refresh] [--skip-elevation] [--baseline FILE] [--report]
    python3 tools/data/import_resorts.py --sql     # alias pairs for migration 0018, no write
"""
import argparse, collections, json, math, os, re, sys, time, unicodedata, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "cache", "ski_areas.geojson")
ELEV_CACHE = os.path.join(HERE, "cache", "elevation.json")
CURATED = os.path.join(HERE, "curated.json")
DST = os.path.join(ROOT, "app", "assets", "data", "resorts.json")

NEAR_DUP_KM = 20.0     # same name + country within this distance = one resort mapped twice
GENERIC_DF = 6         # a name word carried by this many entries identifies nothing ('valley', 'skisenter')
MAX_RADIUS_KM = 18.0   # also the bbox pre-check in ResortRepository.nearest()
GENERATED_ID = re.compile(r"-[a-z]{2}-([0-9a-f]{6})(-[0-9a-f]{4})?$")

# OpenSkiMap id prefix → id prefix of the Verbund it belongs to, where the names do not show
# it. Ski Arlberg = St. Anton/St. Christoph/Stuben + Lech/Zürs + Warth-Schröcken (Flexenbahn
# 2016, Auenfeldjet 2013).
MERGE_INTO = {"66e672": "53410f", "c5107f": "53410f", "29248a": "53410f"}
# Two curated ids in one group: the one listed here stays canonical (else the larger one).
CANONICAL_FIRST = {"st-anton"}
# Curated ids that are never folded into a bigger neighbour: 'Les Arcs – La Plagne' shares a
# word with La Plagne, but the two halves of Paradiski do not fit one 18 km circle.
KEEP_APART = {"paradiski"}

# generic words that never identify a resort
STOP = {"ski", "skigebiet", "skigebiete", "arena", "resort", "am", "im", "in", "an", "der", "die", "das", "und", "bahn", "bahnen", "lifte", "lift", "gletscher", "glacier", "tal", "berg", "alm", "see", "st", "sankt", "mountain", "park", "area", "amade", "space", "snow", "circus", "welt", "world", "station", "domaine", "skiable", "family", "familien", "dorf", "lifts", "skilift", "skilifte", "schlepplift", "sessellift", "seilbahn", "bergbahnen", "bergbahn", "estacion", "invernal", "montana", "sector", "nordique", "alpin", "outdoor"}

def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:40]

def words(name):
    """Identifying words of a name: ASCII-folded, 4+ letters, no generic ski vocabulary."""
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    return {w for w in re.split(r"[^a-z0-9]+", s) if len(w) >= 4 and w not in STOP}

def haversine_km(a, b, c, d):
    p = math.pi / 180
    x = 0.5 - math.cos((c - a) * p) / 2 + math.cos(a * p) * math.cos(c * p) * (1 - math.cos((d - b) * p)) / 2
    return 12742 * math.asin(math.sqrt(x))

def rings(geom):
    """Outer rings (lon/lat lists) of a Polygon/MultiPolygon, [] for a Point."""
    t = geom["type"]
    if t == "Polygon": return [geom["coordinates"][0]]
    if t == "MultiPolygon": return [poly[0] for poly in geom["coordinates"]]
    return []

def point_in_rings(lat, lon, rs):
    """Even-odd ray cast against every outer ring."""
    for ring in rs:
        inside = False
        n = len(ring)
        for i in range(n):
            x1, y1 = ring[i][0], ring[i][1]
            x2, y2 = ring[(i + 1) % n][0], ring[(i + 1) % n][1]
            if (y1 > lat) != (y2 > lat):
                x = x1 + (lat - y1) * (x2 - x1) / (y2 - y1)
                if x > lon: inside = not inside
        if inside: return True
    return False

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

def size(e):
    """'Larger' = longer run network, then bigger radius (runKm is the honest measure of a Verbund)."""
    return (e.get("runKm") or 0.0, e["_r0"])

def cover_of(e):
    """Points a parent's circle has to reach to contain this entry: (lat, lon, pad_km)."""
    pts = [(p[1], p[0], 0.3) for ring in e["_rings"] for p in ring[::max(1, len(ring) // 60)]]
    return pts or [(e["lat"], e["lon"], e["_r0"])]

def reach_km(parent, cover):
    return max(haversine_km(parent["lat"], parent["lon"], a, b) + pad for a, b, pad in cover)

SRC_URL = "https://tiles.openskimap.org/geojson/ski_areas.geojson"

def ensure_source(refresh):
    """Downloads the OpenSkiMap export when it is missing (or older than a day with --refresh)."""
    if os.path.exists(SRC) and not (refresh and time.time() - os.path.getmtime(SRC) > 86400): return
    os.makedirs(os.path.dirname(SRC), exist_ok=True)
    print(f"  downloading {SRC_URL} …", file=sys.stderr)
    tmp = SRC + ".part"
    with urllib.request.urlopen(SRC_URL, timeout=300) as r, open(tmp, "wb") as f:
        while chunk := r.read(1 << 20): f.write(chunk)
    os.replace(tmp, SRC)

def load_entries(curated):
    """One entry per operating downhill area; private '_' fields feed the dedup pass."""
    d = json.load(open(SRC))
    pinned = {o["src"]: o for o in curated if o.get("src")}
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
        if area > 0:
            radius = math.sqrt(area / math.pi) * 1.4 + 1.0
        else:
            radius = 1.5 + 0.06 * run_km
        radius = round(min(max(radius, 1.5), MAX_RADIUS_KM), 1)
        if run_km > 400:  # marketing umbrellas (Ski amadé, Dolomiti Superski …) would swallow real resorts
            dropped += 1; continue
        src = p["id"][:6]
        gen_id = f"{slug(p['name'])}-{country.lower()}-{src}"
        pin = pinned.get(src)
        if pin and pin["id"] not in seen_ids:
            rid, name = pin["id"], pin["name"]    # first-release id and display name stay
        else:
            rid, name = gen_id, p["name"]
        if rid in seen_ids: rid = rid + "-" + p["id"][6:10]
        seen_ids.add(rid)
        entry = {"id": rid, "name": name, "country": country, "lat": round(lat, 4), "lon": round(lon, 4), "radiusKm": radius}
        if mins: entry["baseAltM"] = int(round(min(mins)))
        if maxs: entry["summitAltM"] = int(round(max(maxs)))
        if run_km: entry["runKm"] = round(run_km, 1)
        loc = [(pl.get("localized") or {}).get("en") or {} for pl in places]
        entry["_osm"] = p["name"]
        entry["_words"] = words(name) | words(p["name"])
        entry["_rings"] = rings(g)
        entry["_src"] = src
        entry["_r0"] = radius
        entry["_places"] = [x for x in ([l.get("locality") for l in loc] + [l.get("region") for l in loc]) if x]
        out.append(entry); kept += 1
    # curated resorts without an OpenSkiMap feature (or whose feature vanished) keep their entry
    carried = []
    for o in curated:
        if o["id"] in seen_ids: continue
        if o.get("src"): print(f"  ! curated '{o['id']}': pinned feature {o['src']} is gone, entry carried over as is", file=sys.stderr)
        e = {k: v for k, v in o.items() if k != "src"}
        e.update(_osm=o["name"], _words=words(o["name"]), _rings=[], _src="", _r0=o["radiusKm"], _places=[])
        out.append(e); seen_ids.add(o["id"]); carried.append(o["id"])
    return out, kept, dropped, carried

def dedup(out, curated_ids, log):
    """Folds duplicates and sub-areas into their parent. Returns (entries, counters)."""
    by_id = {e["id"]: e for e in out}
    stats = collections.Counter()
    parent = {}            # alias id → parent id (may chain)
    def root(i):
        while i in parent: i = parent[i]
        return i
    def merge(child, into, why):
        parent[child["id"]] = into["id"]
        stats[why.split(":")[0]] += 1
        into.setdefault("_cover", []).extend(cover_of(child) + child.get("_cover", []))
        log.append((child, into, why))

    # 1. exact name + country duplicates. Close together = one resort mapped twice: the larger
    #    one wins. Far apart = two places that share a name (Crystal Mountain WA / MI): both
    #    stay and get their locality or region appended, so the name is unique again.
    groups = collections.defaultdict(list)
    for e in out: groups[(e["name"].casefold(), e["country"])].append(e)
    for members in groups.values():
        if len(members) < 2: continue
        members.sort(key=lambda e: (e["id"] in curated_ids, size(e)), reverse=True)
        keep = [members[0]]
        for m in members[1:]:
            near = min(keep, key=lambda k: haversine_km(m["lat"], m["lon"], k["lat"], k["lon"]))
            if haversine_km(m["lat"], m["lon"], near["lat"], near["lon"]) <= NEAR_DUP_KM: merge(m, near, "exact")
            else: keep.append(m)
        if len(keep) > 1:
            used = set()
            for k in keep:
                others = {pl for o in keep if o is not k for pl in o["_places"]}
                tag = next((pl for pl in k["_places"] if pl not in others and pl not in used and pl.casefold() != k["name"].casefold()), None)
                if tag is None: raise SystemExit(f"cannot disambiguate '{k['name']}' ({k['country']}): no distinct locality or region")
                used.add(tag); k["name"] = f"{k['name']} ({tag})"; stats["renamed"] += 1

    # 2. Teilgebiet inside a Verbund: centre inside the larger entry's own radius or source
    #    polygon, and a shared identifying name word → alias of the largest such entry.
    #    Containment uses the radius before any growth, so a parent cannot snowball through
    #    the areas it has already taken in; a child the 18 km cap could not cover stays.
    df = collections.Counter(w for e in out for w in e["_words"])
    for e in out: e["_key"] = {w for w in e["_words"] if df[w] < GENERIC_DF}
    live = sorted((e for e in out if e["id"] not in parent), key=size)
    by_src = {e["_src"]: e for e in live if e["_src"]}
    for i, child in enumerate(live):
        best = why = None
        forced = by_src.get(MERGE_INTO.get(child["_src"]))
        if forced is not None:
            best, why = forced, "forced"
        elif child["id"] not in KEEP_APART:
            for big in live[i + 1:]:
                if big["country"] != child["country"] or size(big) <= size(child): continue
                if abs(big["lat"] - child["lat"]) > 0.5: continue
                shared = child["_key"] & big["_key"]
                if not shared: continue
                dist = haversine_km(big["lat"], big["lon"], child["lat"], child["lon"])
                if dist > big["_r0"] and not point_in_rings(child["lat"], child["lon"], big["_rings"]): continue
                if reach_km(big, cover_of(child) + child.get("_cover", [])) > MAX_RADIUS_KM: stats["too_far"] += 1; continue
                if best is None or size(big) > size(best): best, why = big, "word:" + min(shared)
        if best is not None:
            merge(child, best, why)

    # 3. curated ids stay canonical: a group whose root is a generated id takes the id of its
    #    curated member (CANONICAL_FIRST, then the largest); every other id becomes an alias.
    members = collections.defaultdict(list)
    for e in out:
        if e["id"] in parent: members[root(e["id"])].append(e["id"])
    final = []
    for e in out:
        if e["id"] in parent: continue
        rid, ids = e["id"], members.get(e["id"], [])
        cur = sorted((m for m in ids if m in curated_ids), key=lambda m: (m in CANONICAL_FIRST, size(by_id[m])), reverse=True)
        keep_id = rid if rid in curated_ids or not cur else cur[0]
        if keep_id != rid:
            stats["reanchored"] += 1
            # same words, nicer spelling: 'Andermatt-Sedrun-Disentis' over 'Andermatt+Disentis+Sedrun'
            if words(by_id[keep_id]["name"]) == words(e["name"]): e["name"] = by_id[keep_id]["name"]
        stats["curated_alias"] += len([m for m in ids + [rid] if m in curated_ids and m != keep_id])
        entry = {k: v for k, v in e.items() if not k.startswith("_")}
        entry["id"] = keep_id
        if e.get("_cover"):
            entry["radiusKm"] = round(min(MAX_RADIUS_KM, max(e["_r0"], reach_km(e, e["_cover"]))), 1)
            if entry["radiusKm"] != e["_r0"]: stats["grown"] += 1
        aliases = sorted(a for a in ids + [rid] if a != keep_id)
        if aliases: entry["aliases"] = aliases
        entry["_srcs"] = {by_id[m]["_src"] for m in ids + [rid]} - {""}
        final.append(entry)
    return final, stats

def carry_over(final, baseline):
    """Every id/alias of the previous file must still resolve. A generated id whose feature now
    carries another id (curated pin, renamed in OpenStreetMap) becomes an alias of that entry.
    Returns (carried, orphans)."""
    known = {e["id"] for e in final} | {a for e in final for a in e.get("aliases", [])}
    by_src = {s: e for e in final for s in e["_srcs"]}
    carried, orphans = [], []
    for old in sorted({e["id"] for e in baseline} | {a for e in baseline for a in e.get("aliases", [])}):
        if old in known: continue
        m = GENERATED_ID.search(old)
        target = by_src.get(m.group(1)) if m else None
        if target is None: orphans.append(old); continue
        target["aliases"] = sorted(target.get("aliases", []) + [old]); known.add(old); carried.append(old)
    return carried, orphans

def _open_elevation(batch):
    body = json.dumps({"locations": [{"latitude": a, "longitude": b} for a, b in batch]}).encode()
    req = urllib.request.Request("https://api.open-elevation.com/api/v1/lookup", data=body,
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        raw = json.loads(urllib.request.urlopen(req, timeout=60).read())
    except urllib.error.HTTPError as ex:
        if ex.code in (402, 403, 429): raise QuotaError(f"HTTP {ex.code}")
        raise
    if raw.get("code") or raw.get("error"): raise QuotaError(raw.get("error") or raw.get("code"))
    res = raw.get("results", [])
    if len(res) != len(batch): raise ValueError(f"{len(res)} results for {len(batch)} points")
    return [r.get("elevation") for r in res]   # results come back in request order

def _open_meteo(batch):
    """Fallback: Open-Meteo's elevation API (Copernicus DEM 90 m, 100 points per call, no key)."""
    q = "latitude=" + ",".join(str(a) for a, _ in batch) + "&longitude=" + ",".join(str(b) for _, b in batch)
    raw = json.loads(urllib.request.urlopen("https://api.open-meteo.com/v1/elevation?" + q, timeout=60).read())
    res = raw.get("elevation") or []
    if len(res) != len(batch): raise ValueError(f"{len(res)} results for {len(batch)} points")
    return res

class QuotaError(Exception):
    pass

def lookup_elevations(points, cache):
    """Centre elevation for the (lat, lon) pairs missing from the cache; batched (100), retried,
    cached after every batch. Open-Elevation first; once it refuses (anonymous monthly quota,
    repeated failures) the remaining batches go to Open-Meteo. A batch that fails on both is
    left out and retried on the next run."""
    todo = [p for p in points if f"{p[0]},{p[1]}" not in cache]
    sources = [("open-elevation", _open_elevation), ("open-meteo", _open_meteo)]
    for i in range(0, len(todo), 100):
        batch = todo[i:i + 100]
        while sources:
            name, fetch = sources[0]
            res = None
            for attempt in range(3):
                try:
                    res = fetch(batch); break
                except QuotaError as ex:
                    print(f"  {name}: {ex} - switching source", file=sys.stderr); break
                except Exception as ex:  # rate limit / timeout: back off
                    print(f"  {name} batch {i // 100 + 1}: {ex} (attempt {attempt + 1})", file=sys.stderr)
                    time.sleep(3 * (attempt + 1))
            if res is not None:
                for (a, b), elev in zip(batch, res): cache[f"{a},{b}"] = elev
                break
            sources.pop(0)
        if not sources:
            print("  elevation lookup gave up; the missing altitudes stay empty (re-run later)", file=sys.stderr); break
        json.dump(cache, open(ELEV_CACHE, "w"))
        time.sleep(0.5)

def fill_altitudes(out, skip_lookup):
    """Centre elevation for entries without run altitudes. Returns (missing, filled)."""
    missing = [e for e in out if "baseAltM" not in e or "summitAltM" not in e]
    cache = json.load(open(ELEV_CACHE)) if os.path.exists(ELEV_CACHE) else {}
    if not skip_lookup:
        pts = [(e["lat"], e["lon"]) for e in missing]
        lookup_elevations(pts, cache)
        # Open-Elevation (SRTM) has no data north of 60° and answers 0 there (Levi, Åre …):
        # zero/empty cache hits get one more try on Open-Meteo's Copernicus DEM.
        zero = [pt for pt in pts if not (cache.get(f"{pt[0]},{pt[1]}") or 0) > 0]
        for i in range(0, len(zero), 100):
            batch = zero[i:i + 100]
            try:
                for (a, b), elev in zip(batch, _open_meteo(batch)):
                    if elev and elev > 0: cache[f"{a},{b}"] = elev
            except Exception as ex:
                print(f"  open-meteo retry of zero elevations: {ex}", file=sys.stderr); break
        json.dump(cache, open(ELEV_CACHE, "w"))
    filled = 0
    for e in missing:
        elev = cache.get(f"{e['lat']},{e['lon']}")
        if elev is None or elev <= 0: continue   # 0 = sea level / no data in both services
        alt = int(round(elev))
        e.setdefault("baseAltM", alt); e.setdefault("summitAltM", alt)
        e["altFromCentre"] = True; filled += 1
    return len(missing), filled

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--refresh", action="store_true", help="re-download the OpenSkiMap export if the cached copy is older than a day")
    ap.add_argument("--skip-elevation", action="store_true", help="do not call Open-Elevation / Open-Meteo (the cache is still used)")
    ap.add_argument("--baseline", default=DST, help="previous resorts.json whose ids must survive (default: the current file)")
    ap.add_argument("--allow-orphans", action="store_true", help="write the file although ids of the baseline are gone")
    ap.add_argument("--report", action="store_true", help="list every merge (child → parent, reason)")
    ap.add_argument("--sql", action="store_true", help="print the alias INSERT for migration 0018 instead of writing")
    args = ap.parse_args()

    ensure_source(args.refresh)
    curated = json.load(open(CURATED))
    baseline = json.load(open(args.baseline)) if os.path.exists(args.baseline) else []
    out, kept, dropped, carried_curated = load_entries(curated)
    log = []
    out, stats = dedup(out, {o["id"] for o in curated}, log)
    carried, orphans = carry_over(out, baseline)
    for e in out: e.pop("_srcs")
    missing, filled = fill_altitudes(out, args.skip_elevation or args.sql)
    out.sort(key=lambda e: (e["country"], e["name"].lower(), e["id"]))

    pairs = sorted((a, e["id"]) for e in out for a in e.get("aliases", []))
    ids = [e["id"] for e in out]
    assert len(set(ids)) == len(ids), "duplicate ids"
    assert not {a for a, _ in pairs} & set(ids), "an alias is also a canonical id"
    assert len({a for a, _ in pairs}) == len(pairs), "an alias points at two entries"
    if args.sql:
        print("insert into public.resort_aliases (alias_id, canonical_id) values")
        print(",\n".join(f"  ('{a}', '{c}')" for a, c in pairs))
        print("on conflict (alias_id) do update set canonical_id = excluded.canonical_id;")
        return
    if args.report:
        for child, into, why in sorted(log, key=lambda m: (m[1]["country"], m[1]["name"], m[0]["name"])):
            d = haversine_km(child["lat"], child["lon"], into["lat"], into["lon"])
            print(f"  {child['country']} {child['_osm']!r} ({child.get('runKm', 0)} km) → {into['_osm']!r} ({into.get('runKm', 0)} km), {d:.1f} km apart [{why}]")
    if orphans:
        print(f"! {len(orphans)} ids of {args.baseline} are neither an id nor an alias any more: {orphans[:20]}", file=sys.stderr)
        if not args.allow_orphans: raise SystemExit(1)

    json.dump(out, open(DST, "w"), ensure_ascii=False, separators=(",", ":"))
    kb = os.path.getsize(DST) // 1024
    no_alt = sum(1 for e in out if "baseAltM" not in e or "summitAltM" not in e)
    dups = sum(1 for v in collections.Counter((e["name"].casefold(), e["country"]) for e in out).values() if v > 1)
    print(f"kept {kept}, dropped {dropped}, curated ids {len(curated)} ({len(carried_curated)} without an OpenSkiMap feature: {', '.join(carried_curated)})")
    print(f"merged: exact duplicates {stats['exact']}, sub-areas by name {stats['word']}, forced {stats['forced']}; same name far apart renamed {stats['renamed']}; "
          f"groups re-anchored on a curated id {stats['reanchored']}, curated ids that became an alias {stats['curated_alias']}, parents grown {stats['grown']}, not merged (beyond {MAX_RADIUS_KM:.0f} km) {stats['too_far']}")
    print(f"ids of the baseline carried over as aliases: {len(carried)} {carried}; orphans: {len(orphans)}")
    print(f"altitude: {missing} without run altitudes, {filled} filled from the centre elevation, {no_alt} still without")
    print(f"total {len(out)} entries, {len(pairs)} aliases, exact name+country duplicates left: {dups}, {kb} KB")
    print("by country:", collections.Counter(e["country"] for e in out).most_common(12))

if __name__ == "__main__":
    main()
