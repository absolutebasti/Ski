import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/providers.dart';
import '../../data/resorts/resort_repository.dart';
import 'achievement_models.dart';
import 'achievements_engine.dart';

/// Lifetime gamification snapshot of the local user, recomputed whenever the
/// day list changes. Lead-owned contract; override in tests with a fixture.
final achievementsProvider = Provider<Achievements>((ref) {
  final days = ref.watch(daysListProvider).value ?? const [];
  final resorts = ref.watch(resortRepositoryProvider).value;
  return computeAchievements(
    days,
    countryOf: (id) => id == null ? null : resorts?.byId(id)?.country,
  );
});
