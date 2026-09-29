import 'package:flutter/widgets.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';

/// Copy for the Heute screen (idle + live) and the recovery card.
/// German first, English second — sentence case, ski vocabulary.
class TodayStrings {
  const TodayStrings(this.l);
  final AppLocale l;

  static TodayStrings of(BuildContext context) => TodayStrings(AppLocale.of(context));

  // --- chrome --------------------------------------------------------------
  String get title => l.pick(de: 'Heute', en: 'Today');
  String get settings => l.pick(de: 'Einstellungen', en: 'Settings');
  String get openSettings => l.pick(de: 'Einstellungen öffnen', en: 'Open settings');

  // --- idle ----------------------------------------------------------------
  String get start => l.pick(de: 'Tag starten', en: 'Start day');
  String get lastDay => l.pick(de: 'Zuletzt', en: 'Last day');
  String get season => l.pick(de: 'Saison', en: 'Season');
  String get emptyHeadline => l.pick(de: 'Dein erster Skitag wartet.', en: 'Your first ski day is waiting.');
  String get records => l.pick(de: 'Rekorde', en: 'Records');
  String get biggestDay => l.pick(de: 'Größter Tag', en: 'Biggest day');
  String get longestRun => l.pick(de: 'Längste Abfahrt', en: 'Longest run');
  /// Short PB-tile overlines: three tiles share one row, so one line each.
  String get pbBestDay => l.pick(de: 'Bester Tag', en: 'Best day');
  String get pbLongest => l.pick(de: 'Längste', en: 'Longest');
  String get startHint => l.pick(de: 'Läuft weiter, auch wenn das Display gesperrt ist.', en: 'Keeps running with the screen locked.');
  String get emptyLine => l.pick(
        de: 'Noch kein Skitag. Ein Tipp auf Tag starten genügt.',
        en: 'No ski day yet. One tap on start day is all it takes.',
      );

  // --- season card ---------------------------------------------------------
  String get shareSeason => l.pick(de: 'Saison teilen', en: 'Share season');
  String get goal => l.pick(de: 'Ziel', en: 'Goal');
  String get editGoal => l.pick(de: 'Saisonziel ändern', en: 'Change season goal');
  String get goalTitle => l.pick(de: 'Saisonziel', en: 'Season goal');
  String get goalBody => l.pick(
        de: 'Höhenmeter, die du diese Saison schaffen willst. Die Saisonkarte zeigt den Fortschritt.',
        en: 'Vertical metres you want to reach this season. The season card shows your progress.',
      );
  String get goalSave => l.pick(de: 'Speichern', en: 'Save');
  String get goalNone => l.pick(de: 'Kein Ziel', en: 'No goal');
  String get goalLess => l.pick(de: 'Weniger', en: 'Less');
  String get goalMore => l.pick(de: 'Mehr', en: 'More');

  // --- live duel line ------------------------------------------------------
  String get duel => l.pick(de: 'Duell', en: 'Duel');

  /// 'Duell: Platz 2 · Lena +120 hm' — own place and the gap to the leader.
  String duelBehind({required int place, required String leader, required String hm}) =>
      '$duel: ${l.pick(de: 'Platz', en: 'Place')} $place · $leader +$hm $unitHm';

  /// 'Duell: Platz 1 · 120 hm vor Paul' — leading, gap to the runner-up.
  String duelAhead({required String runnerUp, required String hm}) =>
      '$duel: ${l.pick(de: 'Platz', en: 'Place')} 1 · $hm $unitHm ${l.pick(de: 'vor', en: 'ahead of')} $runnerUp';

  /// 'Duell: Platz 1' — alone on the board so far.
  String get duelAlone => '$duel: ${l.pick(de: 'Platz', en: 'Place')} 1';

  // --- live ----------------------------------------------------------------
  String get recording => l.pick(de: 'Aufnahme läuft', en: 'Recording');
  String get end => l.pick(de: 'Tag beenden', en: 'End day');
  String get map => l.pick(de: 'Karte', en: 'Map');
  String get inLift => l.pick(de: 'Im Lift', en: 'On the lift');
  String get pause => l.pick(de: 'Pause', en: 'Rest');
  String get moving => l.pick(de: 'Unterwegs', en: 'Moving');
  String get noGps => l.pick(de: 'Kein GPS', en: 'No GPS');
  String get noGpsBaro => l.pick(de: 'Kein GPS – Höhe über Barometer', en: 'No GPS – altitude from barometer');
  String get tooShort => l.pick(de: 'Zu kurz, nicht gespeichert', en: 'Too short, not saved');

  String get vertical => l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get runs => l.pick(de: 'Abfahrten', en: 'Runs');
  String get topSpeed => l.pick(de: 'Top-Speed', en: 'Top speed');
  String get speed => l.pick(de: 'Geschwindigkeit', en: 'Speed');
  /// Overline of the live tempo strip.
  String get tempo => l.pick(de: 'Tempo', en: 'Speed');
  String get altitude => l.pick(de: 'Höhe', en: 'Altitude');
  String get time => l.pick(de: 'Zeit', en: 'Time');

  String get ski => l.pick(de: 'Ski', en: 'Ski');
  String get lift => l.pick(de: 'Lift', en: 'Lift');
  String get signalLoss => l.pick(de: 'Signalverlust', en: 'Signal loss');
  List<String> get timeBarLabels => [ski, lift, pause, signalLoss];

  String get unitM => 'm';
  String get unitKm => 'km';
  String get unitKmh => 'km/h';
  String get unitHm => l.pick(de: 'hm', en: 'm');
  String get dash => '–';

  String runLabel(int number) => l.pick(de: 'Abfahrt $number', en: 'Run $number');
  String runCount(int n) => l.pick(de: '$n ${n == 1 ? 'Abfahrt' : 'Abfahrten'}', en: '$n ${n == 1 ? 'run' : 'runs'}');
  String dayCount(int n) => l.pick(de: '$n ${n == 1 ? 'Skitag' : 'Tage'}', en: '$n ${n == 1 ? 'day' : 'days'}');

  /// 'Aufnahme läuft · GPS gut'
  String recordingPill(GpsQuality q) => q == GpsQuality.none ? '$recording · $noGps' : '$recording · GPS ${gpsWord(q)}';

  String gpsWord(GpsQuality q) => switch (q) {
        GpsQuality.none => l.pick(de: 'kein Signal', en: 'no signal'),
        GpsQuality.weak => l.pick(de: 'schwach', en: 'weak'),
        GpsQuality.ok => l.pick(de: 'ok', en: 'ok'),
        GpsQuality.good => l.pick(de: 'gut', en: 'good'),
        GpsQuality.veryGood => l.pick(de: 'sehr gut', en: 'very good'),
      };

  /// 'Akku reicht bis ca. 16:30'
  String batteryEta(String clock) => l.pick(de: 'Akku reicht bis ca. $clock', en: 'Battery lasts until approx. $clock');

  /// '7 Abfahrten · 1.804 hm · 61 km/h'
  String dayLine({required int runs, required String dropM, required String kmh}) =>
      '${runCount(runs)} · $dropM $unitHm · $kmh $unitKmh';

  /// '2025/26 · 6 Tage · 41 Abfahrten · 18.240 hm'
  String seasonLine({required String season, required int days, required int runs, required String dropM}) =>
      '$season · ${dayCount(days)} · ${runCount(runs)} · $dropM $unitHm';

  /// 'Abfahrt 7 · 312 hm · 61 km/h'
  String runBanner({required int number, required String dropM, required String kmh}) =>
      '${runLabel(number)} · ${runBannerMetrics(dropM: dropM, kmh: kmh)}';

  /// '312 hm · 61 km/h' — the metric half of the run banner.
  String runBannerMetrics({required String dropM, required String kmh}) => '$dropM $unitHm · $kmh $unitKmh';

  // --- blocking states -----------------------------------------------------
  String get deniedTitle => l.pick(de: 'Standort ist aus', en: 'Location is off');
  String get deniedBody => l.pick(
        de: 'Ohne Standort kann $kAppName keinen Skitag aufzeichnen.',
        en: 'Without location $kAppName cannot record a ski day.',
      );
  String get serviceOffTitle => l.pick(de: 'Ortungsdienste sind aus', en: 'Location services are off');
  String get serviceOffBody => l.pick(
        de: 'Schalte die Ortung in den Einstellungen ein, dann geht es los.',
        en: 'Turn location on in settings, then you are ready to go.',
      );
  String get preciseTitle => l.pick(de: 'Genauer Standort fehlt', en: 'Precise location is missing');
  String get preciseBody => l.pick(
        de: 'Höhenmeter und Top-Speed brauchen den genauen Standort.',
        en: 'Vertical and top speed need precise location.',
      );
  String get preciseAction => l.pick(de: 'Genau ein', en: 'Turn on precise');

  // --- recovery ------------------------------------------------------------
  String interrupted(String date) => l.pick(de: 'Tag vom $date wurde unterbrochen', en: 'Day from $date was interrupted');
  String get finishAndSave => l.pick(de: 'Beenden & speichern', en: 'End & save');
  String get resume => l.pick(de: 'Fortsetzen', en: 'Resume');
  String get discard => l.pick(de: 'Verwerfen', en: 'Discard');
}
