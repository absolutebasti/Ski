# Naming — trademark check "Dropline" (2026-09-22)

Source: TMview search API (EUIPO/WIPO/national offices), EUIPO eSearch record, USPTO TSDR, iTunes Search API. This is a screening, not legal advice — a lawyer's clearance is still needed before the first upload.

## "Dropline" is not free

| Mark | Owner | Office / number | Classes | Goods | Status |
|---|---|---|---|---|---|
| DROPLINE | Oberalp Deutschland GmbH (Salewa / Dynafit group) | EUTM 018187956, also GB, CA, WO | 18, 25 | bags, backpacks, clothing, footwear (the Salewa "Dropline" speed-hiking shoe) | Registered 2020 |
| DROPLINE | Bell Sports LLC (Giro / Bell helmets and goggles) | US 97700138, WO 1729827 | 9 | "Goggles for sports, sports eyewear" — ski goggles | Registered 2022/2023, US first use July 2025 |
| DropLinesSurf | Victor Sanz Hernando | ES | 41 | surf school | Registered 2020 |

Why this matters for a ski app: downloadable software is class 9 — the same class as the Bell Sports goggle mark, in the same sport, and our mascot wears ski goggles. Salewa is one of the biggest alpine brands in the DACH market. Either could oppose an EU or DE application, and the App Store title would sit next to their products in search. Risk: high.

App Store: no exact "Dropline" app, but "Dropline!" and "Dropline.life" (small games) exist; a title "Dropline – Ski-Tracker & Duelle" would be unique but does not remove the trademark issue.

## Pre-screened alternatives (zero hits in TMview across all offices, classes 9/41/42)

- **Dropcount** — "count your drops"; international, describes the product.
- **Vertdrop** — vertical + drop.
- **Droprun** — drop + run.
- **Pistelab** — piste + lab; works in DE/FR/IT/EN.
- **Runcount**, **Snowvert** — free but weaker.

"Skidrop" and "Slopeline" have unrelated hits only (not in 9/41/42). "Fall Line" is crowded (118 marks). None of these have been checked as domains or App Store names yet.

## Process before the first TestFlight upload
1. Founder picks a name from the list (or another) → repeat the TMview screen for the exact word, then a paid clearance (DPMA + EUIPO + WIPO, classes 9, 41, 42).
2. File a DE or EU word mark in 9/41/42 (EUIPO ~850 € for one class online).
3. Rename in code: `kAppName` in app/lib/app/brand.dart, bundle id in app/ios (pbxproj + entitlements + Supabase Apple client id), Watch target name, App Store Connect record. Bundle id becomes permanent with the first upload.
