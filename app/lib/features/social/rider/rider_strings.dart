import 'package:flutter/widgets.dart';

import '../../../app/brand.dart';
import '../../../app/l10n/app_locale.dart';
import '../../../core/core.dart';

/// Copy for the rider profile sheet. German first, English second — sentence
/// case, adult tone, no exclamation marks.
class RiderStrings {
  const RiderStrings(this.l);
  final AppLocale l;

  static RiderStrings of(BuildContext context) => RiderStrings(AppLocale.of(context));

  // --- chrome --------------------------------------------------------------
  String get title => l.pick(de: 'Profil', en: 'Profile');

  /// Semantics label of the whole sheet body.
  String profileOf(String name) => l.pick(de: 'Profil von $name', en: 'Profile of $name');

  String season(String key) => l.pick(de: 'Saison $key', en: 'Season $key');
  String get lifetime => l.pick(de: 'Gesamt', en: 'All time');

  /// 'Zuletzt am Sa, 13. Jan' / 'Noch kein Skitag'.
  String lastDay(int? ms) => ms == null
      ? l.pick(de: 'Noch kein Skitag', en: 'No ski day yet')
      : l.pick(de: 'Zuletzt am ${Fmt.dateShort(ms, locale: l.code)}', en: 'Last day ${Fmt.dateShort(ms, locale: l.code)}');

  // --- numerals (overlines; units separate) --------------------------------
  String get vertical => l.pick(de: 'Höhenmeter', en: 'Vertical');
  String get distance => l.pick(de: 'Ski-km', en: 'Ski km');
  String get runs => l.pick(de: 'Abfahrten', en: 'Runs');
  String get days => l.pick(de: 'Skitage', en: 'Ski days');
  String get unitHm => l.pick(de: 'hm', en: 'm');
  String get unitKm => 'km';
  String get unitPoints => l.pick(de: 'Pkt.', en: 'pts');

  String medals(int earned, int total) => '$earned / $total ${l.pick(de: 'Medaillen', en: 'medals')}';
  String lifetimeKm(String km) => l.pick(de: '$km km gesamt', en: '$km km all time');

  // --- actions -------------------------------------------------------------
  String get challenge => l.pick(de: 'Herausfordern', en: 'Challenge');
  String get addFriend => l.pick(de: 'Freund hinzufügen', en: 'Add friend');
  String get report => l.pick(de: 'Melden', en: 'Report');
  String get block => l.pick(de: 'Blockieren', en: 'Block');
  String get retry => l.pick(de: 'Erneut versuchen', en: 'Try again');

  /// Text of the share sheet after 'Herausfordern'.
  String challengeText(String name, String code) => l.pick(
        de: 'Ich fordere dich heraus, $name. Tagesduell in $kAppName, Code $code. Wer holt heute die meisten Höhenmeter?',
        en: 'I challenge you, $name. Day duel in $kAppName, code $code. Who grabs the most vertical today?',
      );
  String get challengeSubject => l.pick(de: 'Tagesduell', en: 'Day duel');

  // --- states --------------------------------------------------------------
  String get privateHeadline => l.pick(de: 'Dieses Profil ist privat.', en: 'This profile is private.');
  String get privateLine => l.pick(
        de: 'Der Fahrer teilt seine Zahlen nicht. Ein gemeinsames Duell oder eine Freundschaft öffnet das Profil.',
        en: 'This rider does not share their numbers. A shared duel or a friendship opens the profile.',
      );
  String get offlineHeadline => l.pick(de: 'Keine Verbindung.', en: 'No connection.');
  String get offlineLine => l.pick(de: 'Das Profil braucht Netz.', en: 'The profile needs a connection.');
  String get errorHeadline => l.pick(de: 'Hat nicht geklappt.', en: 'That did not work.');
  String get errorLine => l.pick(de: 'Versuch es gleich noch einmal.', en: 'Try again in a moment.');
  String get signInHeadline => l.pick(de: 'Dafür brauchst du ein Konto.', en: 'You need an account for that.');
  String get signInLine => l.pick(de: 'Melde dich an, dann siehst du andere Fahrer.', en: 'Sign in to see other riders.');
}
