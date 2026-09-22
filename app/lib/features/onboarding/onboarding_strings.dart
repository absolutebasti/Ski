import 'package:flutter/widgets.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';

/// Onboarding copy (docs/ONBOARDING-SOCIAL.md). German first.
class OnboardingStrings {
  const OnboardingStrings(this._l);
  final AppLocale _l;
  static OnboardingStrings of(BuildContext context) => OnboardingStrings(AppLocale.of(context));

  // Page 1 — hook
  String get p1Headline => _l.pick(de: 'Fahr. Zähl. Gewinn.', en: 'Ride. Count. Win.');
  String get p1Body => _l.pick(
        de: 'Ein Knopf zeichnet deinen Skitag auf – Abfahrten, Höhenmeter, Top-Speed. Und du siehst sofort, wo du stehst.',
        en: 'One button records your ski day – runs, vertical, top speed. And you see right away where you stand.',
      );
  String get p1Slider => _l.pick(de: 'Wie viele Höhenmeter schaffst du an einem Tag?', en: 'How much vertical can you do in a day?');
  String get p1ChipRuns => _l.pick(de: '7 Abfahrten', en: '7 runs');
  String get p1ChipSpeed => '61 km/h';
  String get p1ChipRank => _l.pick(de: 'Platz 3 in Kitzbühel', en: '#3 in Kitzbühel');
  String p1Mascot(int hm) => hm >= 6000
      ? _l.pick(de: 'Respekt. Das will ich sehen.', en: 'Respect. Show me.')
      : hm >= 3000
          ? _l.pick(de: 'Solide. Da geht noch was.', en: 'Solid. Room to grow.')
          : _l.pick(de: 'Entspannt. Auch gut.', en: 'Relaxed. Fine by me.');

  // Page 2 — home resort + season goal
  String get p2Headline => _l.pick(de: 'Wo fährst du meistens?', en: 'Where do you ski most?');
  String get p2Body => _l.pick(de: 'Dein Heimatgebiet für die Rangliste. Ändern geht jederzeit.', en: 'Your home resort for the rankings. Change it any time.');
  String get p2Search => _l.pick(de: 'Skigebiet suchen', en: 'Search resort');
  String get p2Goal => _l.pick(de: 'Saisonziel', en: 'Season goal');
  String get p2GoalUnit => _l.pick(de: 'hm', en: 'm');
  String p2Teaser(String resort) => _l.pick(de: 'Sei der Erste in $resort.', en: 'Be the first in $resort.');
  String get p2TeaserBody => _l.pick(de: 'Die Rangliste startet mit deinem ersten Skitag.', en: 'The ranking starts with your first ski day.');
  String p2Mascot(int goalHm) => goalHm >= 40000
      ? _l.pick(de: 'Mutig. Gefällt mir.', en: 'Bold. I like it.')
      : _l.pick(de: 'Machbar. Los.', en: 'Doable. Go.');

  // Page 3 — sign in
  String get p3Headline => _l.pick(de: 'Fordere Freunde heraus', en: 'Challenge your friends');
  String get p3Body => _l.pick(
        de: 'Rangliste und Duelle brauchen einen Namen. Kein Passwort, kein Spam – Anmeldung mit Apple.',
        en: 'Rankings and duels need a name. No password, no spam – sign in with Apple.',
      );
  String get p3SignIn => _l.pick(de: 'Mit Apple anmelden', en: 'Sign in with Apple');
  String p3SignedIn(String name) => _l.pick(de: 'Angemeldet als $name', en: 'Signed in as $name');
  String get p3SignedInBody => _l.pick(de: 'Duelle und Ranglisten sind freigeschaltet.', en: 'Duels and rankings are unlocked.');
  String get p3Failed => _l.pick(de: 'Das hat nicht geklappt. Du kannst es später in den Einstellungen versuchen.', en: 'That did not work. You can try again later in settings.');
  String get p3Mascot => _l.pick(de: 'Ohne Namen kein Podium.', en: 'No name, no podium.');

  // Page 4 — permissions
  String get p4Headline => _l.pick(de: 'Startklar', en: 'Ready');
  String get p4Body => _l.pick(de: 'Zwei Fragen vom iPhone, dann geht’s los.', en: 'Two questions from your iPhone, then we go.');
  String get p4ItemA => _l.pick(de: 'Standort „Immer“ – damit die Aufnahme auch weiterläuft, wenn das Handy in der Jacke steckt.', en: 'Location “Always” – so recording keeps running with the phone in your jacket.');
  String get p4ItemB => _l.pick(de: 'Bewegung & Fitness – der Luftdrucksensor macht Höhenmeter auf den Meter genau.', en: 'Motion & Fitness – the barometer makes vertical accurate to the metre.');
  String get p4Mascot => _l.pick(de: 'Ich zähl’ mit. Du fährst.', en: 'I do the counting. You ski.');
  String get denied => _l.pick(de: 'Ohne Standort kann $kAppName keinen Skitag aufzeichnen. Du kannst das in den Einstellungen nachholen.', en: 'Without location $kAppName cannot record a ski day. You can fix that in Settings.');
  String get openSettings => _l.pick(de: 'In Einstellungen öffnen', en: 'Open settings');
  String get grantedWhileInUse => _l.pick(de: 'Passt. Für die Aufnahme im Hintergrund später auf „Immer“ stellen.', en: 'Good. Switch to “Always” later for background recording.');
  String get grantedAlways => _l.pick(de: 'Passt. Wir sind startklar.', en: 'All set. We are ready to go.');

  // Buttons
  String get next => _l.pick(de: 'Weiter', en: 'Next');
  String get allow => _l.pick(de: 'Erlauben', en: 'Allow');
  String get finish => _l.pick(de: 'Los geht’s', en: 'Let’s go');
  String get skip => _l.pick(de: 'Später', en: 'Later');
  String get back => _l.pick(de: 'Zurück', en: 'Back');
  String stepOf(int i, int n) => _l.pick(de: 'Schritt $i von $n', en: 'Step $i of $n');
}
