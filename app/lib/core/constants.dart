/// Every tracking threshold in one place (see docs/PLAN.md §5).
/// Pure Dart — no Flutter imports. Values are SI: metres, seconds, m/s.
class TrackingConfig {
  const TrackingConfig();

  // ---- Gate (per raw fix) ----
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
  static const int engineVersion = 1;
}
