# Tracking: was ist Skifahren, was ist ein Lift?

Eine Seite für die Frage „warum steht da diese Zahl?". Alle Schwellen stehen in
`app/lib/core/constants.dart` (`TrackingConfig`), der Code in `app/lib/tracking/`.

> **In einem Satz:** Bergauf erkennt die App die Seilbahn. **Bergab nicht mehr** —
> eine Gondel, die ins Tal fährt, zählt als Abfahrt. Das ist eine Entscheidung,
> keine Lücke: gemessen an 4.320 synthetischen Ziehweg-Tagen hat die Bergab-Regel
> 427 echte Abfahrten gelöscht, und nichts Messbares trennt einen geraden Ziehweg
> von einer Talgondel. Eine verpasste Gondel kostet ein paar Lift-Kilometer; eine
> gefressene Abfahrt kostet den Top-Speed, die Höhenmeter und das Vertrauen.
> Details: [Bergab: abgeschaltet](#bergab-höhenverlust-abgeschaltet).

## Was als Skifahren zählt

Eine **Abfahrt** (RUN) beginnt, wenn es 8 von 10 Sekunden lang gleichzeitig
bergab (mindestens 0,7 m/s Höhenverlust) und schneller als 2 m/s geht — und
wenn in diesem Moment keine **steigende** Seilbahn-Signatur anliegt (siehe
unten). Nur ein Fenster, das eindeutig Höhe *gewinnt*, verhindert den Start einer
Abfahrt — dann sitzt man im Lift. Alles andere darf eine Abfahrt beginnen:
fallend, flach, und vor allem der sanfte Ziehweg mit 6–11 % Gefälle, der der
Signatur entspricht, aber zu flach für „fallend" ist und früher gar keine
Abfahrt starten konnte. Sie
endet bei 45 s Stillstand, bei einer Minute flachem Trödeln oder wenn ein Lift
beginnt. Zu kurze (< 60 s) oder zu flache (< 40 Höhenmeter) Abfahrten zählen
nicht als Abfahrt, sondern landen im Topf „Sonstiges".

Ski-Kilometer, Top-Speed, Ø Ski-Tempo und Höhenmeter kommen **ausschließlich aus
RUN-Abschnitten**. Was nicht als Abfahrt erkannt wird, kann diese Zahlen nicht
beeinflussen.

## Wie ein Lift erkannt wird

**Nur bergauf.** Bergauf ist eine Seilbahn beweisbar: niemand gewinnt ohne
Maschine bei konstantem Tempo auf einer geraden Linie Höhe. Bergab sieht eine
Gondel ins Tal genauso aus wie ein gerader Ziehweg — und zwar in *jeder* messbaren
Größe, nicht nur knapp. Deshalb wird bergab **gar nicht** umgeschrieben; siehe
[Bergab: abgeschaltet](#bergab-höhenverlust-abgeschaltet).

### Bergauf (Höhengewinn)

Drei Wege führen zu **Lift** (LIFT):

1. **Barometer steigt.** 20 s lang mindestens 0,8 m/s Steigen bei höchstens
   8 m/s Tempo — der Normalfall für Sessel- und Gondelbahn.
2. **Höhengewinn im GPS-Loch.** In der Gondel bricht das GPS oft weg. Steigt der
   Luftdruck während der Funkpause um 30 m, ist das eine Liftfahrt und keine
   Signalstörung.
3. **Seilbahn-Signatur.** Ein Seil fährt **konstant schnell**, **exakt geradeaus**
   und ändert die Höhe **nur in eine Richtung**. Über ein rollendes
   45-Sekunden-Fenster prüft die App alle drei Eigenschaften gleichzeitig. Das
   erwischt die Fälle, die die ersten zwei Regeln verpassen: den **Schlepplift**
   (steigt zu langsam für Regel 1) und die **Standseilbahn** (fährt zu schnell
   für Regel 1).

Zwei Stufen derselben Fensterprüfung:

| Stufe | Bedingung | Wirkung |
| --- | --- | --- |
| **hält** | konstant + geradeaus, Höhe einseitig **oder** flach | hält eine laufende Liftfahrt zusammen: das Flachstück in der Mitte einer Seilbahn, und die Senke, in die ein Sessellift kurz abtaucht |
| **hält & verhindert Abfahrt** | dasselbe, aber eindeutig **steigend** (mindestens 8 m Höhengewinn an mindestens 12 % Gefälle) | verhindert, dass in diesem Moment eine Abfahrt startet — man sitzt im Lift |
| **fährt** | zusätzlich echter Höhen**gewinn** an echtem Gefälle | eröffnet eine Liftfahrt |

Ein **fallendes** Fenster verhindert *nichts*. Das war der Fehler der ersten
Version: eine gleichmäßige Abfahrt mit 5–11 m/s wurde als Seilbahn gelesen und
verschwand komplett aus dem Tag — 0 Abfahrten, 0 km, 0 km/h, 0 Höhenmeter.

#### … und das Fenster allein genügt nicht

Das 45-Sekunden-Fenster misst die Gerade über **fünf gemittelte Abschnitte**.
Diese Mittelung ist der Grund, warum eine langsame Fahrt überhaupt messbar ist —
und gleichzeitig blind für ein *Schlängeln*: wer sich an einem Gegenhang mit
Skating-Schritten bergauf schiebt, erreicht im Fenster eine Geradheit von 0,99 und
wurde als Schlepplift gebucht, mit 1,7 km Phantom-Liftstrecke und der Abfahrt
ringsum in zwei Teile zerschnitten.

Deshalb muss eine Auffahrt, die **nur** auf der Signatur steht, sich auf voller
Auflösung über den ganzen Abschnitt bestätigen (`evaluateAscent` in
`app/lib/tracking/cable.dart`). „Nur auf der Signatur" heißt: keine der beiden
barometrischen Regeln würde sie öffnen — sie steigt nirgends 30 s lang mit
0,8 m/s und nirgends 30 m pro Minute. Ein Sessel-, Gondel- oder Standseilbahn wird
also nie angetastet; geprüft wird der langsame Schlepplift — und der Mensch, der
wie einer aussieht:

1. **Station.** Ein Stillstand von mindestens 10 s, höchstens 45 s vor dem Start.
   Einen Schlepplift besteigt man aus dem Stand. Wer mit 12 m/s aus einer Abfahrt
   kommt, den Gegenhang hochschiebt und weiterfährt, hat nie gestanden — **das ist
   das Kriterium, das den Fehlalarm ganz schließt.**
2. **Gerade auf voller Auflösung**, gemessen als *Bauch*: der mittlere seitliche
   Abstand über je 30 s zur Ausgleichsgeraden der ganzen Fahrt. Die Mittelung über
   30 s nimmt das GPS-Rauschen heraus und lässt die Biegung stehen. Gemessen: jedes
   echte Seil 0,9–2,1 m; dieselbe Bewegung mit 1 °/s Schlängeln 2,1–52 m, mit
   3 °/s 4,7–145 m.
3. **Höhe linear über der Strecke** und **maschinenkonstantes Tempo** über die
   ganze Fahrt, geglättet, gegen die vom Gerät gemeldete Genauigkeit.

Reicht es nicht, wird der Abschnitt **Sonstiges** — nie eine Abfahrt, denn er geht
bergauf. Das kostet im Zweifel eine Liftfahrt, nie eine Abfahrt.

### Bergab (Höhenverlust): abgeschaltet

**Abgeschaltet.** `TrackingConfig.descentRidesEnabled = false`. Eine Gondel, die
ins Tal fährt, zählt als Abfahrt.

Die Regel dafür existiert, ist vollständig und getestet (`descent.dart`,
`descent_test.dart`) — sie ist bewusst aus. Grund:

Gemessen über **4.320 synthetische Ziehweg-Tage** (4–7 m/s, 9–25 % Gefälle,
5–15 % Tempostreuung, 0–0,5 °/s Schlängeln, 5–10 Minuten, je 6 Seeds, jeder Fall
zwischen zwei Stillständen) hat die Regel **427 echte Abfahrten gelöscht**. Ein
schnurgerader Ziehweg mit 5 m/s und 8 % Streuung liefert eine geglättete
Tempostreuung von 0,104–0,141 m/s, einen Abstand zur Linie von 12,9–13,4 m und
einen Höhen-Restfehler von 0,9–1,0 m; eine Talgondel mit 5–7 m/s liefert
0,09–0,12 m/s, 12–15 m und 0,6–1,9 m. Die Verteilungen liegen ineinander. Keine
Schwelle auf Tempo, Gefälle, Sinkrate, Geradheit oder Höhenlinearität trennt sie,
weil das Ziehweg-Band das Gondel-Band **enthält**. Die Regel so weit zu verengen,
dass der Sweep saubere Null zeigt, heißt: Tempo-Untergrenze über 7 m/s — also
oberhalb jeder Talgondel der Fallliste. Das ist dasselbe wie abschalten, nur
unehrlicher.

Der Sweep ist ein Dauertest: `app/test/tracking/ski_road_sweep_test.dart`. Wer die
Konstante umlegt, bekommt 427 rote Fälle und weiß damit, was er kauft.

**Was das kostet** (gemessen, Seed 21):

| Fall | mit der Regel | ohne sie (Auslieferung) |
| --- | --- | --- |
| Talgondel nach einer Abfahrt | 2 Lifte, 1 Abfahrt, 4,8 km Ski | 1 Lift, 1 Abfahrt, **8,2 km Ski**, +600 m Höhenmeter |
| Zweisektionsgondel ins Tal | 1 Lift, 0 Abfahrten, 0 km/h | 0 Lifte, 1 Abfahrt, **29 km/h Top-Speed** |
| Anfänger, Gondel nach Hause (9 m/s) | Top-Speed 26 km/h (seine Abfahrt) | Top-Speed **35 km/h** (die Gondel) |
| Standseilbahn im Tunnel | 0 Abfahrten, 0 km/h | 0 Abfahrten, 0 km/h (unverändert) |

Der Top-Speed des Gründers bleibt in allen gemessenen Fällen unberührt, weil seine
Abfahrt mit 15–22 m/s dreimal schneller ist als die Kabine. Teuer ist der Fall, in
dem die Gondel **das Schnellste des Tages** ist — der Anfänger.

Die Gegenrechnung: eine gefressene Abfahrt kostet Top-Speed, Höhenmeter und
Ski-Kilometer an einem Tag, an dem tatsächlich gefahren wurde. Das ist der
teurere Fehler, und er ist der häufigere — 427 zu 0.

Weil das Bergauf-Fenster erst volllaufen muss, erkennt die App eine Auffahrt
ungefähr eine Minute nach ihrem Beginn und zieht den Anfang beim Tagesabschluss
auf die Station zurück (bis zu 80 s).

Eine Liftfahrt zählt nur, wenn sie mindestens 60 s dauert und die Höhe um
mindestens 30 m verändert.

### Der Skibus

Ein Bus auf der Bergstraße fährt mit Skifahrer-Tempo ein konstantes Gefälle
hinunter — weder die Abfahrts- noch die Seilbahnregeln trennen ihn. Was keine
Piste hat, ist die **Kehre**: eine Richtungsumkehr über hunderte Meter Straße bei
gehaltenem Tempo. Erst wenn alles fünf zusammenkommt (≥ 9 m/s, ≥ 4 Minuten,
≤ 10 % Gefälle, Luftlinie ≤ 55 % der gefahrenen Linie, ≥ 2 Kehren), wird der
Abschnitt **Sonstiges** mit Fahrzeug-Markierung. Nimmt man die Kehren weg, ist
dasselbe Tempo am selben Gefälle wieder eine Abfahrt.

## Welche Zahl enthält was

| Zahl | Lifte enthalten? |
| --- | --- |
| Top-Speed | **nein** — nur aus Abfahrten, und kein Kandidat während einer Seilbahn-Signatur |
| Ø Ski-Tempo | **nein** — Ski-Kilometer geteilt durch Abfahrtszeit |
| Ski-Kilometer | **nein** |
| Höhenmeter (Abfahrt) | **nein** |
| Aufstieg (Höhenmeter im Lift) | nur echte Aufwärtsfahrten; eine Talfahrt ist keine Liftfahrt und zählt dort 0 |
| Lift-Kilometer | **ja** — aber *ohne* Talfahrten, die landen bei den Ski-Kilometern |
| Anzahl Lifte | **ja** |
| Gesamtstrecke | ja (alles) |
| Zeit gesamt / Liftzeit / Pause | **ja** |

## Die Schwellen der Seilbahn-Erkennung

### Bergauf: das rollende Fenster

| Konstante | Wert | Bedeutung |
| --- | --- | --- |
| `cableWindowS` | 45 s | Länge des rollenden Fensters, über das geurteilt wird |
| `cableMinSpanS` | 40 s | so viel Zeit muss das Fenster wirklich abdecken |
| `cableMinSamples` | 30 | … mit mindestens so vielen angenommenen GPS-Punkten |
| `cableMinSpeedMs` | 1,8 m/s | darunter ist es Anstehen oder Station, keine Fahrt |
| `cableMaxSpeedMs` | 11,5 m/s | 41 km/h — schneller als jede Seilbahn, also ein Mensch |
| `cableMaxSpeedCv` | 0,06 | erlaubte Tempo-Streuung, relativ zum Mittel |
| `cableMaxSpeedSdMs` | 0,42 m/s | … oder absolut, je nachdem was größer ist: GPS-Rauschen ist absolut (≈ 0,3 m/s) und würde bei 2,5 m/s jedes relative Budget sprengen. Gilt **nur bergauf** — bergab war genau diese absolute Untergrenze der Fehler (bei 5 m/s erlaubte sie 8,4 % Streuung, also gewöhnliches Skifahren). Weil sie bei 2,2 m/s auch einen Menschen mit 15 % Streuung durchlässt, hängt an ihr die Bestätigung eine Zeile weiter unten |
| `cableSlices` | 5 | das Fenster wird in 5 Abschnitte gemittelt, bevor die Linie gemessen wird |
| `cableMinStraightness` | 0,97 | Luftlinie geteilt durch gefahrene Linie über diese Abschnitte |
| `cableMinAltMonotonicity` | 0,9 | Anteil der Höhenänderung, der in **eine** Richtung geht |
| `cableFlatSliceM` | 4 m | … oder jeder Abschnitt ist so flach: das Flachstück einer Seilbahn hält die Fahrt zusammen, startet aber keine |
| `cableMinAltChangeM` | 8 m | so viel Höhe muss eine echte Fahrt im Fenster machen |
| `cableMinGradientPct` | 12 % | … an einem echten Gefälle; hält Ziehwege und flache Querfahrten draußen |
| `cableStaleS` | 5 s | ohne frischen Fix gilt das Urteil nicht mehr |
| `cableEnterS` | 20 s | so lange muss „fährt" halten, bevor eine Liftfahrt eröffnet wird |
| `cableRunVetoCoverage` | 0,6 | Anteil einer „Abfahrt", der die Signatur tragen muss, damit sie nachträglich zur Auffahrt wird |
| `cableStationS` | 15 s | so weit darf der Anfang der Fahrt über die Anfahrt aus der Station zurückgezogen werden |
| `liftSliverMergeS` | 10 s | so kurz darf ein Splitter zwischen zwei gleichgerichteten Fahrten sein, um keine zweite Fahrt zu sein |
| `finalizeLookbackS` | 90 s (abgeleitet) | so weit greift **irgendeine** Nachbearbeitungsregel zurück, berechnet aus den Regeln selbst: 60 s Wendepunkt-Snap, 80 s Seilbahn-Start-Snap — und 1.925 s, sobald `descentRidesEnabled` an ist. Die Live-Auswertung friert nichts ein, was noch in diesem Fenster liegt; `freeze_margin_test.dart` rechnet die Reichweite nach und fällt um, wenn eine Regel sie überwächst. Marge heute: **+10 s** |

### Bergauf: die Bestätigung auf voller Auflösung

Gilt nur für Auffahrten, die **keine** der beiden barometrischen Regeln öffnen
würde — praktisch: Schlepplift, Tellerlift, und der Mensch, der wie einer aussieht.

| Konstante | Wert | Bedeutung |
| --- | --- | --- |
| `cableAscentBaroWindowS` | 30 s | Fenster, in dem geprüft wird, ob der Barometer die Fahrt schon allein beweist (`liftEnterVz30Ms` = 0,8 m/s oder `liftEnterGained60M` = 30 m pro Minute). Trifft eines zu, wird nichts nachgeprüft: 0,8 m/s über eine halbe Minute sind 2.880 m/h, Tourengehen sind 0,15–0,35 m/s |
| `cableAscentStationLookbackS` | 45 s | so nah muss der Stillstand vor dem Start liegen |
| `cableAscentStationHoldS` | 10 s | … und so lange muss er dauern. 5 s reichten nicht: wer am Fuß eines Gegenhangs auf Schritttempo abfällt, steht zwei, drei Sekunden lang „still" |
| `cableAscentMaxBowFactor` | 0,30 | größter *Bauch* als Vielfaches der gemeldeten GPS-Genauigkeit: mittlerer seitlicher Abstand über je `cableAscentBowWindowS` zur Ausgleichsgeraden. Gemessen: jedes Seil 0,9–2,1 m, 1 °/s Schlängeln 2,1–52 m, 3 °/s 4,7–145 m |
| `cableAscentMaxBowFloorM` / `…CapM` | 2,4 m / 6,0 m | Untergrenze und absolute Obergrenze der Schranke — ein ruhiges Telefon macht sie nicht unmöglich, ein rauschendes schaltet sie nicht ab |
| `cableAscentBowWindowS` | 30 s | feste Fensterlänge, damit die Rauschgrenze des Bauchs nicht von der Fahrtlänge abhängt |
| `cableAscentRampS` | 15 s | so viel wird an beiden Enden abgeschnitten. Der Start-Snap zieht die Fahrt *in* ihre Station, und ein Lift verlässt LIFT erst, wenn die Signatur schal ist — 15 s Stillstand in der Tempo-Reihe machen aus 0,10 m/s Streuung 0,49 m/s |
| `cableAscentMinSamples` | 25 | darunter wird nicht geurteilt und die Liftfahrt bleibt: eine kurze Auffahrt kann keine 30 Phantom-Höhenmeter tragen, und jeden Anfänger-Schlepplift wegzuwerfen wäre der schlechtere Tausch |

### Bergab: die Schwellen der abgeschalteten Regel

`descentRidesEnabled` ist **false**; alles hier drunter ist dokumentiert, weil der
Code steht und die Entscheidung nachvollziehbar bleiben soll. Jede Zahl ist
gemessen, nicht geraten; die Messwerte stehen als Kommentar an der Konstante in
`app/lib/core/constants.dart`.

| Konstante | Wert | Bedeutung |
| --- | --- | --- |
| `descentRidesEnabled` | **false** | Hauptschalter. Umlegen kostet 427 gelöschte Abfahrten im Sweep und weitet `finalizeLookbackS` auf 1.925 s |

| Konstante | Wert | Was sie trennt |
| --- | --- | --- |
| `descentMinDurationS` | 300 s | **Die Regel, die das Ganze trägt.** Eine gerade, gleichmäßige Abfahrt zwischen zwei Stillständen ist auf voller Auflösung *identisch* mit einer Gondel: Abstand zur Linie 11–19 m bei beiden, Höhen-Restfehler 1–2 m bei beiden, und die geglättete Tempostreuung landet auf den ruhigeren Seeds im Seilbahn-Band (5 m/s über 240 s mit 15 % Streuung: 0,131 gegen eine Grenze von 0,150). Nichts Messbares trennt die zwei — also muss die Länge es tun. Talgondeln fahren 5–12 Minuten |
| `descentMaxRideS` | 1800 s | längste Spanne, die als **eine** Fahrt zusammengefasst wird |
| `descentMinDropM` | 120 m | dreimal `runMinDropM`: die Fahrt muss wirklich ins Tal |
| `descentMinGradientPct` | 10 % | Talgondel-Profile 12–30 %, Ziehweg oder Skistraße 5–12 % |
| `descentMinVerticalMs` | 0,7 m/s | Talgondel-Profile sinken mit 0,86–3,0 m/s, ein Ziehweg mit 4–6 m/s nur mit 0,2–0,7 m/s |
| `descentMinSpeedMs` | 4,0 m/s | darunter ist keine Trennung messbar: gerade 2- und 3-m/s-Abfahrten streuen 0,082–0,129 m/s, genau im Seilbahn-Band (0,085–0,131). Also gewinnt die Abfahrt. Talgondeln fahren 5–9 m/s, Standseilbahnen 7–10 m/s |
| `descentSpeedSdFactor` | 0,30 | Tempostreuung als Vielfaches der **gemeldeten** `speedAccMs`, nie als Konstante. Bei `speedAccMs` 0,5 sind das 0,15 m/s: Seilbahnen 0,085–0,131, ein Skifahrer mit 10–11 m/s und 7–9 % Streuung 0,125–0,224 |
| `descentSpeedSdFloorMs` | 0,09 m/s | Untergrenze = gemessenes geglättetes Doppler-Rauschen; ein unrealistisch guter `speedAccMs` kann die Grenze nicht unerreichbar machen |
| `descentSpeedSmoothS` | 9 s | so lange wird das Tempo gemittelt, bevor die Streuung gemessen wird: Doppler-Rauschen ist weiß und mittelt sich weg (0,30 → 0,10 m/s), die Temposchwankung eines Skifahrers ist über Sekunden korreliert und bleibt stehen |
| `descentRampS` | 20 s | so viel wird an beiden Enden abgeschnitten — Anfahrt und Einfahrt sind nicht das Mittelstück |
| `descentMaxChordOffsetFactor` | 2,5 | größter senkrechter Abstand **jedes** Fixes von der Linie Start–Ende, als Vielfaches der gemeldeten GPS-Genauigkeit. Seilbahnen 11–19 m bei ≈ 10 m Genauigkeit (1,1–1,9 ×), eine echte Abfahrt mit Schwüngen 660–1380 m (66–138 ×) |
| `descentMaxChordOffsetFloorM` | 25 m | … aber nie strenger: 25 m Drift über eine kilometerlange Fahrt ist noch eine Gerade |
| `descentMaxChordOffsetCapM` | 40 m | … und nie lockerer, egal was das Gerät meldet. Der Abstand, den eine echte Kurvenfahrt zeigt, wächst *nicht* mit der gemeldeten Genauigkeit — ohne diese Kappe schaltete ein rauschendes Telefon die Prüfung bei 2,5 × 30 m = 75 m stillschweigend ab |
| `descentMaxAltResidualM` | 5,0 m | Restfehler der Höhe gegen die Strecke. Seilbahn-Profile 0,6–3,8 m — das ist das Rauschen der Höhenmessung selbst |
| `descentStationLookbackS` | 45 s | so nah muss der Stillstand vor dem Start und nach dem Ende liegen |
| `descentStationSpeedMs` | 1,0 m/s | darunter gilt ein Fix als „steht in der Station" |
| `descentStationHoldS` | 5 s | … und zwar so lange, damit ein Ausreißer keine Station ist |
| `descentMinSamples` | 60 | so viele Fixes braucht das Mittelstück, bevor seine Streuung etwas bedeutet |
| `descentMidStationS` | 90 s | so lange darf eine Mittelstation dauern, ohne die Fahrt zu zerlegen |
| `descentLiveMinSamples` | 25 | dieselbe Prüfung live, mit kleinerer Untergrenze — sie hält nur eine Zahl eine Sekunde länger zurück |
| `descentLiveBoundSlack` | 1,5 | Spielraum für das Live-Urteil: es rechnet auf einem wachsenden Fenster und ist damit unruhiger. Echtes Skifahren streut 7–23 × über der Grenze, kommt also auch so nicht durch |
| `descentLiveBreakS` | 5 s | so lange muss das Live-Urteil kippen, bevor die Zahl freigegeben wird |
| `descentHoldGraceS` | 20 s | so lange hält der Live-Top-Speed nach dem Anhalten noch zurück, bis die Fahrt umgeschrieben ist |

### Der Skibus: alle fünf müssen zusammenkommen

| Konstante | Wert | Bedeutung |
| --- | --- | --- |
| `roadMinSpeedMs` | 9 m/s | Busse fahren; ein Ziehweg mit 5 m/s erreicht das nie |
| `roadMinDurationS` | 240 s | … und zwar minutenlang ins Tal |
| `roadMaxGradientPct` | 10 % | Straßen sind trassiert, Pisten nicht: eine Piste mit 9 m/s Schnitt hat 20–40 % |
| `roadMaxChordOverPath` | 0,55 | Luftlinie geteilt durch gefahrene Linie — Kehren halbieren sie, ein querender Skifahrer bleibt deutlich darüber |
| `roadMinHairpins` | 2 | so viele Richtungsumkehren … |
| `roadHairpinMinTurnDeg` | 150° | … von mindestens diesem Winkel … |
| `roadHairpinMinPathM` | 400 m | … über mindestens so viel Straße. Ein Skischwung dreht über 20–60 m |
| `roadLiveMinDurationS` | 105 s | nur für die **Live-Anzeige**: ab hier wird dieselbe Geometrie schon auf den offenen Abschnitt angewendet und der Top-Speed zurückgehalten. Eingeordnet wird nichts früher — nur die Zahl wartet |
| `roadLiveMinHairpins` | 1 | … und eine Kehre genügt dafür. Wer bei ≥ 9 m/s Schnitt auf ≤ 10 % Gefälle die doppelte Luftlinie fährt *und* einmal um 150° umkehrt, ist kein Skifahrer; und wäre er es, käme sein Top-Speed eine Minute später |

## Grenzen

Alles hier ist gemessen und als Dauertest festgehalten, nicht geschätzt.

* **Eine Gondel ins Tal zählt als Abfahrt.** Die bewusste Entscheidung, oben
  ausführlich: [Bergab: abgeschaltet](#bergab-höhenverlust-abgeschaltet). Konkret
  gemessen: die Zweisektionsgondel ins Tal bringt 29 km/h Top-Speed und 6,3 km
  Ski-Strecke, die Gondel nach Hause eines Anfängers 35 km/h. Wer das nicht will,
  legt `descentRidesEnabled` um und bezahlt mit 427 gelöschten echten Abfahrten
  (`ski_road_sweep_test.dart`).
* **Ein Aufstieg aus dem Stand, schnurgerade, mit Maschinentempo, bleibt ein
  Lift.** Wer mit 2,2–3,0 m/s auf 13–20 % Gefälle aus dem Stillstand losfährt,
  zwei bis sechs Minuten lang keine Kurve macht und wieder anhält, wird als
  Schlepplift gebucht. Das ist keine Lücke, sondern dasselbe Signal: die
  ausgelieferte Schlepplift-Abnahme (`lift_scenarios_test.dart`, „T-bar on skis
  3 m/s, +200 m") *ist* ein Aufstieg mit 3 m/s, 22 % und 10 % Tempostreuung mit
  Stillstand davor — der Generator erzeugt für Mensch und Seil dieselben Punkte.
  Gemessen: 81 von 945 Fällen des Aufwärts-Sweeps, alle ohne Schlängeln oder unter
  zwei Minuten. Physikalisch ist die Kombination ohnehin keine: 3 m/s auf 20 %
  sind 2.160 Höhenmeter pro Stunde. Der **realistische** Fall — aus der Abfahrt
  heraus den Gegenhang hochschieben und weiterfahren — ist auf 945 Fällen
  vollständig geschlossen: 0 Lifte (`uphill_sweep_test.dart`).
* **Ein Aufstieg von mehr als 30 Höhenmetern pro Minute** ist immer ein Lift, auch
  ohne Seilbahn-Signatur — das ist die barometrische Regel 2, und sie war schon
  vor dieser Runde so. 1.800 m/h hält kein Mensch eine Minute durch.
* **Umgekehrt verpasst:** eine langsame Auffahrt ohne Stillstand davor (in den
  Schlepplift hineingleiten, ohne anzuhalten) wird **Sonstiges** statt Lift. Das
  kostet Lift-Kilometer, nie eine Abfahrt.
* Ein **Zauberteppich** mit 0,7 m/s bleibt eine Pause. Er fährt unter der
  Bewegungsschwelle (0,8 m/s) und gewinnt meist unter 30 Höhenmeter. Die Schwellen
  so weit zu senken, dass er als Lift zählt, würde jede langsame Querfahrt
  bergauf zu einer Liftfahrt machen. Er bringt weder Strecke noch Tempo noch
  Höhenmeter — die Zahlen sind also korrekt, nur die Liftzahl fehlt.
* Live läuft die Erkennung hinterher, und der **Live-Top-Speed darf nachlaufen,
  aber nie überschießen**: eine Zahl, die der fertige Tag wegwirft, soll nicht auf
  dem Bildschirm gestanden haben. Gemessen und festgehalten in
  `live_overshoot_test.dart`:
  * **Skibus:** 41 km/h für höchstens 150 s (vorher 180–240 s). Die Straßenregel
    kann vor 240 s nichts einordnen; ab 105 s hält die Live-Anzeige die Zahl
    zurück. Ganz auf null bringt es nur eine echte Vorhersage.
  * **Standseilbahn im Tunnel:** höchstens 2 s (vorher 17 s). Der offene
    Abfahrts-Abschnitt wuchs auf Wanduhr-Zeit über die 60-Sekunden-Grenze, während
    seine Fixes im Tunnel standen; jetzt zählt nur die Zeit, in der er sich bewegt
    hat und Fixes hatte.
  * Auf **allen** Profilen: der Live-Wert bleibt ≤ dem fertigen Wert, und der
    fertige Wert ist immer das Maximum über die Abfahrten.
* Über **41 km/h** zählt ein Wert live sofort (schneller als jede Seilbahn ist
  sicher Skifahren).
* Zwischen zwei Nachbearbeitungsläufen kann die Live-Anzeige ein paar Sekunden alt
  sein. Der gespleißte Vorlauf plus Nachlauf stimmt auf **allen 16 Profilen**
  exakt mit einer vollen Rechnung überein (≤ 1 m Ski-Strecke, ≤ 1 m Höhenmeter,
  ≤ 0,01 m/s Top-Speed) — `freeze_margin_test.dart`. Die einzige bekannte
  Abweichung ist ein **GPS-Loch mitten in einem Lift**: dort bis zu ~150 m
  Ski-Strecke, weil der Vorlauf nicht über einen Signalverlust hinweg
  eingefroren werden kann, ohne die Kosten pro Tick unbegrenzt wachsen zu lassen.
  Der fertige Tag ist immer exakt.
* Der eingefrorene Vorlauf endet jetzt immer auf einer **Abschnittsgrenze** und der
  Nachlauf bekommt ganze Intervalle plus zwei Reserve-Intervalle davor. Ein
  abgeschnittenes Intervall ist ein anderes Intervall — sein Start-Snap landet
  woanders, seine Station fehlt, seine Tempostreuung wird über ein anderes Fenster
  gemessen. Das kostet Rechenzeit (110 µs statt 70 µs pro Tick auf einem
  10-Stunden-Tag, Budget 5 ms) und ist der Preis dafür, dass die Live-Zahlen und
  der fertige Tag dasselbe sagen.
* `TrackingConfig.engineVersion` ist 2 (war 1). Die Zahl wird nur mitgespeichert;
  alte Tage werden nicht automatisch neu gerechnet — dafür gibt es
  Diagnose → „Neu berechnen".

## Die Dauertests

| Datei | Was sie festhält |
| --- | --- |
| `ski_road_sweep_test.dart` | 4.320 Ziehweg-Tage: **keine** darf zum Lift werden, und Höhenmeter, Strecke und Top-Speed müssen zur Wahrheit des Generators passen. Der Test, der die Bergab-Entscheidung trägt |
| `uphill_sweep_test.dart` | 945 Gegenhang-Fälle aus der Abfahrt heraus: **kein** Lift. Dazu der gemessene Rand der Stillstand-zu-Stillstand-Variante und echte Schlepplifte, die weiter erkannt werden müssen |
| `descent_false_positive_test.dart` | das Band, in dem echtes Skifahren lebt (2–11 m/s, mit und ohne Lift davor) |
| `lift_cases_test.dart` | die Fallliste des Reviews, ein Test pro Fall |
| `lift_rides_test.dart` / `lift_scenarios_test.dart` | jede Liftart, und dass keine etwas zu den Ski-Zahlen beiträgt |
| `freeze_margin_test.dart` | die Reichweite jeder Nachbearbeitungsregel gegen das Einfrier-Fenster, und Vorlauf + Nachlauf gegen eine volle Rechnung auf allen Profilen |
| `live_overshoot_test.dart` | der Live-Top-Speed darf nachlaufen, nie überschießen |
| `live_invariants_test.dart` | derselbe Anspruch Tick für Tick über ganze Tage auf 8 Seeds |
| `descent_test.dart` | `evaluateDescent` Schranke für Schranke |
| `cable_test.dart` | das rollende Fenster Schranke für Schranke |
