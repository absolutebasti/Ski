import 'package:flutter/widgets.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';

/// Onboarding v3 copy: three pages, one decision each. German first.
class OnboardingStrings {
  const OnboardingStrings(this._l);
  final AppLocale _l;
  static OnboardingStrings of(BuildContext context) => OnboardingStrings(AppLocale.of(context));

  // Page 1 — hook
  String get p1Headline => _l.pick(de: 'Fahren. Zählen. Gewinnen.', en: 'Ride. Count. Win.');
  String get p1Body => _l.pick(
        de: 'Ein Tipp startet den Tag. $kAppName zählt Abfahrten, Höhenmeter und Tempo – auch mit gesperrtem iPhone.',
        en: 'One tap starts the day. $kAppName counts runs, vertical and speed – even with the iPhone locked.',
      );
  String get p1Runs => _l.pick(de: 'Abfahrten', en: 'Runs');
  String get p1Vertical => _l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get p1TopSpeed => _l.pick(de: 'Top-Speed', en: 'Top speed');
  String get unitHm => _l.pick(de: 'hm', en: 'm');
  String get unitKmh => 'km/h';

  // Page 2 — team
  String get p2Headline => _l.pick(de: 'Für welches Land fährst du?', en: 'Which country do you ride for?');
  String get p2Body => _l.pick(
        de: 'Dein Land ist dein Team. Ranglisten und Duelle laufen pro Land und pro Skigebiet.',
        en: 'Your country is your team. Rankings and duels run per country and per resort.',
      );
  String get p2Other => _l.pick(de: 'Anderes', en: 'Other');
  String get p2OtherTitle => _l.pick(de: 'Anderes Land', en: 'Other country');
  String get p2Resort => _l.pick(de: 'Heimatgebiet wählen (optional)', en: 'Choose home resort (optional)');
  String get p2ResortLabel => _l.pick(de: 'Heimatgebiet', en: 'Home resort');
  String get p2Search => _l.pick(de: 'Skigebiet suchen', en: 'Search resort');
  String get p2NoMatch => _l.pick(de: 'Kein Skigebiet gefunden.', en: 'No resort found.');

  // Page 3 — ready
  String get p3Headline => _l.pick(de: 'Bereit.', en: 'Ready.');
  String get p3Body => _l.pick(de: 'Ein Konto ist optional. Danach fragt das iPhone zweimal, dann geht es los.', en: 'An account is optional. Then your iPhone asks twice, and you are off.');
  String get p3Account => _l.pick(de: 'Konto', en: 'Account');
  String get p3SignIn => _l.pick(de: 'Mit Apple anmelden', en: 'Sign in with Apple');
  String get p3Benefit => _l.pick(de: 'Backup, Ranglisten, Duelle', en: 'Backup, rankings, duels');
  String get p3OptIn => _l.pick(de: 'In Ranglisten erscheinen', en: 'Appear in leaderboards');
  String get p3OptInHint => _l.pick(
        de: 'Tageswerte, nie die Spur. Name und Avatar sind dann öffentlich sichtbar. Jederzeit im Konto änderbar.',
        en: 'Day figures, never the track. Your name and avatar are then publicly visible. Change it any time in Account.',
      );
  String p3SignedIn(String name) => _l.pick(de: 'Angemeldet als $name', en: 'Signed in as $name');
  String get p3Skipped => _l.pick(de: 'Ohne Konto', en: 'Without account');
  String get p3SkippedBody => _l.pick(de: 'Anmelden geht später in den Einstellungen.', en: 'You can sign in later in settings.');
  String get p3Failed => _l.pick(de: 'Das hat nicht geklappt. Du kannst es später in den Einstellungen versuchen.', en: 'That did not work. You can try again later in settings.');
  String get p3Asks => _l.pick(de: 'Das iPhone fragt', en: 'Your iPhone asks');
  String get p3ItemA => _l.pick(de: 'Standort „Immer“ – die Aufnahme läuft weiter, wenn das iPhone in der Jacke steckt.', en: 'Location “Always” – recording keeps running with the iPhone in your jacket.');
  String get p3ItemB => _l.pick(de: 'Bewegung & Fitness – der Luftdrucksensor macht Höhenmeter auf den Meter genau.', en: 'Motion & Fitness – the barometer makes vertical accurate to the metre.');
  String get denied => _l.pick(de: 'Ohne Standort kann $kAppName keinen Skitag aufzeichnen. Du kannst das in den Einstellungen nachholen.', en: 'Without location $kAppName cannot record a ski day. You can fix that in Settings.');
  String get openSettings => _l.pick(de: 'In Einstellungen öffnen', en: 'Open settings');
  String get grantedWhileInUse => _l.pick(de: 'Passt. Für die Aufnahme im Hintergrund später auf „Immer“ stellen.', en: 'Good. Switch to “Always” later for background recording.');
  String get grantedAlways => _l.pick(de: 'Passt. Alles bereit.', en: 'Good. All set.');

  // Buttons
  String get next => _l.pick(de: 'Weiter', en: 'Next');
  String get finish => _l.pick(de: 'Los geht’s', en: 'Let’s go');
  String get skip => _l.pick(de: 'Später', en: 'Later');
  String get back => _l.pick(de: 'Zurück', en: 'Back');
  String stepOf(int i, int n) => _l.pick(de: 'Schritt $i von $n', en: 'Step $i of $n');
}
