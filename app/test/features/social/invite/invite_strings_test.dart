import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/friends/friends_api.dart';
import 'package:slopetrack/features/social/invite/invite.dart';
import 'package:slopetrack/features/social/social_api.dart';

const _de = InviteStrings(AppLocale(Locale('de')));
const _en = InviteStrings(AppLocale(Locale('en')));

void main() {
  test('duel share text carries code, working link and the store line', () {
    final t = _de.duelShareText('kmj4f2');
    expect(t, contains('Code KMJ4F2'));
    expect(t, contains(InviteLinks.share(InviteKind.duel, 'KMJ4F2')));
    expect(t, contains(InviteLinks.appStoreUrlPlaceholder));
    expect(t.split('\n'), hasLength(3));
    expect(_en.duelShareText('KMJ4F2'), startsWith('Duel in SlopeTrack: code KMJ4F2.'));
  });

  test('friend share text carries code, link and the store line', () {
    final t = _de.friendShareText('KMJ4F2');
    expect(t, startsWith('Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2'));
    expect(t, contains(InviteLinks.share(InviteKind.friend, 'KMJ4F2')));
    expect(t, contains('App laden:'));
    expect(_en.friendShareText('KMJ4F2'), contains('Get the app:'));
  });

  test('failed() maps social and friends errors to their module copy', () {
    expect(_de.failed(const SocialError(SocialErrorKind.duelFull)), 'Das Duell ist voll');
    expect(_de.failed(const FriendsError(FriendsErrorKind.self)), 'Das ist dein eigener Code');
    expect(_de.failed(StateError('x')), 'Hat nicht geklappt');
    expect(_en.failed(StateError('x')), 'That did not work');
  });

  test('toasts', () {
    expect(_de.duelJoined('KMJ4F2'), 'Duell KMJ4F2 beigetreten');
    expect(_de.savedForLater(InviteKind.duel), contains('Konto'));
    expect(_en.savedForLater(InviteKind.friend), 'Invite saved – sign in under Account');
  });
}
