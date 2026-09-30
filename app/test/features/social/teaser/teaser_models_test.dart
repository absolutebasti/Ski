import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/teaser/teaser.dart';

void main() {
  group('TeaserEntry.fromJson', () {
    test('reads the four columns of public_board_teaser', () {
      final e = TeaserEntry.fromJson(const {'rank': 3, 'display_name': 'Nina Aigner', 'avatar_url': 'https://example.invalid/n.jpg', 'value': 1440.0});
      expect(e, const TeaserEntry(rank: 3, displayName: 'Nina Aigner', value: 1440, avatarUrl: 'https://example.invalid/n.jpg'));
    });

    test('tolerates loose wire types and blank fields', () {
      final e = TeaserEntry.fromJson(const {'rank': '2', 'display_name': '  ', 'avatar_url': '', 'value': 1200});
      expect(e.rank, 2);
      expect(e.value, 1200.0);
      expect(e.displayName, isNotEmpty, reason: 'a blank name falls back to the server default');
      expect(e.avatarUrl, isNull);

      final bare = TeaserEntry.fromJson(const {});
      expect(bare.rank, 0);
      expect(bare.value, 0);
      expect(bare.displayName, isNotEmpty);
      expect(bare.avatarUrl, isNull);
    });

    test('trims the name', () {
      expect(TeaserEntry.fromJson(const {'rank': 1, 'display_name': ' Lena ', 'value': 1}).displayName, 'Lena');
    });

    test('a user_id on the wire is ignored — the row never carries one', () {
      final e = TeaserEntry.fromJson(const {'rank': 1, 'user_id': 'u9', 'display_name': 'Lena', 'value': 10});
      expect(e.toEntry().userId, isEmpty);
    });
  });

  test('toEntry maps onto the board row shape without an id, flag or day caption', () {
    final row = const TeaserEntry(rank: 4, displayName: 'Tom Huber', value: 900, avatarUrl: 'https://example.invalid/t.jpg').toEntry();
    expect(row.rank, 4);
    expect(row.userId, '');
    expect(row.displayName, 'Tom Huber');
    expect(row.value, 900);
    expect(row.avatarUrl, 'https://example.invalid/t.jpg');
    expect(row.countryCode, isNull);
    expect(row.lastDayMs, isNull);
    expect(row.dayCount, 0);
  });

  group('parseTeaserRows', () {
    test('anything but a list is an empty board', () {
      expect(parseTeaserRows(null), isEmpty);
      expect(parseTeaserRows('nope'), isEmpty);
      expect(parseTeaserRows(const {'rank': 1}), isEmpty);
    });

    test('skips non-map items, sorts by rank and caps at ten', () {
      final raw = <Object?>[
        for (var i = 14; i >= 1; i--) {'rank': i, 'display_name': 'Rider $i', 'value': 1000 - i},
        'junk',
        null,
      ];
      final rows = parseTeaserRows(raw);
      expect(rows, hasLength(kTeaserLimit));
      expect(rows.map((e) => e.rank), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(rows.first.displayName, 'Rider 1');
    });
  });

  test('TeaserQuery has value equality so the provider family caches', () {
    expect(const TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel'), const TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel'));
    expect(const TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel').hashCode, const TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel').hashCode);
    expect(const TeaserQuery(seasonKey: '2025/26'), isNot(const TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel')));
    expect(const TeaserQuery(seasonKey: '2025/26'), isNot(const TeaserQuery(seasonKey: '2026-01')));
  });
}
