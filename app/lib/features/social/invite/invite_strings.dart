import 'package:flutter/widgets.dart';

import '../../../app/brand.dart';
import '../../../app/l10n/app_locale.dart';
import '../friends/friends_api.dart';
import '../friends/friends_strings.dart';
import '../social_api.dart';
import '../social_strings.dart';
import 'invite_links.dart';

/// Copy for invite links and the join flow. German first, English second —
/// sentence case, adult tone, no exclamation marks.
///
/// The share text builders are the single source for 'Duell teilen' and
/// 'Freunde einladen' (FriendsStrings.shareText routes here): code, working
/// link and — once [InviteLinks.appStoreLinkLive] — the App Store line.
class InviteStrings {
  const InviteStrings(this.l);
  final AppLocale l;

  static InviteStrings of(BuildContext context) => InviteStrings(AppLocale.of(context));

  // --- share texts ---------------------------------------------------------

  /// Duell in SlopeTrack: Code KMJ4F2. Wer holt heute die meisten Höhenmeter?
  /// `<link>` on the next line, `App laden: <store>` once the store link is live.
  String duelShareText(String code) {
    final c = InviteLinks.normaliseCode(code);
    final head = l.pick(
      de: 'Duell in $kAppName: Code $c. Wer holt heute die meisten Höhenmeter?',
      en: 'Duel in $kAppName: code $c. Who grabs the most vertical today?',
    );
    return _lines(head, InviteLinks.share(InviteKind.duel, c));
  }

  /// Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2
  /// `<link>` on the next line, `App laden: <store>` once the store link is live.
  String friendShareText(String code) {
    final c = InviteLinks.normaliseCode(code);
    final head = l.pick(
      de: 'Fahr gegen mich in $kAppName – Freundescode $c',
      en: 'Race me in $kAppName – friend code $c',
    );
    return _lines(head, InviteLinks.share(InviteKind.friend, c));
  }

  /// `App laden: <store>` — only part of a share text while
  /// [InviteLinks.appStoreLinkLive]; the placeholder id must never be shared.
  String get appStoreLine => l.pick(
        de: 'App laden: ${InviteLinks.appStoreUrlPlaceholder}',
        en: 'Get the app: ${InviteLinks.appStoreUrlPlaceholder}',
      );

  String _lines(String head, String link) => [head, link, if (InviteLinks.appStoreLinkLive) appStoreLine].join('\n');

  String get duelSubject => l.pick(de: 'Tagesduell', en: 'Day duel');
  String get friendSubject => l.pick(de: 'Freunde', en: 'Friends');

  // --- join flow toasts ----------------------------------------------------

  String duelJoined(String code) => l.pick(de: 'Duell $code beigetreten', en: 'Joined duel $code');
  String get friendRequested => l.pick(de: 'Freundschaftsanfrage gesendet', en: 'Friend request sent');
  String get friendAccepted => l.pick(de: 'Ihr seid jetzt verbunden', en: 'You are now connected');

  /// Link opened while signed out — kept and used after the next sign-in.
  String savedForLater(InviteKind kind) => switch (kind) {
        InviteKind.duel => l.pick(de: 'Duell gemerkt – melde dich im Konto an', en: 'Duel saved – sign in under Account'),
        InviteKind.friend => l.pick(de: 'Einladung gemerkt – melde dich im Konto an', en: 'Invite saved – sign in under Account'),
      };

  /// Readable line for whatever the join threw.
  String failed(Object error) {
    if (error is SocialError) return SocialStrings(l).error(error.kind);
    if (error is FriendsError) return FriendsStrings(l).error(error.kind);
    return l.pick(de: 'Hat nicht geklappt', en: 'That did not work');
  }
}
