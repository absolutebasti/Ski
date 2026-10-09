import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/brand.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/friends/friends_api.dart';
import 'package:slopetrack/features/social/friends/friends_strings.dart';
import 'package:slopetrack/features/social/invite/invite.dart';
import 'package:slopetrack/features/social/social_api.dart';

const _de = InviteStrings(AppLocale(Locale('de')));
const _en = InviteStrings(AppLocale(Locale('en')));

void main() {
  test('duel share text carries code and working link; no store line while the placeholder id is in place', () {
    final t = _de.duelShareText('kmj4f2');
    expect(t, contains('Code KMJ4F2'));
    expect(t, contains(InviteLinks.share(InviteKind.duel, 'KMJ4F2')));
    expect(InviteLinks.appStoreLinkLive, isFalse, reason: 'set kAppStoreUrl to the real record and this test changes');
    expect(t, isNot(contains('apps.apple.com')));
    expect(t, isNot(contains('App laden')));
    expect(t.split('\n'), hasLength(2));
    expect(_en.duelShareText('KMJ4F2'), startsWith('Duel in SlopeTrack: code KMJ4F2.'));
    expect(_en.duelShareText('KMJ4F2'), isNot(contains('Get the app')));
  });

  test('friend share text carries code and link; no store line while the placeholder id is in place', () {
    final t = _de.friendShareText('KMJ4F2');
    expect(t, startsWith('Fahr gegen mich in SlopeTrack – Freundescode KMJ4F2\n'));
    expect(t, contains(InviteLinks.share(InviteKind.friend, 'KMJ4F2')));
    expect(t, isNot(contains('App laden:')));
    expect(t.split('\n'), hasLength(2));
    expect(_en.friendShareText('KMJ4F2'), startsWith('Race me in SlopeTrack – friend code KMJ4F2\n'));
    expect(_en.friendShareText('KMJ4F2'), isNot(contains('Get the app:')));
  });

  test('the App Store line itself still exists for the day the record is live', () {
    expect(_de.appStoreLine, startsWith('App laden: $kAppStoreUrl'));
    expect(_en.appStoreLine, startsWith('Get the app: $kAppStoreUrl'));
  });

  test('no share text and no friends/invite source but the placeholder constant carries id0000000000', () {
    for (final s in [_de, _en]) {
      for (final t in [s.duelShareText('KMJ4F2'), s.friendShareText('KMJ4F2'), FriendsStrings(s.l).shareText('KMJ4F2')]) {
        expect(t, isNot(contains('id0000000000')));
      }
    }
    // The constant lives in invite_links.dart and nowhere else.
    final files = [
      for (final dir in ['lib/features/social/friends', 'lib/features/social/invite'])
        ...Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
    expect(files, isNotEmpty, reason: 'test runs from the app directory');
    for (final f in files) {
      if (f.path.endsWith('invite_links.dart')) continue;
      expect(f.readAsStringSync(), isNot(contains('id0000000000')), reason: f.path);
    }
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
