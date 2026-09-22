import 'package:drift/drift.dart';

/// One ski day (docs/PLAN.md §9). All DayStats columns live here so the list
/// screen never touches points.
@DataClassName('DayRow')
@TableIndex(name: 'days_started', columns: {#startedAt})
@TableIndex(name: 'days_status', columns: {#status})
class Days extends Table {
  TextColumn get id => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get resortId => text().nullable()();
  TextColumn get resortName => text().nullable()();
  IntColumn get lastFixAt => integer().nullable()();
  IntColumn get engineVersion => integer().withDefault(const Constant(1))();
  IntColumn get streamRestarts => integer().withDefault(const Constant(0))();
  TextColumn get weatherJson => text().nullable()();
  TextColumn get mapThumbPath => text().nullable()();
  BoolColumn get trackedOnWatch => boolean().withDefault(const Constant(false))();
  // DayStats
  IntColumn get elapsedMs => integer().withDefault(const Constant(0))();
  IntColumn get skiMs => integer().withDefault(const Constant(0))();
  IntColumn get liftMs => integer().withDefault(const Constant(0))();
  IntColumn get pauseMs => integer().withDefault(const Constant(0))();
  IntColumn get signalLossMs => integer().withDefault(const Constant(0))();
  IntColumn get otherMs => integer().withDefault(const Constant(0))();
  IntColumn get runCount => integer().withDefault(const Constant(0))();
  IntColumn get liftCount => integer().withDefault(const Constant(0))();
  RealColumn get dropM => real().withDefault(const Constant(0))();
  RealColumn get ascentM => real().withDefault(const Constant(0))();
  RealColumn get skiDistanceM => real().withDefault(const Constant(0))();
  RealColumn get liftDistanceM => real().withDefault(const Constant(0))();
  RealColumn get totalDistanceM => real().withDefault(const Constant(0))();
  RealColumn get maxSpeedMs => real().withDefault(const Constant(0))();
  RealColumn get avgSkiSpeedMs => real().withDefault(const Constant(0))();
  RealColumn get maxAltM => real().nullable()();
  RealColumn get minAltM => real().nullable()();
  TextColumn get maxSpeedSegmentId => text().nullable()();
  TextColumn get longestRunSegmentId => text().nullable()();
  IntColumn get acceptedFixes => integer().withDefault(const Constant(0))();
  IntColumn get rejectedFixes => integer().withDefault(const Constant(0))();
  BoolColumn get hasBarometer => boolean().withDefault(const Constant(false))();
  BoolColumn get vehicleFlag => boolean().withDefault(const Constant(false))();
  IntColumn get avgHeartRateBpm => integer().nullable()();
  IntColumn get maxHeartRateBpm => integer().nullable()();
  // bookkeeping
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SegmentRow')
@TableIndex(name: 'segments_day_idx', columns: {#dayId, #idx})
class Segments extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text()();
  TextColumn get kind => text()();
  IntColumn get idx => integer()();
  IntColumn get runNumber => integer().nullable()();
  IntColumn get startTs => integer()();
  IntColumn get endTs => integer()();
  RealColumn get startAltM => real().withDefault(const Constant(0))();
  RealColumn get endAltM => real().withDefault(const Constant(0))();
  RealColumn get dropM => real().withDefault(const Constant(0))();
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  IntColumn get movingMs => integer().withDefault(const Constant(0))();
  RealColumn get maxSpeedMs => real().withDefault(const Constant(0))();
  IntColumn get maxSpeedAtTs => integer().nullable()();
  RealColumn get avgSpeedMs => real().withDefault(const Constant(0))();
  RealColumn get avgGradientPct => real().withDefault(const Constant(0))();
  RealColumn get steepest100mPct => real().nullable()();
  IntColumn get startPointTs => integer().nullable()();
  IntColumn get endPointTs => integer().nullable()();
  IntColumn get flags => integer().withDefault(const Constant(0))();
  TextColumn get pisteName => text().nullable()();
  TextColumn get pisteOsmId => text().nullable()();
  TextColumn get liftName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PointRow')
@TableIndex(name: 'points_day_ts', columns: {#dayId, #ts})
class Points extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dayId => text()();
  IntColumn get ts => integer()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  RealColumn get hAccM => real().nullable()();
  RealColumn get gpsAltM => real().nullable()();
  RealColumn get vAccM => real().nullable()();
  RealColumn get speedMs => real().nullable()();
  RealColumn get speedAccMs => real().nullable()();
  RealColumn get courseDeg => real().nullable()();
  RealColumn get pressureHpa => real().nullable()();
  RealColumn get fusedAltM => real().nullable()();
  BoolColumn get accepted => boolean().withDefault(const Constant(false))();
  TextColumn get rejectReason => text().withDefault(const Constant('none'))();
  TextColumn get state => text().withDefault(const Constant('unknown'))();
  IntColumn get heartRateBpm => integer().nullable()();
}
