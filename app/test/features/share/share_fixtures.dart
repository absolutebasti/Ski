import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/achievements/achievement_models.dart';
import 'package:slopetrack/features/achievements/medal_catalog.dart';
import 'package:slopetrack/features/share/share_card.dart';
import 'package:slopetrack/features/share/share_card_data.dart';
import 'package:slopetrack/features/share/share_cards.dart';

import '../../support/pump.dart';

/// 2026-09-26, a Saturday.
const int kFixtureDayMs = 1790000000000;

/// The medal with the longest German title in the catalogue — the card must
/// never clip it.
MedalDef longestTitleMedal() => medalCatalog.reduce((a, b) => a.titleDe.length >= b.titleDe.length ? a : b);

MedalDef medalById(String id) => medalCatalog.firstWhere((m) => m.id == id);

MedalCardData medalData({String id = 'streak-gold'}) => MedalCardData(def: medalById(id), earnedAt: kFixtureDayMs);

LevelCardData levelData() => const LevelCardData(
  level: LevelState(index: 4, titleDe: 'Carver', titleEn: 'Carver', distanceM: 162000, nextAtM: 200000, progress: 0.62),
);

SeasonCardData seasonData() => const SeasonCardData(seasonKey: '2026/27', dayCount: 12, dropM: 48213, runCount: 118, skiDistanceM: 312400, maxSpeedMs: 24.7);

RankCardData rankData({int rank = 3, int total = 128}) =>
    RankCardData(rank: rank, total: total, value: 48213, metric: ShareMetric.vertical, seasonKey: '2026/27', scopeName: 'Kitzbühel');

DuelCardData duelData() => const DuelCardData(
  day: kFixtureDayMs,
  resortName: 'Kitzbühel',
  name: 'Freitagsrunde',
  rows: [
    DuelCardRow(displayName: 'Du', dropM: 1849, runCount: 12, maxSpeedMs: 17.2, isMe: true),
    DuelCardRow(displayName: 'Maximilian Hinterseer', dropM: 2210, runCount: 14, maxSpeedMs: 19.4),
    DuelCardRow(displayName: 'Anna', dropM: 1520, runCount: 9, maxSpeedMs: 15.1),
  ],
);

/// Loads the bundled Inter / InterDisplay faces so goldens and clipping
/// checks use the real metrics instead of the Ahem test font.
Future<void> loadShareFonts() async {
  const fonts = {
    'Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
    'InterDisplay': ['InterDisplay-Bold', 'InterDisplay-ExtraBold', 'InterDisplay-Black'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final name in e.value) {
      final bytes = File('assets/fonts/$name.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Pumps a card at its real size (the view is resized to match).
Future<void> pumpCard(WidgetTester tester, ShareCardData data, ShareFormat format, {Locale locale = const Locale('de'), bool rider = true}) async {
  tester.view.physicalSize = format.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    ShareCardView(data: data, format: format, showRider: rider),
    locale: locale,
  );
}

/// Pumps a card scaled to [scale] inside a RepaintBoundary for golden files.
Future<Finder> pumpGolden(WidgetTester tester, ShareCardData data, ShareFormat format, {double scale = 1 / 3}) async {
  final size = format.size * scale;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await pumpApp(
    tester,
    RepaintBoundary(
      key: key,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: FittedBox(
          child: SizedBox(
            width: format.width,
            height: format.height,
            child: ShareCardView(data: data, format: format, showRider: false),
          ),
        ),
      ),
    ),
  );
  return find.byKey(key);
}
