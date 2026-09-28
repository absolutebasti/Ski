import 'package:flutter/widgets.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../core/core.dart';
import '../social_models.dart';
import 'challenge_models.dart';

/// Copy for the Wochen-Challenge card, board sheet and history. German first,
/// English second — sentence case, adult tone, no exclamation marks. Labels
/// shared with the rest of the tab ('Mitmachen', 'Dabei', 'Ziel', 'Du') stay
/// in SocialStrings.
class ChallengeStrings {
  const ChallengeStrings(this.l);
  final AppLocale l;

  static ChallengeStrings of(BuildContext context) => ChallengeStrings(AppLocale.of(context));

  // --- title ---------------------------------------------------------------

  /// The title in the current language: the server column when present
  /// ([WeeklyChallenge.titleDe] / [titleEn]), the legacy German `title` on a
  /// German locale, else derived from metric + target ([title]).
  String titleOf(Challenge c) {
    if (c is WeeklyChallenge) {
      final own = l.isGerman ? c.titleDe : c.titleEn;
      if (own != null && own.isNotEmpty) return own;
    }
    if (l.isGerman && c.title.trim().isNotEmpty) return c.title;
    return title(c.metric, c.target);
  }

  /// 'Wochen-Challenge: 5.000 Höhenmeter' / 'Weekly challenge: 5,000 m vertical'
  /// — the same wording private.challenge_title() writes on the server.
  String title(SocialMetric m, double target) {
    final n = Fmt.metres(target, locale: l.code);
    final whole = target.round();
    final body = switch (m) {
      SocialMetric.dropM => l.pick(de: '$n Höhenmeter', en: '$n m vertical'),
      SocialMetric.skiDistanceM => l.pick(de: '${Fmt.km(target, decimals: 0, locale: l.code)} Ski-km', en: '${Fmt.km(target, decimals: 0, locale: l.code)} km'),
      SocialMetric.runCount => l.pick(de: whole == 1 ? '$n Abfahrt' : '$n Abfahrten', en: whole == 1 ? '$n run' : '$n runs'),
      SocialMetric.dayCount => l.pick(de: whole == 1 ? '$n Skitag' : '$n Skitage', en: whole == 1 ? '$n ski day' : '$n ski days'),
      SocialMetric.maxSpeedMs => l.pick(de: '${Fmt.kmh(target, locale: l.code)} km/h Top-Speed', en: '${Fmt.kmh(target, locale: l.code)} km/h top speed'),
      SocialMetric.points => l.pick(de: '$n Punkte', en: '$n points'),
    };
    return '${l.pick(de: 'Wochen-Challenge', en: 'Weekly challenge')}: $body';
  }

  // --- card ----------------------------------------------------------------

  /// '12 dabei · 3 geschafft' — the line under the progress bar.
  String counts(int participants, int done) {
    if (participants <= 0) return l.pick(de: 'Noch niemand dabei', en: 'Nobody in yet');
    return l.pick(de: '$participants dabei · $done geschafft', en: '$participants in · $done done');
  }

  String get openBoard => l.pick(de: 'Rangliste', en: 'Board');
  String get ended => l.pick(de: 'Die Challenge ist vorbei', en: 'This challenge is over');

  // --- board sheet ---------------------------------------------------------
  String get boardEmptyHeadline => l.pick(de: 'Noch niemand dabei.', en: 'Nobody in yet.');
  String get boardEmptyLine => l.pick(
        de: 'Mach mit, dann steht dein Name hier als Erster.',
        en: 'Join in and your name is the first one here.',
      );
  String get leave => l.pick(de: 'Challenge verlassen', en: 'Leave challenge');
  String get left => l.pick(de: 'Challenge verlassen', en: 'Left the challenge');
  String get done => l.pick(de: 'Geschafft', en: 'Done');
  String get notDone => l.pick(de: 'Nicht geschafft', en: 'Missed');
  String get retry => l.pick(de: 'Erneut versuchen', en: 'Try again');
  String get offlineLine => l.pick(
        de: 'Die Challenge braucht Netz. Deine Skitage sind trotzdem sicher.',
        en: 'The challenge needs a connection. Your ski days are safe anyway.',
      );
  String get errorLine => l.pick(de: 'Die Rangliste ließ sich nicht laden.', en: 'The board could not be loaded.');

  /// 'Platz 3 von 12' — the board and history rank.
  String rankOf(int rank, int total) => l.pick(de: 'Platz $rank von $total', en: 'Rank $rank of $total');

  // --- history -------------------------------------------------------------
  String get history => l.pick(de: 'Bisherige Challenges', en: 'Past challenges');

  /// 'Mo, 12. Jan – So, 18. Jan'
  String window(Challenge c) =>
      '${Fmt.dateShort(c.startsOn.millisecondsSinceEpoch, locale: l.code)} – ${Fmt.dateShort(c.endsOn.millisecondsSinceEpoch, locale: l.code)}';
}
