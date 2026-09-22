import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';

/// Copy for the map feature. German first, English second.
class MapStrings {
  const MapStrings(this._l);
  final AppLocale _l;

  static MapStrings of(BuildContext context) => MapStrings(AppLocale.of(context));

  String get title => _l.pick(de: 'Karte', en: 'Map');
  String get close => _l.pick(de: 'Schließen', en: 'Close');
  String get locate => _l.pick(de: 'Auf mich zentrieren', en: 'Centre on me');
  String get waitingForGps => _l.pick(de: 'Warte auf GPS …', en: 'Waiting for GPS …');
  String get speed => _l.pick(de: 'Tempo', en: 'Speed');
  String get altitude => _l.pick(de: 'Höhe', en: 'Altitude');
  String get start => _l.pick(de: 'Start', en: 'Start');
  String get end => _l.pick(de: 'Ende', en: 'End');
  String get noTrack => _l.pick(de: 'Noch keine Spur', en: 'No track yet');

  // --- GPS quality pill ----------------------------------------------------
  String get noGps => _l.pick(de: 'Kein GPS', en: 'No GPS');

  /// 'GPS gut' / 'Kein GPS' — the word next to the three bars.
  String gpsPill(GpsQuality q) => q == GpsQuality.none ? noGps : 'GPS ${gpsWord(q)}';

  String gpsWord(GpsQuality q) => switch (q) {
        GpsQuality.none => _l.pick(de: 'kein Signal', en: 'no signal'),
        GpsQuality.weak => _l.pick(de: 'schwach', en: 'weak'),
        GpsQuality.ok => _l.pick(de: 'ok', en: 'ok'),
        GpsQuality.good => _l.pick(de: 'gut', en: 'good'),
        GpsQuality.veryGood => _l.pick(de: 'sehr gut', en: 'very good'),
      };

  // --- readout bar ---------------------------------------------------------
  String get endDay => _l.pick(de: 'Tag beenden · halten', en: 'End day · hold');
  String get tooShort => _l.pick(de: 'Zu kurz für einen Skitag.', en: 'Too short for a ski day.');

  /// The motion state, same vocabulary as Heute.
  String stateWord(MotionState s, int runCount) => switch (s) {
        MotionState.run => _l.pick(de: 'Abfahrt $runCount', en: 'Run $runCount'),
        MotionState.lift => _l.pick(de: 'Im Lift', en: 'On the lift'),
        MotionState.stop => _l.pick(de: 'Pause', en: 'Rest'),
        MotionState.other || MotionState.unknown => _l.pick(de: 'Unterwegs', en: 'Moving'),
      };

  String get unitKmh => 'km/h';
  String get unitM => 'm';
  String get dash => '–';
}
