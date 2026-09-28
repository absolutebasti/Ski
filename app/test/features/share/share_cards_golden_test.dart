import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/share/share_card.dart';
import 'package:slopetrack/features/share/share_card_data.dart';

import 'share_fixtures.dart';
import 'synthetic_detail.dart';

/// One golden per kind and format (9:16 story and 1:1 square), rendered at
/// 1/3 scale with the real Inter faces. Re-gold with
/// `flutter test test/features/share --update-goldens`.
void main() {
  setUpAll(loadShareFonts);

  final cards = <String, ShareCardData Function()>{
    'medal': () => medalData(),
    'level': levelData,
    'season': seasonData,
    'rank': () => rankData(),
    'duel': duelData,
    'day': () => DayCardData(syntheticDetail()),
  };

  for (final e in cards.entries) {
    for (final format in [ShareFormat.story, ShareFormat.square]) {
      testWidgets('${e.key} card golden ${format.slug}', (tester) async {
        final boundary = await pumpGolden(tester, e.value(), format);
        expect(tester.takeException(), isNull, reason: 'no overflow in ${e.key} ${format.slug}');
        await expectLater(boundary, matchesGoldenFile('goldens/${e.key}_${format.slug}.png'));
      });
    }
  }
}
