import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import 'database.dart';
import 'days_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final daysRepositoryProvider = Provider<DaysRepository>((ref) => DaysRepository(ref.watch(databaseProvider)));

final daysListProvider = StreamProvider<List<DaySummary>>((ref) => ref.watch(daysRepositoryProvider).watchDays());

final dayDetailProvider = FutureProvider.autoDispose.family<DayDetail, String>((ref, id) async {
  final d = await ref.watch(daysRepositoryProvider).dayDetail(id);
  if (d == null) throw StateError('day $id not found');
  return d;
});

final seasonTotalsProvider = StreamProvider<List<SeasonTotals>>((ref) => ref.watch(daysRepositoryProvider).watchSeasonTotals());

final personalBestsProvider = StreamProvider<PersonalBests>((ref) => ref.watch(daysRepositoryProvider).watchPersonalBests());
