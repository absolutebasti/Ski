import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/medal_catalog.dart';

void main() {
  test('12 metrics × 4 tiers with stable ids', () {
    expect(medalCatalog.length, 48);
    expect(medalCatalog.map((m) => m.id).toSet().length, 48);
    for (final m in medalCatalog) {
      expect(m.id, '${m.metric.name}-${m.tier.name}');
      expect(medalById(m.id), same(m));
    }
    expect(medalById('nope'), isNull);
  });

  test('catalogue order follows the metric order, tiers ascending', () {
    var i = 0;
    for (final metric in medalMetricOrder) {
      final four = medalsOf(metric);
      expect(four.map((m) => m.tier).toList(), MedalTier.values);
      for (final m in four) {
        expect(medalCatalog[i++], same(m));
      }
      for (var t = 1; t < four.length; t++) {
        expect(four[t].threshold, greaterThan(four[t - 1].threshold), reason: metric.name);
      }
    }
    expect(medalMetricOrder.toSet(), AchievementMetric.values.toSet());
  });

  test('thresholds are in SI units (spot checks)', () {
    expect(medalById('vertical-bronze')!.threshold, 10000);
    expect(medalById('distance-gold')!.threshold, 1000000);
    expect(medalById('topSpeed-gold')!.threshold, closeTo(100 / 3.6, 1e-9));
    expect(medalById('avgSpeed-bronze')!.threshold, closeTo(25 / 3.6, 1e-9));
    expect(medalById('dayVertical-black')!.threshold, 6000);
    expect(medalById('points-black')!.threshold, 100000);
  });

  test('copy is short, bilingual and without exclamation marks', () {
    for (final m in medalCatalog) {
      for (final s in [m.titleDe, m.titleEn, m.hintDe, m.hintEn]) {
        expect(s.trim(), isNotEmpty, reason: m.id);
        expect(s, isNot(contains('!')), reason: m.id);
        expect(s, isNot(contains('\n')), reason: m.id);
      }
      expect(m.titleDe.length, lessThanOrEqualTo(24), reason: m.id);
      expect(m.titleEn.length, lessThanOrEqualTo(24), reason: m.id);
    }
  });

  test('level table has 14 ascending bands from 0', () {
    expect(levelTable.length, 14);
    expect(levelTable.first.minM, 0);
    for (var i = 0; i < levelTable.length; i++) {
      expect(levelTable[i].index, i + 1);
      if (i > 0) expect(levelTable[i].minM, greaterThan(levelTable[i - 1].minM));
    }
    expect(levelTable.last.minM, 10000000);
    expect(levelTable.last.titleDe, 'Black');
  });
}
