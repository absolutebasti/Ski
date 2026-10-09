import 'package:flutter/widgets.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';
import 'share_card_data.dart';

/// Copy for the share cards and exports. German first, English second.
class ShareStrings {
  const ShareStrings(this.l);
  final AppLocale l;

  static ShareStrings of(BuildContext context) => ShareStrings(AppLocale.of(context));
  static const de = ShareStrings(AppLocale(Locale('de')));

  String get vertical => l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get runs => l.pick(de: 'Abfahrten', en: 'Runs');
  String get topSpeed => l.pick(de: 'Top-Speed', en: 'Top speed');
  String get skiKm => l.pick(de: 'Ski-km', en: 'Ski km');
  String get longestRun => l.pick(de: 'Längste Abfahrt', en: 'Longest run');
  String get skiDay => l.pick(de: 'Skitag', en: 'Ski day');
  String get freeTerrain => l.pick(de: 'Freies Gelände', en: 'Open terrain');
  String get unitM => 'm';
  String get unitHm => l.pick(de: 'hm', en: 'm');
  String get unitKmh => 'km/h';
  String get unitKm => 'km';
  String get shareCardSubject => l.pick(de: 'Mein Skitag', en: 'My ski day');
  String get gpxSubject => l.pick(de: 'Skitag als GPX', en: 'Ski day as GPX');
  String get diagnosticsSubject => l.pick(de: '$kAppName Diagnosepaket', en: '$kAppName diagnostics bundle');

  /// 'Skitag in Kitzbühel · 3 Abfahrten · 1.900 hm · SlopeTrack' (no resort:
  /// 'Skitag · 3 Abfahrten · …').
  String summaryLine({required String? resort, required String runCount, required String dropM}) => resort == null
      ? l.pick(de: 'Skitag · $runCount Abfahrten · $dropM hm · $kAppName', en: 'Ski day · $runCount runs · $dropM m vertical · $kAppName')
      : l.pick(de: 'Skitag in $resort · $runCount Abfahrten · $dropM hm · $kAppName', en: 'Ski day in $resort · $runCount runs · $dropM m vertical · $kAppName');

  /// Every shared card carries a way to the app: [kGetAppUrl] on its own line.
  String withLink(String text) => '$text\n$kGetAppUrl';

  /// Under the wordmark on every card.
  String get getApp => l.pick(de: 'Gratis im App Store', en: 'Free on the App Store');

  // --- entry points (semantics) ---------------------------------------------
  String get shareMedal => l.pick(de: 'Medaille teilen', en: 'Share medal');
  String get shareMedalHint => l.pick(de: 'Lange drücken zum Teilen', en: 'Long-press to share');
  String get shareLevel => l.pick(de: 'Level teilen', en: 'Share level');

  // --- medal card -----------------------------------------------------------
  String get medal => l.pick(de: 'Medaille', en: 'Medal');
  String get medalSubject => l.pick(de: 'Neue Medaille', en: 'New medal');

  /// 'Neue Medaille: Sieben am Stück · SlopeTrack'
  String medalText(String title) => l.pick(de: 'Neue Medaille: $title · $kAppName', en: 'New medal: $title · $kAppName');

  // --- level card -----------------------------------------------------------
  String get level => l.pick(de: 'Level', en: 'Level');
  String get skiKilometres => l.pick(de: 'Ski-Kilometer', en: 'Ski kilometres');
  String get topLevel => l.pick(de: 'Höchstes Level', en: 'Top level');

  /// 'noch 38 km bis Level 5'
  String nextLevel(double remainingM, int nextIndex) => l.pick(
    de: 'noch ${Fmt.km(remainingM, decimals: 0, locale: l.code)} km bis Level $nextIndex',
    en: '${Fmt.km(remainingM, decimals: 0, locale: l.code)} km to level $nextIndex',
  );
  String get levelSubject => l.pick(de: 'Mein Level', en: 'My level');

  /// 'Level 4 · Carver · 312 km auf Ski · SlopeTrack'
  String levelText(int index, String title, String km) =>
      l.pick(de: 'Level $index · $title · $km km auf Ski · $kAppName', en: 'Level $index · $title · $km km on skis · $kAppName');

  // --- season card ----------------------------------------------------------
  /// 'Saison 2026/27'
  String season(String key) => l.pick(de: 'Saison $key', en: 'Season $key');

  /// 'Saison 26/27' — the short form for one-line captions.
  String seasonShort(String key) => season(key.length > 5 ? key.substring(2) : key);
  String skiDays(int n) => n == 1 ? l.pick(de: '1 Skitag', en: '1 ski day') : l.pick(de: '$n Skitage', en: '$n ski days');
  String get seasonSubject => l.pick(de: 'Meine Saison', en: 'My season');

  /// 'Saison 2026/27 · 12 Skitage · 48.000 hm · SlopeTrack'
  String seasonText(String key, int days, String dropM) => '${season(key)} · ${skiDays(days)} · $dropM $unitHm · $kAppName';

  // --- rank card ------------------------------------------------------------
  String get leaderboard => l.pick(de: 'Rangliste', en: 'Leaderboard');
  String get place => l.pick(de: 'Platz', en: 'Place');

  /// 'von 128'
  String ofTotal(int total) => l.pick(de: 'von $total', en: 'of $total');

  /// 'Platz 3 in Kitzbühel · Saison 26/27' / 'Platz 3 · Saison 26/27'
  String rankLine(int rank, String? scope, String period) =>
      scope == null ? '$place $rank · $period' : l.pick(de: '$place $rank in $scope · $period', en: '$place $rank in $scope · $period');
  String get rankSubject => l.pick(de: 'Mein Platz in der Rangliste', en: 'My leaderboard place');
  String rankText(int rank, String? scope, String period) => '${rankLine(rank, scope, period)} · $kAppName';
  String metricLabel(ShareMetric m) => switch (m) {
    ShareMetric.vertical => vertical,
    ShareMetric.runs => runs,
    ShareMetric.distance => skiKm,
    ShareMetric.topSpeed => topSpeed,
    ShareMetric.points => l.pick(de: 'Punkte', en: 'Points'),
    ShareMetric.days => l.pick(de: 'Skitage', en: 'Ski days'),
  };

  /// SI value → (display value, unit?) for the rank card.
  (String, String?) metricValue(ShareMetric m, double v) => switch (m) {
    ShareMetric.vertical => (Fmt.metres(v, locale: l.code), unitHm),
    ShareMetric.distance => (Fmt.km(v, locale: l.code), unitKm),
    ShareMetric.topSpeed => (Fmt.kmh(v, locale: l.code), unitKmh),
    ShareMetric.runs || ShareMetric.points || ShareMetric.days => (Fmt.metres(v, locale: l.code), null),
  };

  // --- duel card ------------------------------------------------------------
  String get duel => l.pick(de: 'Tagesduell', en: 'Day duel');
  String get you => l.pick(de: 'Du', en: 'You');
  String get duelSubject => l.pick(de: 'Tagesduell', en: 'Day duel');

  /// 'Platz 1 von 3 im Tagesduell · SlopeTrack'
  String duelText(int? myPlace, int n) =>
      myPlace == null ? '$duel · $kAppName' : l.pick(de: '$place $myPlace von $n im $duel · $kAppName', en: '$place $myPlace of $n in the $duel · $kAppName');

  /// '12 Abfahrten · 61 km/h'
  String duelCaption(int runCount, String kmh) => '$runCount ${runs.toLowerCase()} · $kmh $unitKmh';
}
