import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Days, Segments, Points])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database in the app's documents directory, WAL mode.
  AppDatabase.open() : super(driftDatabase(name: 'schwung'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA synchronous=NORMAL');
        },
      );
}
