import 'package:flutter/widgets.dart';

import '../../../app/l10n/app_locale.dart';
import '../../../core/core.dart';

/// Copy of the live Tagesduell: card header, live rows, create sheet,
/// history, result card, rank teaser. German first, English second — sentence
/// case, ski vocabulary. The classic duel strings (start / join / leave /
/// errors) stay in [SocialStrings].
class DuelStrings {
  const DuelStrings(this.l);
  final AppLocale l;

  static DuelStrings of(BuildContext context) => DuelStrings(AppLocale.of(context));

  // --- card ----------------------------------------------------------------

  /// '2 / 3' — members in the duel over its capacity.
  String members(int count, int max) => '$count / $max';

  String get live => l.pick(de: 'live', en: 'live');

  /// 'vor 2 min' · 'gerade eben'.
  String ago(int minutes) => switch (minutes) {
        <= 0 => l.pick(de: 'gerade eben', en: 'just now'),
        < 60 => l.pick(de: 'vor $minutes min', en: '$minutes min ago'),
        _ => l.pick(de: 'vor ${minutes ~/ 60} h', en: '${minutes ~/ 60} h ago'),
      };

  /// 'live · vor 2 min'.
  String liveLine(int? minutes) => minutes == null ? live : '$live · ${ago(minutes)}';

  String get finished => l.pick(de: 'Tag beendet', en: 'Day ended');

  // --- create sheet --------------------------------------------------------
  String get createTitle => l.pick(de: 'Duell starten', en: 'Start duel');
  String get nameLabel => l.pick(de: 'Name (optional)', en: 'Name (optional)');
  String get nameHint => l.pick(de: 'z. B. Hahnenkamm-Crew', en: 'e.g. Hahnenkamm crew');
  String get createAction => l.pick(de: 'Los', en: 'Go');
  String get createLine => l.pick(
        de: 'Bis zu drei Fahrer, ein Tag, die meisten Höhenmeter gewinnen. Der Code gilt bis morgen.',
        en: 'Up to three riders, one day, most vertical wins. The code works until tomorrow.',
      );

  // --- history -------------------------------------------------------------
  String get history => l.pick(de: 'Vergangene Duelle', en: 'Past duels');

  String get yesterday => l.pick(de: 'Gestern', en: 'Yesterday');

  /// 'Gestern' · 'Vorgestern' · 'Mo., 12. Jan.'.
  String dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(day.year, day.month, day.day)).inDays;
    return switch (diff) {
      0 => l.pick(de: 'Heute', en: 'Today'),
      1 => yesterday,
      2 => l.pick(de: 'Vorgestern', en: 'Two days ago'),
      _ => Fmt.dateShort(day.millisecondsSinceEpoch, locale: l.code),
    };
  }

  /// 'Platz 2 von 3'.
  String place(int place, int of) => l.pick(de: 'Platz $place von $of', en: 'Place $place of $of');

  String get notOnBoard => l.pick(de: 'Ohne Wertung', en: 'Not ranked');

  /// 'Gestern · Platz 2 von 3 · 1.849 hm'.
  String historyLine({required String day, required int? place, required int of, required String hm}) =>
      place == null ? '$day · $notOnBoard' : '$day · ${this.place(place, of)} · $hm ${l.pick(de: 'hm', en: 'm')}';

  String get unitHm => l.pick(de: 'hm', en: 'm');

  // --- result card ---------------------------------------------------------
  String get result => l.pick(de: 'Tagesduell', en: 'Day duel');
  String get won => l.pick(de: 'Gewonnen', en: 'You won');
  String get pending => l.pick(de: 'Noch nicht alle im Ziel', en: 'Not everyone has finished');
  String resultLine(int? place, int of) => place == null ? notOnBoard : (place == 1 ? won : this.place(place, of));
  String get share => l.pick(de: 'Teilen', en: 'Share');
  String get you => l.pick(de: 'Du', en: 'You');
  String get winner => l.pick(de: 'Sieger', en: 'Winner');

  // --- rank teaser ---------------------------------------------------------
  String get season => l.pick(de: 'Saison', en: 'Season');

  /// 'Platz 14 in Kitzbühel · Saison' — the my_rank line on the Tagesbilanz.
  String rankTeaser(int rank, String? scopeName) => scopeName == null
      ? '${l.pick(de: 'Platz', en: 'Place')} $rank · $season'
      : '${l.pick(de: 'Platz', en: 'Place')} $rank ${l.pick(de: 'in', en: 'in')} $scopeName · $season';
}
