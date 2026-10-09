/// Every tracking threshold in one place (see docs/PLAN.md §5).
/// Pure Dart — no Flutter imports. Values are SI: metres, seconds, m/s.
class TrackingConfig {
  const TrackingConfig();

  // ---- Gate (per raw fix) ----
  // --- day guards (features/recording/guards.dart) ---------------------------
  /// A recording longer than this is ended automatically (forgotten in the jacket).
  static const int maxDayH = 16;
  /// Local hour at which a day that crossed midnight is closed (03:00).
  static const int dayRolloverHour = 3;
  /// Minutes without location access (permission revoked, service off) before the day is closed.
  static const int noAccessAutoEndMin = 30;

  static const double maxHorizontalAccuracyM = 30;
  static const double maxFixAgeS = 5;
  static const double minAltitudeM = 0;
  static const double maxAltitudeM = 4500;
  static const double maxImpliedSpeedMs = 45;
  static const double maxAccelMs2 = 8;
  static const double speedTrustedMaxAccMs = 1.5;
  static const double maxCandidateHAccM = 20;
  static const double maxCandidateSpeedAccMs = 1.0;
  static const double altAnchorMaxVAccM = 15;
  static const double windowResetGapS = 10;

  // ---- Speed ----
  static const double zeroClampMs = 0.8;
  static const double displayEmaAlpha = 0.4;
  static const double maxSpeedConfirmTolerance = 0.15; // 2 of 3 within 15 %
  static const double hardSpeedCapMs = 45;

  // ---- Altitude fusion ----
  static const double seaLevelHpa = 1013.25;
  static const double hypsometricScaleM = 44330.8;
  static const double hypsometricExponent = 0.19026;
  static const int anchorInitFixes = 10;
  static const double anchorEmaAlpha = 0.02;
  static const double kUpdateMinBaroChangeM = 80;
  static const double kEmaOld = 0.8;
  static const double kMin = 0.85;
  static const double kMax = 1.15;
  static const bool baroScaleCorrectionEnabled = true;
  static const double gpsOnlyAltEmaAlpha = 0.3;
  static const double gpsOnlyThresholdFactor = 2.5;
  static const double baroMedianWindow = 3;
  static const double baroMaxRateHpaPerS = 3;
  static const double baroMaxAgeS = 3;

  // ---- Vertical (turning-point hysteresis) ----
  static const double verticalHysteresisBaroM = 10;
  static const double verticalHysteresisGpsM = 25;

  // ---- Distance ----
  static const double distanceMinSpeedMs = 0.8;
  static const double distanceMaxDtS = 5;

  // ---- Segmenter ----
  static const double stopEnterSpeedMs = 0.8;
  static const int stopEnterS = 10;
  static const double stopExitSpeedMs = 1.5;
  static const int stopExitS = 3;
  static const double liftEnterVz30Ms = 0.8;
  static const int liftEnterS = 20;
  static const double liftEnterGained60M = 30;
  static const double liftMaxHorizontalSpeedMs = 8;
  static const int liftGapEnterS = 30;
  static const double liftGapGainM = 30;
  static const double liftExitVz30Ms = 0.2;
  static const int liftExitS = 15;
  static const double liftExitVz10Ms = -0.7;
  static const int liftMinDurationS = 60;
  static const double liftMinGainM = 30;
  static const double runEnterVz10Ms = -0.7;
  static const double runEnterSpeedMs = 2;
  static const int runEnterHits = 8; // of the last 10 ticks
  static const int runStopAbsorbS = 45;
  static const double runFlatVz30Ms = 0.3;
  static const double runFlatSpeedMs = 2;
  static const int runFlatS = 60;
  static const int runMinDurationS = 60;
  static const double runMinDropM = 40;
  static const int signalLossGapS = 120;

  // ---- Cable-ride signature (docs/TRACKING.md) ----
  // A cable (gondola, chairlift, T-bar, funicular) moves at a constant speed on
  // a straight line and changes altitude one way only. Skiers vary their speed,
  // turn, and lose altitude irregularly. These thresholds separate the two on the
  // way *up*, so a lift ride never lands in top speed or skied distance. On the
  // way *down* they do not separate anything (see [descentRidesEnabled]).
  /// Rolling window over accepted fixes the signature is judged on.
  static const int cableWindowS = 45;
  /// The window must really span this much time (a short burst proves nothing).
  static const int cableMinSpanS = 40;
  /// … with at least this many accepted fixes in it.
  static const int cableMinSamples = 30;
  /// A cable moves: below this the window is a queue or a lift station, not a ride.
  static const double cableMinSpeedMs = 1.8;
  /// Cable cars and funiculars top out near 40 km/h; skiers cruise faster.
  static const double cableMaxSpeedMs = 11.5;
  /// Speed spread / mean speed. A cable is constant, a skier is not — and the
  /// bar has to be low: a skier cruising at ± 15 % has a coefficient of
  /// variation of only 0.09, so 0.10 would call a straight schuss a gondola.
  /// A cable's spread is pure Doppler noise, well under 0.05 above 6 m/s.
  static const double cableMaxSpeedCv = 0.06;
  /// … but GPS speed noise is *absolute* (≈ 0.3 m/s), so on a 2.5 m/s chair the
  /// noise alone would blow any relative budget. The spread may be up to the
  /// larger of [cableMaxSpeedCv] · mean and this noise floor.
  static const double cableMaxSpeedSdMs = 0.42;
  /// The window is split into this many equal-count slices before the path is
  /// measured; averaging each slice removes the GPS noise that would otherwise
  /// make every slow, straight ride look crooked.
  static const int cableSlices = 5;
  /// Chord / path length over the slice centroids (1.0 = perfectly straight).
  static const double cableMinStraightness = 0.97;
  /// |Σ Δh| / Σ|Δh| over the slices: up or down, but one way only.
  static const double cableMinAltMonotonicity = 0.9;
  /// … or every slice is this flat — a cable car's flat mid-span, which holds a
  /// running lift but never starts one.
  static const double cableFlatSliceM = 4;
  /// A ride must change altitude by at least this much over the window.
  static const double cableMinAltChangeM = 8;
  /// … on a real gradient. A cat track or a flat traverse is shallower than this.
  static const double cableMinGradientPct = 12;
  /// Without a fresh fix the signature stops holding after this long.
  static const int cableStaleS = 5;
  /// The signature must hold this long before a LIFT is opened from it.
  static const int cableEnterS = 20;
  /// Share of a RUN interval that must carry the signature for finalize to
  /// rewrite it as a lift ride.
  static const double cableRunVetoCoverage = 0.6;
  /// A cabin leaves the station from a standstill, so finalize may walk a ride's
  /// start back over at most this much acceleration to reach that standstill.
  static const int cableStationS = 15;
  /// How far back the start snap of rule 1c looks for the ride it belongs to:
  /// the window has to fill ([cableWindowS]), hold ([cableEnterS]), and then the
  /// start walks back over the station ramp ([cableStationS]). Its own reach, not
  /// [finalizeLookbackS] — that one is the *maximum over all rules* and grows with
  /// [descentRidesEnabled], which would silently widen this search too.
  static const int cableStartSnapReachS = cableWindowS + cableEnterS + cableStationS;

  // ---- Ascending cable ride: the interval-level confirmation ----------------
  // The 45 s rolling window above measures straightness over *slice centroids*,
  // which is what makes a slow ride measurable at all — and it is also blind to
  // a wander: a skater poling up a connector at T-bar speed scores a
  // straightness of 0.99 over the window and was booked as a cable LIFT. So an
  // ascent that rests on the window *alone* has to clear a second, full
  // resolution check over the whole interval. Measured on the synthetic
  // profiles: every genuine rope (chairlift, T-bar, platter, funicular, gondola,
  // 2–11 m/s, 120–480 s) scores a bow of 0.9–2.1 m; the same motion with a
  // heading wander of 1 °/s scores 2.1–52 m and with 3 °/s 4.7–145 m.
  /// Window the ascent's own vertical speed is measured over to decide whether
  /// the *barometer* already proves the lift: if any window of this length
  /// climbs at [liftEnterVz30Ms], the segmenter's rule 1 would have opened this
  /// lift without the cable signature, so there is nothing to confirm. Nobody
  /// climbs at 0.8 m/s (2.880 m/h) for half a minute without a machine —
  /// skinning is 0.15–0.35 m/s, a bootpack 0.2–0.3. What is left to confirm is
  /// the *slow* rope: T-bar, platter, and the skater who looks like one.
  static const int cableAscentBaroWindowS = 30;
  /// A T-bar or platter is boarded from a standstill in a station. A slow ascent
  /// with no standstill this close in front of it is a skier skating uphill off a
  /// run — which is exactly the false positive this rule exists for.
  static const int cableAscentStationLookbackS = 45;
  /// … and it has to be a real station: you stand in a T-bar queue for at least
  /// ten seconds. A skier crawling through the bottom of a counter-slope does dip
  /// under [descentStationSpeedMs] for two or three seconds, and the five-second
  /// hold a cabin's station needs let exactly those cases through.
  static const int cableAscentStationHoldS = 10;
  /// Seconds dropped at each end of the ascent before it is measured. The start
  /// snap pulls a ride back *into* its station, so the interval begins with a
  /// standstill; and a boundary snap can let a few seconds of the run behind it
  /// in at the other end. Neither is the ride.
  static const int cableAscentRampS = 15;
  /// Largest mean cross-track offset over any [cableAscentBowWindowS] of the
  /// ride, from the least-squares line through the whole ride, as a multiple of
  /// the median reported hAcc — the *bow*. Averaging over the window removes the
  /// per-fix GPS noise that a max-offset test cannot tell from a bend.
  static const double cableAscentMaxBowFactor = 0.30;
  /// … never tighter than this (a very quiet phone must not make it impossible)
  /// and never looser (a noisy one must not switch it off).
  static const double cableAscentMaxBowFloorM = 2.4;
  static const double cableAscentMaxBowCapM = 6.0;
  /// Seconds the cross-track offset is averaged over. Fixed, so the noise floor
  /// of the bow does not depend on how long the ride is.
  static const int cableAscentBowWindowS = 30;
  /// Accepted fixes the confirmation needs before it means anything. The cable
  /// signature itself needs cableWindowS + cableEnterS = 65 s to open a lift at
  /// all, which leaves 35 s of cruise after the two ramps. Below this the lift is
  /// kept: a short ascent cannot carry more than liftMinGainM of phantom ascent,
  /// and throwing away every beginner T-bar would be the worse trade.
  static const int cableAscentMinSamples = 25;

  // ---- Descending cable ride (a gondola riding DOWN into the valley) ----
  // Asymmetric on purpose (docs/TRACKING.md): the rolling-window signature above
  // is evidence enough for a ride *up* — nobody gains altitude at a constant
  // speed on a straight line without a machine. Going *down* at a constant speed
  // on a straight line is exactly what a schuss looks like, so a descent must
  // clear every one of the following before it is taken away from the skier.
  // When the evidence is ambiguous, it stays a run.
  //
  // SHIPPED OFF (2026-09-30). The rule below is complete, tested and switched
  // off, because the ambiguity is not a corner case — it is the whole band.
  // Measured over 4.320 ski-road days (4–7 m/s, 9–25 % gradient, jitter
  // 0.05–0.15, heading wander 0–0.5 °/s, 5–10 minutes, 6 seeds, every case
  // between two standstills): 427 of them were rewritten as a valley ride, i.e.
  // a real run was deleted. A dead-straight ski road at 5 m/s with 8 % speed
  // spread scores a smoothed spread of 0.104–0.141 m/s, a chord offset of
  // 12.9–13.4 m and an altitude residual of 0.9–1.0 m; a valley gondola at
  // 5–7 m/s scores 0.09–0.12 m/s, 12–15 m and 0.6–1.9 m. The distributions
  // overlap, and no threshold on speed, gradient, sink rate, straightness or
  // altitude linearity separates them — the ski-road band *contains* the
  // gondola band. Narrowing the rule until the sweep is clean means a mean-speed
  // floor above 7 m/s, which is above every valley gondola the case list names,
  // so it is the same thing as switching it off, only less honest.
  // Consequence, documented in docs/TRACKING.md: a gondola riding down counts as
  // a run, with its drop and its 25–35 km/h in the ski numbers. That costs
  // honesty in the lift statistics; the alternative costs real runs.
  /// Master switch for rewriting a descent as a cable ride down. **false.**
  /// Everything the rule needs (`descent.dart`, `_descendingCablePass`, the
  /// live hold in the engine, `descent_test.dart`,
  /// `descent_false_positive_test.dart`, `ski_road_sweep_test.dart`) is in place
  /// and exercised; flipping this to true re-enables it, widens
  /// [finalizeLookbackS] to cover its reach and costs the false positives above.
  static const bool descentRidesEnabled = false;
  /// Shortest descent that may be rewritten as a ride, and the gate that carries
  /// the whole rule. Measured: a straight, steady descent between two standstills
  /// is geometrically *identical* to a gondola at full resolution — offset from
  /// the chord 11–19 m for both at hAcc ≈ 10 m, altitude residual 1–2 m for both —
  /// and its smoothed speed spread lands inside the cable band (0.085–0.129 m/s)
  /// on the quieter seeds: 5 m/s over 240 s with 15 % jitter scores 0.131 m/s
  /// against a bound of 0.150. Nothing measurable separates the two, so length
  /// has to. Valley gondolas run 5–12 minutes; every descent a skier can
  /// plausibly ski dead straight at a constant speed stays a run.
  static const int descentMinDurationS = 300;
  /// Longest span the rule joins into one ride (a mid-station stop or a five
  /// minute GPS dropout inside a steel cabin stay inside one ride).
  static const int descentMaxRideS = 1800;
  /// … and the ride must really go into the valley: three times runMinDropM.
  static const double descentMinDropM = 120;
  /// … on a cable gradient. Measured: valley-gondola profiles 12–30 %, a cat
  /// track or ski road 5–12 %.
  static const double descentMinGradientPct = 10;
  /// … and it must sink at cable pace. Measured: valley-gondola profiles
  /// 0.86–3.0 m/s of vertical speed, a cat track at 4–6 m/s and 5–12 % only
  /// 0.2–0.7 m/s. Together with the gradient this is what keeps a long, straight
  /// ski road on the skier's account.
  static const double descentMinVerticalMs = 0.7;
  /// Slowest descending cable. Measured: straight 2 and 3 m/s descents score a
  /// smoothed speed spread of 0.082–0.129 m/s, right inside the cable band
  /// (0.085–0.131 m/s) — at that speed the two are indistinguishable, so the run
  /// wins. Valley gondolas run 5–9 m/s, funiculars 7–10 m/s.
  static const double descentMinSpeedMs = 4.0;
  /// Speed spread bound as a multiple of the **reported** `speedAccMs` — never a
  /// constant, so a noisy phone cannot silently disable the test and a quiet one
  /// cannot swallow slow skiing. Measured at speedAccMs = 0.5 over the cruise
  /// portion: cables 0.085–0.131 m/s, a skier at 10–11 m/s with 7–9 % spread
  /// 0.125–0.224 m/s. 0.30 · 0.5 = 0.15 m/s sits between them.
  static const double descentSpeedSdFactor = 0.30;
  /// … but never below the smoothed Doppler noise floor measured on the cable
  /// profiles (0.085 m/s), so an implausibly optimistic speedAccMs cannot make
  /// the bound unreachable.
  static const double descentSpeedSdFloorMs = 0.09;
  /// Seconds the speed series is averaged over before its spread is measured.
  /// Doppler noise is white and averages out (0.30 m/s → 0.10 m/s over 9 s); a
  /// skier's speed changes are correlated over seconds and survive.
  static const int descentSpeedSmoothS = 9;
  /// Seconds dropped at each end before the speed spread is measured — the
  /// station ramps are not the cruise.
  static const int descentRampS = 20;
  /// Maximum perpendicular distance of **each accepted fix** from the start-end
  /// chord, as a multiple of the ride's median reported hAcc — full resolution,
  /// never over averaged slices. Measured: cables 11–19 m at hAcc ≈ 10 m
  /// (1.1–1.9 ×), a real descent with turns 660–1380 m (66–138 ×).
  static const double descentMaxChordOffsetFactor = 2.5;
  /// … and never tighter than this: 25 m of drift over a kilometre-long ride is
  /// still a straight line, and a very quiet phone must not make it impossible.
  static const double descentMaxChordOffsetFloorM = 25;
  /// … and never looser than this, whatever the device claims. The measured
  /// offset of a real curving path does not grow with the reported accuracy, so
  /// scaling the bound all the way to 2,5 × 30 m = 75 m only ever switched the
  /// test off on a noisy phone. Measured: straight rides 8–19 m at hAcc 8–30,
  /// a curving descent 28 m (0,3 °/s) to 1.380 m.
  static const double descentMaxChordOffsetCapM = 40;
  /// RMS residual of altitude fitted against cumulative distance: a cable is a
  /// straight line in 3D, a piste rolls. Measured: cable profiles 0.6–3.8 m,
  /// which is the fused-altitude noise level itself.
  static const double descentMaxAltResidualM = 5.0;
  /// A cabin is boarded and left at a station: a standstill must be found this
  /// close before the ride starts and this close after it ends. 45 s covers the
  /// segmenter's recognition lag plus the station ramp.
  static const int descentStationLookbackS = 45;
  /// Speed below which a fix counts as standing in the station.
  static const double descentStationSpeedMs = 1.0;
  /// … sustained this long, so one stray fix is not a station.
  static const int descentStationHoldS = 5;
  /// Accepted fixes the cruise portion needs before its spread means anything.
  static const int descentMinSamples = 60;
  /// Slack the *live* provisional verdict gets on the speed-spread and
  /// chord-offset bounds. The live estimate runs over a growing window, so it is
  /// noisier than the final one — on one seed the cabin's own spread touched the
  /// bound exactly (0.150 of 0.150) and released the hold mid-ride. Measured:
  /// real skiing scores 1.13–3.46 m/s of spread (7–23 × the bound) and 225–1380 m
  /// of chord offset (9–55 ×), so 1.5 × cannot let a skier through — and erring
  /// this way only ever delays a number, never shows a wrong one.
  static const double descentLiveBoundSlack = 1.5;
  /// … and the verdict must fail this many seconds in a row before the hold is
  /// given up, so one noisy second cannot release it.
  static const int descentLiveBreakS = 5;
  /// … and the smaller floor the *live* provisional verdict uses. It only decides
  /// whether to hold a top speed back for another second, and it is re-judged
  /// every second, so 25 s of cruise is enough — and it means a real run's peak
  /// below cableMaxSpeedMs waits at most descentRampS + this before it shows.
  static const int descentLiveMinSamples = 25;
  /// A ride is only rewritten once the standstill it arrived at has registered
  /// (descentStationHoldS) and the next finalize pass has run. The live top speed
  /// keeps holding its provisional peaks back for this long after the cabin has
  /// stopped, so the gondola's speed cannot flash on screen in that gap.
  static const int descentHoldGraceS = 20;
  /// A mid-station stop (or a short OTHER sliver) inside one ride may last this
  /// long before the ride counts as two rides.
  static const int descentMidStationS = 90;
  /// A sliver of OTHER between two rides in the same direction this short is not
  /// a second ride: it is one tick where a chairlift dipped and the rolling
  /// window could not hold. A real lift-to-lift transfer takes longer.
  static const int liftSliverMergeS = 10;

  // ---- Road guard (the ski bus) ----
  // A bus on a mountain road descends at skier speed on a constant gradient, so
  // neither the run rules nor the cable rules separate it. What no piste has is
  // a hairpin: a heading reversal taken over hundreds of metres of road at
  // sustained speed. All five conditions must hold together.
  /// Buses cruise; a cat track at 5 m/s never reaches this.
  static const double roadMinSpeedMs = 9;
  /// … for this long. A bus ride down to the valley takes minutes.
  static const int roadMinDurationS = 240;
  /// Roads are graded; pistes are not. 10 % is the legal limit for most alpine
  /// roads, a piste at 9 m/s average runs 20–40 %.
  static const double roadMaxGradientPct = 10;
  /// Straight line / driven line. Switchbacks halve it; a skier traversing a
  /// piste stays well above it.
  static const double roadMaxChordOverPath = 0.55;
  /// Heading reversals of [roadHairpinMinTurnDeg] taken over at least
  /// [roadHairpinMinPathM] of path. A skier's turn reverses over 20–60 m.
  static const int roadMinHairpins = 2;
  static const double roadHairpinMinPathM = 400;
  static const double roadHairpinMinTurnDeg = 150;
  /// The guard cannot fire before [roadMinDurationS], and until then the live
  /// screen shows the bus's 40 km/h as a top speed the finished day throws away.
  /// From this duration on the *same* geometry (both hairpins included) is
  /// evaluated on the open interval and its peaks are held back. Nothing is
  /// reclassified early — only the live number waits.
  static const int roadLiveMinDurationS = 105;
  /// … and one reversal is enough for the live hold. A skier who reverses by 150 °
  /// over 400 m of path while averaging [roadMinSpeedMs] on a gradient under
  /// [roadMaxGradientPct] and driving twice their straight line does not exist;
  /// and if they did, the only cost is that their top speed appears a minute late.
  static const int roadLiveMinHairpins = 1;

  /// How far back *any* finalize rule reaches, derived from the rules themselves
  /// so it cannot drift out of date. The live engine freezes only segments that
  /// end before this window, so a frozen segment can never be moved by a later
  /// rule and the spliced prefix+tail equals a full recompute.
  ///
  /// * the 60 s turning-point snap (rule 3b) → 60 s
  /// * the cable start snap (rule 1c) → cableWindowS + cableEnterS +
  ///   cableStationS = 80 s
  /// * the descending carve, *only when [descentRidesEnabled]* → a ride may span
  ///   descentMaxRideS and its station may sit descentStationLookbackS earlier
  ///   still, and the start snap then applies on top → 1.925 s
  ///
  /// The window is the furthest reach plus [finalizeLookbackSlackS], in both
  /// settings of the flag: off (shipped) → 80 + 10 = 90 s; on → 1.925 + 10 s.
  /// `freeze_margin_test.dart` recomputes the reach from the constants and
  /// fails if any rule ever outgrows the window.
  static const int finalizeLookbackSlackS = 10;
  static const int finalizeLookbackS = (descentRidesEnabled
          ? descentMaxRideS + descentStationLookbackS + cableStartSnapReachS
          : cableStartSnapReachS) +
      finalizeLookbackSlackS;

  // ---- Guards ----
  static const double vehicleSpeedMs = 30;
  static const int vehicleSustainS = 60;
  static const int vehicleAutoEndS = 300;
  static const int idleReminderMin = 90;
  static const int idleAutoEndMin = 180;
  static const int dayReminderH = 4;
  static const double meaningfulDayMinDistanceM = 100;
  static const int meaningfulDayMinMovingS = 60;
  static const int restartMergeWindowH = 4;
  static const int silentResumeMaxMin = 30;
  static const int streamWatchdogS = 60;

  // ---- Persistence ----
  static const int batchFlushPoints = 10;
  static const int batchFlushS = 5;
  static const int liveRingPoints = 300;

  // ---- GPS quality words (rolling 10 s median hAcc) ----
  static const double gpsVeryGoodM = 5;
  static const double gpsGoodM = 10;
  static const double gpsOkM = 20;
  static const int gpsNoFixS = 10;

  // ---- Battery ----
  static const int batterySampleMin = 5;
  static const int batteryWarnPct = 15;

  /// Bump when the engine's output for the same raw points changes.
  /// 2 — lift/cable detection, and the barometric scale correction no longer
  /// steps the fused altitude. A cable ride *up* is a lift, not a run: read off a
  /// 45 s window and, when it is too slow for the barometer to prove on its own,
  /// confirmed at full resolution over the whole interval (cable.dart). A ride
  /// *down* is **not** reclassified — see [descentRidesEnabled]. The rule was
  /// rebuilt inside version 2 before it ever shipped, so there is no 3.
  /// Provenance only: nothing branches on this value, a bump does not recompute
  /// anything (Diagnose → "Neu berechnen" is manual).
  static const int engineVersion = 2;
}
