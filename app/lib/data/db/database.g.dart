// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DaysTable extends Days with TableInfo<$DaysTable, DayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resortIdMeta = const VerificationMeta(
    'resortId',
  );
  @override
  late final GeneratedColumn<String> resortId = GeneratedColumn<String>(
    'resort_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resortNameMeta = const VerificationMeta(
    'resortName',
  );
  @override
  late final GeneratedColumn<String> resortName = GeneratedColumn<String>(
    'resort_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFixAtMeta = const VerificationMeta(
    'lastFixAt',
  );
  @override
  late final GeneratedColumn<int> lastFixAt = GeneratedColumn<int>(
    'last_fix_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<int> engineVersion = GeneratedColumn<int>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _streamRestartsMeta = const VerificationMeta(
    'streamRestarts',
  );
  @override
  late final GeneratedColumn<int> streamRestarts = GeneratedColumn<int>(
    'stream_restarts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _weatherJsonMeta = const VerificationMeta(
    'weatherJson',
  );
  @override
  late final GeneratedColumn<String> weatherJson = GeneratedColumn<String>(
    'weather_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mapThumbPathMeta = const VerificationMeta(
    'mapThumbPath',
  );
  @override
  late final GeneratedColumn<String> mapThumbPath = GeneratedColumn<String>(
    'map_thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackedOnWatchMeta = const VerificationMeta(
    'trackedOnWatch',
  );
  @override
  late final GeneratedColumn<bool> trackedOnWatch = GeneratedColumn<bool>(
    'tracked_on_watch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tracked_on_watch" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _elapsedMsMeta = const VerificationMeta(
    'elapsedMs',
  );
  @override
  late final GeneratedColumn<int> elapsedMs = GeneratedColumn<int>(
    'elapsed_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skiMsMeta = const VerificationMeta('skiMs');
  @override
  late final GeneratedColumn<int> skiMs = GeneratedColumn<int>(
    'ski_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _liftMsMeta = const VerificationMeta('liftMs');
  @override
  late final GeneratedColumn<int> liftMs = GeneratedColumn<int>(
    'lift_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pauseMsMeta = const VerificationMeta(
    'pauseMs',
  );
  @override
  late final GeneratedColumn<int> pauseMs = GeneratedColumn<int>(
    'pause_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _signalLossMsMeta = const VerificationMeta(
    'signalLossMs',
  );
  @override
  late final GeneratedColumn<int> signalLossMs = GeneratedColumn<int>(
    'signal_loss_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _otherMsMeta = const VerificationMeta(
    'otherMs',
  );
  @override
  late final GeneratedColumn<int> otherMs = GeneratedColumn<int>(
    'other_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _runCountMeta = const VerificationMeta(
    'runCount',
  );
  @override
  late final GeneratedColumn<int> runCount = GeneratedColumn<int>(
    'run_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _liftCountMeta = const VerificationMeta(
    'liftCount',
  );
  @override
  late final GeneratedColumn<int> liftCount = GeneratedColumn<int>(
    'lift_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dropMMeta = const VerificationMeta('dropM');
  @override
  late final GeneratedColumn<double> dropM = GeneratedColumn<double>(
    'drop_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ascentMMeta = const VerificationMeta(
    'ascentM',
  );
  @override
  late final GeneratedColumn<double> ascentM = GeneratedColumn<double>(
    'ascent_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skiDistanceMMeta = const VerificationMeta(
    'skiDistanceM',
  );
  @override
  late final GeneratedColumn<double> skiDistanceM = GeneratedColumn<double>(
    'ski_distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _liftDistanceMMeta = const VerificationMeta(
    'liftDistanceM',
  );
  @override
  late final GeneratedColumn<double> liftDistanceM = GeneratedColumn<double>(
    'lift_distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalDistanceMMeta = const VerificationMeta(
    'totalDistanceM',
  );
  @override
  late final GeneratedColumn<double> totalDistanceM = GeneratedColumn<double>(
    'total_distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxSpeedMsMeta = const VerificationMeta(
    'maxSpeedMs',
  );
  @override
  late final GeneratedColumn<double> maxSpeedMs = GeneratedColumn<double>(
    'max_speed_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgSkiSpeedMsMeta = const VerificationMeta(
    'avgSkiSpeedMs',
  );
  @override
  late final GeneratedColumn<double> avgSkiSpeedMs = GeneratedColumn<double>(
    'avg_ski_speed_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxAltMMeta = const VerificationMeta(
    'maxAltM',
  );
  @override
  late final GeneratedColumn<double> maxAltM = GeneratedColumn<double>(
    'max_alt_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minAltMMeta = const VerificationMeta(
    'minAltM',
  );
  @override
  late final GeneratedColumn<double> minAltM = GeneratedColumn<double>(
    'min_alt_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxSpeedSegmentIdMeta = const VerificationMeta(
    'maxSpeedSegmentId',
  );
  @override
  late final GeneratedColumn<String> maxSpeedSegmentId =
      GeneratedColumn<String>(
        'max_speed_segment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _longestRunSegmentIdMeta =
      const VerificationMeta('longestRunSegmentId');
  @override
  late final GeneratedColumn<String> longestRunSegmentId =
      GeneratedColumn<String>(
        'longest_run_segment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _acceptedFixesMeta = const VerificationMeta(
    'acceptedFixes',
  );
  @override
  late final GeneratedColumn<int> acceptedFixes = GeneratedColumn<int>(
    'accepted_fixes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rejectedFixesMeta = const VerificationMeta(
    'rejectedFixes',
  );
  @override
  late final GeneratedColumn<int> rejectedFixes = GeneratedColumn<int>(
    'rejected_fixes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasBarometerMeta = const VerificationMeta(
    'hasBarometer',
  );
  @override
  late final GeneratedColumn<bool> hasBarometer = GeneratedColumn<bool>(
    'has_barometer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_barometer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _vehicleFlagMeta = const VerificationMeta(
    'vehicleFlag',
  );
  @override
  late final GeneratedColumn<bool> vehicleFlag = GeneratedColumn<bool>(
    'vehicle_flag',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vehicle_flag" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _avgHeartRateBpmMeta = const VerificationMeta(
    'avgHeartRateBpm',
  );
  @override
  late final GeneratedColumn<int> avgHeartRateBpm = GeneratedColumn<int>(
    'avg_heart_rate_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxHeartRateBpmMeta = const VerificationMeta(
    'maxHeartRateBpm',
  );
  @override
  late final GeneratedColumn<int> maxHeartRateBpm = GeneratedColumn<int>(
    'max_heart_rate_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    status,
    resortId,
    resortName,
    lastFixAt,
    engineVersion,
    streamRestarts,
    weatherJson,
    mapThumbPath,
    trackedOnWatch,
    elapsedMs,
    skiMs,
    liftMs,
    pauseMs,
    signalLossMs,
    otherMs,
    runCount,
    liftCount,
    dropM,
    ascentM,
    skiDistanceM,
    liftDistanceM,
    totalDistanceM,
    maxSpeedMs,
    avgSkiSpeedMs,
    maxAltM,
    minAltM,
    maxSpeedSegmentId,
    longestRunSegmentId,
    acceptedFixes,
    rejectedFixes,
    hasBarometer,
    vehicleFlag,
    avgHeartRateBpm,
    maxHeartRateBpm,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'days';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('resort_id')) {
      context.handle(
        _resortIdMeta,
        resortId.isAcceptableOrUnknown(data['resort_id']!, _resortIdMeta),
      );
    }
    if (data.containsKey('resort_name')) {
      context.handle(
        _resortNameMeta,
        resortName.isAcceptableOrUnknown(data['resort_name']!, _resortNameMeta),
      );
    }
    if (data.containsKey('last_fix_at')) {
      context.handle(
        _lastFixAtMeta,
        lastFixAt.isAcceptableOrUnknown(data['last_fix_at']!, _lastFixAtMeta),
      );
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    }
    if (data.containsKey('stream_restarts')) {
      context.handle(
        _streamRestartsMeta,
        streamRestarts.isAcceptableOrUnknown(
          data['stream_restarts']!,
          _streamRestartsMeta,
        ),
      );
    }
    if (data.containsKey('weather_json')) {
      context.handle(
        _weatherJsonMeta,
        weatherJson.isAcceptableOrUnknown(
          data['weather_json']!,
          _weatherJsonMeta,
        ),
      );
    }
    if (data.containsKey('map_thumb_path')) {
      context.handle(
        _mapThumbPathMeta,
        mapThumbPath.isAcceptableOrUnknown(
          data['map_thumb_path']!,
          _mapThumbPathMeta,
        ),
      );
    }
    if (data.containsKey('tracked_on_watch')) {
      context.handle(
        _trackedOnWatchMeta,
        trackedOnWatch.isAcceptableOrUnknown(
          data['tracked_on_watch']!,
          _trackedOnWatchMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_ms')) {
      context.handle(
        _elapsedMsMeta,
        elapsedMs.isAcceptableOrUnknown(data['elapsed_ms']!, _elapsedMsMeta),
      );
    }
    if (data.containsKey('ski_ms')) {
      context.handle(
        _skiMsMeta,
        skiMs.isAcceptableOrUnknown(data['ski_ms']!, _skiMsMeta),
      );
    }
    if (data.containsKey('lift_ms')) {
      context.handle(
        _liftMsMeta,
        liftMs.isAcceptableOrUnknown(data['lift_ms']!, _liftMsMeta),
      );
    }
    if (data.containsKey('pause_ms')) {
      context.handle(
        _pauseMsMeta,
        pauseMs.isAcceptableOrUnknown(data['pause_ms']!, _pauseMsMeta),
      );
    }
    if (data.containsKey('signal_loss_ms')) {
      context.handle(
        _signalLossMsMeta,
        signalLossMs.isAcceptableOrUnknown(
          data['signal_loss_ms']!,
          _signalLossMsMeta,
        ),
      );
    }
    if (data.containsKey('other_ms')) {
      context.handle(
        _otherMsMeta,
        otherMs.isAcceptableOrUnknown(data['other_ms']!, _otherMsMeta),
      );
    }
    if (data.containsKey('run_count')) {
      context.handle(
        _runCountMeta,
        runCount.isAcceptableOrUnknown(data['run_count']!, _runCountMeta),
      );
    }
    if (data.containsKey('lift_count')) {
      context.handle(
        _liftCountMeta,
        liftCount.isAcceptableOrUnknown(data['lift_count']!, _liftCountMeta),
      );
    }
    if (data.containsKey('drop_m')) {
      context.handle(
        _dropMMeta,
        dropM.isAcceptableOrUnknown(data['drop_m']!, _dropMMeta),
      );
    }
    if (data.containsKey('ascent_m')) {
      context.handle(
        _ascentMMeta,
        ascentM.isAcceptableOrUnknown(data['ascent_m']!, _ascentMMeta),
      );
    }
    if (data.containsKey('ski_distance_m')) {
      context.handle(
        _skiDistanceMMeta,
        skiDistanceM.isAcceptableOrUnknown(
          data['ski_distance_m']!,
          _skiDistanceMMeta,
        ),
      );
    }
    if (data.containsKey('lift_distance_m')) {
      context.handle(
        _liftDistanceMMeta,
        liftDistanceM.isAcceptableOrUnknown(
          data['lift_distance_m']!,
          _liftDistanceMMeta,
        ),
      );
    }
    if (data.containsKey('total_distance_m')) {
      context.handle(
        _totalDistanceMMeta,
        totalDistanceM.isAcceptableOrUnknown(
          data['total_distance_m']!,
          _totalDistanceMMeta,
        ),
      );
    }
    if (data.containsKey('max_speed_ms')) {
      context.handle(
        _maxSpeedMsMeta,
        maxSpeedMs.isAcceptableOrUnknown(
          data['max_speed_ms']!,
          _maxSpeedMsMeta,
        ),
      );
    }
    if (data.containsKey('avg_ski_speed_ms')) {
      context.handle(
        _avgSkiSpeedMsMeta,
        avgSkiSpeedMs.isAcceptableOrUnknown(
          data['avg_ski_speed_ms']!,
          _avgSkiSpeedMsMeta,
        ),
      );
    }
    if (data.containsKey('max_alt_m')) {
      context.handle(
        _maxAltMMeta,
        maxAltM.isAcceptableOrUnknown(data['max_alt_m']!, _maxAltMMeta),
      );
    }
    if (data.containsKey('min_alt_m')) {
      context.handle(
        _minAltMMeta,
        minAltM.isAcceptableOrUnknown(data['min_alt_m']!, _minAltMMeta),
      );
    }
    if (data.containsKey('max_speed_segment_id')) {
      context.handle(
        _maxSpeedSegmentIdMeta,
        maxSpeedSegmentId.isAcceptableOrUnknown(
          data['max_speed_segment_id']!,
          _maxSpeedSegmentIdMeta,
        ),
      );
    }
    if (data.containsKey('longest_run_segment_id')) {
      context.handle(
        _longestRunSegmentIdMeta,
        longestRunSegmentId.isAcceptableOrUnknown(
          data['longest_run_segment_id']!,
          _longestRunSegmentIdMeta,
        ),
      );
    }
    if (data.containsKey('accepted_fixes')) {
      context.handle(
        _acceptedFixesMeta,
        acceptedFixes.isAcceptableOrUnknown(
          data['accepted_fixes']!,
          _acceptedFixesMeta,
        ),
      );
    }
    if (data.containsKey('rejected_fixes')) {
      context.handle(
        _rejectedFixesMeta,
        rejectedFixes.isAcceptableOrUnknown(
          data['rejected_fixes']!,
          _rejectedFixesMeta,
        ),
      );
    }
    if (data.containsKey('has_barometer')) {
      context.handle(
        _hasBarometerMeta,
        hasBarometer.isAcceptableOrUnknown(
          data['has_barometer']!,
          _hasBarometerMeta,
        ),
      );
    }
    if (data.containsKey('vehicle_flag')) {
      context.handle(
        _vehicleFlagMeta,
        vehicleFlag.isAcceptableOrUnknown(
          data['vehicle_flag']!,
          _vehicleFlagMeta,
        ),
      );
    }
    if (data.containsKey('avg_heart_rate_bpm')) {
      context.handle(
        _avgHeartRateBpmMeta,
        avgHeartRateBpm.isAcceptableOrUnknown(
          data['avg_heart_rate_bpm']!,
          _avgHeartRateBpmMeta,
        ),
      );
    }
    if (data.containsKey('max_heart_rate_bpm')) {
      context.handle(
        _maxHeartRateBpmMeta,
        maxHeartRateBpm.isAcceptableOrUnknown(
          data['max_heart_rate_bpm']!,
          _maxHeartRateBpmMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      resortId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resort_id'],
      ),
      resortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resort_name'],
      ),
      lastFixAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_fix_at'],
      ),
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}engine_version'],
      )!,
      streamRestarts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stream_restarts'],
      )!,
      weatherJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather_json'],
      ),
      mapThumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}map_thumb_path'],
      ),
      trackedOnWatch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tracked_on_watch'],
      )!,
      elapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_ms'],
      )!,
      skiMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ski_ms'],
      )!,
      liftMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lift_ms'],
      )!,
      pauseMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pause_ms'],
      )!,
      signalLossMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}signal_loss_ms'],
      )!,
      otherMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}other_ms'],
      )!,
      runCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_count'],
      )!,
      liftCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lift_count'],
      )!,
      dropM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}drop_m'],
      )!,
      ascentM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ascent_m'],
      )!,
      skiDistanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ski_distance_m'],
      )!,
      liftDistanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lift_distance_m'],
      )!,
      totalDistanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_distance_m'],
      )!,
      maxSpeedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_speed_ms'],
      )!,
      avgSkiSpeedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_ski_speed_ms'],
      )!,
      maxAltM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_alt_m'],
      ),
      minAltM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_alt_m'],
      ),
      maxSpeedSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}max_speed_segment_id'],
      ),
      longestRunSegmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}longest_run_segment_id'],
      ),
      acceptedFixes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted_fixes'],
      )!,
      rejectedFixes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rejected_fixes'],
      )!,
      hasBarometer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_barometer'],
      )!,
      vehicleFlag: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vehicle_flag'],
      )!,
      avgHeartRateBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_heart_rate_bpm'],
      ),
      maxHeartRateBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_heart_rate_bpm'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DaysTable createAlias(String alias) {
    return $DaysTable(attachedDatabase, alias);
  }
}

class DayRow extends DataClass implements Insertable<DayRow> {
  final String id;
  final int startedAt;
  final int? endedAt;
  final String status;
  final String? resortId;
  final String? resortName;
  final int? lastFixAt;
  final int engineVersion;
  final int streamRestarts;
  final String? weatherJson;
  final String? mapThumbPath;
  final bool trackedOnWatch;
  final int elapsedMs;
  final int skiMs;
  final int liftMs;
  final int pauseMs;
  final int signalLossMs;
  final int otherMs;
  final int runCount;
  final int liftCount;
  final double dropM;
  final double ascentM;
  final double skiDistanceM;
  final double liftDistanceM;
  final double totalDistanceM;
  final double maxSpeedMs;
  final double avgSkiSpeedMs;
  final double? maxAltM;
  final double? minAltM;
  final String? maxSpeedSegmentId;
  final String? longestRunSegmentId;
  final int acceptedFixes;
  final int rejectedFixes;
  final bool hasBarometer;
  final bool vehicleFlag;
  final int? avgHeartRateBpm;
  final int? maxHeartRateBpm;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const DayRow({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.resortId,
    this.resortName,
    this.lastFixAt,
    required this.engineVersion,
    required this.streamRestarts,
    this.weatherJson,
    this.mapThumbPath,
    required this.trackedOnWatch,
    required this.elapsedMs,
    required this.skiMs,
    required this.liftMs,
    required this.pauseMs,
    required this.signalLossMs,
    required this.otherMs,
    required this.runCount,
    required this.liftCount,
    required this.dropM,
    required this.ascentM,
    required this.skiDistanceM,
    required this.liftDistanceM,
    required this.totalDistanceM,
    required this.maxSpeedMs,
    required this.avgSkiSpeedMs,
    this.maxAltM,
    this.minAltM,
    this.maxSpeedSegmentId,
    this.longestRunSegmentId,
    required this.acceptedFixes,
    required this.rejectedFixes,
    required this.hasBarometer,
    required this.vehicleFlag,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || resortId != null) {
      map['resort_id'] = Variable<String>(resortId);
    }
    if (!nullToAbsent || resortName != null) {
      map['resort_name'] = Variable<String>(resortName);
    }
    if (!nullToAbsent || lastFixAt != null) {
      map['last_fix_at'] = Variable<int>(lastFixAt);
    }
    map['engine_version'] = Variable<int>(engineVersion);
    map['stream_restarts'] = Variable<int>(streamRestarts);
    if (!nullToAbsent || weatherJson != null) {
      map['weather_json'] = Variable<String>(weatherJson);
    }
    if (!nullToAbsent || mapThumbPath != null) {
      map['map_thumb_path'] = Variable<String>(mapThumbPath);
    }
    map['tracked_on_watch'] = Variable<bool>(trackedOnWatch);
    map['elapsed_ms'] = Variable<int>(elapsedMs);
    map['ski_ms'] = Variable<int>(skiMs);
    map['lift_ms'] = Variable<int>(liftMs);
    map['pause_ms'] = Variable<int>(pauseMs);
    map['signal_loss_ms'] = Variable<int>(signalLossMs);
    map['other_ms'] = Variable<int>(otherMs);
    map['run_count'] = Variable<int>(runCount);
    map['lift_count'] = Variable<int>(liftCount);
    map['drop_m'] = Variable<double>(dropM);
    map['ascent_m'] = Variable<double>(ascentM);
    map['ski_distance_m'] = Variable<double>(skiDistanceM);
    map['lift_distance_m'] = Variable<double>(liftDistanceM);
    map['total_distance_m'] = Variable<double>(totalDistanceM);
    map['max_speed_ms'] = Variable<double>(maxSpeedMs);
    map['avg_ski_speed_ms'] = Variable<double>(avgSkiSpeedMs);
    if (!nullToAbsent || maxAltM != null) {
      map['max_alt_m'] = Variable<double>(maxAltM);
    }
    if (!nullToAbsent || minAltM != null) {
      map['min_alt_m'] = Variable<double>(minAltM);
    }
    if (!nullToAbsent || maxSpeedSegmentId != null) {
      map['max_speed_segment_id'] = Variable<String>(maxSpeedSegmentId);
    }
    if (!nullToAbsent || longestRunSegmentId != null) {
      map['longest_run_segment_id'] = Variable<String>(longestRunSegmentId);
    }
    map['accepted_fixes'] = Variable<int>(acceptedFixes);
    map['rejected_fixes'] = Variable<int>(rejectedFixes);
    map['has_barometer'] = Variable<bool>(hasBarometer);
    map['vehicle_flag'] = Variable<bool>(vehicleFlag);
    if (!nullToAbsent || avgHeartRateBpm != null) {
      map['avg_heart_rate_bpm'] = Variable<int>(avgHeartRateBpm);
    }
    if (!nullToAbsent || maxHeartRateBpm != null) {
      map['max_heart_rate_bpm'] = Variable<int>(maxHeartRateBpm);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  DaysCompanion toCompanion(bool nullToAbsent) {
    return DaysCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      status: Value(status),
      resortId: resortId == null && nullToAbsent
          ? const Value.absent()
          : Value(resortId),
      resortName: resortName == null && nullToAbsent
          ? const Value.absent()
          : Value(resortName),
      lastFixAt: lastFixAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFixAt),
      engineVersion: Value(engineVersion),
      streamRestarts: Value(streamRestarts),
      weatherJson: weatherJson == null && nullToAbsent
          ? const Value.absent()
          : Value(weatherJson),
      mapThumbPath: mapThumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(mapThumbPath),
      trackedOnWatch: Value(trackedOnWatch),
      elapsedMs: Value(elapsedMs),
      skiMs: Value(skiMs),
      liftMs: Value(liftMs),
      pauseMs: Value(pauseMs),
      signalLossMs: Value(signalLossMs),
      otherMs: Value(otherMs),
      runCount: Value(runCount),
      liftCount: Value(liftCount),
      dropM: Value(dropM),
      ascentM: Value(ascentM),
      skiDistanceM: Value(skiDistanceM),
      liftDistanceM: Value(liftDistanceM),
      totalDistanceM: Value(totalDistanceM),
      maxSpeedMs: Value(maxSpeedMs),
      avgSkiSpeedMs: Value(avgSkiSpeedMs),
      maxAltM: maxAltM == null && nullToAbsent
          ? const Value.absent()
          : Value(maxAltM),
      minAltM: minAltM == null && nullToAbsent
          ? const Value.absent()
          : Value(minAltM),
      maxSpeedSegmentId: maxSpeedSegmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(maxSpeedSegmentId),
      longestRunSegmentId: longestRunSegmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(longestRunSegmentId),
      acceptedFixes: Value(acceptedFixes),
      rejectedFixes: Value(rejectedFixes),
      hasBarometer: Value(hasBarometer),
      vehicleFlag: Value(vehicleFlag),
      avgHeartRateBpm: avgHeartRateBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(avgHeartRateBpm),
      maxHeartRateBpm: maxHeartRateBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(maxHeartRateBpm),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      status: serializer.fromJson<String>(json['status']),
      resortId: serializer.fromJson<String?>(json['resortId']),
      resortName: serializer.fromJson<String?>(json['resortName']),
      lastFixAt: serializer.fromJson<int?>(json['lastFixAt']),
      engineVersion: serializer.fromJson<int>(json['engineVersion']),
      streamRestarts: serializer.fromJson<int>(json['streamRestarts']),
      weatherJson: serializer.fromJson<String?>(json['weatherJson']),
      mapThumbPath: serializer.fromJson<String?>(json['mapThumbPath']),
      trackedOnWatch: serializer.fromJson<bool>(json['trackedOnWatch']),
      elapsedMs: serializer.fromJson<int>(json['elapsedMs']),
      skiMs: serializer.fromJson<int>(json['skiMs']),
      liftMs: serializer.fromJson<int>(json['liftMs']),
      pauseMs: serializer.fromJson<int>(json['pauseMs']),
      signalLossMs: serializer.fromJson<int>(json['signalLossMs']),
      otherMs: serializer.fromJson<int>(json['otherMs']),
      runCount: serializer.fromJson<int>(json['runCount']),
      liftCount: serializer.fromJson<int>(json['liftCount']),
      dropM: serializer.fromJson<double>(json['dropM']),
      ascentM: serializer.fromJson<double>(json['ascentM']),
      skiDistanceM: serializer.fromJson<double>(json['skiDistanceM']),
      liftDistanceM: serializer.fromJson<double>(json['liftDistanceM']),
      totalDistanceM: serializer.fromJson<double>(json['totalDistanceM']),
      maxSpeedMs: serializer.fromJson<double>(json['maxSpeedMs']),
      avgSkiSpeedMs: serializer.fromJson<double>(json['avgSkiSpeedMs']),
      maxAltM: serializer.fromJson<double?>(json['maxAltM']),
      minAltM: serializer.fromJson<double?>(json['minAltM']),
      maxSpeedSegmentId: serializer.fromJson<String?>(
        json['maxSpeedSegmentId'],
      ),
      longestRunSegmentId: serializer.fromJson<String?>(
        json['longestRunSegmentId'],
      ),
      acceptedFixes: serializer.fromJson<int>(json['acceptedFixes']),
      rejectedFixes: serializer.fromJson<int>(json['rejectedFixes']),
      hasBarometer: serializer.fromJson<bool>(json['hasBarometer']),
      vehicleFlag: serializer.fromJson<bool>(json['vehicleFlag']),
      avgHeartRateBpm: serializer.fromJson<int?>(json['avgHeartRateBpm']),
      maxHeartRateBpm: serializer.fromJson<int?>(json['maxHeartRateBpm']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'status': serializer.toJson<String>(status),
      'resortId': serializer.toJson<String?>(resortId),
      'resortName': serializer.toJson<String?>(resortName),
      'lastFixAt': serializer.toJson<int?>(lastFixAt),
      'engineVersion': serializer.toJson<int>(engineVersion),
      'streamRestarts': serializer.toJson<int>(streamRestarts),
      'weatherJson': serializer.toJson<String?>(weatherJson),
      'mapThumbPath': serializer.toJson<String?>(mapThumbPath),
      'trackedOnWatch': serializer.toJson<bool>(trackedOnWatch),
      'elapsedMs': serializer.toJson<int>(elapsedMs),
      'skiMs': serializer.toJson<int>(skiMs),
      'liftMs': serializer.toJson<int>(liftMs),
      'pauseMs': serializer.toJson<int>(pauseMs),
      'signalLossMs': serializer.toJson<int>(signalLossMs),
      'otherMs': serializer.toJson<int>(otherMs),
      'runCount': serializer.toJson<int>(runCount),
      'liftCount': serializer.toJson<int>(liftCount),
      'dropM': serializer.toJson<double>(dropM),
      'ascentM': serializer.toJson<double>(ascentM),
      'skiDistanceM': serializer.toJson<double>(skiDistanceM),
      'liftDistanceM': serializer.toJson<double>(liftDistanceM),
      'totalDistanceM': serializer.toJson<double>(totalDistanceM),
      'maxSpeedMs': serializer.toJson<double>(maxSpeedMs),
      'avgSkiSpeedMs': serializer.toJson<double>(avgSkiSpeedMs),
      'maxAltM': serializer.toJson<double?>(maxAltM),
      'minAltM': serializer.toJson<double?>(minAltM),
      'maxSpeedSegmentId': serializer.toJson<String?>(maxSpeedSegmentId),
      'longestRunSegmentId': serializer.toJson<String?>(longestRunSegmentId),
      'acceptedFixes': serializer.toJson<int>(acceptedFixes),
      'rejectedFixes': serializer.toJson<int>(rejectedFixes),
      'hasBarometer': serializer.toJson<bool>(hasBarometer),
      'vehicleFlag': serializer.toJson<bool>(vehicleFlag),
      'avgHeartRateBpm': serializer.toJson<int?>(avgHeartRateBpm),
      'maxHeartRateBpm': serializer.toJson<int?>(maxHeartRateBpm),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  DayRow copyWith({
    String? id,
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    String? status,
    Value<String?> resortId = const Value.absent(),
    Value<String?> resortName = const Value.absent(),
    Value<int?> lastFixAt = const Value.absent(),
    int? engineVersion,
    int? streamRestarts,
    Value<String?> weatherJson = const Value.absent(),
    Value<String?> mapThumbPath = const Value.absent(),
    bool? trackedOnWatch,
    int? elapsedMs,
    int? skiMs,
    int? liftMs,
    int? pauseMs,
    int? signalLossMs,
    int? otherMs,
    int? runCount,
    int? liftCount,
    double? dropM,
    double? ascentM,
    double? skiDistanceM,
    double? liftDistanceM,
    double? totalDistanceM,
    double? maxSpeedMs,
    double? avgSkiSpeedMs,
    Value<double?> maxAltM = const Value.absent(),
    Value<double?> minAltM = const Value.absent(),
    Value<String?> maxSpeedSegmentId = const Value.absent(),
    Value<String?> longestRunSegmentId = const Value.absent(),
    int? acceptedFixes,
    int? rejectedFixes,
    bool? hasBarometer,
    bool? vehicleFlag,
    Value<int?> avgHeartRateBpm = const Value.absent(),
    Value<int?> maxHeartRateBpm = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => DayRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    status: status ?? this.status,
    resortId: resortId.present ? resortId.value : this.resortId,
    resortName: resortName.present ? resortName.value : this.resortName,
    lastFixAt: lastFixAt.present ? lastFixAt.value : this.lastFixAt,
    engineVersion: engineVersion ?? this.engineVersion,
    streamRestarts: streamRestarts ?? this.streamRestarts,
    weatherJson: weatherJson.present ? weatherJson.value : this.weatherJson,
    mapThumbPath: mapThumbPath.present ? mapThumbPath.value : this.mapThumbPath,
    trackedOnWatch: trackedOnWatch ?? this.trackedOnWatch,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    skiMs: skiMs ?? this.skiMs,
    liftMs: liftMs ?? this.liftMs,
    pauseMs: pauseMs ?? this.pauseMs,
    signalLossMs: signalLossMs ?? this.signalLossMs,
    otherMs: otherMs ?? this.otherMs,
    runCount: runCount ?? this.runCount,
    liftCount: liftCount ?? this.liftCount,
    dropM: dropM ?? this.dropM,
    ascentM: ascentM ?? this.ascentM,
    skiDistanceM: skiDistanceM ?? this.skiDistanceM,
    liftDistanceM: liftDistanceM ?? this.liftDistanceM,
    totalDistanceM: totalDistanceM ?? this.totalDistanceM,
    maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
    avgSkiSpeedMs: avgSkiSpeedMs ?? this.avgSkiSpeedMs,
    maxAltM: maxAltM.present ? maxAltM.value : this.maxAltM,
    minAltM: minAltM.present ? minAltM.value : this.minAltM,
    maxSpeedSegmentId: maxSpeedSegmentId.present
        ? maxSpeedSegmentId.value
        : this.maxSpeedSegmentId,
    longestRunSegmentId: longestRunSegmentId.present
        ? longestRunSegmentId.value
        : this.longestRunSegmentId,
    acceptedFixes: acceptedFixes ?? this.acceptedFixes,
    rejectedFixes: rejectedFixes ?? this.rejectedFixes,
    hasBarometer: hasBarometer ?? this.hasBarometer,
    vehicleFlag: vehicleFlag ?? this.vehicleFlag,
    avgHeartRateBpm: avgHeartRateBpm.present
        ? avgHeartRateBpm.value
        : this.avgHeartRateBpm,
    maxHeartRateBpm: maxHeartRateBpm.present
        ? maxHeartRateBpm.value
        : this.maxHeartRateBpm,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DayRow copyWithCompanion(DaysCompanion data) {
    return DayRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      status: data.status.present ? data.status.value : this.status,
      resortId: data.resortId.present ? data.resortId.value : this.resortId,
      resortName: data.resortName.present
          ? data.resortName.value
          : this.resortName,
      lastFixAt: data.lastFixAt.present ? data.lastFixAt.value : this.lastFixAt,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      streamRestarts: data.streamRestarts.present
          ? data.streamRestarts.value
          : this.streamRestarts,
      weatherJson: data.weatherJson.present
          ? data.weatherJson.value
          : this.weatherJson,
      mapThumbPath: data.mapThumbPath.present
          ? data.mapThumbPath.value
          : this.mapThumbPath,
      trackedOnWatch: data.trackedOnWatch.present
          ? data.trackedOnWatch.value
          : this.trackedOnWatch,
      elapsedMs: data.elapsedMs.present ? data.elapsedMs.value : this.elapsedMs,
      skiMs: data.skiMs.present ? data.skiMs.value : this.skiMs,
      liftMs: data.liftMs.present ? data.liftMs.value : this.liftMs,
      pauseMs: data.pauseMs.present ? data.pauseMs.value : this.pauseMs,
      signalLossMs: data.signalLossMs.present
          ? data.signalLossMs.value
          : this.signalLossMs,
      otherMs: data.otherMs.present ? data.otherMs.value : this.otherMs,
      runCount: data.runCount.present ? data.runCount.value : this.runCount,
      liftCount: data.liftCount.present ? data.liftCount.value : this.liftCount,
      dropM: data.dropM.present ? data.dropM.value : this.dropM,
      ascentM: data.ascentM.present ? data.ascentM.value : this.ascentM,
      skiDistanceM: data.skiDistanceM.present
          ? data.skiDistanceM.value
          : this.skiDistanceM,
      liftDistanceM: data.liftDistanceM.present
          ? data.liftDistanceM.value
          : this.liftDistanceM,
      totalDistanceM: data.totalDistanceM.present
          ? data.totalDistanceM.value
          : this.totalDistanceM,
      maxSpeedMs: data.maxSpeedMs.present
          ? data.maxSpeedMs.value
          : this.maxSpeedMs,
      avgSkiSpeedMs: data.avgSkiSpeedMs.present
          ? data.avgSkiSpeedMs.value
          : this.avgSkiSpeedMs,
      maxAltM: data.maxAltM.present ? data.maxAltM.value : this.maxAltM,
      minAltM: data.minAltM.present ? data.minAltM.value : this.minAltM,
      maxSpeedSegmentId: data.maxSpeedSegmentId.present
          ? data.maxSpeedSegmentId.value
          : this.maxSpeedSegmentId,
      longestRunSegmentId: data.longestRunSegmentId.present
          ? data.longestRunSegmentId.value
          : this.longestRunSegmentId,
      acceptedFixes: data.acceptedFixes.present
          ? data.acceptedFixes.value
          : this.acceptedFixes,
      rejectedFixes: data.rejectedFixes.present
          ? data.rejectedFixes.value
          : this.rejectedFixes,
      hasBarometer: data.hasBarometer.present
          ? data.hasBarometer.value
          : this.hasBarometer,
      vehicleFlag: data.vehicleFlag.present
          ? data.vehicleFlag.value
          : this.vehicleFlag,
      avgHeartRateBpm: data.avgHeartRateBpm.present
          ? data.avgHeartRateBpm.value
          : this.avgHeartRateBpm,
      maxHeartRateBpm: data.maxHeartRateBpm.present
          ? data.maxHeartRateBpm.value
          : this.maxHeartRateBpm,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('resortId: $resortId, ')
          ..write('resortName: $resortName, ')
          ..write('lastFixAt: $lastFixAt, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('streamRestarts: $streamRestarts, ')
          ..write('weatherJson: $weatherJson, ')
          ..write('mapThumbPath: $mapThumbPath, ')
          ..write('trackedOnWatch: $trackedOnWatch, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('skiMs: $skiMs, ')
          ..write('liftMs: $liftMs, ')
          ..write('pauseMs: $pauseMs, ')
          ..write('signalLossMs: $signalLossMs, ')
          ..write('otherMs: $otherMs, ')
          ..write('runCount: $runCount, ')
          ..write('liftCount: $liftCount, ')
          ..write('dropM: $dropM, ')
          ..write('ascentM: $ascentM, ')
          ..write('skiDistanceM: $skiDistanceM, ')
          ..write('liftDistanceM: $liftDistanceM, ')
          ..write('totalDistanceM: $totalDistanceM, ')
          ..write('maxSpeedMs: $maxSpeedMs, ')
          ..write('avgSkiSpeedMs: $avgSkiSpeedMs, ')
          ..write('maxAltM: $maxAltM, ')
          ..write('minAltM: $minAltM, ')
          ..write('maxSpeedSegmentId: $maxSpeedSegmentId, ')
          ..write('longestRunSegmentId: $longestRunSegmentId, ')
          ..write('acceptedFixes: $acceptedFixes, ')
          ..write('rejectedFixes: $rejectedFixes, ')
          ..write('hasBarometer: $hasBarometer, ')
          ..write('vehicleFlag: $vehicleFlag, ')
          ..write('avgHeartRateBpm: $avgHeartRateBpm, ')
          ..write('maxHeartRateBpm: $maxHeartRateBpm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    startedAt,
    endedAt,
    status,
    resortId,
    resortName,
    lastFixAt,
    engineVersion,
    streamRestarts,
    weatherJson,
    mapThumbPath,
    trackedOnWatch,
    elapsedMs,
    skiMs,
    liftMs,
    pauseMs,
    signalLossMs,
    otherMs,
    runCount,
    liftCount,
    dropM,
    ascentM,
    skiDistanceM,
    liftDistanceM,
    totalDistanceM,
    maxSpeedMs,
    avgSkiSpeedMs,
    maxAltM,
    minAltM,
    maxSpeedSegmentId,
    longestRunSegmentId,
    acceptedFixes,
    rejectedFixes,
    hasBarometer,
    vehicleFlag,
    avgHeartRateBpm,
    maxHeartRateBpm,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.status == this.status &&
          other.resortId == this.resortId &&
          other.resortName == this.resortName &&
          other.lastFixAt == this.lastFixAt &&
          other.engineVersion == this.engineVersion &&
          other.streamRestarts == this.streamRestarts &&
          other.weatherJson == this.weatherJson &&
          other.mapThumbPath == this.mapThumbPath &&
          other.trackedOnWatch == this.trackedOnWatch &&
          other.elapsedMs == this.elapsedMs &&
          other.skiMs == this.skiMs &&
          other.liftMs == this.liftMs &&
          other.pauseMs == this.pauseMs &&
          other.signalLossMs == this.signalLossMs &&
          other.otherMs == this.otherMs &&
          other.runCount == this.runCount &&
          other.liftCount == this.liftCount &&
          other.dropM == this.dropM &&
          other.ascentM == this.ascentM &&
          other.skiDistanceM == this.skiDistanceM &&
          other.liftDistanceM == this.liftDistanceM &&
          other.totalDistanceM == this.totalDistanceM &&
          other.maxSpeedMs == this.maxSpeedMs &&
          other.avgSkiSpeedMs == this.avgSkiSpeedMs &&
          other.maxAltM == this.maxAltM &&
          other.minAltM == this.minAltM &&
          other.maxSpeedSegmentId == this.maxSpeedSegmentId &&
          other.longestRunSegmentId == this.longestRunSegmentId &&
          other.acceptedFixes == this.acceptedFixes &&
          other.rejectedFixes == this.rejectedFixes &&
          other.hasBarometer == this.hasBarometer &&
          other.vehicleFlag == this.vehicleFlag &&
          other.avgHeartRateBpm == this.avgHeartRateBpm &&
          other.maxHeartRateBpm == this.maxHeartRateBpm &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DaysCompanion extends UpdateCompanion<DayRow> {
  final Value<String> id;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<String> status;
  final Value<String?> resortId;
  final Value<String?> resortName;
  final Value<int?> lastFixAt;
  final Value<int> engineVersion;
  final Value<int> streamRestarts;
  final Value<String?> weatherJson;
  final Value<String?> mapThumbPath;
  final Value<bool> trackedOnWatch;
  final Value<int> elapsedMs;
  final Value<int> skiMs;
  final Value<int> liftMs;
  final Value<int> pauseMs;
  final Value<int> signalLossMs;
  final Value<int> otherMs;
  final Value<int> runCount;
  final Value<int> liftCount;
  final Value<double> dropM;
  final Value<double> ascentM;
  final Value<double> skiDistanceM;
  final Value<double> liftDistanceM;
  final Value<double> totalDistanceM;
  final Value<double> maxSpeedMs;
  final Value<double> avgSkiSpeedMs;
  final Value<double?> maxAltM;
  final Value<double?> minAltM;
  final Value<String?> maxSpeedSegmentId;
  final Value<String?> longestRunSegmentId;
  final Value<int> acceptedFixes;
  final Value<int> rejectedFixes;
  final Value<bool> hasBarometer;
  final Value<bool> vehicleFlag;
  final Value<int?> avgHeartRateBpm;
  final Value<int?> maxHeartRateBpm;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const DaysCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.resortId = const Value.absent(),
    this.resortName = const Value.absent(),
    this.lastFixAt = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.streamRestarts = const Value.absent(),
    this.weatherJson = const Value.absent(),
    this.mapThumbPath = const Value.absent(),
    this.trackedOnWatch = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.skiMs = const Value.absent(),
    this.liftMs = const Value.absent(),
    this.pauseMs = const Value.absent(),
    this.signalLossMs = const Value.absent(),
    this.otherMs = const Value.absent(),
    this.runCount = const Value.absent(),
    this.liftCount = const Value.absent(),
    this.dropM = const Value.absent(),
    this.ascentM = const Value.absent(),
    this.skiDistanceM = const Value.absent(),
    this.liftDistanceM = const Value.absent(),
    this.totalDistanceM = const Value.absent(),
    this.maxSpeedMs = const Value.absent(),
    this.avgSkiSpeedMs = const Value.absent(),
    this.maxAltM = const Value.absent(),
    this.minAltM = const Value.absent(),
    this.maxSpeedSegmentId = const Value.absent(),
    this.longestRunSegmentId = const Value.absent(),
    this.acceptedFixes = const Value.absent(),
    this.rejectedFixes = const Value.absent(),
    this.hasBarometer = const Value.absent(),
    this.vehicleFlag = const Value.absent(),
    this.avgHeartRateBpm = const Value.absent(),
    this.maxHeartRateBpm = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DaysCompanion.insert({
    required String id,
    required int startedAt,
    this.endedAt = const Value.absent(),
    required String status,
    this.resortId = const Value.absent(),
    this.resortName = const Value.absent(),
    this.lastFixAt = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.streamRestarts = const Value.absent(),
    this.weatherJson = const Value.absent(),
    this.mapThumbPath = const Value.absent(),
    this.trackedOnWatch = const Value.absent(),
    this.elapsedMs = const Value.absent(),
    this.skiMs = const Value.absent(),
    this.liftMs = const Value.absent(),
    this.pauseMs = const Value.absent(),
    this.signalLossMs = const Value.absent(),
    this.otherMs = const Value.absent(),
    this.runCount = const Value.absent(),
    this.liftCount = const Value.absent(),
    this.dropM = const Value.absent(),
    this.ascentM = const Value.absent(),
    this.skiDistanceM = const Value.absent(),
    this.liftDistanceM = const Value.absent(),
    this.totalDistanceM = const Value.absent(),
    this.maxSpeedMs = const Value.absent(),
    this.avgSkiSpeedMs = const Value.absent(),
    this.maxAltM = const Value.absent(),
    this.minAltM = const Value.absent(),
    this.maxSpeedSegmentId = const Value.absent(),
    this.longestRunSegmentId = const Value.absent(),
    this.acceptedFixes = const Value.absent(),
    this.rejectedFixes = const Value.absent(),
    this.hasBarometer = const Value.absent(),
    this.vehicleFlag = const Value.absent(),
    this.avgHeartRateBpm = const Value.absent(),
    this.maxHeartRateBpm = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DayRow> custom({
    Expression<String>? id,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? status,
    Expression<String>? resortId,
    Expression<String>? resortName,
    Expression<int>? lastFixAt,
    Expression<int>? engineVersion,
    Expression<int>? streamRestarts,
    Expression<String>? weatherJson,
    Expression<String>? mapThumbPath,
    Expression<bool>? trackedOnWatch,
    Expression<int>? elapsedMs,
    Expression<int>? skiMs,
    Expression<int>? liftMs,
    Expression<int>? pauseMs,
    Expression<int>? signalLossMs,
    Expression<int>? otherMs,
    Expression<int>? runCount,
    Expression<int>? liftCount,
    Expression<double>? dropM,
    Expression<double>? ascentM,
    Expression<double>? skiDistanceM,
    Expression<double>? liftDistanceM,
    Expression<double>? totalDistanceM,
    Expression<double>? maxSpeedMs,
    Expression<double>? avgSkiSpeedMs,
    Expression<double>? maxAltM,
    Expression<double>? minAltM,
    Expression<String>? maxSpeedSegmentId,
    Expression<String>? longestRunSegmentId,
    Expression<int>? acceptedFixes,
    Expression<int>? rejectedFixes,
    Expression<bool>? hasBarometer,
    Expression<bool>? vehicleFlag,
    Expression<int>? avgHeartRateBpm,
    Expression<int>? maxHeartRateBpm,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (status != null) 'status': status,
      if (resortId != null) 'resort_id': resortId,
      if (resortName != null) 'resort_name': resortName,
      if (lastFixAt != null) 'last_fix_at': lastFixAt,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (streamRestarts != null) 'stream_restarts': streamRestarts,
      if (weatherJson != null) 'weather_json': weatherJson,
      if (mapThumbPath != null) 'map_thumb_path': mapThumbPath,
      if (trackedOnWatch != null) 'tracked_on_watch': trackedOnWatch,
      if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      if (skiMs != null) 'ski_ms': skiMs,
      if (liftMs != null) 'lift_ms': liftMs,
      if (pauseMs != null) 'pause_ms': pauseMs,
      if (signalLossMs != null) 'signal_loss_ms': signalLossMs,
      if (otherMs != null) 'other_ms': otherMs,
      if (runCount != null) 'run_count': runCount,
      if (liftCount != null) 'lift_count': liftCount,
      if (dropM != null) 'drop_m': dropM,
      if (ascentM != null) 'ascent_m': ascentM,
      if (skiDistanceM != null) 'ski_distance_m': skiDistanceM,
      if (liftDistanceM != null) 'lift_distance_m': liftDistanceM,
      if (totalDistanceM != null) 'total_distance_m': totalDistanceM,
      if (maxSpeedMs != null) 'max_speed_ms': maxSpeedMs,
      if (avgSkiSpeedMs != null) 'avg_ski_speed_ms': avgSkiSpeedMs,
      if (maxAltM != null) 'max_alt_m': maxAltM,
      if (minAltM != null) 'min_alt_m': minAltM,
      if (maxSpeedSegmentId != null) 'max_speed_segment_id': maxSpeedSegmentId,
      if (longestRunSegmentId != null)
        'longest_run_segment_id': longestRunSegmentId,
      if (acceptedFixes != null) 'accepted_fixes': acceptedFixes,
      if (rejectedFixes != null) 'rejected_fixes': rejectedFixes,
      if (hasBarometer != null) 'has_barometer': hasBarometer,
      if (vehicleFlag != null) 'vehicle_flag': vehicleFlag,
      if (avgHeartRateBpm != null) 'avg_heart_rate_bpm': avgHeartRateBpm,
      if (maxHeartRateBpm != null) 'max_heart_rate_bpm': maxHeartRateBpm,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DaysCompanion copyWith({
    Value<String>? id,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<String>? status,
    Value<String?>? resortId,
    Value<String?>? resortName,
    Value<int?>? lastFixAt,
    Value<int>? engineVersion,
    Value<int>? streamRestarts,
    Value<String?>? weatherJson,
    Value<String?>? mapThumbPath,
    Value<bool>? trackedOnWatch,
    Value<int>? elapsedMs,
    Value<int>? skiMs,
    Value<int>? liftMs,
    Value<int>? pauseMs,
    Value<int>? signalLossMs,
    Value<int>? otherMs,
    Value<int>? runCount,
    Value<int>? liftCount,
    Value<double>? dropM,
    Value<double>? ascentM,
    Value<double>? skiDistanceM,
    Value<double>? liftDistanceM,
    Value<double>? totalDistanceM,
    Value<double>? maxSpeedMs,
    Value<double>? avgSkiSpeedMs,
    Value<double?>? maxAltM,
    Value<double?>? minAltM,
    Value<String?>? maxSpeedSegmentId,
    Value<String?>? longestRunSegmentId,
    Value<int>? acceptedFixes,
    Value<int>? rejectedFixes,
    Value<bool>? hasBarometer,
    Value<bool>? vehicleFlag,
    Value<int?>? avgHeartRateBpm,
    Value<int?>? maxHeartRateBpm,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DaysCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      resortId: resortId ?? this.resortId,
      resortName: resortName ?? this.resortName,
      lastFixAt: lastFixAt ?? this.lastFixAt,
      engineVersion: engineVersion ?? this.engineVersion,
      streamRestarts: streamRestarts ?? this.streamRestarts,
      weatherJson: weatherJson ?? this.weatherJson,
      mapThumbPath: mapThumbPath ?? this.mapThumbPath,
      trackedOnWatch: trackedOnWatch ?? this.trackedOnWatch,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      skiMs: skiMs ?? this.skiMs,
      liftMs: liftMs ?? this.liftMs,
      pauseMs: pauseMs ?? this.pauseMs,
      signalLossMs: signalLossMs ?? this.signalLossMs,
      otherMs: otherMs ?? this.otherMs,
      runCount: runCount ?? this.runCount,
      liftCount: liftCount ?? this.liftCount,
      dropM: dropM ?? this.dropM,
      ascentM: ascentM ?? this.ascentM,
      skiDistanceM: skiDistanceM ?? this.skiDistanceM,
      liftDistanceM: liftDistanceM ?? this.liftDistanceM,
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      avgSkiSpeedMs: avgSkiSpeedMs ?? this.avgSkiSpeedMs,
      maxAltM: maxAltM ?? this.maxAltM,
      minAltM: minAltM ?? this.minAltM,
      maxSpeedSegmentId: maxSpeedSegmentId ?? this.maxSpeedSegmentId,
      longestRunSegmentId: longestRunSegmentId ?? this.longestRunSegmentId,
      acceptedFixes: acceptedFixes ?? this.acceptedFixes,
      rejectedFixes: rejectedFixes ?? this.rejectedFixes,
      hasBarometer: hasBarometer ?? this.hasBarometer,
      vehicleFlag: vehicleFlag ?? this.vehicleFlag,
      avgHeartRateBpm: avgHeartRateBpm ?? this.avgHeartRateBpm,
      maxHeartRateBpm: maxHeartRateBpm ?? this.maxHeartRateBpm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (resortId.present) {
      map['resort_id'] = Variable<String>(resortId.value);
    }
    if (resortName.present) {
      map['resort_name'] = Variable<String>(resortName.value);
    }
    if (lastFixAt.present) {
      map['last_fix_at'] = Variable<int>(lastFixAt.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<int>(engineVersion.value);
    }
    if (streamRestarts.present) {
      map['stream_restarts'] = Variable<int>(streamRestarts.value);
    }
    if (weatherJson.present) {
      map['weather_json'] = Variable<String>(weatherJson.value);
    }
    if (mapThumbPath.present) {
      map['map_thumb_path'] = Variable<String>(mapThumbPath.value);
    }
    if (trackedOnWatch.present) {
      map['tracked_on_watch'] = Variable<bool>(trackedOnWatch.value);
    }
    if (elapsedMs.present) {
      map['elapsed_ms'] = Variable<int>(elapsedMs.value);
    }
    if (skiMs.present) {
      map['ski_ms'] = Variable<int>(skiMs.value);
    }
    if (liftMs.present) {
      map['lift_ms'] = Variable<int>(liftMs.value);
    }
    if (pauseMs.present) {
      map['pause_ms'] = Variable<int>(pauseMs.value);
    }
    if (signalLossMs.present) {
      map['signal_loss_ms'] = Variable<int>(signalLossMs.value);
    }
    if (otherMs.present) {
      map['other_ms'] = Variable<int>(otherMs.value);
    }
    if (runCount.present) {
      map['run_count'] = Variable<int>(runCount.value);
    }
    if (liftCount.present) {
      map['lift_count'] = Variable<int>(liftCount.value);
    }
    if (dropM.present) {
      map['drop_m'] = Variable<double>(dropM.value);
    }
    if (ascentM.present) {
      map['ascent_m'] = Variable<double>(ascentM.value);
    }
    if (skiDistanceM.present) {
      map['ski_distance_m'] = Variable<double>(skiDistanceM.value);
    }
    if (liftDistanceM.present) {
      map['lift_distance_m'] = Variable<double>(liftDistanceM.value);
    }
    if (totalDistanceM.present) {
      map['total_distance_m'] = Variable<double>(totalDistanceM.value);
    }
    if (maxSpeedMs.present) {
      map['max_speed_ms'] = Variable<double>(maxSpeedMs.value);
    }
    if (avgSkiSpeedMs.present) {
      map['avg_ski_speed_ms'] = Variable<double>(avgSkiSpeedMs.value);
    }
    if (maxAltM.present) {
      map['max_alt_m'] = Variable<double>(maxAltM.value);
    }
    if (minAltM.present) {
      map['min_alt_m'] = Variable<double>(minAltM.value);
    }
    if (maxSpeedSegmentId.present) {
      map['max_speed_segment_id'] = Variable<String>(maxSpeedSegmentId.value);
    }
    if (longestRunSegmentId.present) {
      map['longest_run_segment_id'] = Variable<String>(
        longestRunSegmentId.value,
      );
    }
    if (acceptedFixes.present) {
      map['accepted_fixes'] = Variable<int>(acceptedFixes.value);
    }
    if (rejectedFixes.present) {
      map['rejected_fixes'] = Variable<int>(rejectedFixes.value);
    }
    if (hasBarometer.present) {
      map['has_barometer'] = Variable<bool>(hasBarometer.value);
    }
    if (vehicleFlag.present) {
      map['vehicle_flag'] = Variable<bool>(vehicleFlag.value);
    }
    if (avgHeartRateBpm.present) {
      map['avg_heart_rate_bpm'] = Variable<int>(avgHeartRateBpm.value);
    }
    if (maxHeartRateBpm.present) {
      map['max_heart_rate_bpm'] = Variable<int>(maxHeartRateBpm.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaysCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('resortId: $resortId, ')
          ..write('resortName: $resortName, ')
          ..write('lastFixAt: $lastFixAt, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('streamRestarts: $streamRestarts, ')
          ..write('weatherJson: $weatherJson, ')
          ..write('mapThumbPath: $mapThumbPath, ')
          ..write('trackedOnWatch: $trackedOnWatch, ')
          ..write('elapsedMs: $elapsedMs, ')
          ..write('skiMs: $skiMs, ')
          ..write('liftMs: $liftMs, ')
          ..write('pauseMs: $pauseMs, ')
          ..write('signalLossMs: $signalLossMs, ')
          ..write('otherMs: $otherMs, ')
          ..write('runCount: $runCount, ')
          ..write('liftCount: $liftCount, ')
          ..write('dropM: $dropM, ')
          ..write('ascentM: $ascentM, ')
          ..write('skiDistanceM: $skiDistanceM, ')
          ..write('liftDistanceM: $liftDistanceM, ')
          ..write('totalDistanceM: $totalDistanceM, ')
          ..write('maxSpeedMs: $maxSpeedMs, ')
          ..write('avgSkiSpeedMs: $avgSkiSpeedMs, ')
          ..write('maxAltM: $maxAltM, ')
          ..write('minAltM: $minAltM, ')
          ..write('maxSpeedSegmentId: $maxSpeedSegmentId, ')
          ..write('longestRunSegmentId: $longestRunSegmentId, ')
          ..write('acceptedFixes: $acceptedFixes, ')
          ..write('rejectedFixes: $rejectedFixes, ')
          ..write('hasBarometer: $hasBarometer, ')
          ..write('vehicleFlag: $vehicleFlag, ')
          ..write('avgHeartRateBpm: $avgHeartRateBpm, ')
          ..write('maxHeartRateBpm: $maxHeartRateBpm, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SegmentsTable extends Segments
    with TableInfo<$SegmentsTable, SegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idxMeta = const VerificationMeta('idx');
  @override
  late final GeneratedColumn<int> idx = GeneratedColumn<int>(
    'idx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runNumberMeta = const VerificationMeta(
    'runNumber',
  );
  @override
  late final GeneratedColumn<int> runNumber = GeneratedColumn<int>(
    'run_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTsMeta = const VerificationMeta(
    'startTs',
  );
  @override
  late final GeneratedColumn<int> startTs = GeneratedColumn<int>(
    'start_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTsMeta = const VerificationMeta('endTs');
  @override
  late final GeneratedColumn<int> endTs = GeneratedColumn<int>(
    'end_ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAltMMeta = const VerificationMeta(
    'startAltM',
  );
  @override
  late final GeneratedColumn<double> startAltM = GeneratedColumn<double>(
    'start_alt_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _endAltMMeta = const VerificationMeta(
    'endAltM',
  );
  @override
  late final GeneratedColumn<double> endAltM = GeneratedColumn<double>(
    'end_alt_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dropMMeta = const VerificationMeta('dropM');
  @override
  late final GeneratedColumn<double> dropM = GeneratedColumn<double>(
    'drop_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _movingMsMeta = const VerificationMeta(
    'movingMs',
  );
  @override
  late final GeneratedColumn<int> movingMs = GeneratedColumn<int>(
    'moving_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxSpeedMsMeta = const VerificationMeta(
    'maxSpeedMs',
  );
  @override
  late final GeneratedColumn<double> maxSpeedMs = GeneratedColumn<double>(
    'max_speed_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxSpeedAtTsMeta = const VerificationMeta(
    'maxSpeedAtTs',
  );
  @override
  late final GeneratedColumn<int> maxSpeedAtTs = GeneratedColumn<int>(
    'max_speed_at_ts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgSpeedMsMeta = const VerificationMeta(
    'avgSpeedMs',
  );
  @override
  late final GeneratedColumn<double> avgSpeedMs = GeneratedColumn<double>(
    'avg_speed_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgGradientPctMeta = const VerificationMeta(
    'avgGradientPct',
  );
  @override
  late final GeneratedColumn<double> avgGradientPct = GeneratedColumn<double>(
    'avg_gradient_pct',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _steepest100mPctMeta = const VerificationMeta(
    'steepest100mPct',
  );
  @override
  late final GeneratedColumn<double> steepest100mPct = GeneratedColumn<double>(
    'steepest100m_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startPointTsMeta = const VerificationMeta(
    'startPointTs',
  );
  @override
  late final GeneratedColumn<int> startPointTs = GeneratedColumn<int>(
    'start_point_ts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endPointTsMeta = const VerificationMeta(
    'endPointTs',
  );
  @override
  late final GeneratedColumn<int> endPointTs = GeneratedColumn<int>(
    'end_point_ts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flagsMeta = const VerificationMeta('flags');
  @override
  late final GeneratedColumn<int> flags = GeneratedColumn<int>(
    'flags',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pisteNameMeta = const VerificationMeta(
    'pisteName',
  );
  @override
  late final GeneratedColumn<String> pisteName = GeneratedColumn<String>(
    'piste_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pisteOsmIdMeta = const VerificationMeta(
    'pisteOsmId',
  );
  @override
  late final GeneratedColumn<String> pisteOsmId = GeneratedColumn<String>(
    'piste_osm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _liftNameMeta = const VerificationMeta(
    'liftName',
  );
  @override
  late final GeneratedColumn<String> liftName = GeneratedColumn<String>(
    'lift_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayId,
    kind,
    idx,
    runNumber,
    startTs,
    endTs,
    startAltM,
    endAltM,
    dropM,
    distanceM,
    movingMs,
    maxSpeedMs,
    maxSpeedAtTs,
    avgSpeedMs,
    avgGradientPct,
    steepest100mPct,
    startPointTs,
    endPointTs,
    flags,
    pisteName,
    pisteOsmId,
    liftName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('idx')) {
      context.handle(
        _idxMeta,
        idx.isAcceptableOrUnknown(data['idx']!, _idxMeta),
      );
    } else if (isInserting) {
      context.missing(_idxMeta);
    }
    if (data.containsKey('run_number')) {
      context.handle(
        _runNumberMeta,
        runNumber.isAcceptableOrUnknown(data['run_number']!, _runNumberMeta),
      );
    }
    if (data.containsKey('start_ts')) {
      context.handle(
        _startTsMeta,
        startTs.isAcceptableOrUnknown(data['start_ts']!, _startTsMeta),
      );
    } else if (isInserting) {
      context.missing(_startTsMeta);
    }
    if (data.containsKey('end_ts')) {
      context.handle(
        _endTsMeta,
        endTs.isAcceptableOrUnknown(data['end_ts']!, _endTsMeta),
      );
    } else if (isInserting) {
      context.missing(_endTsMeta);
    }
    if (data.containsKey('start_alt_m')) {
      context.handle(
        _startAltMMeta,
        startAltM.isAcceptableOrUnknown(data['start_alt_m']!, _startAltMMeta),
      );
    }
    if (data.containsKey('end_alt_m')) {
      context.handle(
        _endAltMMeta,
        endAltM.isAcceptableOrUnknown(data['end_alt_m']!, _endAltMMeta),
      );
    }
    if (data.containsKey('drop_m')) {
      context.handle(
        _dropMMeta,
        dropM.isAcceptableOrUnknown(data['drop_m']!, _dropMMeta),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('moving_ms')) {
      context.handle(
        _movingMsMeta,
        movingMs.isAcceptableOrUnknown(data['moving_ms']!, _movingMsMeta),
      );
    }
    if (data.containsKey('max_speed_ms')) {
      context.handle(
        _maxSpeedMsMeta,
        maxSpeedMs.isAcceptableOrUnknown(
          data['max_speed_ms']!,
          _maxSpeedMsMeta,
        ),
      );
    }
    if (data.containsKey('max_speed_at_ts')) {
      context.handle(
        _maxSpeedAtTsMeta,
        maxSpeedAtTs.isAcceptableOrUnknown(
          data['max_speed_at_ts']!,
          _maxSpeedAtTsMeta,
        ),
      );
    }
    if (data.containsKey('avg_speed_ms')) {
      context.handle(
        _avgSpeedMsMeta,
        avgSpeedMs.isAcceptableOrUnknown(
          data['avg_speed_ms']!,
          _avgSpeedMsMeta,
        ),
      );
    }
    if (data.containsKey('avg_gradient_pct')) {
      context.handle(
        _avgGradientPctMeta,
        avgGradientPct.isAcceptableOrUnknown(
          data['avg_gradient_pct']!,
          _avgGradientPctMeta,
        ),
      );
    }
    if (data.containsKey('steepest100m_pct')) {
      context.handle(
        _steepest100mPctMeta,
        steepest100mPct.isAcceptableOrUnknown(
          data['steepest100m_pct']!,
          _steepest100mPctMeta,
        ),
      );
    }
    if (data.containsKey('start_point_ts')) {
      context.handle(
        _startPointTsMeta,
        startPointTs.isAcceptableOrUnknown(
          data['start_point_ts']!,
          _startPointTsMeta,
        ),
      );
    }
    if (data.containsKey('end_point_ts')) {
      context.handle(
        _endPointTsMeta,
        endPointTs.isAcceptableOrUnknown(
          data['end_point_ts']!,
          _endPointTsMeta,
        ),
      );
    }
    if (data.containsKey('flags')) {
      context.handle(
        _flagsMeta,
        flags.isAcceptableOrUnknown(data['flags']!, _flagsMeta),
      );
    }
    if (data.containsKey('piste_name')) {
      context.handle(
        _pisteNameMeta,
        pisteName.isAcceptableOrUnknown(data['piste_name']!, _pisteNameMeta),
      );
    }
    if (data.containsKey('piste_osm_id')) {
      context.handle(
        _pisteOsmIdMeta,
        pisteOsmId.isAcceptableOrUnknown(
          data['piste_osm_id']!,
          _pisteOsmIdMeta,
        ),
      );
    }
    if (data.containsKey('lift_name')) {
      context.handle(
        _liftNameMeta,
        liftName.isAcceptableOrUnknown(data['lift_name']!, _liftNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      idx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}idx'],
      )!,
      runNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_number'],
      ),
      startTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ts'],
      )!,
      endTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ts'],
      )!,
      startAltM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_alt_m'],
      )!,
      endAltM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_alt_m'],
      )!,
      dropM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}drop_m'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      )!,
      movingMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}moving_ms'],
      )!,
      maxSpeedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_speed_ms'],
      )!,
      maxSpeedAtTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_speed_at_ts'],
      ),
      avgSpeedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_speed_ms'],
      )!,
      avgGradientPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_gradient_pct'],
      )!,
      steepest100mPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}steepest100m_pct'],
      ),
      startPointTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_point_ts'],
      ),
      endPointTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_point_ts'],
      ),
      flags: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flags'],
      )!,
      pisteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piste_name'],
      ),
      pisteOsmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}piste_osm_id'],
      ),
      liftName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lift_name'],
      ),
    );
  }

  @override
  $SegmentsTable createAlias(String alias) {
    return $SegmentsTable(attachedDatabase, alias);
  }
}

class SegmentRow extends DataClass implements Insertable<SegmentRow> {
  final String id;
  final String dayId;
  final String kind;
  final int idx;
  final int? runNumber;
  final int startTs;
  final int endTs;
  final double startAltM;
  final double endAltM;
  final double dropM;
  final double distanceM;
  final int movingMs;
  final double maxSpeedMs;
  final int? maxSpeedAtTs;
  final double avgSpeedMs;
  final double avgGradientPct;
  final double? steepest100mPct;
  final int? startPointTs;
  final int? endPointTs;
  final int flags;
  final String? pisteName;
  final String? pisteOsmId;
  final String? liftName;
  const SegmentRow({
    required this.id,
    required this.dayId,
    required this.kind,
    required this.idx,
    this.runNumber,
    required this.startTs,
    required this.endTs,
    required this.startAltM,
    required this.endAltM,
    required this.dropM,
    required this.distanceM,
    required this.movingMs,
    required this.maxSpeedMs,
    this.maxSpeedAtTs,
    required this.avgSpeedMs,
    required this.avgGradientPct,
    this.steepest100mPct,
    this.startPointTs,
    this.endPointTs,
    required this.flags,
    this.pisteName,
    this.pisteOsmId,
    this.liftName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day_id'] = Variable<String>(dayId);
    map['kind'] = Variable<String>(kind);
    map['idx'] = Variable<int>(idx);
    if (!nullToAbsent || runNumber != null) {
      map['run_number'] = Variable<int>(runNumber);
    }
    map['start_ts'] = Variable<int>(startTs);
    map['end_ts'] = Variable<int>(endTs);
    map['start_alt_m'] = Variable<double>(startAltM);
    map['end_alt_m'] = Variable<double>(endAltM);
    map['drop_m'] = Variable<double>(dropM);
    map['distance_m'] = Variable<double>(distanceM);
    map['moving_ms'] = Variable<int>(movingMs);
    map['max_speed_ms'] = Variable<double>(maxSpeedMs);
    if (!nullToAbsent || maxSpeedAtTs != null) {
      map['max_speed_at_ts'] = Variable<int>(maxSpeedAtTs);
    }
    map['avg_speed_ms'] = Variable<double>(avgSpeedMs);
    map['avg_gradient_pct'] = Variable<double>(avgGradientPct);
    if (!nullToAbsent || steepest100mPct != null) {
      map['steepest100m_pct'] = Variable<double>(steepest100mPct);
    }
    if (!nullToAbsent || startPointTs != null) {
      map['start_point_ts'] = Variable<int>(startPointTs);
    }
    if (!nullToAbsent || endPointTs != null) {
      map['end_point_ts'] = Variable<int>(endPointTs);
    }
    map['flags'] = Variable<int>(flags);
    if (!nullToAbsent || pisteName != null) {
      map['piste_name'] = Variable<String>(pisteName);
    }
    if (!nullToAbsent || pisteOsmId != null) {
      map['piste_osm_id'] = Variable<String>(pisteOsmId);
    }
    if (!nullToAbsent || liftName != null) {
      map['lift_name'] = Variable<String>(liftName);
    }
    return map;
  }

  SegmentsCompanion toCompanion(bool nullToAbsent) {
    return SegmentsCompanion(
      id: Value(id),
      dayId: Value(dayId),
      kind: Value(kind),
      idx: Value(idx),
      runNumber: runNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(runNumber),
      startTs: Value(startTs),
      endTs: Value(endTs),
      startAltM: Value(startAltM),
      endAltM: Value(endAltM),
      dropM: Value(dropM),
      distanceM: Value(distanceM),
      movingMs: Value(movingMs),
      maxSpeedMs: Value(maxSpeedMs),
      maxSpeedAtTs: maxSpeedAtTs == null && nullToAbsent
          ? const Value.absent()
          : Value(maxSpeedAtTs),
      avgSpeedMs: Value(avgSpeedMs),
      avgGradientPct: Value(avgGradientPct),
      steepest100mPct: steepest100mPct == null && nullToAbsent
          ? const Value.absent()
          : Value(steepest100mPct),
      startPointTs: startPointTs == null && nullToAbsent
          ? const Value.absent()
          : Value(startPointTs),
      endPointTs: endPointTs == null && nullToAbsent
          ? const Value.absent()
          : Value(endPointTs),
      flags: Value(flags),
      pisteName: pisteName == null && nullToAbsent
          ? const Value.absent()
          : Value(pisteName),
      pisteOsmId: pisteOsmId == null && nullToAbsent
          ? const Value.absent()
          : Value(pisteOsmId),
      liftName: liftName == null && nullToAbsent
          ? const Value.absent()
          : Value(liftName),
    );
  }

  factory SegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SegmentRow(
      id: serializer.fromJson<String>(json['id']),
      dayId: serializer.fromJson<String>(json['dayId']),
      kind: serializer.fromJson<String>(json['kind']),
      idx: serializer.fromJson<int>(json['idx']),
      runNumber: serializer.fromJson<int?>(json['runNumber']),
      startTs: serializer.fromJson<int>(json['startTs']),
      endTs: serializer.fromJson<int>(json['endTs']),
      startAltM: serializer.fromJson<double>(json['startAltM']),
      endAltM: serializer.fromJson<double>(json['endAltM']),
      dropM: serializer.fromJson<double>(json['dropM']),
      distanceM: serializer.fromJson<double>(json['distanceM']),
      movingMs: serializer.fromJson<int>(json['movingMs']),
      maxSpeedMs: serializer.fromJson<double>(json['maxSpeedMs']),
      maxSpeedAtTs: serializer.fromJson<int?>(json['maxSpeedAtTs']),
      avgSpeedMs: serializer.fromJson<double>(json['avgSpeedMs']),
      avgGradientPct: serializer.fromJson<double>(json['avgGradientPct']),
      steepest100mPct: serializer.fromJson<double?>(json['steepest100mPct']),
      startPointTs: serializer.fromJson<int?>(json['startPointTs']),
      endPointTs: serializer.fromJson<int?>(json['endPointTs']),
      flags: serializer.fromJson<int>(json['flags']),
      pisteName: serializer.fromJson<String?>(json['pisteName']),
      pisteOsmId: serializer.fromJson<String?>(json['pisteOsmId']),
      liftName: serializer.fromJson<String?>(json['liftName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dayId': serializer.toJson<String>(dayId),
      'kind': serializer.toJson<String>(kind),
      'idx': serializer.toJson<int>(idx),
      'runNumber': serializer.toJson<int?>(runNumber),
      'startTs': serializer.toJson<int>(startTs),
      'endTs': serializer.toJson<int>(endTs),
      'startAltM': serializer.toJson<double>(startAltM),
      'endAltM': serializer.toJson<double>(endAltM),
      'dropM': serializer.toJson<double>(dropM),
      'distanceM': serializer.toJson<double>(distanceM),
      'movingMs': serializer.toJson<int>(movingMs),
      'maxSpeedMs': serializer.toJson<double>(maxSpeedMs),
      'maxSpeedAtTs': serializer.toJson<int?>(maxSpeedAtTs),
      'avgSpeedMs': serializer.toJson<double>(avgSpeedMs),
      'avgGradientPct': serializer.toJson<double>(avgGradientPct),
      'steepest100mPct': serializer.toJson<double?>(steepest100mPct),
      'startPointTs': serializer.toJson<int?>(startPointTs),
      'endPointTs': serializer.toJson<int?>(endPointTs),
      'flags': serializer.toJson<int>(flags),
      'pisteName': serializer.toJson<String?>(pisteName),
      'pisteOsmId': serializer.toJson<String?>(pisteOsmId),
      'liftName': serializer.toJson<String?>(liftName),
    };
  }

  SegmentRow copyWith({
    String? id,
    String? dayId,
    String? kind,
    int? idx,
    Value<int?> runNumber = const Value.absent(),
    int? startTs,
    int? endTs,
    double? startAltM,
    double? endAltM,
    double? dropM,
    double? distanceM,
    int? movingMs,
    double? maxSpeedMs,
    Value<int?> maxSpeedAtTs = const Value.absent(),
    double? avgSpeedMs,
    double? avgGradientPct,
    Value<double?> steepest100mPct = const Value.absent(),
    Value<int?> startPointTs = const Value.absent(),
    Value<int?> endPointTs = const Value.absent(),
    int? flags,
    Value<String?> pisteName = const Value.absent(),
    Value<String?> pisteOsmId = const Value.absent(),
    Value<String?> liftName = const Value.absent(),
  }) => SegmentRow(
    id: id ?? this.id,
    dayId: dayId ?? this.dayId,
    kind: kind ?? this.kind,
    idx: idx ?? this.idx,
    runNumber: runNumber.present ? runNumber.value : this.runNumber,
    startTs: startTs ?? this.startTs,
    endTs: endTs ?? this.endTs,
    startAltM: startAltM ?? this.startAltM,
    endAltM: endAltM ?? this.endAltM,
    dropM: dropM ?? this.dropM,
    distanceM: distanceM ?? this.distanceM,
    movingMs: movingMs ?? this.movingMs,
    maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
    maxSpeedAtTs: maxSpeedAtTs.present ? maxSpeedAtTs.value : this.maxSpeedAtTs,
    avgSpeedMs: avgSpeedMs ?? this.avgSpeedMs,
    avgGradientPct: avgGradientPct ?? this.avgGradientPct,
    steepest100mPct: steepest100mPct.present
        ? steepest100mPct.value
        : this.steepest100mPct,
    startPointTs: startPointTs.present ? startPointTs.value : this.startPointTs,
    endPointTs: endPointTs.present ? endPointTs.value : this.endPointTs,
    flags: flags ?? this.flags,
    pisteName: pisteName.present ? pisteName.value : this.pisteName,
    pisteOsmId: pisteOsmId.present ? pisteOsmId.value : this.pisteOsmId,
    liftName: liftName.present ? liftName.value : this.liftName,
  );
  SegmentRow copyWithCompanion(SegmentsCompanion data) {
    return SegmentRow(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      kind: data.kind.present ? data.kind.value : this.kind,
      idx: data.idx.present ? data.idx.value : this.idx,
      runNumber: data.runNumber.present ? data.runNumber.value : this.runNumber,
      startTs: data.startTs.present ? data.startTs.value : this.startTs,
      endTs: data.endTs.present ? data.endTs.value : this.endTs,
      startAltM: data.startAltM.present ? data.startAltM.value : this.startAltM,
      endAltM: data.endAltM.present ? data.endAltM.value : this.endAltM,
      dropM: data.dropM.present ? data.dropM.value : this.dropM,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      movingMs: data.movingMs.present ? data.movingMs.value : this.movingMs,
      maxSpeedMs: data.maxSpeedMs.present
          ? data.maxSpeedMs.value
          : this.maxSpeedMs,
      maxSpeedAtTs: data.maxSpeedAtTs.present
          ? data.maxSpeedAtTs.value
          : this.maxSpeedAtTs,
      avgSpeedMs: data.avgSpeedMs.present
          ? data.avgSpeedMs.value
          : this.avgSpeedMs,
      avgGradientPct: data.avgGradientPct.present
          ? data.avgGradientPct.value
          : this.avgGradientPct,
      steepest100mPct: data.steepest100mPct.present
          ? data.steepest100mPct.value
          : this.steepest100mPct,
      startPointTs: data.startPointTs.present
          ? data.startPointTs.value
          : this.startPointTs,
      endPointTs: data.endPointTs.present
          ? data.endPointTs.value
          : this.endPointTs,
      flags: data.flags.present ? data.flags.value : this.flags,
      pisteName: data.pisteName.present ? data.pisteName.value : this.pisteName,
      pisteOsmId: data.pisteOsmId.present
          ? data.pisteOsmId.value
          : this.pisteOsmId,
      liftName: data.liftName.present ? data.liftName.value : this.liftName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SegmentRow(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('kind: $kind, ')
          ..write('idx: $idx, ')
          ..write('runNumber: $runNumber, ')
          ..write('startTs: $startTs, ')
          ..write('endTs: $endTs, ')
          ..write('startAltM: $startAltM, ')
          ..write('endAltM: $endAltM, ')
          ..write('dropM: $dropM, ')
          ..write('distanceM: $distanceM, ')
          ..write('movingMs: $movingMs, ')
          ..write('maxSpeedMs: $maxSpeedMs, ')
          ..write('maxSpeedAtTs: $maxSpeedAtTs, ')
          ..write('avgSpeedMs: $avgSpeedMs, ')
          ..write('avgGradientPct: $avgGradientPct, ')
          ..write('steepest100mPct: $steepest100mPct, ')
          ..write('startPointTs: $startPointTs, ')
          ..write('endPointTs: $endPointTs, ')
          ..write('flags: $flags, ')
          ..write('pisteName: $pisteName, ')
          ..write('pisteOsmId: $pisteOsmId, ')
          ..write('liftName: $liftName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    dayId,
    kind,
    idx,
    runNumber,
    startTs,
    endTs,
    startAltM,
    endAltM,
    dropM,
    distanceM,
    movingMs,
    maxSpeedMs,
    maxSpeedAtTs,
    avgSpeedMs,
    avgGradientPct,
    steepest100mPct,
    startPointTs,
    endPointTs,
    flags,
    pisteName,
    pisteOsmId,
    liftName,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SegmentRow &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.kind == this.kind &&
          other.idx == this.idx &&
          other.runNumber == this.runNumber &&
          other.startTs == this.startTs &&
          other.endTs == this.endTs &&
          other.startAltM == this.startAltM &&
          other.endAltM == this.endAltM &&
          other.dropM == this.dropM &&
          other.distanceM == this.distanceM &&
          other.movingMs == this.movingMs &&
          other.maxSpeedMs == this.maxSpeedMs &&
          other.maxSpeedAtTs == this.maxSpeedAtTs &&
          other.avgSpeedMs == this.avgSpeedMs &&
          other.avgGradientPct == this.avgGradientPct &&
          other.steepest100mPct == this.steepest100mPct &&
          other.startPointTs == this.startPointTs &&
          other.endPointTs == this.endPointTs &&
          other.flags == this.flags &&
          other.pisteName == this.pisteName &&
          other.pisteOsmId == this.pisteOsmId &&
          other.liftName == this.liftName);
}

class SegmentsCompanion extends UpdateCompanion<SegmentRow> {
  final Value<String> id;
  final Value<String> dayId;
  final Value<String> kind;
  final Value<int> idx;
  final Value<int?> runNumber;
  final Value<int> startTs;
  final Value<int> endTs;
  final Value<double> startAltM;
  final Value<double> endAltM;
  final Value<double> dropM;
  final Value<double> distanceM;
  final Value<int> movingMs;
  final Value<double> maxSpeedMs;
  final Value<int?> maxSpeedAtTs;
  final Value<double> avgSpeedMs;
  final Value<double> avgGradientPct;
  final Value<double?> steepest100mPct;
  final Value<int?> startPointTs;
  final Value<int?> endPointTs;
  final Value<int> flags;
  final Value<String?> pisteName;
  final Value<String?> pisteOsmId;
  final Value<String?> liftName;
  final Value<int> rowid;
  const SegmentsCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.kind = const Value.absent(),
    this.idx = const Value.absent(),
    this.runNumber = const Value.absent(),
    this.startTs = const Value.absent(),
    this.endTs = const Value.absent(),
    this.startAltM = const Value.absent(),
    this.endAltM = const Value.absent(),
    this.dropM = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.movingMs = const Value.absent(),
    this.maxSpeedMs = const Value.absent(),
    this.maxSpeedAtTs = const Value.absent(),
    this.avgSpeedMs = const Value.absent(),
    this.avgGradientPct = const Value.absent(),
    this.steepest100mPct = const Value.absent(),
    this.startPointTs = const Value.absent(),
    this.endPointTs = const Value.absent(),
    this.flags = const Value.absent(),
    this.pisteName = const Value.absent(),
    this.pisteOsmId = const Value.absent(),
    this.liftName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SegmentsCompanion.insert({
    required String id,
    required String dayId,
    required String kind,
    required int idx,
    this.runNumber = const Value.absent(),
    required int startTs,
    required int endTs,
    this.startAltM = const Value.absent(),
    this.endAltM = const Value.absent(),
    this.dropM = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.movingMs = const Value.absent(),
    this.maxSpeedMs = const Value.absent(),
    this.maxSpeedAtTs = const Value.absent(),
    this.avgSpeedMs = const Value.absent(),
    this.avgGradientPct = const Value.absent(),
    this.steepest100mPct = const Value.absent(),
    this.startPointTs = const Value.absent(),
    this.endPointTs = const Value.absent(),
    this.flags = const Value.absent(),
    this.pisteName = const Value.absent(),
    this.pisteOsmId = const Value.absent(),
    this.liftName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dayId = Value(dayId),
       kind = Value(kind),
       idx = Value(idx),
       startTs = Value(startTs),
       endTs = Value(endTs);
  static Insertable<SegmentRow> custom({
    Expression<String>? id,
    Expression<String>? dayId,
    Expression<String>? kind,
    Expression<int>? idx,
    Expression<int>? runNumber,
    Expression<int>? startTs,
    Expression<int>? endTs,
    Expression<double>? startAltM,
    Expression<double>? endAltM,
    Expression<double>? dropM,
    Expression<double>? distanceM,
    Expression<int>? movingMs,
    Expression<double>? maxSpeedMs,
    Expression<int>? maxSpeedAtTs,
    Expression<double>? avgSpeedMs,
    Expression<double>? avgGradientPct,
    Expression<double>? steepest100mPct,
    Expression<int>? startPointTs,
    Expression<int>? endPointTs,
    Expression<int>? flags,
    Expression<String>? pisteName,
    Expression<String>? pisteOsmId,
    Expression<String>? liftName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (kind != null) 'kind': kind,
      if (idx != null) 'idx': idx,
      if (runNumber != null) 'run_number': runNumber,
      if (startTs != null) 'start_ts': startTs,
      if (endTs != null) 'end_ts': endTs,
      if (startAltM != null) 'start_alt_m': startAltM,
      if (endAltM != null) 'end_alt_m': endAltM,
      if (dropM != null) 'drop_m': dropM,
      if (distanceM != null) 'distance_m': distanceM,
      if (movingMs != null) 'moving_ms': movingMs,
      if (maxSpeedMs != null) 'max_speed_ms': maxSpeedMs,
      if (maxSpeedAtTs != null) 'max_speed_at_ts': maxSpeedAtTs,
      if (avgSpeedMs != null) 'avg_speed_ms': avgSpeedMs,
      if (avgGradientPct != null) 'avg_gradient_pct': avgGradientPct,
      if (steepest100mPct != null) 'steepest100m_pct': steepest100mPct,
      if (startPointTs != null) 'start_point_ts': startPointTs,
      if (endPointTs != null) 'end_point_ts': endPointTs,
      if (flags != null) 'flags': flags,
      if (pisteName != null) 'piste_name': pisteName,
      if (pisteOsmId != null) 'piste_osm_id': pisteOsmId,
      if (liftName != null) 'lift_name': liftName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? dayId,
    Value<String>? kind,
    Value<int>? idx,
    Value<int?>? runNumber,
    Value<int>? startTs,
    Value<int>? endTs,
    Value<double>? startAltM,
    Value<double>? endAltM,
    Value<double>? dropM,
    Value<double>? distanceM,
    Value<int>? movingMs,
    Value<double>? maxSpeedMs,
    Value<int?>? maxSpeedAtTs,
    Value<double>? avgSpeedMs,
    Value<double>? avgGradientPct,
    Value<double?>? steepest100mPct,
    Value<int?>? startPointTs,
    Value<int?>? endPointTs,
    Value<int>? flags,
    Value<String?>? pisteName,
    Value<String?>? pisteOsmId,
    Value<String?>? liftName,
    Value<int>? rowid,
  }) {
    return SegmentsCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      kind: kind ?? this.kind,
      idx: idx ?? this.idx,
      runNumber: runNumber ?? this.runNumber,
      startTs: startTs ?? this.startTs,
      endTs: endTs ?? this.endTs,
      startAltM: startAltM ?? this.startAltM,
      endAltM: endAltM ?? this.endAltM,
      dropM: dropM ?? this.dropM,
      distanceM: distanceM ?? this.distanceM,
      movingMs: movingMs ?? this.movingMs,
      maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
      maxSpeedAtTs: maxSpeedAtTs ?? this.maxSpeedAtTs,
      avgSpeedMs: avgSpeedMs ?? this.avgSpeedMs,
      avgGradientPct: avgGradientPct ?? this.avgGradientPct,
      steepest100mPct: steepest100mPct ?? this.steepest100mPct,
      startPointTs: startPointTs ?? this.startPointTs,
      endPointTs: endPointTs ?? this.endPointTs,
      flags: flags ?? this.flags,
      pisteName: pisteName ?? this.pisteName,
      pisteOsmId: pisteOsmId ?? this.pisteOsmId,
      liftName: liftName ?? this.liftName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (idx.present) {
      map['idx'] = Variable<int>(idx.value);
    }
    if (runNumber.present) {
      map['run_number'] = Variable<int>(runNumber.value);
    }
    if (startTs.present) {
      map['start_ts'] = Variable<int>(startTs.value);
    }
    if (endTs.present) {
      map['end_ts'] = Variable<int>(endTs.value);
    }
    if (startAltM.present) {
      map['start_alt_m'] = Variable<double>(startAltM.value);
    }
    if (endAltM.present) {
      map['end_alt_m'] = Variable<double>(endAltM.value);
    }
    if (dropM.present) {
      map['drop_m'] = Variable<double>(dropM.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (movingMs.present) {
      map['moving_ms'] = Variable<int>(movingMs.value);
    }
    if (maxSpeedMs.present) {
      map['max_speed_ms'] = Variable<double>(maxSpeedMs.value);
    }
    if (maxSpeedAtTs.present) {
      map['max_speed_at_ts'] = Variable<int>(maxSpeedAtTs.value);
    }
    if (avgSpeedMs.present) {
      map['avg_speed_ms'] = Variable<double>(avgSpeedMs.value);
    }
    if (avgGradientPct.present) {
      map['avg_gradient_pct'] = Variable<double>(avgGradientPct.value);
    }
    if (steepest100mPct.present) {
      map['steepest100m_pct'] = Variable<double>(steepest100mPct.value);
    }
    if (startPointTs.present) {
      map['start_point_ts'] = Variable<int>(startPointTs.value);
    }
    if (endPointTs.present) {
      map['end_point_ts'] = Variable<int>(endPointTs.value);
    }
    if (flags.present) {
      map['flags'] = Variable<int>(flags.value);
    }
    if (pisteName.present) {
      map['piste_name'] = Variable<String>(pisteName.value);
    }
    if (pisteOsmId.present) {
      map['piste_osm_id'] = Variable<String>(pisteOsmId.value);
    }
    if (liftName.present) {
      map['lift_name'] = Variable<String>(liftName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SegmentsCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('kind: $kind, ')
          ..write('idx: $idx, ')
          ..write('runNumber: $runNumber, ')
          ..write('startTs: $startTs, ')
          ..write('endTs: $endTs, ')
          ..write('startAltM: $startAltM, ')
          ..write('endAltM: $endAltM, ')
          ..write('dropM: $dropM, ')
          ..write('distanceM: $distanceM, ')
          ..write('movingMs: $movingMs, ')
          ..write('maxSpeedMs: $maxSpeedMs, ')
          ..write('maxSpeedAtTs: $maxSpeedAtTs, ')
          ..write('avgSpeedMs: $avgSpeedMs, ')
          ..write('avgGradientPct: $avgGradientPct, ')
          ..write('steepest100mPct: $steepest100mPct, ')
          ..write('startPointTs: $startPointTs, ')
          ..write('endPointTs: $endPointTs, ')
          ..write('flags: $flags, ')
          ..write('pisteName: $pisteName, ')
          ..write('pisteOsmId: $pisteOsmId, ')
          ..write('liftName: $liftName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PointsTable extends Points with TableInfo<$PointsTable, PointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hAccMMeta = const VerificationMeta('hAccM');
  @override
  late final GeneratedColumn<double> hAccM = GeneratedColumn<double>(
    'h_acc_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsAltMMeta = const VerificationMeta(
    'gpsAltM',
  );
  @override
  late final GeneratedColumn<double> gpsAltM = GeneratedColumn<double>(
    'gps_alt_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vAccMMeta = const VerificationMeta('vAccM');
  @override
  late final GeneratedColumn<double> vAccM = GeneratedColumn<double>(
    'v_acc_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMsMeta = const VerificationMeta(
    'speedMs',
  );
  @override
  late final GeneratedColumn<double> speedMs = GeneratedColumn<double>(
    'speed_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedAccMsMeta = const VerificationMeta(
    'speedAccMs',
  );
  @override
  late final GeneratedColumn<double> speedAccMs = GeneratedColumn<double>(
    'speed_acc_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courseDegMeta = const VerificationMeta(
    'courseDeg',
  );
  @override
  late final GeneratedColumn<double> courseDeg = GeneratedColumn<double>(
    'course_deg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureHpaMeta = const VerificationMeta(
    'pressureHpa',
  );
  @override
  late final GeneratedColumn<double> pressureHpa = GeneratedColumn<double>(
    'pressure_hpa',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fusedAltMMeta = const VerificationMeta(
    'fusedAltM',
  );
  @override
  late final GeneratedColumn<double> fusedAltM = GeneratedColumn<double>(
    'fused_alt_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acceptedMeta = const VerificationMeta(
    'accepted',
  );
  @override
  late final GeneratedColumn<bool> accepted = GeneratedColumn<bool>(
    'accepted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("accepted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rejectReasonMeta = const VerificationMeta(
    'rejectReason',
  );
  @override
  late final GeneratedColumn<String> rejectReason = GeneratedColumn<String>(
    'reject_reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _heartRateBpmMeta = const VerificationMeta(
    'heartRateBpm',
  );
  @override
  late final GeneratedColumn<int> heartRateBpm = GeneratedColumn<int>(
    'heart_rate_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayId,
    ts,
    lat,
    lon,
    hAccM,
    gpsAltM,
    vAccM,
    speedMs,
    speedAccMs,
    courseDeg,
    pressureHpa,
    fusedAltM,
    accepted,
    rejectReason,
    state,
    heartRateBpm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points';
  @override
  VerificationContext validateIntegrity(
    Insertable<PointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('h_acc_m')) {
      context.handle(
        _hAccMMeta,
        hAccM.isAcceptableOrUnknown(data['h_acc_m']!, _hAccMMeta),
      );
    }
    if (data.containsKey('gps_alt_m')) {
      context.handle(
        _gpsAltMMeta,
        gpsAltM.isAcceptableOrUnknown(data['gps_alt_m']!, _gpsAltMMeta),
      );
    }
    if (data.containsKey('v_acc_m')) {
      context.handle(
        _vAccMMeta,
        vAccM.isAcceptableOrUnknown(data['v_acc_m']!, _vAccMMeta),
      );
    }
    if (data.containsKey('speed_ms')) {
      context.handle(
        _speedMsMeta,
        speedMs.isAcceptableOrUnknown(data['speed_ms']!, _speedMsMeta),
      );
    }
    if (data.containsKey('speed_acc_ms')) {
      context.handle(
        _speedAccMsMeta,
        speedAccMs.isAcceptableOrUnknown(
          data['speed_acc_ms']!,
          _speedAccMsMeta,
        ),
      );
    }
    if (data.containsKey('course_deg')) {
      context.handle(
        _courseDegMeta,
        courseDeg.isAcceptableOrUnknown(data['course_deg']!, _courseDegMeta),
      );
    }
    if (data.containsKey('pressure_hpa')) {
      context.handle(
        _pressureHpaMeta,
        pressureHpa.isAcceptableOrUnknown(
          data['pressure_hpa']!,
          _pressureHpaMeta,
        ),
      );
    }
    if (data.containsKey('fused_alt_m')) {
      context.handle(
        _fusedAltMMeta,
        fusedAltM.isAcceptableOrUnknown(data['fused_alt_m']!, _fusedAltMMeta),
      );
    }
    if (data.containsKey('accepted')) {
      context.handle(
        _acceptedMeta,
        accepted.isAcceptableOrUnknown(data['accepted']!, _acceptedMeta),
      );
    }
    if (data.containsKey('reject_reason')) {
      context.handle(
        _rejectReasonMeta,
        rejectReason.isAcceptableOrUnknown(
          data['reject_reason']!,
          _rejectReasonMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('heart_rate_bpm')) {
      context.handle(
        _heartRateBpmMeta,
        heartRateBpm.isAcceptableOrUnknown(
          data['heart_rate_bpm']!,
          _heartRateBpmMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_id'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      hAccM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}h_acc_m'],
      ),
      gpsAltM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_alt_m'],
      ),
      vAccM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}v_acc_m'],
      ),
      speedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_ms'],
      ),
      speedAccMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_acc_ms'],
      ),
      courseDeg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}course_deg'],
      ),
      pressureHpa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_hpa'],
      ),
      fusedAltM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fused_alt_m'],
      ),
      accepted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}accepted'],
      )!,
      rejectReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reject_reason'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      heartRateBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}heart_rate_bpm'],
      ),
    );
  }

  @override
  $PointsTable createAlias(String alias) {
    return $PointsTable(attachedDatabase, alias);
  }
}

class PointRow extends DataClass implements Insertable<PointRow> {
  final int id;
  final String dayId;
  final int ts;
  final double? lat;
  final double? lon;
  final double? hAccM;
  final double? gpsAltM;
  final double? vAccM;
  final double? speedMs;
  final double? speedAccMs;
  final double? courseDeg;
  final double? pressureHpa;
  final double? fusedAltM;
  final bool accepted;
  final String rejectReason;
  final String state;
  final int? heartRateBpm;
  const PointRow({
    required this.id,
    required this.dayId,
    required this.ts,
    this.lat,
    this.lon,
    this.hAccM,
    this.gpsAltM,
    this.vAccM,
    this.speedMs,
    this.speedAccMs,
    this.courseDeg,
    this.pressureHpa,
    this.fusedAltM,
    required this.accepted,
    required this.rejectReason,
    required this.state,
    this.heartRateBpm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_id'] = Variable<String>(dayId);
    map['ts'] = Variable<int>(ts);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || hAccM != null) {
      map['h_acc_m'] = Variable<double>(hAccM);
    }
    if (!nullToAbsent || gpsAltM != null) {
      map['gps_alt_m'] = Variable<double>(gpsAltM);
    }
    if (!nullToAbsent || vAccM != null) {
      map['v_acc_m'] = Variable<double>(vAccM);
    }
    if (!nullToAbsent || speedMs != null) {
      map['speed_ms'] = Variable<double>(speedMs);
    }
    if (!nullToAbsent || speedAccMs != null) {
      map['speed_acc_ms'] = Variable<double>(speedAccMs);
    }
    if (!nullToAbsent || courseDeg != null) {
      map['course_deg'] = Variable<double>(courseDeg);
    }
    if (!nullToAbsent || pressureHpa != null) {
      map['pressure_hpa'] = Variable<double>(pressureHpa);
    }
    if (!nullToAbsent || fusedAltM != null) {
      map['fused_alt_m'] = Variable<double>(fusedAltM);
    }
    map['accepted'] = Variable<bool>(accepted);
    map['reject_reason'] = Variable<String>(rejectReason);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || heartRateBpm != null) {
      map['heart_rate_bpm'] = Variable<int>(heartRateBpm);
    }
    return map;
  }

  PointsCompanion toCompanion(bool nullToAbsent) {
    return PointsCompanion(
      id: Value(id),
      dayId: Value(dayId),
      ts: Value(ts),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      hAccM: hAccM == null && nullToAbsent
          ? const Value.absent()
          : Value(hAccM),
      gpsAltM: gpsAltM == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsAltM),
      vAccM: vAccM == null && nullToAbsent
          ? const Value.absent()
          : Value(vAccM),
      speedMs: speedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(speedMs),
      speedAccMs: speedAccMs == null && nullToAbsent
          ? const Value.absent()
          : Value(speedAccMs),
      courseDeg: courseDeg == null && nullToAbsent
          ? const Value.absent()
          : Value(courseDeg),
      pressureHpa: pressureHpa == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureHpa),
      fusedAltM: fusedAltM == null && nullToAbsent
          ? const Value.absent()
          : Value(fusedAltM),
      accepted: Value(accepted),
      rejectReason: Value(rejectReason),
      state: Value(state),
      heartRateBpm: heartRateBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(heartRateBpm),
    );
  }

  factory PointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PointRow(
      id: serializer.fromJson<int>(json['id']),
      dayId: serializer.fromJson<String>(json['dayId']),
      ts: serializer.fromJson<int>(json['ts']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      hAccM: serializer.fromJson<double?>(json['hAccM']),
      gpsAltM: serializer.fromJson<double?>(json['gpsAltM']),
      vAccM: serializer.fromJson<double?>(json['vAccM']),
      speedMs: serializer.fromJson<double?>(json['speedMs']),
      speedAccMs: serializer.fromJson<double?>(json['speedAccMs']),
      courseDeg: serializer.fromJson<double?>(json['courseDeg']),
      pressureHpa: serializer.fromJson<double?>(json['pressureHpa']),
      fusedAltM: serializer.fromJson<double?>(json['fusedAltM']),
      accepted: serializer.fromJson<bool>(json['accepted']),
      rejectReason: serializer.fromJson<String>(json['rejectReason']),
      state: serializer.fromJson<String>(json['state']),
      heartRateBpm: serializer.fromJson<int?>(json['heartRateBpm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayId': serializer.toJson<String>(dayId),
      'ts': serializer.toJson<int>(ts),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'hAccM': serializer.toJson<double?>(hAccM),
      'gpsAltM': serializer.toJson<double?>(gpsAltM),
      'vAccM': serializer.toJson<double?>(vAccM),
      'speedMs': serializer.toJson<double?>(speedMs),
      'speedAccMs': serializer.toJson<double?>(speedAccMs),
      'courseDeg': serializer.toJson<double?>(courseDeg),
      'pressureHpa': serializer.toJson<double?>(pressureHpa),
      'fusedAltM': serializer.toJson<double?>(fusedAltM),
      'accepted': serializer.toJson<bool>(accepted),
      'rejectReason': serializer.toJson<String>(rejectReason),
      'state': serializer.toJson<String>(state),
      'heartRateBpm': serializer.toJson<int?>(heartRateBpm),
    };
  }

  PointRow copyWith({
    int? id,
    String? dayId,
    int? ts,
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<double?> hAccM = const Value.absent(),
    Value<double?> gpsAltM = const Value.absent(),
    Value<double?> vAccM = const Value.absent(),
    Value<double?> speedMs = const Value.absent(),
    Value<double?> speedAccMs = const Value.absent(),
    Value<double?> courseDeg = const Value.absent(),
    Value<double?> pressureHpa = const Value.absent(),
    Value<double?> fusedAltM = const Value.absent(),
    bool? accepted,
    String? rejectReason,
    String? state,
    Value<int?> heartRateBpm = const Value.absent(),
  }) => PointRow(
    id: id ?? this.id,
    dayId: dayId ?? this.dayId,
    ts: ts ?? this.ts,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    hAccM: hAccM.present ? hAccM.value : this.hAccM,
    gpsAltM: gpsAltM.present ? gpsAltM.value : this.gpsAltM,
    vAccM: vAccM.present ? vAccM.value : this.vAccM,
    speedMs: speedMs.present ? speedMs.value : this.speedMs,
    speedAccMs: speedAccMs.present ? speedAccMs.value : this.speedAccMs,
    courseDeg: courseDeg.present ? courseDeg.value : this.courseDeg,
    pressureHpa: pressureHpa.present ? pressureHpa.value : this.pressureHpa,
    fusedAltM: fusedAltM.present ? fusedAltM.value : this.fusedAltM,
    accepted: accepted ?? this.accepted,
    rejectReason: rejectReason ?? this.rejectReason,
    state: state ?? this.state,
    heartRateBpm: heartRateBpm.present ? heartRateBpm.value : this.heartRateBpm,
  );
  PointRow copyWithCompanion(PointsCompanion data) {
    return PointRow(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      ts: data.ts.present ? data.ts.value : this.ts,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      hAccM: data.hAccM.present ? data.hAccM.value : this.hAccM,
      gpsAltM: data.gpsAltM.present ? data.gpsAltM.value : this.gpsAltM,
      vAccM: data.vAccM.present ? data.vAccM.value : this.vAccM,
      speedMs: data.speedMs.present ? data.speedMs.value : this.speedMs,
      speedAccMs: data.speedAccMs.present
          ? data.speedAccMs.value
          : this.speedAccMs,
      courseDeg: data.courseDeg.present ? data.courseDeg.value : this.courseDeg,
      pressureHpa: data.pressureHpa.present
          ? data.pressureHpa.value
          : this.pressureHpa,
      fusedAltM: data.fusedAltM.present ? data.fusedAltM.value : this.fusedAltM,
      accepted: data.accepted.present ? data.accepted.value : this.accepted,
      rejectReason: data.rejectReason.present
          ? data.rejectReason.value
          : this.rejectReason,
      state: data.state.present ? data.state.value : this.state,
      heartRateBpm: data.heartRateBpm.present
          ? data.heartRateBpm.value
          : this.heartRateBpm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PointRow(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('ts: $ts, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('hAccM: $hAccM, ')
          ..write('gpsAltM: $gpsAltM, ')
          ..write('vAccM: $vAccM, ')
          ..write('speedMs: $speedMs, ')
          ..write('speedAccMs: $speedAccMs, ')
          ..write('courseDeg: $courseDeg, ')
          ..write('pressureHpa: $pressureHpa, ')
          ..write('fusedAltM: $fusedAltM, ')
          ..write('accepted: $accepted, ')
          ..write('rejectReason: $rejectReason, ')
          ..write('state: $state, ')
          ..write('heartRateBpm: $heartRateBpm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayId,
    ts,
    lat,
    lon,
    hAccM,
    gpsAltM,
    vAccM,
    speedMs,
    speedAccMs,
    courseDeg,
    pressureHpa,
    fusedAltM,
    accepted,
    rejectReason,
    state,
    heartRateBpm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PointRow &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.ts == this.ts &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.hAccM == this.hAccM &&
          other.gpsAltM == this.gpsAltM &&
          other.vAccM == this.vAccM &&
          other.speedMs == this.speedMs &&
          other.speedAccMs == this.speedAccMs &&
          other.courseDeg == this.courseDeg &&
          other.pressureHpa == this.pressureHpa &&
          other.fusedAltM == this.fusedAltM &&
          other.accepted == this.accepted &&
          other.rejectReason == this.rejectReason &&
          other.state == this.state &&
          other.heartRateBpm == this.heartRateBpm);
}

class PointsCompanion extends UpdateCompanion<PointRow> {
  final Value<int> id;
  final Value<String> dayId;
  final Value<int> ts;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<double?> hAccM;
  final Value<double?> gpsAltM;
  final Value<double?> vAccM;
  final Value<double?> speedMs;
  final Value<double?> speedAccMs;
  final Value<double?> courseDeg;
  final Value<double?> pressureHpa;
  final Value<double?> fusedAltM;
  final Value<bool> accepted;
  final Value<String> rejectReason;
  final Value<String> state;
  final Value<int?> heartRateBpm;
  const PointsCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.ts = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.hAccM = const Value.absent(),
    this.gpsAltM = const Value.absent(),
    this.vAccM = const Value.absent(),
    this.speedMs = const Value.absent(),
    this.speedAccMs = const Value.absent(),
    this.courseDeg = const Value.absent(),
    this.pressureHpa = const Value.absent(),
    this.fusedAltM = const Value.absent(),
    this.accepted = const Value.absent(),
    this.rejectReason = const Value.absent(),
    this.state = const Value.absent(),
    this.heartRateBpm = const Value.absent(),
  });
  PointsCompanion.insert({
    this.id = const Value.absent(),
    required String dayId,
    required int ts,
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.hAccM = const Value.absent(),
    this.gpsAltM = const Value.absent(),
    this.vAccM = const Value.absent(),
    this.speedMs = const Value.absent(),
    this.speedAccMs = const Value.absent(),
    this.courseDeg = const Value.absent(),
    this.pressureHpa = const Value.absent(),
    this.fusedAltM = const Value.absent(),
    this.accepted = const Value.absent(),
    this.rejectReason = const Value.absent(),
    this.state = const Value.absent(),
    this.heartRateBpm = const Value.absent(),
  }) : dayId = Value(dayId),
       ts = Value(ts);
  static Insertable<PointRow> custom({
    Expression<int>? id,
    Expression<String>? dayId,
    Expression<int>? ts,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<double>? hAccM,
    Expression<double>? gpsAltM,
    Expression<double>? vAccM,
    Expression<double>? speedMs,
    Expression<double>? speedAccMs,
    Expression<double>? courseDeg,
    Expression<double>? pressureHpa,
    Expression<double>? fusedAltM,
    Expression<bool>? accepted,
    Expression<String>? rejectReason,
    Expression<String>? state,
    Expression<int>? heartRateBpm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (ts != null) 'ts': ts,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (hAccM != null) 'h_acc_m': hAccM,
      if (gpsAltM != null) 'gps_alt_m': gpsAltM,
      if (vAccM != null) 'v_acc_m': vAccM,
      if (speedMs != null) 'speed_ms': speedMs,
      if (speedAccMs != null) 'speed_acc_ms': speedAccMs,
      if (courseDeg != null) 'course_deg': courseDeg,
      if (pressureHpa != null) 'pressure_hpa': pressureHpa,
      if (fusedAltM != null) 'fused_alt_m': fusedAltM,
      if (accepted != null) 'accepted': accepted,
      if (rejectReason != null) 'reject_reason': rejectReason,
      if (state != null) 'state': state,
      if (heartRateBpm != null) 'heart_rate_bpm': heartRateBpm,
    });
  }

  PointsCompanion copyWith({
    Value<int>? id,
    Value<String>? dayId,
    Value<int>? ts,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<double?>? hAccM,
    Value<double?>? gpsAltM,
    Value<double?>? vAccM,
    Value<double?>? speedMs,
    Value<double?>? speedAccMs,
    Value<double?>? courseDeg,
    Value<double?>? pressureHpa,
    Value<double?>? fusedAltM,
    Value<bool>? accepted,
    Value<String>? rejectReason,
    Value<String>? state,
    Value<int?>? heartRateBpm,
  }) {
    return PointsCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      ts: ts ?? this.ts,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      hAccM: hAccM ?? this.hAccM,
      gpsAltM: gpsAltM ?? this.gpsAltM,
      vAccM: vAccM ?? this.vAccM,
      speedMs: speedMs ?? this.speedMs,
      speedAccMs: speedAccMs ?? this.speedAccMs,
      courseDeg: courseDeg ?? this.courseDeg,
      pressureHpa: pressureHpa ?? this.pressureHpa,
      fusedAltM: fusedAltM ?? this.fusedAltM,
      accepted: accepted ?? this.accepted,
      rejectReason: rejectReason ?? this.rejectReason,
      state: state ?? this.state,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (hAccM.present) {
      map['h_acc_m'] = Variable<double>(hAccM.value);
    }
    if (gpsAltM.present) {
      map['gps_alt_m'] = Variable<double>(gpsAltM.value);
    }
    if (vAccM.present) {
      map['v_acc_m'] = Variable<double>(vAccM.value);
    }
    if (speedMs.present) {
      map['speed_ms'] = Variable<double>(speedMs.value);
    }
    if (speedAccMs.present) {
      map['speed_acc_ms'] = Variable<double>(speedAccMs.value);
    }
    if (courseDeg.present) {
      map['course_deg'] = Variable<double>(courseDeg.value);
    }
    if (pressureHpa.present) {
      map['pressure_hpa'] = Variable<double>(pressureHpa.value);
    }
    if (fusedAltM.present) {
      map['fused_alt_m'] = Variable<double>(fusedAltM.value);
    }
    if (accepted.present) {
      map['accepted'] = Variable<bool>(accepted.value);
    }
    if (rejectReason.present) {
      map['reject_reason'] = Variable<String>(rejectReason.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (heartRateBpm.present) {
      map['heart_rate_bpm'] = Variable<int>(heartRateBpm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('ts: $ts, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('hAccM: $hAccM, ')
          ..write('gpsAltM: $gpsAltM, ')
          ..write('vAccM: $vAccM, ')
          ..write('speedMs: $speedMs, ')
          ..write('speedAccMs: $speedAccMs, ')
          ..write('courseDeg: $courseDeg, ')
          ..write('pressureHpa: $pressureHpa, ')
          ..write('fusedAltM: $fusedAltM, ')
          ..write('accepted: $accepted, ')
          ..write('rejectReason: $rejectReason, ')
          ..write('state: $state, ')
          ..write('heartRateBpm: $heartRateBpm')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DaysTable days = $DaysTable(this);
  late final $SegmentsTable segments = $SegmentsTable(this);
  late final $PointsTable points = $PointsTable(this);
  late final Index daysStarted = Index(
    'days_started',
    'CREATE INDEX days_started ON days (started_at)',
  );
  late final Index daysStatus = Index(
    'days_status',
    'CREATE INDEX days_status ON days (status)',
  );
  late final Index segmentsDayIdx = Index(
    'segments_day_idx',
    'CREATE INDEX segments_day_idx ON segments (day_id, idx)',
  );
  late final Index pointsDayTs = Index(
    'points_day_ts',
    'CREATE INDEX points_day_ts ON points (day_id, ts)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    days,
    segments,
    points,
    daysStarted,
    daysStatus,
    segmentsDayIdx,
    pointsDayTs,
  ];
}

typedef $$DaysTableCreateCompanionBuilder =
    DaysCompanion Function({
      required String id,
      required int startedAt,
      Value<int?> endedAt,
      required String status,
      Value<String?> resortId,
      Value<String?> resortName,
      Value<int?> lastFixAt,
      Value<int> engineVersion,
      Value<int> streamRestarts,
      Value<String?> weatherJson,
      Value<String?> mapThumbPath,
      Value<bool> trackedOnWatch,
      Value<int> elapsedMs,
      Value<int> skiMs,
      Value<int> liftMs,
      Value<int> pauseMs,
      Value<int> signalLossMs,
      Value<int> otherMs,
      Value<int> runCount,
      Value<int> liftCount,
      Value<double> dropM,
      Value<double> ascentM,
      Value<double> skiDistanceM,
      Value<double> liftDistanceM,
      Value<double> totalDistanceM,
      Value<double> maxSpeedMs,
      Value<double> avgSkiSpeedMs,
      Value<double?> maxAltM,
      Value<double?> minAltM,
      Value<String?> maxSpeedSegmentId,
      Value<String?> longestRunSegmentId,
      Value<int> acceptedFixes,
      Value<int> rejectedFixes,
      Value<bool> hasBarometer,
      Value<bool> vehicleFlag,
      Value<int?> avgHeartRateBpm,
      Value<int?> maxHeartRateBpm,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$DaysTableUpdateCompanionBuilder =
    DaysCompanion Function({
      Value<String> id,
      Value<int> startedAt,
      Value<int?> endedAt,
      Value<String> status,
      Value<String?> resortId,
      Value<String?> resortName,
      Value<int?> lastFixAt,
      Value<int> engineVersion,
      Value<int> streamRestarts,
      Value<String?> weatherJson,
      Value<String?> mapThumbPath,
      Value<bool> trackedOnWatch,
      Value<int> elapsedMs,
      Value<int> skiMs,
      Value<int> liftMs,
      Value<int> pauseMs,
      Value<int> signalLossMs,
      Value<int> otherMs,
      Value<int> runCount,
      Value<int> liftCount,
      Value<double> dropM,
      Value<double> ascentM,
      Value<double> skiDistanceM,
      Value<double> liftDistanceM,
      Value<double> totalDistanceM,
      Value<double> maxSpeedMs,
      Value<double> avgSkiSpeedMs,
      Value<double?> maxAltM,
      Value<double?> minAltM,
      Value<String?> maxSpeedSegmentId,
      Value<String?> longestRunSegmentId,
      Value<int> acceptedFixes,
      Value<int> rejectedFixes,
      Value<bool> hasBarometer,
      Value<bool> vehicleFlag,
      Value<int?> avgHeartRateBpm,
      Value<int?> maxHeartRateBpm,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$DaysTableFilterComposer extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resortId => $composableBuilder(
    column: $table.resortId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resortName => $composableBuilder(
    column: $table.resortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFixAt => $composableBuilder(
    column: $table.lastFixAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streamRestarts => $composableBuilder(
    column: $table.streamRestarts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weatherJson => $composableBuilder(
    column: $table.weatherJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mapThumbPath => $composableBuilder(
    column: $table.mapThumbPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackedOnWatch => $composableBuilder(
    column: $table.trackedOnWatch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skiMs => $composableBuilder(
    column: $table.skiMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get liftMs => $composableBuilder(
    column: $table.liftMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pauseMs => $composableBuilder(
    column: $table.pauseMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get signalLossMs => $composableBuilder(
    column: $table.signalLossMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get otherMs => $composableBuilder(
    column: $table.otherMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runCount => $composableBuilder(
    column: $table.runCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get liftCount => $composableBuilder(
    column: $table.liftCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dropM => $composableBuilder(
    column: $table.dropM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ascentM => $composableBuilder(
    column: $table.ascentM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get skiDistanceM => $composableBuilder(
    column: $table.skiDistanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get liftDistanceM => $composableBuilder(
    column: $table.liftDistanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDistanceM => $composableBuilder(
    column: $table.totalDistanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxSpeedMs => $composableBuilder(
    column: $table.maxSpeedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgSkiSpeedMs => $composableBuilder(
    column: $table.avgSkiSpeedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxAltM => $composableBuilder(
    column: $table.maxAltM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minAltM => $composableBuilder(
    column: $table.minAltM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maxSpeedSegmentId => $composableBuilder(
    column: $table.maxSpeedSegmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get longestRunSegmentId => $composableBuilder(
    column: $table.longestRunSegmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acceptedFixes => $composableBuilder(
    column: $table.acceptedFixes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rejectedFixes => $composableBuilder(
    column: $table.rejectedFixes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasBarometer => $composableBuilder(
    column: $table.hasBarometer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vehicleFlag => $composableBuilder(
    column: $table.vehicleFlag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgHeartRateBpm => $composableBuilder(
    column: $table.avgHeartRateBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxHeartRateBpm => $composableBuilder(
    column: $table.maxHeartRateBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaysTableOrderingComposer extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resortId => $composableBuilder(
    column: $table.resortId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resortName => $composableBuilder(
    column: $table.resortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFixAt => $composableBuilder(
    column: $table.lastFixAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streamRestarts => $composableBuilder(
    column: $table.streamRestarts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weatherJson => $composableBuilder(
    column: $table.weatherJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mapThumbPath => $composableBuilder(
    column: $table.mapThumbPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackedOnWatch => $composableBuilder(
    column: $table.trackedOnWatch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMs => $composableBuilder(
    column: $table.elapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skiMs => $composableBuilder(
    column: $table.skiMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get liftMs => $composableBuilder(
    column: $table.liftMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pauseMs => $composableBuilder(
    column: $table.pauseMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get signalLossMs => $composableBuilder(
    column: $table.signalLossMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get otherMs => $composableBuilder(
    column: $table.otherMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runCount => $composableBuilder(
    column: $table.runCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get liftCount => $composableBuilder(
    column: $table.liftCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dropM => $composableBuilder(
    column: $table.dropM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ascentM => $composableBuilder(
    column: $table.ascentM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get skiDistanceM => $composableBuilder(
    column: $table.skiDistanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get liftDistanceM => $composableBuilder(
    column: $table.liftDistanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDistanceM => $composableBuilder(
    column: $table.totalDistanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxSpeedMs => $composableBuilder(
    column: $table.maxSpeedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgSkiSpeedMs => $composableBuilder(
    column: $table.avgSkiSpeedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxAltM => $composableBuilder(
    column: $table.maxAltM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minAltM => $composableBuilder(
    column: $table.minAltM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maxSpeedSegmentId => $composableBuilder(
    column: $table.maxSpeedSegmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get longestRunSegmentId => $composableBuilder(
    column: $table.longestRunSegmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acceptedFixes => $composableBuilder(
    column: $table.acceptedFixes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rejectedFixes => $composableBuilder(
    column: $table.rejectedFixes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasBarometer => $composableBuilder(
    column: $table.hasBarometer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vehicleFlag => $composableBuilder(
    column: $table.vehicleFlag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgHeartRateBpm => $composableBuilder(
    column: $table.avgHeartRateBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxHeartRateBpm => $composableBuilder(
    column: $table.maxHeartRateBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get resortId =>
      $composableBuilder(column: $table.resortId, builder: (column) => column);

  GeneratedColumn<String> get resortName => $composableBuilder(
    column: $table.resortName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFixAt =>
      $composableBuilder(column: $table.lastFixAt, builder: (column) => column);

  GeneratedColumn<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streamRestarts => $composableBuilder(
    column: $table.streamRestarts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weatherJson => $composableBuilder(
    column: $table.weatherJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mapThumbPath => $composableBuilder(
    column: $table.mapThumbPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trackedOnWatch => $composableBuilder(
    column: $table.trackedOnWatch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedMs =>
      $composableBuilder(column: $table.elapsedMs, builder: (column) => column);

  GeneratedColumn<int> get skiMs =>
      $composableBuilder(column: $table.skiMs, builder: (column) => column);

  GeneratedColumn<int> get liftMs =>
      $composableBuilder(column: $table.liftMs, builder: (column) => column);

  GeneratedColumn<int> get pauseMs =>
      $composableBuilder(column: $table.pauseMs, builder: (column) => column);

  GeneratedColumn<int> get signalLossMs => $composableBuilder(
    column: $table.signalLossMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get otherMs =>
      $composableBuilder(column: $table.otherMs, builder: (column) => column);

  GeneratedColumn<int> get runCount =>
      $composableBuilder(column: $table.runCount, builder: (column) => column);

  GeneratedColumn<int> get liftCount =>
      $composableBuilder(column: $table.liftCount, builder: (column) => column);

  GeneratedColumn<double> get dropM =>
      $composableBuilder(column: $table.dropM, builder: (column) => column);

  GeneratedColumn<double> get ascentM =>
      $composableBuilder(column: $table.ascentM, builder: (column) => column);

  GeneratedColumn<double> get skiDistanceM => $composableBuilder(
    column: $table.skiDistanceM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get liftDistanceM => $composableBuilder(
    column: $table.liftDistanceM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalDistanceM => $composableBuilder(
    column: $table.totalDistanceM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxSpeedMs => $composableBuilder(
    column: $table.maxSpeedMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgSkiSpeedMs => $composableBuilder(
    column: $table.avgSkiSpeedMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxAltM =>
      $composableBuilder(column: $table.maxAltM, builder: (column) => column);

  GeneratedColumn<double> get minAltM =>
      $composableBuilder(column: $table.minAltM, builder: (column) => column);

  GeneratedColumn<String> get maxSpeedSegmentId => $composableBuilder(
    column: $table.maxSpeedSegmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get longestRunSegmentId => $composableBuilder(
    column: $table.longestRunSegmentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get acceptedFixes => $composableBuilder(
    column: $table.acceptedFixes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rejectedFixes => $composableBuilder(
    column: $table.rejectedFixes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasBarometer => $composableBuilder(
    column: $table.hasBarometer,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get vehicleFlag => $composableBuilder(
    column: $table.vehicleFlag,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avgHeartRateBpm => $composableBuilder(
    column: $table.avgHeartRateBpm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxHeartRateBpm => $composableBuilder(
    column: $table.maxHeartRateBpm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DaysTable,
          DayRow,
          $$DaysTableFilterComposer,
          $$DaysTableOrderingComposer,
          $$DaysTableAnnotationComposer,
          $$DaysTableCreateCompanionBuilder,
          $$DaysTableUpdateCompanionBuilder,
          (DayRow, BaseReferences<_$AppDatabase, $DaysTable, DayRow>),
          DayRow,
          PrefetchHooks Function()
        > {
  $$DaysTableTableManager(_$AppDatabase db, $DaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> resortId = const Value.absent(),
                Value<String?> resortName = const Value.absent(),
                Value<int?> lastFixAt = const Value.absent(),
                Value<int> engineVersion = const Value.absent(),
                Value<int> streamRestarts = const Value.absent(),
                Value<String?> weatherJson = const Value.absent(),
                Value<String?> mapThumbPath = const Value.absent(),
                Value<bool> trackedOnWatch = const Value.absent(),
                Value<int> elapsedMs = const Value.absent(),
                Value<int> skiMs = const Value.absent(),
                Value<int> liftMs = const Value.absent(),
                Value<int> pauseMs = const Value.absent(),
                Value<int> signalLossMs = const Value.absent(),
                Value<int> otherMs = const Value.absent(),
                Value<int> runCount = const Value.absent(),
                Value<int> liftCount = const Value.absent(),
                Value<double> dropM = const Value.absent(),
                Value<double> ascentM = const Value.absent(),
                Value<double> skiDistanceM = const Value.absent(),
                Value<double> liftDistanceM = const Value.absent(),
                Value<double> totalDistanceM = const Value.absent(),
                Value<double> maxSpeedMs = const Value.absent(),
                Value<double> avgSkiSpeedMs = const Value.absent(),
                Value<double?> maxAltM = const Value.absent(),
                Value<double?> minAltM = const Value.absent(),
                Value<String?> maxSpeedSegmentId = const Value.absent(),
                Value<String?> longestRunSegmentId = const Value.absent(),
                Value<int> acceptedFixes = const Value.absent(),
                Value<int> rejectedFixes = const Value.absent(),
                Value<bool> hasBarometer = const Value.absent(),
                Value<bool> vehicleFlag = const Value.absent(),
                Value<int?> avgHeartRateBpm = const Value.absent(),
                Value<int?> maxHeartRateBpm = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                resortId: resortId,
                resortName: resortName,
                lastFixAt: lastFixAt,
                engineVersion: engineVersion,
                streamRestarts: streamRestarts,
                weatherJson: weatherJson,
                mapThumbPath: mapThumbPath,
                trackedOnWatch: trackedOnWatch,
                elapsedMs: elapsedMs,
                skiMs: skiMs,
                liftMs: liftMs,
                pauseMs: pauseMs,
                signalLossMs: signalLossMs,
                otherMs: otherMs,
                runCount: runCount,
                liftCount: liftCount,
                dropM: dropM,
                ascentM: ascentM,
                skiDistanceM: skiDistanceM,
                liftDistanceM: liftDistanceM,
                totalDistanceM: totalDistanceM,
                maxSpeedMs: maxSpeedMs,
                avgSkiSpeedMs: avgSkiSpeedMs,
                maxAltM: maxAltM,
                minAltM: minAltM,
                maxSpeedSegmentId: maxSpeedSegmentId,
                longestRunSegmentId: longestRunSegmentId,
                acceptedFixes: acceptedFixes,
                rejectedFixes: rejectedFixes,
                hasBarometer: hasBarometer,
                vehicleFlag: vehicleFlag,
                avgHeartRateBpm: avgHeartRateBpm,
                maxHeartRateBpm: maxHeartRateBpm,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                required String status,
                Value<String?> resortId = const Value.absent(),
                Value<String?> resortName = const Value.absent(),
                Value<int?> lastFixAt = const Value.absent(),
                Value<int> engineVersion = const Value.absent(),
                Value<int> streamRestarts = const Value.absent(),
                Value<String?> weatherJson = const Value.absent(),
                Value<String?> mapThumbPath = const Value.absent(),
                Value<bool> trackedOnWatch = const Value.absent(),
                Value<int> elapsedMs = const Value.absent(),
                Value<int> skiMs = const Value.absent(),
                Value<int> liftMs = const Value.absent(),
                Value<int> pauseMs = const Value.absent(),
                Value<int> signalLossMs = const Value.absent(),
                Value<int> otherMs = const Value.absent(),
                Value<int> runCount = const Value.absent(),
                Value<int> liftCount = const Value.absent(),
                Value<double> dropM = const Value.absent(),
                Value<double> ascentM = const Value.absent(),
                Value<double> skiDistanceM = const Value.absent(),
                Value<double> liftDistanceM = const Value.absent(),
                Value<double> totalDistanceM = const Value.absent(),
                Value<double> maxSpeedMs = const Value.absent(),
                Value<double> avgSkiSpeedMs = const Value.absent(),
                Value<double?> maxAltM = const Value.absent(),
                Value<double?> minAltM = const Value.absent(),
                Value<String?> maxSpeedSegmentId = const Value.absent(),
                Value<String?> longestRunSegmentId = const Value.absent(),
                Value<int> acceptedFixes = const Value.absent(),
                Value<int> rejectedFixes = const Value.absent(),
                Value<bool> hasBarometer = const Value.absent(),
                Value<bool> vehicleFlag = const Value.absent(),
                Value<int?> avgHeartRateBpm = const Value.absent(),
                Value<int?> maxHeartRateBpm = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                resortId: resortId,
                resortName: resortName,
                lastFixAt: lastFixAt,
                engineVersion: engineVersion,
                streamRestarts: streamRestarts,
                weatherJson: weatherJson,
                mapThumbPath: mapThumbPath,
                trackedOnWatch: trackedOnWatch,
                elapsedMs: elapsedMs,
                skiMs: skiMs,
                liftMs: liftMs,
                pauseMs: pauseMs,
                signalLossMs: signalLossMs,
                otherMs: otherMs,
                runCount: runCount,
                liftCount: liftCount,
                dropM: dropM,
                ascentM: ascentM,
                skiDistanceM: skiDistanceM,
                liftDistanceM: liftDistanceM,
                totalDistanceM: totalDistanceM,
                maxSpeedMs: maxSpeedMs,
                avgSkiSpeedMs: avgSkiSpeedMs,
                maxAltM: maxAltM,
                minAltM: minAltM,
                maxSpeedSegmentId: maxSpeedSegmentId,
                longestRunSegmentId: longestRunSegmentId,
                acceptedFixes: acceptedFixes,
                rejectedFixes: rejectedFixes,
                hasBarometer: hasBarometer,
                vehicleFlag: vehicleFlag,
                avgHeartRateBpm: avgHeartRateBpm,
                maxHeartRateBpm: maxHeartRateBpm,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DaysTable, DayRow>(table),
                  BaseReferences<_$AppDatabase, $DaysTable, DayRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DaysTable,
      DayRow,
      $$DaysTableFilterComposer,
      $$DaysTableOrderingComposer,
      $$DaysTableAnnotationComposer,
      $$DaysTableCreateCompanionBuilder,
      $$DaysTableUpdateCompanionBuilder,
      (DayRow, BaseReferences<_$AppDatabase, $DaysTable, DayRow>),
      DayRow,
      PrefetchHooks Function()
    >;
typedef $$SegmentsTableCreateCompanionBuilder =
    SegmentsCompanion Function({
      required String id,
      required String dayId,
      required String kind,
      required int idx,
      Value<int?> runNumber,
      required int startTs,
      required int endTs,
      Value<double> startAltM,
      Value<double> endAltM,
      Value<double> dropM,
      Value<double> distanceM,
      Value<int> movingMs,
      Value<double> maxSpeedMs,
      Value<int?> maxSpeedAtTs,
      Value<double> avgSpeedMs,
      Value<double> avgGradientPct,
      Value<double?> steepest100mPct,
      Value<int?> startPointTs,
      Value<int?> endPointTs,
      Value<int> flags,
      Value<String?> pisteName,
      Value<String?> pisteOsmId,
      Value<String?> liftName,
      Value<int> rowid,
    });
typedef $$SegmentsTableUpdateCompanionBuilder =
    SegmentsCompanion Function({
      Value<String> id,
      Value<String> dayId,
      Value<String> kind,
      Value<int> idx,
      Value<int?> runNumber,
      Value<int> startTs,
      Value<int> endTs,
      Value<double> startAltM,
      Value<double> endAltM,
      Value<double> dropM,
      Value<double> distanceM,
      Value<int> movingMs,
      Value<double> maxSpeedMs,
      Value<int?> maxSpeedAtTs,
      Value<double> avgSpeedMs,
      Value<double> avgGradientPct,
      Value<double?> steepest100mPct,
      Value<int?> startPointTs,
      Value<int?> endPointTs,
      Value<int> flags,
      Value<String?> pisteName,
      Value<String?> pisteOsmId,
      Value<String?> liftName,
      Value<int> rowid,
    });

class $$SegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runNumber => $composableBuilder(
    column: $table.runNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTs => $composableBuilder(
    column: $table.startTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTs => $composableBuilder(
    column: $table.endTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startAltM => $composableBuilder(
    column: $table.startAltM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endAltM => $composableBuilder(
    column: $table.endAltM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dropM => $composableBuilder(
    column: $table.dropM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get movingMs => $composableBuilder(
    column: $table.movingMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxSpeedMs => $composableBuilder(
    column: $table.maxSpeedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxSpeedAtTs => $composableBuilder(
    column: $table.maxSpeedAtTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgSpeedMs => $composableBuilder(
    column: $table.avgSpeedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgGradientPct => $composableBuilder(
    column: $table.avgGradientPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get steepest100mPct => $composableBuilder(
    column: $table.steepest100mPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startPointTs => $composableBuilder(
    column: $table.startPointTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endPointTs => $composableBuilder(
    column: $table.endPointTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pisteName => $composableBuilder(
    column: $table.pisteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pisteOsmId => $composableBuilder(
    column: $table.pisteOsmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get liftName => $composableBuilder(
    column: $table.liftName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idx => $composableBuilder(
    column: $table.idx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runNumber => $composableBuilder(
    column: $table.runNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTs => $composableBuilder(
    column: $table.startTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTs => $composableBuilder(
    column: $table.endTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startAltM => $composableBuilder(
    column: $table.startAltM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endAltM => $composableBuilder(
    column: $table.endAltM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dropM => $composableBuilder(
    column: $table.dropM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get movingMs => $composableBuilder(
    column: $table.movingMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxSpeedMs => $composableBuilder(
    column: $table.maxSpeedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxSpeedAtTs => $composableBuilder(
    column: $table.maxSpeedAtTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgSpeedMs => $composableBuilder(
    column: $table.avgSpeedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgGradientPct => $composableBuilder(
    column: $table.avgGradientPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get steepest100mPct => $composableBuilder(
    column: $table.steepest100mPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startPointTs => $composableBuilder(
    column: $table.startPointTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endPointTs => $composableBuilder(
    column: $table.endPointTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pisteName => $composableBuilder(
    column: $table.pisteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pisteOsmId => $composableBuilder(
    column: $table.pisteOsmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get liftName => $composableBuilder(
    column: $table.liftName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SegmentsTable> {
  $$SegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dayId =>
      $composableBuilder(column: $table.dayId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get idx =>
      $composableBuilder(column: $table.idx, builder: (column) => column);

  GeneratedColumn<int> get runNumber =>
      $composableBuilder(column: $table.runNumber, builder: (column) => column);

  GeneratedColumn<int> get startTs =>
      $composableBuilder(column: $table.startTs, builder: (column) => column);

  GeneratedColumn<int> get endTs =>
      $composableBuilder(column: $table.endTs, builder: (column) => column);

  GeneratedColumn<double> get startAltM =>
      $composableBuilder(column: $table.startAltM, builder: (column) => column);

  GeneratedColumn<double> get endAltM =>
      $composableBuilder(column: $table.endAltM, builder: (column) => column);

  GeneratedColumn<double> get dropM =>
      $composableBuilder(column: $table.dropM, builder: (column) => column);

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<int> get movingMs =>
      $composableBuilder(column: $table.movingMs, builder: (column) => column);

  GeneratedColumn<double> get maxSpeedMs => $composableBuilder(
    column: $table.maxSpeedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxSpeedAtTs => $composableBuilder(
    column: $table.maxSpeedAtTs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgSpeedMs => $composableBuilder(
    column: $table.avgSpeedMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgGradientPct => $composableBuilder(
    column: $table.avgGradientPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get steepest100mPct => $composableBuilder(
    column: $table.steepest100mPct,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startPointTs => $composableBuilder(
    column: $table.startPointTs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endPointTs => $composableBuilder(
    column: $table.endPointTs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get flags =>
      $composableBuilder(column: $table.flags, builder: (column) => column);

  GeneratedColumn<String> get pisteName =>
      $composableBuilder(column: $table.pisteName, builder: (column) => column);

  GeneratedColumn<String> get pisteOsmId => $composableBuilder(
    column: $table.pisteOsmId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get liftName =>
      $composableBuilder(column: $table.liftName, builder: (column) => column);
}

class $$SegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SegmentsTable,
          SegmentRow,
          $$SegmentsTableFilterComposer,
          $$SegmentsTableOrderingComposer,
          $$SegmentsTableAnnotationComposer,
          $$SegmentsTableCreateCompanionBuilder,
          $$SegmentsTableUpdateCompanionBuilder,
          (
            SegmentRow,
            BaseReferences<_$AppDatabase, $SegmentsTable, SegmentRow>,
          ),
          SegmentRow,
          PrefetchHooks Function()
        > {
  $$SegmentsTableTableManager(_$AppDatabase db, $SegmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dayId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> idx = const Value.absent(),
                Value<int?> runNumber = const Value.absent(),
                Value<int> startTs = const Value.absent(),
                Value<int> endTs = const Value.absent(),
                Value<double> startAltM = const Value.absent(),
                Value<double> endAltM = const Value.absent(),
                Value<double> dropM = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<int> movingMs = const Value.absent(),
                Value<double> maxSpeedMs = const Value.absent(),
                Value<int?> maxSpeedAtTs = const Value.absent(),
                Value<double> avgSpeedMs = const Value.absent(),
                Value<double> avgGradientPct = const Value.absent(),
                Value<double?> steepest100mPct = const Value.absent(),
                Value<int?> startPointTs = const Value.absent(),
                Value<int?> endPointTs = const Value.absent(),
                Value<int> flags = const Value.absent(),
                Value<String?> pisteName = const Value.absent(),
                Value<String?> pisteOsmId = const Value.absent(),
                Value<String?> liftName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SegmentsCompanion(
                id: id,
                dayId: dayId,
                kind: kind,
                idx: idx,
                runNumber: runNumber,
                startTs: startTs,
                endTs: endTs,
                startAltM: startAltM,
                endAltM: endAltM,
                dropM: dropM,
                distanceM: distanceM,
                movingMs: movingMs,
                maxSpeedMs: maxSpeedMs,
                maxSpeedAtTs: maxSpeedAtTs,
                avgSpeedMs: avgSpeedMs,
                avgGradientPct: avgGradientPct,
                steepest100mPct: steepest100mPct,
                startPointTs: startPointTs,
                endPointTs: endPointTs,
                flags: flags,
                pisteName: pisteName,
                pisteOsmId: pisteOsmId,
                liftName: liftName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dayId,
                required String kind,
                required int idx,
                Value<int?> runNumber = const Value.absent(),
                required int startTs,
                required int endTs,
                Value<double> startAltM = const Value.absent(),
                Value<double> endAltM = const Value.absent(),
                Value<double> dropM = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<int> movingMs = const Value.absent(),
                Value<double> maxSpeedMs = const Value.absent(),
                Value<int?> maxSpeedAtTs = const Value.absent(),
                Value<double> avgSpeedMs = const Value.absent(),
                Value<double> avgGradientPct = const Value.absent(),
                Value<double?> steepest100mPct = const Value.absent(),
                Value<int?> startPointTs = const Value.absent(),
                Value<int?> endPointTs = const Value.absent(),
                Value<int> flags = const Value.absent(),
                Value<String?> pisteName = const Value.absent(),
                Value<String?> pisteOsmId = const Value.absent(),
                Value<String?> liftName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SegmentsCompanion.insert(
                id: id,
                dayId: dayId,
                kind: kind,
                idx: idx,
                runNumber: runNumber,
                startTs: startTs,
                endTs: endTs,
                startAltM: startAltM,
                endAltM: endAltM,
                dropM: dropM,
                distanceM: distanceM,
                movingMs: movingMs,
                maxSpeedMs: maxSpeedMs,
                maxSpeedAtTs: maxSpeedAtTs,
                avgSpeedMs: avgSpeedMs,
                avgGradientPct: avgGradientPct,
                steepest100mPct: steepest100mPct,
                startPointTs: startPointTs,
                endPointTs: endPointTs,
                flags: flags,
                pisteName: pisteName,
                pisteOsmId: pisteOsmId,
                liftName: liftName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SegmentsTable, SegmentRow>(table),
                  BaseReferences<_$AppDatabase, $SegmentsTable, SegmentRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SegmentsTable,
      SegmentRow,
      $$SegmentsTableFilterComposer,
      $$SegmentsTableOrderingComposer,
      $$SegmentsTableAnnotationComposer,
      $$SegmentsTableCreateCompanionBuilder,
      $$SegmentsTableUpdateCompanionBuilder,
      (SegmentRow, BaseReferences<_$AppDatabase, $SegmentsTable, SegmentRow>),
      SegmentRow,
      PrefetchHooks Function()
    >;
typedef $$PointsTableCreateCompanionBuilder =
    PointsCompanion Function({
      Value<int> id,
      required String dayId,
      required int ts,
      Value<double?> lat,
      Value<double?> lon,
      Value<double?> hAccM,
      Value<double?> gpsAltM,
      Value<double?> vAccM,
      Value<double?> speedMs,
      Value<double?> speedAccMs,
      Value<double?> courseDeg,
      Value<double?> pressureHpa,
      Value<double?> fusedAltM,
      Value<bool> accepted,
      Value<String> rejectReason,
      Value<String> state,
      Value<int?> heartRateBpm,
    });
typedef $$PointsTableUpdateCompanionBuilder =
    PointsCompanion Function({
      Value<int> id,
      Value<String> dayId,
      Value<int> ts,
      Value<double?> lat,
      Value<double?> lon,
      Value<double?> hAccM,
      Value<double?> gpsAltM,
      Value<double?> vAccM,
      Value<double?> speedMs,
      Value<double?> speedAccMs,
      Value<double?> courseDeg,
      Value<double?> pressureHpa,
      Value<double?> fusedAltM,
      Value<bool> accepted,
      Value<String> rejectReason,
      Value<String> state,
      Value<int?> heartRateBpm,
    });

class $$PointsTableFilterComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hAccM => $composableBuilder(
    column: $table.hAccM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsAltM => $composableBuilder(
    column: $table.gpsAltM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vAccM => $composableBuilder(
    column: $table.vAccM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedMs => $composableBuilder(
    column: $table.speedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedAccMs => $composableBuilder(
    column: $table.speedAccMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get courseDeg => $composableBuilder(
    column: $table.courseDeg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fusedAltM => $composableBuilder(
    column: $table.fusedAltM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get accepted => $composableBuilder(
    column: $table.accepted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejectReason => $composableBuilder(
    column: $table.rejectReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heartRateBpm => $composableBuilder(
    column: $table.heartRateBpm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PointsTableOrderingComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hAccM => $composableBuilder(
    column: $table.hAccM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsAltM => $composableBuilder(
    column: $table.gpsAltM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vAccM => $composableBuilder(
    column: $table.vAccM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedMs => $composableBuilder(
    column: $table.speedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedAccMs => $composableBuilder(
    column: $table.speedAccMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get courseDeg => $composableBuilder(
    column: $table.courseDeg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fusedAltM => $composableBuilder(
    column: $table.fusedAltM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get accepted => $composableBuilder(
    column: $table.accepted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejectReason => $composableBuilder(
    column: $table.rejectReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heartRateBpm => $composableBuilder(
    column: $table.heartRateBpm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dayId =>
      $composableBuilder(column: $table.dayId, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<double> get hAccM =>
      $composableBuilder(column: $table.hAccM, builder: (column) => column);

  GeneratedColumn<double> get gpsAltM =>
      $composableBuilder(column: $table.gpsAltM, builder: (column) => column);

  GeneratedColumn<double> get vAccM =>
      $composableBuilder(column: $table.vAccM, builder: (column) => column);

  GeneratedColumn<double> get speedMs =>
      $composableBuilder(column: $table.speedMs, builder: (column) => column);

  GeneratedColumn<double> get speedAccMs => $composableBuilder(
    column: $table.speedAccMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get courseDeg =>
      $composableBuilder(column: $table.courseDeg, builder: (column) => column);

  GeneratedColumn<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fusedAltM =>
      $composableBuilder(column: $table.fusedAltM, builder: (column) => column);

  GeneratedColumn<bool> get accepted =>
      $composableBuilder(column: $table.accepted, builder: (column) => column);

  GeneratedColumn<String> get rejectReason => $composableBuilder(
    column: $table.rejectReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get heartRateBpm => $composableBuilder(
    column: $table.heartRateBpm,
    builder: (column) => column,
  );
}

class $$PointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PointsTable,
          PointRow,
          $$PointsTableFilterComposer,
          $$PointsTableOrderingComposer,
          $$PointsTableAnnotationComposer,
          $$PointsTableCreateCompanionBuilder,
          $$PointsTableUpdateCompanionBuilder,
          (PointRow, BaseReferences<_$AppDatabase, $PointsTable, PointRow>),
          PointRow,
          PrefetchHooks Function()
        > {
  $$PointsTableTableManager(_$AppDatabase db, $PointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dayId = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<double?> hAccM = const Value.absent(),
                Value<double?> gpsAltM = const Value.absent(),
                Value<double?> vAccM = const Value.absent(),
                Value<double?> speedMs = const Value.absent(),
                Value<double?> speedAccMs = const Value.absent(),
                Value<double?> courseDeg = const Value.absent(),
                Value<double?> pressureHpa = const Value.absent(),
                Value<double?> fusedAltM = const Value.absent(),
                Value<bool> accepted = const Value.absent(),
                Value<String> rejectReason = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> heartRateBpm = const Value.absent(),
              }) => PointsCompanion(
                id: id,
                dayId: dayId,
                ts: ts,
                lat: lat,
                lon: lon,
                hAccM: hAccM,
                gpsAltM: gpsAltM,
                vAccM: vAccM,
                speedMs: speedMs,
                speedAccMs: speedAccMs,
                courseDeg: courseDeg,
                pressureHpa: pressureHpa,
                fusedAltM: fusedAltM,
                accepted: accepted,
                rejectReason: rejectReason,
                state: state,
                heartRateBpm: heartRateBpm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dayId,
                required int ts,
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<double?> hAccM = const Value.absent(),
                Value<double?> gpsAltM = const Value.absent(),
                Value<double?> vAccM = const Value.absent(),
                Value<double?> speedMs = const Value.absent(),
                Value<double?> speedAccMs = const Value.absent(),
                Value<double?> courseDeg = const Value.absent(),
                Value<double?> pressureHpa = const Value.absent(),
                Value<double?> fusedAltM = const Value.absent(),
                Value<bool> accepted = const Value.absent(),
                Value<String> rejectReason = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int?> heartRateBpm = const Value.absent(),
              }) => PointsCompanion.insert(
                id: id,
                dayId: dayId,
                ts: ts,
                lat: lat,
                lon: lon,
                hAccM: hAccM,
                gpsAltM: gpsAltM,
                vAccM: vAccM,
                speedMs: speedMs,
                speedAccMs: speedAccMs,
                courseDeg: courseDeg,
                pressureHpa: pressureHpa,
                fusedAltM: fusedAltM,
                accepted: accepted,
                rejectReason: rejectReason,
                state: state,
                heartRateBpm: heartRateBpm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PointsTable, PointRow>(table),
                  BaseReferences<_$AppDatabase, $PointsTable, PointRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PointsTable,
      PointRow,
      $$PointsTableFilterComposer,
      $$PointsTableOrderingComposer,
      $$PointsTableAnnotationComposer,
      $$PointsTableCreateCompanionBuilder,
      $$PointsTableUpdateCompanionBuilder,
      (PointRow, BaseReferences<_$AppDatabase, $PointsTable, PointRow>),
      PointRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DaysTableTableManager get days => $$DaysTableTableManager(_db, _db.days);
  $$SegmentsTableTableManager get segments =>
      $$SegmentsTableTableManager(_db, _db.segments);
  $$PointsTableTableManager get points =>
      $$PointsTableTableManager(_db, _db.points);
}
