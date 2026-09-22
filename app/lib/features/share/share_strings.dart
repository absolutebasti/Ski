import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy for the share card and exports. German first, English second.
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
  String get unitKmh => 'km/h';
  String get unitKm => 'km';
  String get shareCardSubject => l.pick(de: 'Mein Skitag', en: 'My ski day');
  String get gpxSubject => l.pick(de: 'Skitag als GPX', en: 'Ski day as GPX');
  String get diagnosticsSubject => l.pick(de: 'Schwung Diagnosepaket', en: 'Schwung diagnostics bundle');

  /// 'Skitag in Kitzbühel · 3 Abfahrten · 1.900 hm'
  String summaryLine({required String resort, required String runCount, required String dropM}) =>
      l.pick(de: 'Skitag in $resort · $runCount Abfahrten · $dropM hm', en: 'Ski day in $resort · $runCount runs · $dropM m vertical');
}
