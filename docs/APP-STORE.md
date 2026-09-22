# Dropline — App Store Connect draft (v1 TestFlight)

**Bundle ID** `de.torchtechnology.dropline` · **Team** 5GDU97KSQU · **Primary language** German · **Category** Health & Fitness (secondary: Sports) · **Age rating** 4+ · **Devices** iPhone only, portrait.

## Names
| Field | DE | EN |
|---|---|---|
| Name (30) | Dropline: Ski Tracker | Dropline: Ski Tracker |
| Subtitle (30) | Skitag mit einem Tipp | Your ski day, one tap |
| Promotional text (170) | Ein Knopf. Ein Skitag. Abfahrten, Höhenmeter und Top-Speed – automatisch, auch wenn das Handy in der Jacke steckt. | One button. One ski day. Runs, vertical and top speed – automatically, even with the phone in your jacket. |
| Keywords (100) | ski,skifahren,tracker,abfahrten,höhenmeter,piste,gps,snowboard,skitag,winter | ski,skiing,tracker,runs,vertical,slope,gps,snowboard,ski day,winter |

## Description (DE)
Dropline zeichnet deinen ganzen Skitag mit einem Tipp auf. Handy in die Jacke, Sperre an – die Aufnahme läuft weiter. Am Abend siehst du, was zählt: Abfahrten, Höhenmeter, Top-Speed, deine beste Abfahrt und wie viel Zeit du auf der Piste, im Lift und in der Pause warst.

• Ein Start, ein Ende – Lift, Pause und Abfahrt erkennt Dropline selbst
• Läuft weiter, wenn das iPhone gesperrt in der Tasche steckt
• Ehrliche Zahlen: Höhenmeter über den Luftdrucksensor, Geschwindigkeit direkt vom GPS
• Nichts geht verloren – jeder Punkt landet sofort auf dem Gerät
• Tagesbilanz zum Teilen, GPX-Export für andere Apps
• Saison im Blick: Skitage, Abfahrten, Höhenmeter, persönliche Bestwerte
• Kein Konto, keine Werbung, keine Cloud – deine Daten bleiben auf dem iPhone

Hinweis: Dropline nutzt den Standort im Hintergrund, solange ein Skitag aufgezeichnet wird. Das kann den Akku stärker beanspruchen.

## Description (EN)
Dropline records your whole ski day with one tap. Phone in the jacket, screen locked – recording keeps going. In the evening you see what matters: runs, vertical, top speed, your best run and how long you spent skiing, riding lifts and resting.

• One start, one end – lifts, breaks and runs are detected automatically
• Keeps tracking while the iPhone is locked in your pocket
• Honest numbers: vertical from the barometer, speed straight from GPS
• Nothing is lost – every point is saved to the device immediately
• Day summary to share, GPX export for other apps
• Season at a glance: ski days, runs, vertical, personal bests
• No account, no ads, no cloud – your data stays on your iPhone

Note: Dropline uses background location while a ski day is being recorded, which increases battery use.

## App Privacy (nutrition label)
- Precise Location: collected, **not linked** to identity, **not used for tracking**, purpose App Functionality.
- Fitness (heart rate via Apple Watch, later builds): collected, not linked, not for tracking, App Functionality.
- Everything else: not collected. No third-party SDKs that collect data. No tracking, no ATT prompt.
- Privacy policy URL: https://dropline.torchtechnology.de/privacy (host `docs/PRIVACY.md` there before store release).

## Review notes (paste into "Notes for Reviewer")
Dropline has no accounts and no sign-in; no demo credentials are needed. The core feature needs GPS while skiing, which cannot be reproduced indoors. To evaluate:
1. Complete the 3-step onboarding (Location "Always" is requested so recording survives an app relaunch; "While Using" also works as long as the day is started in the foreground).
2. Tap "Tag starten". Walk outside for a few minutes with the phone locked; the blue location indicator shows recording is active.
3. Hold "Tag beenden" for one second. Very short days are discarded on purpose; a normal ski day produces the summary with runs and vertical.
4. Settings → tap the version 7 times to open "Diagnose", which shows accepted GPS points and sensor status.
Background location is used only while a ski day is being recorded and stops when the day ends. ITSAppUsesNonExemptEncryption is set to false (HTTPS only).

## TestFlight "What to test" (internal group)
- Ganzer Skitag mit dem iPhone in der Jacke: läuft die Aufnahme bis zum Abend durch?
- Stimmen Abfahrten, Höhenmeter und Top-Speed ungefähr mit dem Skipass/anderen Apps überein?
- Wie viel Akku pro Stunde? (Einstellungen → Diagnose zeigt Punkte und Neustarts)
- Bitte am Abend "Diagnosepaket teilen" an hello@torchtechnology.de schicken.
