import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';

/// Copy of the conditions strip. German first, overlines are upper-cased by
/// the widget, so these read in sentence case.
class WeatherStrings {
  const WeatherStrings(this.l);
  final AppLocale l;

  static WeatherStrings of(BuildContext context) => WeatherStrings(AppLocale.of(context));

  String get summit => l.pick(de: 'Berg', en: 'Summit');
  String get base => l.pick(de: 'Tal', en: 'Base');
  String get freshSnow => l.pick(de: 'Neuschnee', en: 'Fresh snow');
  String get snowDepth => l.pick(de: 'Schneehöhe', en: 'Snow depth');
  String get today => l.pick(de: 'Heute', en: 'Today');
  String get conditions => l.pick(de: 'Bedingungen', en: 'Conditions');

  String cm(int v) => '$v cm';
}
