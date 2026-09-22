# Schwung — Design system v2 "Instrument" (2026-09-22)

Founder verdict on v1: "zu generisch, nicht abgerundet genug, sieht aus wie eine unfertige App". Three directions were proposed (premium-dark, editorial-light, alpine-modern) and judged from founder-taste, Flutter-engineer and skier-outdoors lenses; **premium-dark "Instrument"** won all three (35.5 / 28.5 / 26.5). This document is the binding spec. Public widget constructors stay source-compatible; new parameters default to the old behaviour.

## 0. Decisions (lead) and grafts from the other directions

1. **Dark-first.** `ThemeMode.dark` ships; the light theme stays correct and gets a user toggle later (Einstellungen → Erscheinungsbild).
2. **One solid champagne CTA** with ink label; no gradients on controls. Exactly three gradients in the app (page top, champagne radial behind Start/Tagesbilanz/share card, ink scrim over photos).
3. **Overline above the numeral** everywhere; units are separate tertiary text; numerals are never grey. This replaces every "·"-joined sentence with number/unit/label triples in fixed-flex columns that align down a list.
4. **Route is the hero surface** (graft from alpine-modern): drawn from stored points at 84 px (rows), 16:9 (Letzter Tag card, Tagesbilanz top block) and full-bleed (Tag detail map). Fallback order cached PNG → live CustomPaint → contour pattern. **The skier-glyph placeholder box is deleted.**
5. **Semantic colour pair on every surface** (graft): champagne = Abfahrt, liftGrey dashed = Lift, identical on map, thumbnail, time bar, altitude profile, run list, share card. Max one accent element visible at a time; ice only for live/GPS, danger only for failure.
6. **Glass only on tab bar and sheets** (judge correction): docks use surface@94 % solid; never BackdropFilter over the live map.
7. **Hold-to-end = danger sweep with label inversion** (graft from editorial-light): the label is drawn twice and clipped at the sweep edge; no CircularProgressIndicator. Raw-pointer Listener stays.
8. **PB strip = three equal 64 pt tiles**; records never as chips. Mascot only as a 16:9 card or pull-quote, never a floating circle.
9. **Map tiles** without a branded dark URL get `ColorFiltered` desaturate+darken plus a dark veil under the track (graft); a dark `MAP_TILE_URL` before the store build is a founder decision.
10. **Fix `AppColors.copyWith`/`lerp`** (real bug) and keep old field names as getters so account/social/sync files compile.
11. **Hero transition** from a Tage row's route into the Tag-detail map (graft, ~15 lines).
12. **German copy pass** in the same change: the simulator screenshots rendered English; German is the product language, `Fmt` with de separators, "–" for undefined.
13. **Contrast guard**: unit test asserting every text token ≥ 4.5:1 on its surface (tertiary allowed only for overlines/glyphs ≥ 11 pt bold and never body copy).
14. **Icons**: one family (Material Symbols Rounded, weight 400) + six custom CustomPaint glyphs (chevron, slalom, chairlift, gauge, flake, crest); tab bar icons custom.
15. Season delta line under the Saison hero ("+412 hm zur Vorsaison") when a previous season exists.

## 1. Thesis

Schwung should feel like a precision instrument you clip to your jacket: black, quiet, and absolutely legible — the numbers are the interface, everything else is a hairline holding them in place. Today it feels unfinished for eleven concrete reasons, all fixable without new packages. (1) It ships as a LIGHT app: ThemeMode.system means the founder sees a warm cream field with white cards — the exact opposite of the ShapeMe/Slopes DNA he's benchmarking. (2) The primary button is a pale champagne gradient with a cream label (~1.6:1 contrast) — it reads as disabled, and that one control is the whole product. (3) Heute idle has ~600 pt of dead space between the season line and the button: the screen's most valuable fact (5.717 Höhenmeter this season) is rendered as 15 pt grey body text while the middle of the screen is empty. (4) All data is `·`-joined grey strings ("3 runs · 1,849 m · 69 km/h") instead of number/unit/label triples — nothing is tabular, nothing aligns, nothing is scannable with goggles on. (5) Cards are plain rectangles with a 1 px border and no internal rhythm; there is no elevation system at all. (6) The Tage thumbnails are three identical grey boxes with a skier glyph — the single most "unfinished-app" artefact in the screenshots. (7) The PB chips wrap into a ragged 2+1 line of three different widths. (8) The tab bar and app bar are stock Material 3 (pill indicator, white bar, gear icon) — instantly recognisable as a default Flutter app. (9) StatTile puts the label under the number, so baselines never line up in a grid. (10) Tagesbilanz — the emotional payoff of the entire product — is a flat list with grey record chips. (11) Onboarding wastes a 250 px cream band above a full-bleed photo and sets body copy at 4:1 grey-on-cream. The fix is not new features: it's a dark-first token set, one solid champagne, a numeral system with the label above a locked baseline, glass docks, and route art that is always drawn.

## 2. Tokens
```
DARK (default — propose ThemeMode.dark, keep light valid)
bg #0B0C0E · bgTop #121316 (page gradient top 240 pt) · ink #07070A (scrims, share card, live screen base)
surface #16181C · surfaceRaised #1D2026 · glassFill rgba(255,255,255,0.055) · glassStroke rgba(255,255,255,0.075)
hairline #24272D · hairlineStrong #31353D · topHighlight rgba(255,255,255,0.07)→transparent over top 24 px of every card
textPrimary #F6F4EE (cream from the app icon) · textSecondary #A2A7B0 · textTertiary #6A6F79 · textQuaternary #474C55
accent (champagne) #E3C88C · accentHi #F2DDB0 · accentPressed #C9AC6E · accentDim #8A7645 · accentWash #E3C88C@10% · accentGlow #E3C88C@18%
ice (live/speed/GPS) #8FD8F5 · iceDim #2C5A6E · iceWash #8FD8F5@12%
danger #FF5A4A · dangerWash #FF5A4A@10% · dangerDim #4A1C18
liftGrey #5B616B · runColor = accent · pauseColor #24272D · signalLoss #FF5A4A@60%
onAccent #0B0C0E (ink label on champagne — never cream)
LIVE/GLARE OVERRIDE (recording): bg #000000, surface #0E0F11, textPrimary #FFFFFF, accent #FFD98A, ice #A8E4FB. Applied by wrapping LiveView in a Theme with AppColors.glare — one extra const, no new screen.

LIGHT (cold snow, not cream soup — the warm cream stays brand-only: onboarding hero, share card, icon)
bg #F4F2ED · bgTop #FFFFFF · surface #FFFFFF · surfaceRaised #FBFAF7 · glassFill rgba(255,255,255,0.72)
hairline #E4E0D7 · hairlineStrong #D2CCBE
textPrimary #0E1013 · textSecondary #5A5F68 · textTertiary #8B9098 · textQuaternary #AFB4BB
accent #7A5E1E (4.9:1 on #FFF) · accentPressed #634C16 · accentWash #E3C88C@22% · onAccent #FFFFFF
ice #0A6E9E · danger #D6321F · liftGrey #8B9098

RADII (use RSuperellipse / RoundedSuperellipseBorder — Apple squircle; fall back to RRect)
r4 ticks · r10 inner chips & thumbnail insets · r14 stat tile · r20 card & list row · r28 sheet top / hero media · r999 pills & all buttons

SPACING (4 pt base): 4 · 8 · 12 · 16 · 20 · 24 · 28 · 32 · 40 · 56
page gutter 20 · card padding 18 (20 for hero cards) · gap between cards 12 · section gap 28 · dock inner padding 16/16/16/safe

ELEVATION — three layers only, no Material shadows anywhere
L0 page: LinearGradient(#121316 → #0B0C0E, top 240 pt), then flat bg.
L1 card: surface fill + BorderSide(0.5, hairline) + topHighlight inset line. No shadow.
L2 floating (bottom dock, sheets, toasts, map controls): BackdropFilter(sigma 30) + surface@88% + BorderSide(0.5, glassStroke) + BoxShadow(#000@55%, blur 40, dy 8, spread -8).
Exception: never BackdropFilter over the live map (moving raster = expensive) — use surface@94% solid there.

HAIRLINES: always 0.5 logical px in dark (≈1.5 device px at dpr 3, reads as a drawn line, not a border), 1.0 in light. Dividers inside cards inset 18 left.

FOCUS/PRESS: press scale 0.985 + opacity 0.9, 120 ms easeOut. No splash, no ripple (NoSplash already set).
```

## 3. Typography
```
Keep the bundled families — Inter (400/500/600/700) and InterDisplay (700/800/900). InterDisplay-Black is already in assets and currently unused; it becomes the numeral face. FontFeature.tabularFigures() on every numeric style, plus FontFeature('ss01') is not needed. Add slashed-zero only if he asks.

SCALE (size / line-height / tracking / family-weight)
numeric-xxl  92 / 0.88 / -0.045em / InterDisplay 900   Tagesbilanz hero, live lead metric
numeric-xl   64 / 0.90 / -0.040em / InterDisplay 900   Saison hero card, Heute-live lead on small phones
numeric-l    44 / 0.94 / -0.032em / InterDisplay 900   Tag-detail 3-up
numeric-m    34 / 0.96 / -0.028em / InterDisplay 800   stat tiles, live secondary
numeric-s    22 / 1.00 / -0.018em / InterDisplay 800   list-row metrics, PB tiles, run rows
numeric-xs   15 / 1.00 / -0.010em / InterDisplay 800   inline values in chips
unit         0.30 × numeral size (min 11, max 26) / Inter 600 / textTertiary / 6 pt gap, baseline-aligned to the numeral's alphabetic baseline
display      30 / 1.05 / -0.020em / InterDisplay 800   screen titles (Heute, Tage, Rangliste)
displayS     19 / 1.10 / -0.015em / InterDisplay 800   collapsed header title
headline     22 / 1.15 / -0.015em / InterDisplay 800   sheet titles, card headlines, onboarding P2/P3
headlineL    34 / 1.05 / -0.025em / InterDisplay 900   onboarding P1 headline
title        17 / 1.25 / 0        / Inter 700          card/list-row titles
body         16 / 1.45 / 0        / Inter 400          paragraphs
bodyStrong   16 / 1.40 / 0        / Inter 600          mascot lines, emphasised rows
caption      13.5 / 1.35 / 0      / Inter 500 / textSecondary   resort, date sub-lines
label        11 / 1.10 / +0.10em  / Inter 700 / UPPERCASE / textTertiary   the overline — this tracking is the editorial tell
button       17 / 1.00 / +0.010em / Inter 700 (19 on the 76 pt Start)

RULES
- The overline label goes ABOVE the numeral, never below. That locks every baseline in a grid and is what fixes the ragged StatTile rows.
- Numerals never use textSecondary. Cream (or accent/ice), always.
- Units are never part of the numeral string; always a separate Text so they can be tertiary and smaller.
- German decimal/thousand separators stay as Fmt already does (1.849, 69 km/h).
- Max 2 type sizes per card.
- textScaler: clamp to 1.0–1.35 on the live screen only (so the hero never wraps), unclamped elsewhere.

OPTIONAL (phase 2, founder's call): swap the numeral face to Space Grotesk (OFL) for a more technical, less neutral instrument feel — https://github.com/floriankarsten/space-grotesk (fonts/ttf/SpaceGrotesk-Bold.ttf, -Medium.ttf) or https://fonts.google.com/specimen/Space+Grotesk. Its digits are wide and mechanical and would separate us from every Inter app. Default recommendation: ship InterDisplay 900 first, A/B the swap later — it's a two-line change in typography.dart.
```

## 4. Components
```
APP BAR / HEADER (replaces stock AppBar)
Collapsing SliverAppBar-style "Kopf": expanded 104 pt — title `display` 30 left at 20 pt gutter, `caption` sub-line under it ("Sa, 22. Sep · Kitzbühel"); collapsed 52 pt — `displayS` 19 + a 0.5 hairline that fades in at scroll > 12. Trailing: 40×40 glass circle (glassFill, 0.5 glassStroke, icon 20) — never a bare IconButton. Status bar icons light.

CARD (GlassCard, replaces AppCard — AppCard stays as a deprecated alias so other agents' files keep compiling)
fill surface · RSuperellipse r20 · BorderSide(0.5, hairline) · topHighlight gradient on the top 24 px · padding 18. Props: `tone` {plain, accent, ice, danger} → adds a 10 % wash + tinted 0.5 border; `header` (overline + optional trailing 16 pt chevron); `onTap` → press scale.

STAT TILE (88 pt min height, 2-col grid = (w−40−12)/2)
Top: overline label (11/+0.10em/tertiary), 10 pt gap. Bottom: numeric-m 34 baseline-aligned with unit 13. Optional 28 pt sparkline strip bottom-right at 18 % accent. Variants plain / accent (number champagne, 0.5 accent border, 6 % wash) / ice (live). Fill surface, r14, 0.5 hairline, padding 14.

HERO NUMBER
Optional 2×28 pt champagne tick rule, then overline label, 8 pt gap, numeral at numeric-xxl/xl/l with unit baseline-aligned, 6 pt gap. Left-aligned by default. Value changes cross-fade with a 4 pt upward slide, 140 ms.

PRIMARY BUTTON — solid, never a gradient
h 60 (default) / 76 (Start) · capsule · fill accent #E3C88C · label `button` in onAccent #0B0C0E · optional leading glyph 22.
Start variant adds BoxShadow(accentGlow, blur 32, spread -6) — the only glow in the app — and a single 1.0 s breathing pulse (scale 1.00→1.015) on first appearance after onboarding.
Pressed: fill accentPressed, scale 0.985. Disabled: fill surfaceRaised, label textQuaternary, 0.5 hairline.

SECONDARY BUTTON
h 56 · capsule · glassFill + 0.5 glassStroke · label Inter 700 16 cream · icon 20. Icon-only variant 56×56.

HOLD BUTTON (Tag beenden)
h 64 · capsule · fill surface · 1.5 px border lerping hairline→danger over the hold · fill sweeps from the left with danger@22 % · 24 pt ring around the leading stop glyph · label "Tag beenden · halten" Inter 700 17 · selection haptics at 33/66 %, heavy at 100 %. Keep the raw-pointer Listener implementation (glove-safe) exactly as is.

CHIPS
h 32 · r999 · padding 12 h · icon 14 + 6 pt gap.
neutral: glassFill, text secondary, 0.5 hairline · accent: accentWash, text accent, no border · ice: iceWash/ice · danger: dangerWash/danger.
RecordingPill: h 34, glassFill, 8 pt ice dot pulsing 1.2 s sine, text 12 Inter 700 cream.
PB TILE (replaces the three wrapping chips): equal-width 3-up Row of mini tiles, h 64, r14, accentWash 8 %, 0.5 accent border: overline label ("TOP-SPEED") / numeric-s 22 champagne + unit 11. Three identical widths — this alone removes the "accidental" look.

TAB BAR (custom, replaces NavigationBar)
h 56 + bottom safe area · BackdropFilter(30) over bg@72 % · top hairline 0.5. Three items: icon 24, label 11/+0.06em, 4 pt gap. Selected = cream icon+label plus a 24×2 champagne bar 6 pt above the icon (no pill indicator). Unselected #6A6F79. While recording: the Heute icon gets a pulsing ice ring and the bar's top hairline turns ice at 40 %.

BOTTOM ACTION DOCK (new, on Heute/Tagesbilanz/Tag detail)
The buttons stop floating on the page background. Dock = L2 glass, top hairline, padding 16/20/16/safe, holds (optionally) the permission/recovery card, then the primary row. Content above scrolls under it with a 24 pt fade-out mask.

BOTTOM SHEETS
r28 top · L2 glass at 92 % · handle 36×4 hairlineStrong at 8 pt · header row: headline 22 left + 32 pt glass close circle right + 0.5 hairline under · content padding 20 · full-height variant 92 %.

LIST ROW (Tage / Letzter Tag — one component, used on both screens)
h 112 · r20 · surface · 0.5 hairline · padding 12.
Left: 84×84 route thumbnail, r10, inner 0.5 hairline.
Middle (16 pt gap): title 17 Inter 700 cream; caption 13.5 resort; 8 pt gap; then a 3-up metric strip — `12`/`ABFAHRTEN`, `1.849`/`HM`, `69`/`KM/H` where values are numeric-xs 15 tabular cream and units are 11 overline tertiary, columns at fixed flex so rows align vertically down the whole list.
Right: 16 pt champagne star if PB, 16 pt chevron tertiary.
Section header: sticky, h 44, overline left + season totals tabular right.

EMPTY STATES
No floating circular photo. A full-width card: 16:9 mascot still/video with a bottom ink gradient, headline 22, body 16 secondary, primary action. On Tage: three 112 pt skeleton rows at 6 % opacity behind it so the user sees the shape of what's coming.

MAP THUMBNAIL
3:2 or 1:1, graphite #101216 base, faint 6 % contour hatch, route champagne 2.5 round-cap, lift segments liftGrey 1.5 dashed, 3 pt champagne start dot, 12 % vignette. Fallback order: cached PNG → draw live from stored points via CustomPaint → contour pattern. The skier glyph placeholder is deleted.

CHARTS
Altitude profile (160 pt card): stroke champagne 2, area LinearGradient(accent@22 % → transparent), baseline 0.5 hairline, x labels 11 overline tertiary, scrub = 1 px ice vertical + a floating glass readout chip ("11:42 · 1.980 m").
StackedTimeBar: h 12, r6, 2 pt gaps between segments (the gap is what makes it look designed), legend as a 3/4-up row with 8 pt dots + tabular minutes.
Sparkline (new): 28–40 pt, champagne 1.5 stroke, last point as a 3 pt dot, no axes. Used in Saison cards and stat tiles.

TOASTS
Floating glass capsule, h 48, r999, L2, icon 18 + text 15, 20 pt above the tab bar, 3 s, slide-up 12 pt + fade 220 ms. Replaces the stock SnackBar.
```

## 5. Screens

### Onboarding — P1 Willkommen
Full-bleed, edge to edge INCLUDING behind the status bar. Today a ~250 px cream band sits above the photo and reads as a rendering bug — it is deleted; the back affordance becomes a 40 pt glass circle floating at (20, safeTop+8), disabled/hidden on P1. Hero image fills 100 % with a 3-stop scrim: transparent at 45 % → ink@55 % at 72 % → ink@96 % at 100 %, plus 3 % monochrome grain. Copy block bottom-left, 20 pt gutters, 28 pt above the dock: mascot line (14 pt ice waveform glyph + 15 pt Inter 600 cream), 16 gap, headline 34 InterDisplay 900 cream on 2 lines, 12 gap, body 16 #A2A7B0 max 3 lines. Dock (L2 glass, top hairline): dots (6 pt; active 22×6 champagne r3) 16 gap, 60 pt solid-champagne primary.

### Onboarding — P2 So funktioniert es
Graphite page (L0 gradient). 20 pt gutters. MascotCard 16:9 r28 with ink bottom gradient and the caption line inside · 24 · headline 22 · 20 · three step rows, each h 56: a 32 pt champagne OUTLINE numeral (InterDisplay 900, 1.5 px stroke via foreground paint) instead of today's 26 pt filled circle, 16 gap, text 16 cream · 20 · a 'Live-Aktivität' card (GlassCard, tone ice): a real Dynamic-Island pill mock (ink capsule 96×28 with an ice near_me glyph) + 15 pt explanation · 16 · body 16 secondary. Same dock as P1.

### Onboarding — P3 Was iOS fragt
Same skeleton as P2. MascotCard · headline 22 · body 16 · 16 · three icon rows h 48 (icon 22 tertiary, text 16 cream) · 20 · status card: granted → GlassCard tone accent with a 20 pt check and 15 pt line; denied → GlassCard tone danger with a 20 pt location-off, 15 pt line and a 48 pt secondary 'Einstellungen öffnen'. Dock primary label switches Erlauben → Fertig. Page transition: 320 ms easeOutCubic slide with 8 % parallax on the hero.

### Heute — idle
This is the screen with ~600 pt of dead air today; every band below is real content, so the button no longer floats in a void.
1. Header 104: 'Heute' 30 + caption 'Sa, 22. Sep · Kitzbühel' + 40 pt glass gear.
2. Bedingungen strip, h 72, GlassCard: weather glyph 22 ice, '−4° Berg · 12 cm Neuschnee' 16 cream, right-aligned caption 'Bergwetter' / lift status if known. Replaces today's naked grey line.
3. SAISON hero card, h ~204, GlassCard r20, padding 20: overline 'SAISON 2026/27' · 10 · numeral 5.717 at numeric-xl 64 champagne + unit 'hm' 20 · 14 · a 3-up footer of value/overline pairs (3 TAGE · 9 ABFAHRTEN · 69 KM/H TOP) at numeric-s 22 · a 36 pt champagne sparkline of vertical-per-day bleeding to both card edges at the bottom. THIS is the new visual anchor.
4. Overline 'LETZTER TAG' · 8 · one 112 pt list row (same component as Tage) — replaces the current bare white card.
5. PB strip: 3-up equal 64 pt tiles.
6. 24 pt spacer, then the scroll fades under the dock.
7. DOCK (L2 glass): recovery card and/or permission card (GlassCard tone danger, r20, icon 20 + title 16 Inter 600 + body 15 secondary + 48 pt secondary button) · 12 · the 76 pt solid-champagne Start with its glow, label 'Tag starten' 19 + 24 pt play glyph · 8 · centred 12 pt tertiary 'Läuft weiter, auch wenn das Display gesperrt ist.'

### Heute — live
Glare theme: pure #000000, white text, #FFD98A accent, #A8E4FB ice. Nothing on this screen animates except the recording dot and the run banner.
1. Status row h 40: RecordingPill (ice dot + 'Aufnahme läuft · GPS gut') + state chip ('Abfahrt 7' accent / 'Im Lift' ice / 'Pause' neutral / 'Kein GPS' danger).
2. LEAD HERO, left-aligned, full width: overline 'HÖHENMETER' · numeral 1.849 at 92 pt InterDisplay 900 white + 'hm' 26. Readable at arm's length with goggles — today three 56 pt numbers share one row and all three are secondary-weight.
3. 2-up at numeric-m 34: 'ABFAHRTEN 7' · 'TOP 69 km/h'.
4. TEMPO strip, h 96, GlassCard tone ice, full width: numeral 41 at 56 pt ice + 'km/h' 18, and under it a 24 pt horizontal bar (0 → day max) with a 2 pt ice head — glanceable speed without reading digits.
5. Two 72 pt tiles: Höhe · Zeit (tabular clock).
6. StackedTimeBar with 2 pt gaps + legend.
7. 12 pt tertiary battery-ETA line.
8. DOCK: 56×56 glass icon button 'Karte' + expanded 64 pt hold-to-end.
Run banner: today a 44 pt empty SizedBox is permanently reserved and causes a visible hole; it becomes an OVERLAY that slides down over the status row (accentWash capsule r20, run number at numeric-s 22 + '312 hm · 61 km/h' 15), 3 s, no layout shift.

### Tagesbilanz
The payoff screen — currently a flat list with grey chips.
1. Full-bleed top block h 300: the day's route drawn large on ink with a radial champagne glow (accent@10 %, 420 pt) behind it; the champagne stroke DRAWS ITSELF over 900 ms easeOutQuart. Date + resort as a bottom-left glass plate (r14, padding 10/12, caption 13.5).
2. 28 · hero 'HÖHENMETER 1.849' at 92 pt champagne, counting up 400 ms.
3. 20 · 3-up at 40 pt counting up staggered 90 ms: Abfahrten · Top-Speed · Ski-km.
4. If PB: a full-width SOLID champagne card h 76, r20, ink text: 16 pt star + 'REKORD' overline + 'Schnellster Tag der Saison' 17 Inter 700 — one real moment instead of three grey chips. Heavy haptic on appear.
5. 24 · Beste Abfahrt GlassCard with a 3-up mini-metric strip.
6. 20 · StackedTimeBar + total line.
7. 24 · MascotCard 16:9 with Toni's line (replaces the floating 96 pt circle).
8. DOCK: 'Teilen' secondary (icon) + 'Fertig' primary, 50/50.

### Tage — Liste
1. Header 104: 'Tage' 30 + caption 'Saison 2026/27'.
2. Saison card, compact 148 pt variant of the Heute hero card (numeral 44, 3-up, sparkline).
3. PB strip: 3-up equal 64 pt tiles — fixes today's ragged 2+1 wrap.
4. 28 · sticky season section header h 44 (overline left, totals tabular right).
5. 112 pt list rows, 12 pt apart, each with a real drawn route thumbnail. The three identical grey skier boxes are gone.
6. Older seasons: a 56 pt glass row (overline + totals + chevron) that expands into rows; chevron rotates 180° over 220 ms.
7. Empty: three 6 %-opacity skeleton rows behind a mascot card with 'Ersten Tag aufzeichnen' primary.

### Tag — Detail
1. The MAP is the hero: full-bleed 320 pt from the very top edge (under the status bar), dark tiles, champagne route 4 pt, lift dashed grey, start/end dots. A bottom-left glass plate carries date 22 InterDisplay 800 + resort/weather caption. A 40 pt glass back circle top-left, 40 pt glass share circle top-right. Scrolling collapses it into a 52 pt bar with the date at 19 pt and a 0.5 hairline.
2. 3-up hero numbers at numeric-l 44 on graphite (Abfahrten · Höhenmeter · Top-Speed).
3. Höhenprofil GlassCard 160 pt with scrub → marker on the map.
4. StackedTimeBar card + total.
5. Stats grid 2×4 of the new 88 pt tiles (label above → all eight baselines align, which they do not today).
6. Abfahrten list: rows h 56, hairline-separated, four fixed columns — '#7' numeric-xs tertiary | 312 hm | 5,5 km | 61 km/h — all tabular and column-aligned.
7. DOCK: 'Teilen' primary + 'Löschen' glass with danger label.

### Einstellungen — Sheet (spec only, file owned by another agent)
92 % L2 glass sheet, r28, handle, header 'Einstellungen' 22 + glass close. Grouped GlassCards, rows min 56: leading 22 pt glyph, title 16 cream, optional caption 13.5, trailing switch (champagne track) / value 16 secondary + chevron. Section overlines between groups. Destructive rows: danger label, no icon fill. New row: 'Erscheinungsbild — System / Hell / Dunkel' (segmented, default Dunkel). Footer: glyph 28 + kAppName + version, centred, tertiary.

### Rangliste — Tab (spec only)
1. Header 104: 'Rangliste' 30 + caption.
2. Segmented control h 40, r999, glassFill, 3 segments (Saison · Monat · Woche); selected segment = surface pill + cream label, 200 ms slide.
3. Podium block h 180: three columns — 2nd/1st/3rd with avatars 48/64/48 (r999, 0.5 hairline; champagne 1.5 ring on #1), name 13.5, value numeric-s 22 tabular, rank plates 1/2/3.
4. Rows h 64, hairline-separated: rank numeral 22 tabular tertiary (w 32) · avatar 36 · name 16 cream + caption 13.5 · value numeric-s 22 champagne right-aligned + unit 11.
5. Own row pinned above the tab bar in a L2 glass strip with accentWash 10 %.
6. Empty: mascot card 'Noch keine Freunde hier' + 'Freunde einladen' primary.

### Karte — Sheet
92 % height, r28 top, dark tiles (CartoDB dark_matter fallback / Mapbox dark via MAP_TILE_URL). Track champagne 4 pt with a 10 pt ice glow under the live head. Top row at 12 pt: 44 pt glass close left, title 17 centred, 44 pt glass locate right; a GPS-quality pill (3 ice bars + 'GPS gut') top-left under it, Slopes-style. Bottom: a readout bar, r24, h 96, surface@94 % solid (no blur over a moving map), 0.5 hairline, padding 16 — state chip left, speed numeral 34 ice + km/h, altitude 22, and an inline 56 pt hold-to-end capsule so the day can be finished without leaving the map.

### Share Card 1080×1350 (+1080×1080, 1080×1920)
Always dark, independent of theme. bg #0B0C0E with a 700 px champagne radial at 8 % top-right and 3 % grain. Padding 72.
Top: date 44 InterDisplay 800 cream, resort 30 secondary.
560 pt route block: champagne 6 pt round-cap stroke, lift 3 pt dashed liftGrey, 14 pt start dot, centred with 40 pt inset.
40 · hero row: 1.849 at 120 pt InterDisplay 900 champagne + 'hm' 34; Abfahrten and km/h at 104.
28 · full-width 0.5 hairline at 10 % white.
24 · bottom row: two 56 pt stats left (Ski-km, längste Abfahrt) and the wordmark bottom-right — GlyphPainter 56 + kAppName 46 InterDisplay 800 cream.
Variants: 1080×1080 drops the bottom stat row; 1080×1920 centres the route at 900 pt with the hero row below and the wordmark 120 pt above the bottom edge (IG-Story safe area).

## 6. Imagery and motion
```
IMAGERY
- Photography appears in exactly two places: onboarding P1 hero and the MascotCard. Nowhere else — no decorative stock imagery on data screens.
- The current Toni assets are bright and warm and fight a graphite app. Regrade in-app first (cheap): ColorFiltered with a matrix at −12 % exposure and cooled shadows, plus a fixed ink scrim. If he wants new plates, generate three via fal.ai (flux-pro/ultra, 4:5 and 16:9):
  1) "Cinematic dusk alpine ridge, lone skier silhouette in a charcoal shell jacket, deep blue-grey shadows, low warm sun grazing the snow, heavy negative space in the lower third, muted graphite and champagne palette, 85mm, shallow depth of field, editorial ski magazine, no logos"
  2) "Close portrait of a woman skier at blue hour, goggles up, cream beanie, breath vapour, dark mountain background falling into near-black, warm champagne rim light on the left, graphite colour grade, 16:9, cinematic"
  3) "Abstract aerial of groomed corduroy piste at dusk, near-black snow with faint champagne highlights, minimal, texture-only, no people, 4:5" — for the Tage empty state backdrop at 8 % opacity.
- Gradients: exactly three. The page gradient (#121316 → #0B0C0E over 240 pt), the champagne radial behind Start/Tagesbilanz/share card, and the ink scrim over photography. Controls are solid fills — the current champagne gradient button is the main reason the app reads as washed out.
- Grain: a 3 % monochrome noise PNG tiled over onboarding heroes and the share card only. One asset, ~8 KB, and it is disproportionately responsible for looking "produced".
- Illustration: none. The instrument doesn't draw pictures; it draws routes.

MOTION (all guarded by MediaQuery.disableAnimationsOf)
- Press: scale 0.985 + opacity 0.90, 120 ms easeOut.
- Count-up: 400 ms easeOutCubic, 90 ms stagger between the four Tagesbilanz numbers (existing count_up.dart keeps working).
- Route draw-on: 900 ms easeOutQuart on Tagesbilanz and the share-card preview, using a PathMetric extract — the single most "designed" moment in the app.
- Hero value change (live): cross-fade + 4 pt upward slide, 140 ms.
- New top speed: 260 ms champagne flash on the Tempo strip border + light haptic tick.
- Run committed: banner slides down 12 pt + fades in 200 ms, holds 3 s, fades out 200 ms; medium haptic.
- Recording dot: 1.2 s sine opacity 0.35→1.0 (unchanged).
- Hold-to-end: 1.2 s linear ring + capsule sweep, selection haptic at 33 %/66 %, heavy at 100 %.
- Start button: one 1.0 s breathing pulse the first time it appears after onboarding, then static forever.
- Sheets: 320 ms easeOutCubic up, 240 ms down; backdrop dims to ink@55 %.
- Tab switch: 180 ms cross-fade only, no horizontal slide (an IndexedStack slide is the classic "template app" tell).
- Onboarding: 320 ms page slide with 8 % hero parallax.
- Section reveal on Heute/Tage first paint: 6 pt rise + fade, 260 ms, 40 ms stagger, once per app launch.
- Forbidden: bouncing, springy overscroll glow, ripples, shimmer skeletons on the live screen, anything moving while recording.
```

## 7. Iconography
```
One family, one weight, no exceptions: Material Symbols Rounded, weight 400, grade 0, optical size 24, unfilled. Today the app mixes `_rounded` and `_outlined` (map_outlined next to settings_rounded, satellite_alt_outlined next to downhill_skiing_rounded) — that inconsistency is a large part of the unfinished feel. Sizes: 24 tab bar, 22 inline/rows, 20 glass circle buttons, 14 chips, 16 chevrons/stars.

Colours: tertiary #6A6F79 by default; cream when the row is primary; champagne only for record/accent semantics; ice only for live/GPS; danger only for failure. An icon is never champagne "for decoration".

Six custom 24 pt CustomPaint glyphs give the app its own hand (stroke 1.75, round caps, drawn on a 24 grid, ~120 lines total):
1. `chevron` — the brand mark from GlyphPainter, used wherever Höhenmeter appears (and as the Heute tab icon inside a 24 pt ring).
2. `slalom` — two stacked gates, for Abfahrten.
3. `chairlift` — a cable with one hanging seat, for Liftfahrten/lift segments.
4. `gauge` — a 240° arc with a needle, for Top-Speed.
5. `flake` — a 6-spoke snowflake, for Neuschnee/conditions.
6. `crest` — a 5-point star inside a rounded shield, for Rekorde (replaces Icons.star_rounded, which is the single most generic glyph on the Tage screen).

Tab bar: Heute = chevron-in-ring (recording → pulsing ice ring), Tage = a 3-bar calendar (custom, because calendar_month_rounded is instantly recognisable Material), Rangliste = a 3-step podium.

App icon stays as-is (cream field + ink chevron) and is the only place the cream field survives at full strength; a dark-mode iOS icon variant is worth adding: ink #0B0C0E field with the chevron in champagne #E3C88C.
```

## 8. Implementation packages
```
MUST NOT TOUCH (other agents own them right now): lib/features/account/**, lib/features/social/**, lib/data/sync/**, lib/features/settings/settings_sheet.dart. Everything below is additive or confined to files those agents don't hold; `AppCard`, `StatTile`, `HeroNumber`, `StateChip`, `PrimaryButton`, `SecondaryButton` keep their current constructors (new params default to today's behaviour) so settings_sheet.dart and the social placeholder keep compiling untouched and get the new look for free.

PACKAGES (sequential, each independently shippable and testable)

P1 — Foundation (~1.5 d)
app/lib/app/theme/tokens.dart (full new ramp, AppColors.dark/light/glare, radii, blur/shadow consts)
app/lib/app/theme/typography.dart (the scale above; InterDisplay 900 becomes the numeral face)
app/lib/app/theme/theme.dart (dark default, custom sheet/snackbar/switch themes, textScaler clamp helper)
app/lib/app/theme/surfaces.dart (NEW: GlassLayer, topHighlight painter, squircle helpers)
app/lib/app/app.dart (ThemeMode.dark)
app/lib/app/widgets/{app_card,buttons,chips,numbers}.dart rewritten in place
app/lib/app/widgets/{glyphs.dart, tab_bar.dart, dock.dart, header.dart, sparkline.dart, toast.dart} (NEW)
app/lib/app/shell.dart (custom tab bar)

P2 — Heute (~1 d): features/today/{idle_view,live_view,heute_screen,recovery_card}.dart, features/weather/weather_line.dart → conditions strip, plus a new features/today/season_card.dart shared with Tage.

P3 — Tage + Tag (~1.5 d): features/days/{tage_screen,day_card,stats_grid,day_detail_screen,run_list}.dart, features/map/thumbnail_renderer.dart (route always drawn; contour fallback), features/profile/altitude_profile.dart (champagne area + scrub chip), widgets/numbers.dart StackedTimeBar gaps.

P4 — Tagesbilanz + Share (~1 d): features/summary/tagesbilanz_screen.dart, features/summary/count_up.dart (stagger), features/share/share_card.dart (+1:1 and 9:16 variants), features/share/share_card_renderer.dart.

P5 — Onboarding, Karte, polish (~1 d): features/onboarding/{onboarding_flow,onboarding_pages,mascot_hero}.dart, features/map/{map_sheet,track_map,tile_config}.dart (dark tiles + GPS pill + inline hold-to-end), widgets/empty_state.dart, toast rollout, icon sweep.

Total ≈ 6 dev-days for one agent; P1 must land before P2–P5 and P2–P5 are parallelisable across three agents.

NEW ASSETS: one 3 % grain PNG (~8 KB), optionally three fal.ai plates. No new pub packages — fl_chart and flutter_map are already in pubspec; sparkline/route/glyphs are CustomPaint.

RISKS
- RSuperellipse / RoundedSuperellipseBorder: available from Flutter 3.32+, so fine on 3.44, but gate it behind a `Squircle.border(r)` helper so a downgrade falls back to RRect in one place.
- BackdropFilter cost: fine on static docks and sheets; do NOT blur over the live map or during recording — use a solid 94 % fill there. Measure on an iPhone 11 before shipping P5.
- Dark-first is a product decision, not just a theme flip: the light theme must stay correct because ThemeMode is user-visible later. Every new widget takes its colours from AppColors, never from Tokens.* directly (the share card is the one legal exception).
- Golden/widget tests: ~19 map tests plus the today/days/summary widget tests will need re-golding after P1; budget half a day and re-gold once at the end of each package, not per commit.
- Contrast audit to run after P1: accent #E3C88C on #0B0C0E = 11.4:1, ink #0B0C0E on #E3C88C = 11.4:1, ice #8FD8F5 on #000 = 13.8:1, secondary #A2A7B0 on #16181C = 7.3:1, tertiary #6A6F79 on #16181C = 3.4:1 → tertiary is legal for ≥18 pt overlines and glyphs only, never for body copy.
- Copy stays German sentence case with the existing ski vocabulary; kAppName remains the only name reference, so a rename touches app/lib/app/brand.dart and nothing in this work.
```

## Appendix — judge grafts (raw)
- From C: make run/lift a semantic colour pair used identically on every surface (route thumbnail, live map, StackedTimeBar, altitude profile, run list, share card) — champagne = Abfahrt, liftGrey dashed = Lift — plus C's hard rule 'max one accent element visible at a time' written into the tokens file. A's two accents otherwise creep.
- From C: RouteHero as a card background — make 'Letzter Tag' on Heute a 16:9 route card with a scrim and the numbers on top, not a 112 pt list row. The track is the only image the app owns.
- From C: Hero transition from the tapped Tage row's route thumbnail into the Tag-detail map (~15 lines, highest perceived-quality-per-line item available).
- From B: the no-placeholder rule, absolutely — RouteDrawing from stored points at 72 / 300 / 620 pt, offline, no tiles; fallback is a typeset 'Ohne Track', never a pictogram. Delete Icons.downhill_skiing_rounded from the codebase.
- From B: column-aligned tabular tables instead of '·'-joined sentences, with fixed flex columns so values line up vertically down the whole list — stricter than A's 3-up strip.
- From B: one single eyebrow/overline pattern (11 pt, uppercase, +0.10 em, always above the value, no second label style anywhere in the app).
- From B: hold-to-end label inversion — a second copy of the label clipped at the sweep edge — instead of A's arc + ring. More legible with goggles, fewer moving parts.
- From C: OpenTopoMap tile clash mitigation (ColorFiltered desaturate+darken + veil under the track) in P1's risk list, and raise 'branded dark MAP_TILE_URL before the store build' as a founder decision, not a bug.
- From B and C: fix AppColors.copyWith and AppColors.lerp — both are no-ops today and silently break theme animation — and keep the old field names as deprecated getters for one release so the account/social/sync/settings files keep compiling.
- From C: a contrast unit test (every text token ≥ 4.5:1 against its surface) plus goldens for card / stat tile / day row / primary button / tab bar in both brightnesses, run once at the end of each package — the guardrail four parallel agents need.
- From B and C: a season delta line ('+412 hm zur Vorsaison') under the Saison hero — cheap, motivating, and the Slopes trends idiom the founder pointed at.
- From B: a German copy pass as part of the work. All three current screens render English ('Today', 'Days', '3 runs', 'Start day'); the redesign must ship DE-proofed, with kAppName as the only name reference.
- From B: keep a light 'paper' share-card variant as a phase-2 option next to the dark one — Slopes' white relief card is what actually reads well in a feed, and it is the one place the cream/ink brand field belongs at full strength.
- Against A itself: cut BackdropFilter to the tab bar and sheets only (not docks, toasts and every header button) — blur everywhere is the stock-iOS look A is trying to escape, and it is the main perf risk on an iPhone 11.
- From alpine-modern: RouteHero — the drawn route becomes the card's background surface on Heute "Letzter Tag" and the Tagesbilanz top block, not a thumbnail parked next to text. Instrument's route art is correct but too timid; this is the idea that makes the app look like only this app could have made it.
- From alpine-modern: Hero transition from the day row's route into the Tag-detail map (~15 lines, highest premium-per-line in the whole set).
- From alpine-modern: ColorFiltered desaturate+darken on the map tiles plus a dark veil under the track. Instrument assumes a dark tile URL exists; OpenTopoMap is beige today and would wreck the graphite shell in every screenshot.
- From alpine-modern: hillshade/relief texture at ~8% behind the share-card route (the verified Slopes trick), instead of a plain champagne radial.
- From alpine-modern: a contrast unit test asserting every text token ≥4.5:1 on its surface — permanently prevents a repeat of today's ~1.6:1 CTA.
- From alpine-modern: swipe-left Teilen/Löschen on day rows, so day actions are not long-press-only.
- From Schnee-Papier: hold-to-end as a danger wipe with the label double-set and clipped at the wipe edge so the text flips colour. Drop the CircularProgressIndicator — it is the most Material-default element on the live screen. Keep the raw Listener implementation untouched.
- From Schnee-Papier: the mascot as a set pull-quote with a 3 pt accent rule in Tagesbilanz and the empty states — drop the floating circular photo everywhere.
- From Schnee-Papier: line-pager (24×2 bars) in onboarding instead of dots, and text tabs with an underline instead of any Material segmented control in Rangliste/Einstellungen.
- From Schnee-Papier: German copy pass in the same PR. All three current screens render English ("Today", "Start day", "3 runs · 1,849 m"); a redesign that ships English reads unfinished again regardless of the visuals.
- From Schnee-Papier: fix AppColors.copyWith/lerp — both are no-op stubs today and silently break every theme animation. Do it in the Foundation package.
- From both: delete the Icons.downhill_skiing_rounded grey box outright. Fallback order is cached PNG → live CustomPaint from stored points → ghost/contour route. There must be no state in which a placeholder rectangle ships.
- From alpine-modern: make the recorded route the hero surface, not a side thumbnail. A RouteHero component used at three scales — 16:9 as the background of the "Letzter Tag" card on Heute, 1:1 at 96 px in every Tage row, full-bleed 300–320 pt on Tagesbilanz and Tag-Detail. The grey box with Icons.downhill_skiing_rounded in day_card.dart's _placeholder must be deleted outright; fallback order is cached PNG → live CustomPaint from stored points → generated ridgeline from the altitude series. Never a pictogram.
- From alpine-modern: give Lift a real colour instead of liftGrey. Keep champagne as the run/brand colour and promote the existing ice token (or a warm counter-colour) to mean Lift, used identically on the map, the stacked time bar, the altitude profile ticks, the run list and the share card. One meaning, one colour, everywhere — that consistency is what reads as "a system" rather than "a skin".
- From alpine-modern: the Hero transition from a Tage row's route thumbnail into the Tag-Detail map. ~15 lines, and it is the cheapest premium moment available.
- From alpine-modern: ColorFiltered desaturate+darken matrix and a dark veil under the map tiles whenever MAP_TILE_URL is unset, so the beige OpenTopoMap raster cannot sit inside the graphite shell looking broken. Track must be the brightest thing on the map.
- From Editorial-light: fix AppColors.copyWith and lerp in P1. Both are no-ops today (copyWith returns `this`, lerp snaps at t<0.5), so theme transitions do not animate at all. Real bug, not a style preference.
- From Editorial-light: do not treat the pure-black glare screen as settled. Ship the high-contrast live theme, but add screen-brightness-to-1.0 during recording and field-test light-vs-dark in direct sun before TestFlight — a bright surface with near-black numerals may win outdoors, and PLAN §11 asserts #000 without evidence.
- From Editorial-light: German copy audit across all three screens. The current build renders English ("Today", "3 runs", "Record", "Start day") although German is the product language; also enforce de-DE number formatting, "–" for undefined (never 0), and units as separate small-caps text so they can sit in a column header rather than inside the value string.
- Keep the winner's compile-compatibility rule as a hard constraint, and let it override any renaming impulse from the other two: AppCard, StatTile, HeroNumber, StateChip, PrimaryButton, SecondaryButton keep their present constructors and AppColors keeps its present field names (new fields added, none renamed) for as long as the account, social, sync and settings_sheet agents are in flight.
