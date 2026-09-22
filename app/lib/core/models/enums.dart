enum RejectReason { none, stale, nonMonotonic, hAcc, altitudeRange, impliedSpeed, accel, mocked }

enum MotionState { unknown, stop, run, lift, other }

enum SegmentKind { run, lift, stop, other, signalLoss }

enum GpsQuality { none, weak, ok, good, veryGood }

enum DayStatus { active, finished, discarded }

enum RecordingStatus { idle, starting, recording, ending }

extension SegmentKindX on SegmentKind {
  String get dbValue => name;
  static SegmentKind fromDb(String v) => SegmentKind.values.firstWhere((e) => e.name == v, orElse: () => SegmentKind.other);
}

extension DayStatusX on DayStatus {
  String get dbValue => name;
  static DayStatus fromDb(String v) => DayStatus.values.firstWhere((e) => e.name == v, orElse: () => DayStatus.finished);
}
