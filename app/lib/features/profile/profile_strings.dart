import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy for the altitude profile. German first, English second.
class ProfileStrings {
  const ProfileStrings(this.l);
  final AppLocale l;

  static ProfileStrings of(BuildContext context) => ProfileStrings(AppLocale.of(context));

  String get chartLabel => l.pick(de: 'Höhenprofil des Skitags', en: 'Altitude profile of the ski day');
  String get lift => l.pick(de: 'Liftfahrt', en: 'Lift');
  String get signalLoss => l.pick(de: 'Kein GPS', en: 'No GPS');
  String get noData => l.pick(de: 'Kein Höhenprofil', en: 'No altitude profile');

  // --- legend row under the chart ---------------------------------------
  String get legendRun => l.pick(de: 'Abfahrt', en: 'Run');
  String get legendLift => l.pick(de: 'Lift', en: 'Lift');
  String get legendSignalLoss => l.pick(de: 'Signalverlust', en: 'Signal loss');
  String get unitM => 'm';
}
