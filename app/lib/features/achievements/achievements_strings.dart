import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';
import 'achievement_models.dart';

/// Copy for the gamification surfaces (header, medals sheet, banners).
/// German first, English second — minimal, adult, no exclamation marks.
class AchievementsStrings {
  const AchievementsStrings(this.l);
  final AppLocale l;

  static AchievementsStrings of(BuildContext context) => AchievementsStrings(AppLocale.of(context));

  // --- header ---------------------------------------------------------------
  String get level => l.pick(de: 'Level', en: 'Level');
  String get points => l.pick(de: 'Punkte', en: 'Points');
  String get formula => l.pick(
        de: 'Punkte = hm ÷ 10 + km × 10 + Abfahrten × 5 + 50 pro Tag',
        en: 'Points = m ÷ 10 + km × 10 + runs × 5 + 50 per day',
      );
  String get openMedals => l.pick(de: 'Medaillen öffnen', en: 'Open medals');
  String levelTitle(LevelState level) => l.pick(de: level.titleDe, en: level.titleEn);
  /// 'LEVEL 4 · CARVER' (caller applies `.overline`).
  String levelLine(LevelState level) => '${this.level} ${level.index} · ${levelTitle(level)}';
  String medalCount(int earned, int total) => '$earned / $total ${l.pick(de: 'Medaillen', en: 'medals')}';
  String get unitKm => 'km';
  String get unitKmh => 'km/h';
  String get unitHm => l.pick(de: 'hm', en: 'm');

  // --- streak ---------------------------------------------------------------
  String streak(int days) => l.pick(de: '$days Tage am Stück', en: '$days days in a row');

  // --- medals sheet ---------------------------------------------------------
  String get medalsTitle => l.pick(de: 'Medaillen', en: 'Medals');
  String nextLevel(double remainingM, int nextIndex) => l.pick(
        de: 'Noch ${Fmt.km(remainingM, decimals: 0, locale: l.code)} km bis Level $nextIndex',
        en: '${Fmt.km(remainingM, decimals: 0, locale: l.code)} km to level $nextIndex',
      );
  String get topLevel => l.pick(de: 'Höchstes Level', en: 'Top level');
  String medalTitle(MedalDef def) => l.pick(de: def.titleDe, en: def.titleEn);
  String medalHint(MedalDef def) => l.pick(de: def.hintDe, en: def.hintEn);
  String get locked => l.pick(de: 'Offen', en: 'Locked');

  String metric(AchievementMetric m) => switch (m) {
        AchievementMetric.days => l.pick(de: 'Skitage', en: 'Ski days'),
        AchievementMetric.streak => l.pick(de: 'Serie', en: 'Streak'),
        AchievementMetric.vertical => l.pick(de: 'Höhenmeter', en: 'Vertical'),
        AchievementMetric.distance => l.pick(de: 'Ski-Kilometer', en: 'Ski distance'),
        AchievementMetric.topSpeed => l.pick(de: 'Top-Speed', en: 'Top speed'),
        AchievementMetric.avgSpeed => l.pick(de: 'Ø Tempo', en: 'Avg speed'),
        AchievementMetric.runs => l.pick(de: 'Abfahrten', en: 'Runs'),
        AchievementMetric.dayVertical => l.pick(de: 'Höhenmeter an einem Tag', en: 'Vertical in one day'),
        AchievementMetric.dayRuns => l.pick(de: 'Abfahrten an einem Tag', en: 'Runs in one day'),
        AchievementMetric.countries => l.pick(de: 'Länder', en: 'Countries'),
        AchievementMetric.resorts => l.pick(de: 'Skigebiete', en: 'Resorts'),
        AchievementMetric.points => l.pick(de: 'Punkte', en: 'Points'),
      };

  String tier(MedalTier t) => switch (t) {
        MedalTier.bronze => l.pick(de: 'Bronze', en: 'Bronze'),
        MedalTier.silver => l.pick(de: 'Silber', en: 'Silver'),
        MedalTier.gold => l.pick(de: 'Gold', en: 'Gold'),
        MedalTier.black => 'Black',
      };

  /// Threshold as (value, unit?) — SI in, display out: metres → hm,
  /// m/s → km/h, distance metres → km, counts plain with de separators.
  (String, String?) threshold(MedalDef def) => switch (def.metric) {
        AchievementMetric.vertical || AchievementMetric.dayVertical => (Fmt.metres(def.threshold, locale: l.code), unitHm),
        AchievementMetric.distance => (Fmt.km(def.threshold, decimals: 0, locale: l.code), unitKm),
        AchievementMetric.topSpeed || AchievementMetric.avgSpeed => (Fmt.kmh(def.threshold, locale: l.code), unitKmh),
        _ => (Fmt.metres(def.threshold, locale: l.code), null),
      };

  // --- banner ---------------------------------------------------------------
  String get newMedal => l.pick(de: 'Neue Medaille', en: 'New medal');
  String more(int n) => '+$n';
}
