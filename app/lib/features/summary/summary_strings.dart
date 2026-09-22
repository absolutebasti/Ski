import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy for the Tagesbilanz (docs/PLAN.md §3) and the notification opt-in sheet.
class SummaryStrings {
  const SummaryStrings(this.l);
  final AppLocale l;

  static SummaryStrings of(BuildContext context) => SummaryStrings(AppLocale.of(context));

  String get title => l.pick(de: 'Tagesbilanz', en: 'Day summary');
  String get vertical => l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get runs => l.pick(de: 'Abfahrten', en: 'Runs');
  String get topSpeed => l.pick(de: 'Top-Speed', en: 'Top speed');
  String get skiKm => l.pick(de: 'Ski-km', en: 'Ski km');
  String get bestRun => l.pick(de: 'Beste Abfahrt', en: 'Best run');
  String get share => l.pick(de: 'Teilen', en: 'Share');
  String get done => l.pick(de: 'Fertig', en: 'Done');
  String get loadFailed => l.pick(de: 'Der Tag konnte nicht geladen werden.', en: 'This day could not be loaded.');
  String get noRuns => l.pick(de: 'Keine Abfahrt erkannt.', en: 'No run detected.');
  String get biggestDay => l.pick(de: 'Größter Tag', en: 'Biggest day');
  String get longestRun => l.pick(de: 'Längste Abfahrt', en: 'Longest run');
  String get record => l.pick(de: 'Rekord', en: 'Record');

  String get ski => l.pick(de: 'Ski', en: 'Ski');
  String get lift => l.pick(de: 'Lift', en: 'Lift');
  String get pause => l.pick(de: 'Pause', en: 'Rest');
  String get signalLoss => l.pick(de: 'Signalverlust', en: 'Signal loss');
  List<String> get timeBarLabels => [ski, lift, pause, signalLoss];

  String get unitM => 'm';
  String get unitKm => 'km';
  String get unitKmh => 'km/h';
  String get unitHm => l.pick(de: 'hm', en: 'm');

  String runLabel(int number) => l.pick(de: 'Abfahrt $number', en: 'Run $number');

  /// 'Abfahrt 7 · 10:42 · 312 hm · 2,1 km · 61 km/h'
  String bestRunLine({required int number, required String clock, required String dropM, required String km, required String kmh}) =>
      '${runLabel(number)} · $clock · $dropM $unitHm · $km $unitKm · $kmh $unitKmh';

  String get noTrack => l.pick(de: 'Ohne Track', en: 'No track');
  String get timeOnSnow => l.pick(de: 'Zeit', en: 'Time');
  String get total => l.pick(de: 'Gesamt', en: 'Total');

  /// The line on the solid champagne record card.
  String get recordFastestDay => l.pick(de: 'Schnellster Tag der Saison', en: 'Fastest day of the season');
  String get recordBiggestDay => l.pick(de: 'Größter Tag der Saison', en: 'Biggest day of the season');
  String get recordLongestRun => l.pick(de: 'Längste Abfahrt der Saison', en: 'Longest run of the season');

  /// 'Abfahrt 7 · 10:42'
  String bestRunTitle({required int number, required String clock}) => '${runLabel(number)} · $clock';

  // --- notification opt-in -------------------------------------------------
  String get notifyTitle => l.pick(de: 'Soll ich mich melden?', en: 'Should I check in?');
  String get notifyBody => l.pick(
        de: 'Eine Erinnerung nach 4 Stunden Aufnahme und eine Warnung bei 15 % Akku. Sonst nie.',
        en: 'One reminder after 4 hours of recording and a warning at 15 % battery. Nothing else.',
      );
  String get notifyYes => l.pick(de: 'Erinnerungen an', en: 'Turn reminders on');
  String get notifyNo => l.pick(de: 'Nicht jetzt', en: 'Not now');

  // --- mascot line (rule based) -------------------------------------------
  String get mascotFirstDay =>
      l.pick(de: 'Dein erster Skitag ist im Kasten. Den vergisst du nicht.', en: 'Your first ski day is in the bag. You will remember it.');
  String get mascotRecord =>
      l.pick(de: 'Neuer Rekord. Den musst du erst mal wieder schlagen.', en: 'New record. Beat that again if you can.');
  String mascotBigVertical(String dropM) =>
      l.pick(de: '$dropM Höhenmeter an einem Tag. Solide Arbeit.', en: '$dropM metres of vertical in one day. Solid work.');
  String mascotManyRuns(int runs) =>
      l.pick(de: '$runs Abfahrten. Das spüren die Beine morgen früh.', en: '$runs runs. Your legs will notice tomorrow.');
  String get mascotShortDay =>
      l.pick(de: 'Kurzer Tag. Zählt trotzdem.', en: 'Short day. Counts anyway.');
  String get mascotDefault =>
      l.pick(de: 'Sauber gefahren. Bis zum nächsten Dropline.', en: 'Nicely done. See you for the next turn.');
}
