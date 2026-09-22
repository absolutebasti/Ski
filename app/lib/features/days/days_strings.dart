import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy for the Tage list and the Tag detail. German first, English second.
class DaysStrings {
  const DaysStrings(this.l);
  final AppLocale l;

  static DaysStrings of(BuildContext context) => DaysStrings(AppLocale.of(context));

  // --- titles / states -----------------------------------------------------
  String get title => l.pick(de: 'Tage', en: 'Days');
  String get dayTitle => l.pick(de: 'Skitag', en: 'Ski day');
  String get emptyHeadline => l.pick(de: 'Noch kein Skitag.', en: 'No ski day yet.');
  String get seasonWord => l.pick(de: 'Saison', en: 'Season');
  String get dayTitlePlural => l.pick(de: 'Skitage', en: 'Ski days');
  String get emptyLine =>
      l.pick(de: 'Noch kein Skitag aufgezeichnet. Dein erster Tag wartet auf Heute.', en: 'No ski day recorded yet. Your first day is waiting on Today.');
  String get loadFailed => l.pick(de: 'Der Tag konnte nicht geladen werden.', en: 'This day could not be loaded.');
  String get freeTerrain => l.pick(de: 'Freies Gelände', en: 'Open terrain');
  String get noRuns => l.pick(de: 'Keine Abfahrt erkannt.', en: 'No run detected.');
  String get noTrack => l.pick(de: 'Keine Spur aufgezeichnet.', en: 'No track recorded.');

  // --- personal bests ------------------------------------------------------
  String get topSpeed => l.pick(de: 'Top-Speed', en: 'Top speed');
  String get biggestDay => l.pick(de: 'Größter Tag', en: 'Biggest day');
  String get longestRun => l.pick(de: 'Längste Abfahrt', en: 'Longest run');
  String get pbBadge => l.pick(de: 'Rekord', en: 'Record');

  // --- actions -------------------------------------------------------------
  String get share => l.pick(de: 'Teilen', en: 'Share');
  String get shareCard => l.pick(de: 'Bild teilen', en: 'Share image');
  String get shareGpx => l.pick(de: 'GPX teilen', en: 'Share GPX');
  String get delete => l.pick(de: 'Löschen', en: 'Delete');
  String get cancel => l.pick(de: 'Abbrechen', en: 'Cancel');
  String get deleteTitle => l.pick(de: 'Skitag löschen?', en: 'Delete ski day?');
  String get deleteBody =>
      l.pick(de: 'Der Tag verschwindet aus deiner Liste und zählt nicht mehr zur Saison.', en: 'The day disappears from your list and no longer counts towards the season.');

  // --- stats grid ----------------------------------------------------------
  String get runs => l.pick(de: 'Abfahrten', en: 'Runs');
  String get vertical => l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get skiKm => l.pick(de: 'Ski-km', en: 'Ski km');
  String get liftKm => l.pick(de: 'Lift-km', en: 'Lift km');
  String get drop => l.pick(de: 'Abfahrt', en: 'Descent');
  String get ascent => l.pick(de: 'Aufstieg', en: 'Ascent');
  String get avgSkiSpeed => l.pick(de: 'Ø Speed beim Skifahren', en: 'Avg speed while skiing');
  String get highLow => l.pick(de: 'Höchster/Tiefster Punkt', en: 'Highest/lowest point');
  String get lifts => l.pick(de: 'Lifte', en: 'Lifts');

  // --- time bar ------------------------------------------------------------
  String get ski => l.pick(de: 'Ski', en: 'Ski');
  String get lift => l.pick(de: 'Lift', en: 'Lift');
  String get pause => l.pick(de: 'Pause', en: 'Rest');
  String get signalLoss => l.pick(de: 'Signalverlust', en: 'Signal loss');
  List<String> get timeBarLabels => [ski, lift, pause, signalLoss];
  String total(String duration) => l.pick(de: 'Gesamt $duration', en: 'Total $duration');

  // --- units / lines -------------------------------------------------------
  String get unitM => 'm';
  String get unitKm => 'km';
  String get unitKmh => 'km/h';
  String get unitHm => l.pick(de: 'hm', en: 'm');

  String runLabel(int number) => l.pick(de: 'Abfahrt $number', en: 'Run $number');

  String dayCount(int n) => l.pick(de: '$n ${n == 1 ? 'Skitag' : 'Tage'}', en: '$n ${n == 1 ? 'day' : 'days'}');
  String runCount(int n) => l.pick(de: '$n ${n == 1 ? 'Abfahrt' : 'Abfahrten'}', en: '$n ${n == 1 ? 'run' : 'runs'}');

  /// '2025/26 · 6 Tage · 41 Abfahrten · 18.240 hm'
  String seasonLine({required String season, required int days, required int runs, required String dropM}) =>
      '$season · ${dayCount(days)} · ${runCount(runs)} · $dropM $unitHm';

  /// '7 Abfahrten · 1.804 hm · 61 km/h'
  String dayLine({required int runs, required String dropM, required String kmh}) =>
      '${runCount(runs)} · $dropM $unitHm · $kmh $unitKmh';

  /// 'Abfahrt 7 · 10:42 · 312 hm · 2,1 km · 61 km/h · 14 %'
  String runLine({
    required int number,
    required String clock,
    required String dropM,
    required String km,
    required String kmh,
    required String gradient,
  }) =>
      '${runLabel(number)} · $clock · $dropM $unitHm · $km $unitKm · $kmh $unitKmh · $gradient';
}
