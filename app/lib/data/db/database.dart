import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Days, Segments, Points, SyncOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database in the app's documents directory, WAL mode.
  AppDatabase.open() : super(driftDatabase(name: 'dropline'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 (WP-14): backend sync — outbox table + per-day sync bookkeeping.
          if (from < 2) {
            await m.createTable(syncOutbox);
            await m.addColumn(days, days.syncedAt);
            await m.addColumn(days, days.remoteUpdatedAt);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA synchronous=NORMAL');
        },
      );
}
