import 'package:flutter/widgets.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';

/// Copy for onboarding (docs/PLAN.md §4). German first, English second.
class OnboardingStrings {
  const OnboardingStrings(this._l);
  final AppLocale _l;

  static OnboardingStrings of(BuildContext context) => OnboardingStrings(AppLocale.of(context));

  // Page 1 — Willkommen
  String get p1Headline => _l.pick(de: 'Ein Knopf. Ein Skitag.', en: 'One button. One ski day.');
  String get p1Body => _l.pick(
        de: '$kAppName zählt deine Abfahrten, Höhenmeter und Top-Speed — automatisch, auch wenn das Handy in der Jacke steckt.',
        en: '$kAppName counts your runs, vertical metres and top speed — automatically, even with the phone in your jacket.',
      );
  String get p1Mascot => _l.pick(
        de: 'Servus, ich bin $kMascotName. Ich zähl’ mit — du fährst.',
        en: 'Hi, I’m $kMascotName. I do the counting — you ski.',
      );

  // Page 2 — So funktioniert's
  String get p2Headline => _l.pick(de: 'So funktioniert’s', en: 'How it works');
  String get p2Row1 => _l.pick(de: 'Tippe auf Start', en: 'Tap start');
  String get p2Row2 => _l.pick(de: 'Handy weg, Sperre an — die Aufnahme läuft', en: 'Phone away, screen locked — recording keeps running');
  String get p2Row3 => _l.pick(de: 'Am Abend: Beenden, fertig.', en: 'In the evening: end the day, done.');
  String get p2Pill => _l.pick(de: 'Dieses blaue Symbol heißt: es läuft.', en: 'This blue badge means: it is running.');
  String get p2Body => _l.pick(de: 'Lift, Pause, Abfahrt erkennen wir selbst.', en: 'Lift, pause and run are detected for you.');
  String get p2Mascot => _l.pick(
        de: 'Liftfahrt, Pause, Abfahrt — das erkenn’ ich selbst. Du musst nichts drücken.',
        en: 'Lift ride, pause, run — I spot those myself. You never have to press a thing.',
      );

  // Page 3 — Standort & Sensoren
  String get p3Headline => _l.pick(de: 'Standort & Sensoren', en: 'Location & sensors');
  String get p3Body => _l.pick(de: 'Gleich fragt dich das iPhone dreimal:', en: 'In a moment your iPhone asks you three times:');
  String get p3ItemA => _l.pick(
        de: 'Standort → «Beim Verwenden» erlauben',
        en: 'Location → allow «While using the app»',
      );
  String get p3ItemB => _l.pick(
        de: 'Direkt danach «Auf Immer erlauben ändern» — damit die Aufnahme nach einem Neustart weiterläuft',
        en: 'Right after that «Change to Always Allow» — so recording continues after a restart',
      );
  String get p3ItemC => _l.pick(
        de: 'Bewegung & Fitness → für den Luftdrucksensor (Höhenmeter auf den Meter)',
        en: 'Motion & fitness → for the barometer (vertical metres to the metre)',
      );
  String get p3Mascot => _l.pick(
        de: 'Drei Fragen vom iPhone, dann sind wir startklar.',
        en: 'Three questions from your iPhone, then we are ready to go.',
      );

  // Actions
  String get next => _l.pick(de: 'Weiter', en: 'Next');
  String get allow => _l.pick(de: 'Erlauben', en: 'Allow');
  String get finish => _l.pick(de: 'Los geht’s', en: 'Let’s go');
  String get skip => _l.pick(de: 'Später', en: 'Later');
  String get back => _l.pick(de: 'Zurück', en: 'Back');

  // Permission outcome
  String get denied => _l.pick(
        de: 'Ohne Standort kann $kAppName keine Abfahrten zählen. Du kannst das in den Einstellungen jederzeit ändern.',
        en: '$kAppName cannot count runs without location. You can change this in Settings at any time.',
      );
  String get openSettings => _l.pick(de: 'In Einstellungen öffnen', en: 'Open settings');
  String get grantedWhileInUse => _l.pick(
        de: 'Passt. «Beim Verwenden» reicht für den Start — «Immer» hält die Aufnahme auch nach einem Neustart am Laufen.',
        en: 'All good. «While using» is enough to start — «Always» keeps recording alive after a restart.',
      );
  String get grantedAlways => _l.pick(de: 'Passt. Wir sind startklar.', en: 'All set. We are ready to go.');

  String stepOf(int step, int total) => _l.pick(de: 'Schritt $step von $total', en: 'Step $step of $total');
}
