import 'package:flutter/widgets.dart';

import '../../../app/l10n/app_locale.dart';
import 'moderation_api.dart';
import 'name_rules.dart';

/// Copy for Melden / Blockieren and the display-name rule. German first,
/// English second — sentence case, adult tone, no exclamation marks.
///
/// ---------------------------------------------------------------------------
/// REVIEW NOTE — paragraph for docs/APP-STORE.md › "Notes for Reviewer"
/// (pasted by SETTINGS-RELEASE; Apple guideline 1.2 user-generated content):
///
/// User-generated content is limited to display names (max. 24 characters,
/// filtered on device against a DE/EN word list before they are saved) and
/// avatars. Every rider profile reached from a leaderboard, duel or friends
/// list offers "Melden" (Report) with a reason and "Blockieren" (Block).
/// Reports are stored server-side with reporter, target and reason and are
/// reviewed within 24 hours; the support address is in Settings › Support.
/// Blocking hides the blocked rider from the user's leaderboards, duel boards
/// and friends list immediately and ends an existing friendship; the user can
/// undo it from the same profile. No messaging, comments or free-text posts
/// exist in the app.
/// ---------------------------------------------------------------------------
class ModerationStrings {
  const ModerationStrings(this.l);
  final AppLocale l;

  static ModerationStrings of(BuildContext context) => ModerationStrings(AppLocale.of(context));

  // --- report ------------------------------------------------------------------
  String get reportTitle => l.pick(de: 'Melden', en: 'Report');
  String reportQuestion(String name) => l.pick(de: 'Was stimmt mit dem Profil von $name nicht?', en: 'What is wrong with the profile of $name?');
  String reason(ReportReason r) => switch (r) {
        ReportReason.offensiveName => l.pick(de: 'Anstößiger Name', en: 'Offensive name'),
        ReportReason.offensiveImage => l.pick(de: 'Anstößiges Profilbild', en: 'Offensive profile photo'),
        ReportReason.cheating => l.pick(de: 'Betrug/unrealistische Werte', en: 'Cheating / unrealistic values'),
        ReportReason.other => l.pick(de: 'Sonstiges', en: 'Other'),
      };
  String get detailsHint => l.pick(de: 'Optional: kurz beschreiben', en: 'Optional: a short note');
  String get reportSubmit => l.pick(de: 'Melden', en: 'Report');
  String get reportThanks => l.pick(de: 'Danke, wir schauen uns das an', en: 'Thanks, we will take a look');
  String get reportLine => l.pick(
        de: 'Wir prüfen die Meldung innerhalb von 24 Stunden. Der Fahrer erfährt nicht, wer gemeldet hat.',
        en: 'We review reports within 24 hours. The rider does not learn who reported them.',
      );

  // --- block -------------------------------------------------------------------
  String get blockTitle => l.pick(de: 'Blockieren', en: 'Block');
  String blockQuestion(String name) => l.pick(de: '$name blockieren?', en: 'Block $name?');
  String get blockLine => l.pick(
        de: 'Du siehst diesen Fahrer nicht mehr in Ranglisten und Duellen. Eine Freundschaft wird beendet. Aufheben kannst du das jederzeit im Profil.',
        en: 'You will no longer see this rider in leaderboards or duels. A friendship ends. You can undo this any time from the profile.',
      );
  String get blockConfirm => l.pick(de: 'Blockieren', en: 'Block');
  String get cancel => l.pick(de: 'Abbrechen', en: 'Cancel');
  String get blocked => l.pick(de: 'Blockiert', en: 'Blocked');
  String get unblock => l.pick(de: 'Blockierung aufheben', en: 'Unblock');
  String get unblocked => l.pick(de: 'Blockierung aufgehoben', en: 'Unblocked');

  // --- feedback ----------------------------------------------------------------
  String error(ModerationErrorKind kind) => switch (kind) {
        ModerationErrorKind.offline => l.pick(de: 'Keine Verbindung', en: 'No connection'),
        ModerationErrorKind.notSignedIn => l.pick(de: 'Dafür brauchst du ein Konto', en: 'You need an account for that'),
        ModerationErrorKind.failed => l.pick(de: 'Hat nicht geklappt. Versuch es gleich noch einmal.', en: 'That did not work. Try again in a moment.'),
      };

  // --- display-name rule -------------------------------------------------------
  String nameRejected(NameRejectReason reason) => switch (reason) {
        NameRejectReason.empty => l.pick(de: 'Gib einen Namen ein.', en: 'Enter a name.'),
        NameRejectReason.tooLong => l.pick(de: 'Höchstens ${NameRules.maxLength} Zeichen.', en: 'At most ${NameRules.maxLength} characters.'),
        NameRejectReason.listedWord => l.pick(de: 'Dieser Name geht nicht. Wähl einen anderen.', en: 'That name is not allowed. Pick another one.'),
      };
}
