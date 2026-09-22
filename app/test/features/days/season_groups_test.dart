import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/days/season_groups.dart';

import 'day_fixtures.dart';

void main() {
  test('groupBySeason keeps the newest-first order and splits at 1 July', () {
    final days = [
      summary(id: 'a', startedAt: tsThisSeason + 86400000),
      summary(id: 'b', startedAt: tsThisSeason),
      summary(id: 'c', startedAt: tsLastSeason),
    ];
    final groups = groupBySeason(days);
    expect(groups.map((g) => g.seasonKey).toList(), ['2025/26', '2024/25']);
    expect(groups.first.days.map((d) => d.id).toList(), ['a', 'b']);
    expect(groups.last.days.single.id, 'c');
  });

  test('groupBySeason on an empty list yields no groups', () {
    expect(groupBySeason(const []), isEmpty);
  });

  test('totalsFor picks the matching season row', () {
    const totals = [SeasonTotals(seasonKey: '2025/26', dayCount: 6), SeasonTotals(seasonKey: '2024/25', dayCount: 3)];
    expect(totalsFor(totals, '2024/25')?.dayCount, 3);
    expect(totalsFor(totals, '2019/20'), isNull);
  });
}
