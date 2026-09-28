import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/invite/invite.dart';

void main() {
  group('builders', () {
    test('duel / friend canonical links', () {
      expect(InviteLinks.duel('KMJ4F2'), 'https://slopetrack.app/d/KMJ4F2');
      expect(InviteLinks.friend('KMJ4F2'), 'https://slopetrack.app/f/KMJ4F2');
      expect(InviteLinks.duel('kmj 4f2'), 'https://slopetrack.app/d/KMJ4F2', reason: 'normalised');
    });

    test('scheme and hosted fallbacks', () {
      expect(InviteLinks.duelScheme('KMJ4F2'), 'slopetrack://d/KMJ4F2');
      expect(InviteLinks.friendScheme('KMJ4F2'), 'slopetrack://f/KMJ4F2');
      expect(InviteLinks.hosted(InviteKind.duel, 'KMJ4F2'), 'https://absolutebasti.github.io/Ski/d/?c=KMJ4F2');
      expect(InviteLinks.hosted(InviteKind.friend, 'KMJ4F2'), 'https://absolutebasti.github.io/Ski/f/?c=KMJ4F2');
    });

    test('share link is the hosted page until the custom domain is live', () {
      expect(InviteLinks.share(InviteKind.duel, 'KMJ4F2'), InviteLinks.customDomainLive ? InviteLinks.duel('KMJ4F2') : InviteLinks.hosted(InviteKind.duel, 'KMJ4F2'));
    });
  });

  group('parse round-trip', () {
    const duel = InviteLink(InviteKind.duel, 'KMJ4F2');
    const friend = InviteLink(InviteKind.friend, 'KMJ4F2');

    test('https canonical', () {
      expect(InviteLinks.parseString(InviteLinks.duel('KMJ4F2')), duel);
      expect(InviteLinks.parseString(InviteLinks.friend('KMJ4F2')), friend);
      expect(InviteLinks.parseString('https://www.slopetrack.app/d/KMJ4F2/'), duel, reason: 'trailing slash + www');
    });

    test('scheme', () {
      expect(InviteLinks.parseString(InviteLinks.duelScheme('KMJ4F2')), duel);
      expect(InviteLinks.parseString(InviteLinks.friendScheme('KMJ4F2')), friend);
      expect(InviteLinks.parseString('SLOPETRACK://D/kmj4f2'), duel, reason: 'case-insensitive');
    });

    test('hosted page forms: query, hash, index.html, /Ski prefix', () {
      expect(InviteLinks.parseString(InviteLinks.hosted(InviteKind.duel, 'KMJ4F2')), duel);
      expect(InviteLinks.parseString(InviteLinks.hosted(InviteKind.friend, 'KMJ4F2')), friend);
      expect(InviteLinks.parseString('https://absolutebasti.github.io/Ski/d/#KMJ4F2'), duel);
      expect(InviteLinks.parseString('https://absolutebasti.github.io/Ski/d/index.html?code=KMJ4F2'), duel);
      expect(InviteLinks.parseString('https://absolutebasti.github.io/Ski/f/KMJ4F2'), friend);
    });

    test('malformed links are ignored', () {
      const bad = [
        '',
        'not a link',
        'https://slopetrack.app/',
        'https://slopetrack.app/d/',
        'https://slopetrack.app/d/KMJ4F', // five chars
        'https://slopetrack.app/d/KMJ4F2X', // seven chars
        'https://slopetrack.app/d/KMJ0F2', // 0 is not in the alphabet
        'https://slopetrack.app/x/KMJ4F2', // unknown kind
        'https://slopetrack.app/privacy.html',
        'slopetrack://settings',
        'slopetrack://d',
        'mailto:hello@torchtechnology.de',
        'ftp://slopetrack.app/d/KMJ4F2',
        'https://slopetrack.app/d/KMJ4F2/extra', // code position holds a non-code
      ];
      for (final b in bad) {
        expect(InviteLinks.parseString(b), isNull, reason: b);
      }
      expect(InviteLinks.parseString(null), isNull);
      expect(InviteLinks.parseString('https://slopetrack.app/d/KMJ4F2/extra'), isNull);
    });

    test('a code from the wrong alphabet in the query is ignored too', () {
      expect(InviteLinks.parseString('https://absolutebasti.github.io/Ski/d/?c=KMJ0F2'), isNull);
    });
  });

  group('wire', () {
    test('round-trips through SharedPreferences form', () {
      const link = InviteLink(InviteKind.friend, 'ABC234');
      expect(link.wire, 'f:ABC234');
      expect(InviteLink.fromWire(link.wire), link);
      expect(InviteLink.fromWire('d:KMJ4F2'), const InviteLink(InviteKind.duel, 'KMJ4F2'));
      expect(InviteLink.fromWire(null), isNull);
      expect(InviteLink.fromWire('KMJ4F2'), isNull);
      expect(InviteLink.fromWire('x:KMJ4F2'), isNull);
      expect(InviteLink.fromWire('d:KMJ0F2'), isNull);
    });
  });
}
