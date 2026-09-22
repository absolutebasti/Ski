# Dropline — ski day tracker

One tap records your whole ski day. Runs, lifts and stops are detected automatically, tracking keeps
running while the phone stays locked in your jacket, and the evening summary shows honest vertical,
runs and top speed. iOS first (TestFlight), Apple Watch companion, Android builds.

| Folder | What |
|---|---|
| `app/` | Flutter app (`flutter run` inside `app/`). Package `dropline`, bundle id `de.torchtechnology.dropline`. |
| `docs/PLAN.md` | Product definition, screens, accuracy pipeline, background tracking, work packages. Start here. |
| `docs/ANALYSIS.md` | Audit of the legacy PWA, competitor critique, founder-data insights, keep/drop matrix. |
| `docs/competitors/` | bergfex Ski, Slopes, Skiline benchmark notes. |
| `design/` | Logo (SVG + 1024 px icons), mascot clips/stills ("Toni"), fonts (Inter, OFL). |
| `tools/assets/` | fal.ai generators for the mascot (needs `FAL_KEY`; never commit it). |
| `legacy-pwa/` | The 2025 vanilla-JS PWA and its multi-agent artefacts. Kept for history, not built. |

## Build

```bash
cd app
flutter pub get
flutter run                      # simulator or device
flutter build ipa --release      # TestFlight archive (signing: Team 5GDU97KSQU)
```

Requires Flutter 3.44+, Xcode 26+. Android builds need an Android SDK (not installed on the founder's Mac).
