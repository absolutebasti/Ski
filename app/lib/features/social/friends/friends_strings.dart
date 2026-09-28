import 'package:flutter/widgets.dart';

import '../../../app/brand.dart';
import '../invite/invite_links.dart';
import '../../../app/l10n/app_locale.dart';
import 'friends_api.dart';
import 'friends_models.dart';

/// Copy for the Freunde sheet and the Freunde-Rangliste. German first,
/// English second — sentence case, adult tone, no exclamation marks.
class FriendsStrings {
  const FriendsStrings(this.l);
  final AppLocale l;

  static FriendsStrings of(BuildContext context) => FriendsStrings(AppLocale.of(context));

  // --- chrome --------------------------------------------------------------
  String get title => l.pick(de: 'Freunde', en: 'Friends');
  String get friendsChip => title;

  // --- own code ------------------------------------------------------------
  String get myCode => l.pick(de: 'Dein Freundescode', en: 'Your friend code');
  String get myCodeLine => l.pick(
        de: 'Wer deinen Code eingibt, schickt dir eine Anfrage. Nur Freunde sehen deine Zahlen in der Freunde-Rangliste.',
        en: 'Whoever enters your code sends you a request. Only friends see your numbers on the friends board.',
      );
  String get codeUnavailable => l.pick(de: 'Code wird geladen', en: 'Loading your code');
  String get share => l.pick(de: 'Teilen', en: 'Share');
  String get copy => l.pick(de: 'Kopieren', en: 'Copy');
  String get copied => l.pick(de: 'Code kopiert', en: 'Code copied');

  /// 'Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2 · https://slopetrack.app/f/KMJ4F2'
  String shareText(String code) {
    final c = FriendCode.normalise(code);
    return l.pick(
      de: 'Fahr gegen mich in $kAppName – Freundescode $c · ${InviteLinks.share(InviteKind.friend, c)}',
      en: 'Race me in $kAppName – friend code $c · ${InviteLinks.share(InviteKind.friend, c)}',
    );
  }

  // --- add by code ---------------------------------------------------------
  String get addFriend => l.pick(de: 'Freund hinzufügen', en: 'Add a friend');
  String get codeHint => l.pick(de: 'Code eingeben', en: 'Enter code');
  String get add => l.pick(de: 'Hinzufügen', en: 'Add');
  String get requestSent => l.pick(de: 'Anfrage gesendet', en: 'Request sent');
  String get nowFriends => l.pick(de: 'Ihr seid jetzt Freunde', en: 'You are friends now');

  // --- requests ------------------------------------------------------------
  String get requests => l.pick(de: 'Anfragen', en: 'Requests');
  String get accept => l.pick(de: 'Annehmen', en: 'Accept');
  String get decline => l.pick(de: 'Ablehnen', en: 'Decline');
  String get sent => l.pick(de: 'Gesendet', en: 'Sent');
  String get waiting => l.pick(de: 'Wartet auf Antwort', en: 'Waiting for a reply');
  String get withdraw => l.pick(de: 'Zurückziehen', en: 'Withdraw');
  String get accepted => l.pick(de: 'Angenommen', en: 'Accepted');
  String get declined => l.pick(de: 'Abgelehnt', en: 'Declined');

  // --- list ----------------------------------------------------------------
  String friendsCount(int n) => switch (n) {
        0 => l.pick(de: 'Noch keine Freunde', en: 'No friends yet'),
        1 => l.pick(de: '1 Freund', en: '1 friend'),
        _ => l.pick(de: '$n Freunde', en: '$n friends'),
      };
  String get remove => l.pick(de: 'Entfernen', en: 'Remove');
  String get removed => l.pick(de: 'Entfernt', en: 'Removed');
  String get swipeHint => l.pick(de: 'Nach links wischen zum Entfernen', en: 'Swipe left to remove');
  String get emptyLine => l.pick(
        de: 'Teile deinen Code, dann füllt sich die Freunde-Rangliste.',
        en: 'Share your code and the friends board fills up.',
      );

  // --- states --------------------------------------------------------------
  String get signedOutLine => l.pick(
        de: 'Melde dich im Konto an, um Freunde hinzuzufügen.',
        en: 'Sign in under Account to add friends.',
      );
  String get offlineLine => l.pick(
        de: 'Freunde brauchen Netz. Deine Skitage sind trotzdem sicher.',
        en: 'Friends need a connection. Your ski days are safe anyway.',
      );
  String get retry => l.pick(de: 'Erneut versuchen', en: 'Try again');

  // --- board (for SOC-RANGLISTE) -------------------------------------------
  String get boardEmptyHeadline => l.pick(de: 'Noch keine Freunde hier.', en: 'No friends here yet.');
  String get boardEmptyLine => l.pick(
        de: 'Lade Freunde ein, dann seht ihr euch hier gegenseitig.',
        en: 'Invite friends and you will see each other here.',
      );
  String get invite => l.pick(de: 'Freunde einladen', en: 'Invite friends');

  // --- feedback ------------------------------------------------------------
  String error(FriendsErrorKind kind) => switch (kind) {
        FriendsErrorKind.offline => l.pick(de: 'Keine Verbindung', en: 'No connection'),
        FriendsErrorKind.notSignedIn => l.pick(de: 'Dafür brauchst du ein Konto', en: 'You need an account for that'),
        FriendsErrorKind.codeNotFound => l.pick(de: 'Diesen Code gibt es nicht', en: 'No rider with that code'),
        FriendsErrorKind.self => l.pick(de: 'Das ist dein eigener Code', en: 'That is your own code'),
        FriendsErrorKind.alreadyFriends => l.pick(de: 'Ihr seid schon verbunden', en: 'You are already connected'),
        FriendsErrorKind.requestNotFound => l.pick(de: 'Die Anfrage gibt es nicht mehr', en: 'That request is gone'),
        FriendsErrorKind.failed => l.pick(de: 'Hat nicht geklappt. Versuch es gleich noch einmal.', en: 'That did not work. Try again in a moment.'),
      };
}
