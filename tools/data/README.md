# tools/data — resort list

`import_resorts.py` builds `app/assets/data/resorts.json` (the bundled resort centres the
app uses for auto-detection, the pickers and the boards) from OpenSkiMap
(`tiles.openskimap.org/geojson/ski_areas.geojson`, OpenStreetMap data, ODbL).

```
python3 tools/data/import_resorts.py                  # full run (downloads the export only when the cache is empty)
python3 tools/data/import_resorts.py --refresh        # re-download the export if the cached copy is older than a day
python3 tools/data/import_resorts.py --skip-elevation # no elevation API calls, cache still used
python3 tools/data/import_resorts.py --report         # also list every merge (child → parent, reason)
python3 tools/data/import_resorts.py --sql            # print the resort_aliases INSERT, write nothing
python3 tools/data/import_resorts.py --baseline OLD.json  # ids of OLD.json must survive (default: current file)
```

- `curated.json` — the 52 hand-curated ids of the first release (`kitzbuehel`, `st-anton`,
  `soelden` …), each pinned to its OpenSkiMap feature by id prefix (`src`). Re-running never
  moves a curated id; a group that contains one keeps it as canonical id.
- `cache/` (gitignored) — `ski_areas.geojson` (≈ 20 MB) and `elevation.json` (centre
  elevations). Delete `elevation.json` to look every centre up again.
- The run fails if an id of the baseline file is neither an id nor an alias any more
  (`--allow-orphans` overrides) — days stored on phones and on the server reference them.

## Entry format

`{"id", "name", "country", "lat", "lon", "radiusKm", "baseAltM"?, "summitAltM"?, "runKm"?,
"aliases"?: [retired ids], "altFromCentre"?: true}`. `ResortRepository.fromJsonString`
reads `aliases` into `canonicalId()` / `byId()`; `Resort.fromJson` ignores the extra keys.

## Rules (DATA-RESORTS-2)

1. **Keep**: operating downhill areas with a name; umbrella areas > 400 run km (Ski amadé,
   Dolomiti Superski …) are dropped because they would swallow real resorts. Radius from
   the polygon area (or run length), 1.5–18 km.
2. **Exact name + country duplicates**: within 20 km → one entry, the larger run network
   wins, the other id becomes an alias. Farther apart (Crystal Mountain WA / MI) → both
   stay and get their locality or region appended.
3. **Verbund before Teilgebiet**: a smaller entry whose centre lies inside a larger entry's
   radius or source polygon and that shares an identifying name word (≥ 4 letters, not
   generic ski vocabulary, carried by fewer than 6 entries) becomes an alias of the largest
   such entry; the parent's radius grows to cover it (cap 18 km). `MERGE_INTO` forces
   groups the names do not show: Ski Arlberg = St. Anton/St. Christoph/Stuben + Lech/Zürs
   + Warth-Schröcken → canonical id `st-anton`. `KEEP_APART` protects `paradiski`.
4. **Altitudes**: entries without run altitudes get the centre elevation as base and summit
   (`altFromCentre: true`). Open-Elevation first (batches of 100, retried, cached); once its
   anonymous quota refuses, Open-Meteo's elevation API (Copernicus DEM) takes over, and it
   also retries the zeros SRTM returns north of 60° (Levi, Åre …). Entries still without a
   value carry no altitude keys (null in the app); no screen shows resort altitudes, the
   weather strip then asks Open-Meteo without an elevation.
5. **Aliases on the server**: migration `supabase/migrations/0018_resort_aliases.sql` holds
   the same pairs (`--sql`), canonicalises `days.resort_id` / `profiles.home_resort_id` on
   write, backfilled existing rows and lets `private.board` resolve alias ids. After a
   re-import that adds aliases, put the new `--sql` output in a new migration.

## Counts (run of 2026-09-30)

| step | count |
|---|---|
| OpenSkiMap features kept / dropped (not downhill, not operating, unnamed, umbrellas) | 4.925 / 7.352 |
| curated ids without an OpenSkiMap feature (carried as is) | 4 (oberstdorf, les-3-vallees, cervinia, val-gardena) |
| exact name + country duplicates merged | 60 |
| same name far apart, renamed with locality | 6 |
| sub-areas folded into their Verbund by name word | 118 |
| forced merges (Ski Arlberg) | 3 |
| parents whose radius grew to cover their children | 105 |
| groups re-anchored on a curated id / curated ids that became an alias | 2 / 1 (`lech-zuers` → `st-anton`) |
| ids of the previous file carried over as aliases | 5 |
| **entries total** (previous file: 4.929) | **4.748** |
| **aliases** | **186** |
| exact name + country duplicates left | 0 |
| entries without run altitudes | 842 |
| … filled from the centre elevation | 839 |
| **… still without altitude** (indoor halls below sea level: Rotterdam, Hoofddorp, Amsterdam) | **3** |

Checked by `app/test/data/resorts/` (St. Anton / St. Christoph / Stuben / Zürs / Lech /
Warth → `st-anton`; Damüls / Mellau / Faschina and the three old Damüls ids → one id; no
duplicates in either picker for "Arlberg") and `supabase/tests/0018_resort_aliases.sql`.
