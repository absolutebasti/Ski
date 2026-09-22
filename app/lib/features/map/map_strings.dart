import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy for the map feature. German first, English second.
class MapStrings {
  const MapStrings(this._l);
  final AppLocale _l;

  static MapStrings of(BuildContext context) => MapStrings(AppLocale.of(context));

  String get title => _l.pick(de: 'Karte', en: 'Map');
  String get close => _l.pick(de: 'Schließen', en: 'Close');
  String get locate => _l.pick(de: 'Auf mich zentrieren', en: 'Centre on me');
  String get waitingForGps => _l.pick(de: 'Warte auf GPS …', en: 'Waiting for GPS …');
  String get speed => _l.pick(de: 'Geschwindigkeit', en: 'Speed');
  String get altitude => _l.pick(de: 'Höhe', en: 'Altitude');
  String get start => _l.pick(de: 'Start', en: 'Start');
  String get end => _l.pick(de: 'Ende', en: 'End');
  String get noTrack => _l.pick(de: 'Noch keine Spur', en: 'No track yet');
}
