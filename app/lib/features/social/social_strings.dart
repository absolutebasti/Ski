import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';
import 'social_api.dart';
import 'social_models.dart';

/// Copy for the Rangliste tab (Top-Board, Tagesduell, Wochen-Challenge).
/// German first, English second — sentence case, ski vocabulary.
class SocialStrings {
  const SocialStrings(this.l);
  final AppLocale l;

  static SocialStrings of(BuildContext context) => SocialStrings(AppLocale.of(context));

  // --- chrome --------------------------------------------------------------
  String get title => l.pick(de: 'Rangliste', en: 'Leaderboard');
  String get allResorts => l.pick(de: 'Alle Gebiete', en: 'All resorts');
  String get you => l.pick(de: 'Du', en: 'You');
  String get rank => l.pick(de: 'Platz', en: 'Rank');
  String get retry => l.pick(de: 'Erneut versuchen', en: 'Try again');
  String get cancel => l.pick(de: 'Abbrechen', en: 'Cancel');

  String period(LeaderboardPeriod p) => switch (p) {
        LeaderboardPeriod.season => l.pick(de: 'Saison', en: 'Season'),
        LeaderboardPeriod.month => l.pick(de: 'Monat', en: 'Month'),
        LeaderboardPeriod.week => l.pick(de: 'Woche', en: 'Week'),
      };

  List<String> get periods => LeaderboardPeriod.values.map(period).toList();

  String metric(SocialMetric m) => switch (m) {
        SocialMetric.dropM => l.pick(de: 'Höhenmeter', en: 'Vertical'),
        SocialMetric.runCount => l.pick(de: 'Abfahrten', en: 'Runs'),
        SocialMetric.skiDistanceM => l.pick(de: 'Ski-km', en: 'Ski km'),
        SocialMetric.maxSpeedMs => l.pick(de: 'Top-Speed', en: 'Top speed'),
        SocialMetric.dayCount => l.pick(de: 'Skitage', en: 'Ski days'),
      };

  /// Numeral and unit for a metric value; the unit is drawn as separate
  /// tertiary text, never inside the numeral (docs/DESIGN.md §3).
  (String, String?) value(SocialMetric m, double v) => switch (m) {
        SocialMetric.dropM => (Fmt.metres(v, locale: l.code), unitHm),
        SocialMetric.runCount => (v.round().toString(), null),
        SocialMetric.skiDistanceM => (Fmt.km(v, locale: l.code), 'km'),
        SocialMetric.maxSpeedMs => (Fmt.kmh(v, locale: l.code), 'km/h'),
        SocialMetric.dayCount => (v.round().toString(), l.pick(de: 'Tage', en: 'days')),
      };

  String valueLine(SocialMetric m, double v) {
    final (n, unit) = value(m, v);
    return unit == null ? n : '$n $unit';
  }

  String get unitHm => l.pick(de: 'hm', en: 'm');

  String caption(LeaderboardPeriod p, String seasonKey, String? resortName) {
    final head = switch (p) {
      LeaderboardPeriod.season => '${period(p)} $seasonKey',
      LeaderboardPeriod.month => l.pick(de: 'Dieser Monat', en: 'This month'),
      LeaderboardPeriod.week => l.pick(de: 'Diese Woche', en: 'This week'),
    };
    return resortName == null ? '$head · $allResorts' : '$head · $resortName';
  }

  /// 'Du · Platz 14 · 12.480 hm'
  String ownRow(int place, SocialMetric m, double v) => '$you · $rank $place · ${valueLine(m, v)}';

  String get notRankedYet => l.pick(de: 'Du bist noch nicht gewertet', en: 'You are not ranked yet');

  // --- states --------------------------------------------------------------
  String get signedOutHeadline => l.pick(de: 'Hol dir Platz 1.', en: 'Go for first place.');
  String signedOutLine(String? resortName) => resortName == null
      ? l.pick(de: 'Melde dich an und fahr gegen alle anderen.', en: 'Sign in and race everyone else.')
      : l.pick(de: 'Melde dich an und hol dir Platz 1 in $resortName.', en: 'Sign in and take first place in $resortName.');
  String get signIn => l.pick(de: 'Mit Apple anmelden', en: 'Sign in with Apple');

  String get optInHeadline => l.pick(de: 'Deine Zahlen sind noch privat.', en: 'Your numbers are still private.');
  String get optInLine => l.pick(
        de: 'Schalte die Rangliste frei, dann tauchst du mit deinem Namen auf.',
        en: 'Turn the leaderboard on and you show up with your name.',
      );
  String get optInAction => l.pick(de: 'Rangliste freischalten', en: 'Turn leaderboard on');

  String get offlineHeadline => l.pick(de: 'Keine Verbindung.', en: 'No connection.');
  String get offlineLine => l.pick(
        de: 'Die Rangliste braucht Netz. Deine Skitage sind trotzdem sicher.',
        en: 'The leaderboard needs a connection. Your ski days are safe anyway.',
      );

  String emptyHeadline(String? resortName) =>
      resortName == null ? l.pick(de: 'Noch ist es leer.', en: 'Nothing here yet.') : l.pick(de: 'Sei der Erste in $resortName.', en: 'Be the first in $resortName.');
  String get emptyLine => l.pick(
        de: 'Noch niemand gewertet. Hol deine Freunde dazu.',
        en: 'Nobody ranked yet. Bring your friends along.',
      );
  String get invite => l.pick(de: 'Freunde einladen', en: 'Invite friends');
  String get inviteText => l.pick(
        de: 'Fahr gegen mich in SlopeTrack – Abfahrten, Höhenmeter, Top-Speed.',
        en: 'Race me in SlopeTrack – runs, vertical, top speed.',
      );

  // --- Tagesduell ----------------------------------------------------------
  String get duel => l.pick(de: 'Tagesduell', en: 'Day duel');
  String get duelIdleLine => l.pick(
        de: 'Fahr heute gegen deine Freunde. Wer holt die meisten Höhenmeter?',
        en: 'Race your friends today. Who grabs the most vertical?',
      );
  String get duelStart => l.pick(de: 'Duell starten', en: 'Start duel');
  String get duelJoin => l.pick(de: 'Code eingeben', en: 'Enter code');
  String get duelShare => l.pick(de: 'Duell teilen', en: 'Share duel');
  String get duelLeave => l.pick(de: 'Verlassen', en: 'Leave');
  String get duelCode => l.pick(de: 'Code', en: 'Code');
  String get duelName => l.pick(de: 'Name des Duells', en: 'Duel name');
  String get duelDefaultName => l.pick(de: 'Tagesduell', en: 'Day duel');
  String get duelCodeHint => l.pick(de: 'Sechs Zeichen, z. B. KMJ4F2', en: 'Six characters, e.g. KMJ4F2');
  String duelShareText(String code) => l.pick(
        de: 'Duell in SlopeTrack: Code $code. Wer holt heute die meisten Höhenmeter?',
        en: 'Duel in SlopeTrack: code $code. Who grabs the most vertical today?',
      );
  String get duelWaiting => l.pick(de: 'Wartet auf Mitfahrer', en: 'Waiting for riders');
  String get duelLeader => l.pick(de: 'Führt', en: 'Leading');

  // --- Wochen-Challenge ----------------------------------------------------
  String get challenge => l.pick(de: 'Wochen-Challenge', en: 'Weekly challenge');
  String get challengeJoin => l.pick(de: 'Mitmachen', en: 'Join in');
  String get challengeIn => l.pick(de: 'Dabei', en: "You're in");
  String get challengeTarget => l.pick(de: 'Ziel', en: 'Target');
  String get challengeUpdate => l.pick(de: 'Stand melden', en: 'Update');
  String challengeDaysLeft(int days) => switch (days) {
        <= 0 => l.pick(de: 'Letzter Tag', en: 'Last day'),
        1 => l.pick(de: 'Noch 1 Tag', en: '1 day left'),
        _ => l.pick(de: 'Noch $days Tage', en: '$days days left'),
      };
  String challengeProgress(SocialMetric m, double value, double target) => '${valueLine(m, value)} / ${valueLine(m, target)}';

  // --- feedback ------------------------------------------------------------
  String get signInFirst => l.pick(de: 'Dafür brauchst du ein Konto', en: 'You need an account for that');
  String get duelCreated => l.pick(de: 'Duell läuft', en: 'Duel is live');
  String get duelJoined => l.pick(de: 'Du bist dabei', en: "You're in");
  String get duelLeft => l.pick(de: 'Duell verlassen', en: 'Left the duel');
  String get challengeJoined => l.pick(de: 'Du machst mit', en: 'You joined in');

  String error(SocialErrorKind kind) => switch (kind) {
        SocialErrorKind.offline => l.pick(de: 'Keine Verbindung', en: 'No connection'),
        SocialErrorKind.notSignedIn => signInFirst,
        SocialErrorKind.codeNotFound => l.pick(de: 'Diesen Code gibt es nicht', en: 'No duel with that code'),
        SocialErrorKind.duelFull => l.pick(de: 'Das Duell ist voll', en: 'The duel is full'),
        SocialErrorKind.alreadyMember => duelJoined,
        SocialErrorKind.failed => l.pick(de: 'Hat nicht geklappt', en: 'That did not work'),
      };
}
