import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/features/share/share.dart';
import 'package:slopetrack/features/today/season_card.dart';

import '../../support/pump.dart';

/// Records what the card asked for instead of rendering and sharing a PNG.
class _FakeShare extends ShareService {
  _FakeShare() : super(sink: (files, {subject, text}) async {});
  final List<(ShareCardKind, ShareCardData)> calls = [];

  @override
  Future<void> shareCard(BuildContext context, ShareCardKind kind, ShareCardData data, {ShareFormat format = ShareService.defaultCardFormat, Future<void> Function()? awaitFrame}) async {
    calls.add((kind, data));
  }
}

const _totals = SeasonTotals(seasonKey: '2025/26', dayCount: 6, runCount: 41, dropM: 18240, skiDistanceM: 62000, maxSpeedMs: 19.2);

Future<_FakeShare> _pump(WidgetTester tester, {bool shareable = true}) async {
  final share = _FakeShare();
  await pumpApp(
    tester,
    Scaffold(body: SeasonCard(totals: _totals, days: const [], shareable: shareable)),
    overrides: [shareServiceProvider.overrideWithValue(share)],
  );
  await tester.pump();
  return share;
}

void main() {
  testWidgets('the share glyph hands a SeasonCardData built from the totals to ShareService', (tester) async {
    final share = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('season-share')));
    await tester.pump();

    expect(share.calls, hasLength(1));
    final (kind, data) = share.calls.single;
    expect(kind, ShareCardKind.season);
    final season = data as SeasonCardData;
    expect(season.seasonKey, '2025/26');
    expect(season.dayCount, 6);
    expect(season.runCount, 41);
    expect(season.dropM, 18240);
    expect(season.skiDistanceM, 62000);
    expect(season.maxSpeedMs, 19.2);
  });

  testWidgets('a long press on the card shares too', (tester) async {
    final share = await _pump(tester);
    await tester.longPress(find.text('SAISON 2025/26'));
    await tester.pump();
    expect(share.calls.map((c) => c.$1), [ShareCardKind.season]);
  });

  testWidgets('shareable: false hides the glyph and ignores the long press', (tester) async {
    final share = await _pump(tester, shareable: false);
    expect(find.byKey(const ValueKey('season-share')), findsNothing);
    await tester.longPress(find.text('SAISON 2025/26'));
    await tester.pump();
    expect(share.calls, isEmpty);
  });
}
