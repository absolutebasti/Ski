import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/moderation/moderation.dart';

void main() {
  group('NameRules.check', () {
    test('normal names pass, normalised', () {
      for (final n in ['Lena Bergmann', 'Sebastian Fackelmann', 'Paul M.', 'Jürgen Aßmann', 'Dick Müller', 'Nina 🎿', 'Ski-Hase 99']) {
        final r = NameRules.check(n);
        expect(r.isOk, isTrue, reason: n);
        expect(r.name, n);
      }
    });

    test('trims and collapses whitespace', () {
      expect(NameRules.check(' Lena  B. '), const NameCheck.ok('Lena B.'));
      expect(NameRules.normalize('\tTom\n  Huber '), 'Tom Huber');
    });

    test('empty and whitespace-only are rejected', () {
      expect(NameRules.check(''), const NameCheck.reject(NameRejectReason.empty));
      expect(NameRules.check('   '), const NameCheck.reject(NameRejectReason.empty));
    });

    test('25 characters are rejected, 24 pass', () {
      expect(NameRules.check('a' * 25), const NameCheck.reject(NameRejectReason.tooLong));
      expect(NameRules.check('a' * 24).isOk, isTrue);
    });

    test('length counts characters, not UTF-16 units — umlauts and emoji', () {
      expect(NameRules.length('Ä' * 24), 24);
      expect(NameRules.check('Ä' * 24).isOk, isTrue);
      expect(NameRules.check('Ä' * 25), const NameCheck.reject(NameRejectReason.tooLong));
      // '🎿' is two UTF-16 code units but one character.
      expect(('🎿' * 24).length, 48);
      expect(NameRules.check('🎿' * 24).isOk, isTrue);
      expect(NameRules.check('🎿' * 25), const NameCheck.reject(NameRejectReason.tooLong));
    });

    test('a listed word is rejected — whole, in compounds, any case, ß/ss', () {
      for (final n in ['Hurensohn', 'HURENSOHN', 'Arschloch99', 'Lena Fotze', 'Scheiße', 'fuck you', 'MotherFucker', 'Nazi Lena', 'SlopeTrack Team', 'Admin']) {
        expect(NameRules.check(n), const NameCheck.reject(NameRejectReason.listedWord), reason: n);
      }
    });

    test('short listed words only hit as whole tokens', () {
      expect(NameRules.containsListedWord('Fickinger'), isFalse);
      expect(NameRules.containsListedWord('Ignazia'), isFalse);
      expect(NameRules.containsListedWord('Hurenkind'), isFalse);
      expect(NameRules.containsListedWord('fick dich'), isTrue);
    });

    test('too long wins over a listed word; the rule normalises first', () {
      expect(NameRules.check('Hurensohn ${'x' * 20}'), const NameCheck.reject(NameRejectReason.tooLong));
      expect(NameRules.check(' ${'a' * 24} ').isOk, isTrue, reason: 'padding does not count');
    });
  });

  group('DisplayNamePolicy.validate', () {
    test('null for a fine name, German hint by default, English on request', () {
      expect(DisplayNamePolicy.validate('Lena B.'), isNull);
      expect(DisplayNamePolicy.validate('a' * 25), 'Höchstens 24 Zeichen.');
      expect(DisplayNamePolicy.validate('Arschloch'), 'Dieser Name geht nicht. Wähl einen anderen.');
      expect(DisplayNamePolicy.validate(''), 'Gib einen Namen ein.');
      expect(DisplayNamePolicy.validate('a' * 25, locale: const AppLocale(Locale('en'))), 'At most 24 characters.');
      expect(DisplayNamePolicy.validate('Arschloch', locale: const AppLocale(Locale('en'))), 'That name is not allowed. Pick another one.');
      expect(DisplayNamePolicy.normalized(' Lena  B. '), 'Lena B.');
      expect(DisplayNamePolicy.normalized('Arschloch'), isNull);
      expect(DisplayNamePolicy.maxLength, 24);
    });
  });

  group('ReportReason.encode', () {
    test('wire prefix, optional note, hard cap at 200 characters', () {
      expect(ReportReason.cheating.encode(null), 'cheating');
      expect(ReportReason.cheating.encode('  '), 'cheating');
      expect(ReportReason.other.encode(' 4.000 hm in 10 Minuten '), 'other: 4.000 hm in 10 Minuten');
      final long = ReportReason.offensiveName.encode('ä' * 300);
      expect(long.runes.length, 200);
      expect(long, startsWith('offensive_name: '));
    });
  });
}
