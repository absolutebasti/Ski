import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard: no German copy in the data models or the profile service
/// (SOC-NAME-FALLBACK). Models keep what the server sends; user-facing text
/// lives in `<feature>_strings.dart` or goes through `riderName`
/// (social/rider_name.dart). Reads the sources, so a literal like the old
/// `?? 'Skifahrer'` fails here before it ships.
///
/// Only string literals count — comments may stay German.
void main() {
  test('no German string literal in features/**/*_models.dart and profile_service.dart', () {
    final files = [
      ...Directory('lib/features').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('_models.dart')),
      File('lib/features/account/profile_service.dart'),
    ];
    expect(files.length, greaterThanOrEqualTo(7), reason: 'test runs from the app directory');
    final hits = <String>[
      for (final f in files)
        for (final literal in germanLiterals(f.readAsStringSync())) '${f.path}: \'$literal\'',
    ];
    expect(hits, isEmpty);
  });

  group('the detector', () {
    test('flags the old parser fallback and umlauts', () {
      expect(germanLiterals("displayName: (j['display_name'] as String?) ?? 'Skifahrer',"), ['Skifahrer']);
      expect(germanLiterals("const t = 'Höhe';"), ['Höhe']);
      expect(germanLiterals('final s = "Dein Freund";'), ['Dein Freund']);
      expect(germanLiterals("final s = '''\nNoch kein Tag\n''';"), hasLength(1));
      expect(germanLiterals(r"final s = '${a ? 'x' : 'y'} Duell';"), hasLength(1));
    });

    test('ignores comments, wire keys, directives and English', () {
      const src = '''
import 'package:flutter/foundation.dart';
/// Rangliste — Höhenmeter, Skifahrer, Freunde.
// 'Skifahrer' in a comment is fine
/* Duell 'Gebiet' */
final a = j['display_name'] as String?;
final b = 'Profile(\$id, \$displayName)';
final c = 'profile load failed: \$e';
final d = r'\\s+';
''';
      expect(germanLiterals(src), isEmpty);
    });
  });
}

final RegExp _umlaut = RegExp('[äöüÄÖÜß]');

/// Nouns of the app's German vocabulary plus a few function words that never
/// appear in English copy.
final RegExp _germanWord = RegExp(
  r'\b(Skifahrer\w*|Fahrer\w*|Freund\w*|Duell\w*|Gebiet\w*|Rangliste\w*|Saison\w*|Abfahrt\w*|Liftfahrt\w*|Skitag\w*|'
  r'Tag|Tage|Woche|Monat|Platz|Profil|Konto|Heute|Gast|Unbekannt\w*|Anonym|Teilnehmer\w*|Einladung\w*|Herausforder\w*|'
  r'und|oder|nicht|kein\w*|noch|dein\w*|mit|ohne)\b',
);

/// String literals of [source] that read German.
List<String> germanLiterals(String source) =>
    _Scanner(source).literals().where((s) => !_isDirective(s) && (_umlaut.hasMatch(s) || _germanWord.hasMatch(s))).toList();

bool _isDirective(String s) => s.startsWith('package:') || s.startsWith('dart:') || s.endsWith('.dart');

/// Minimal Dart lexer: collects the text of every string literal (single,
/// double, triple, raw; interpolations recurse) and skips comments.
class _Scanner {
  _Scanner(this.s);
  final String s;
  int i = 0;
  final List<String> _out = [];

  List<String> literals() {
    _code(untilBrace: false);
    return _out;
  }

  void _code({required bool untilBrace}) {
    var depth = 0;
    while (i < s.length) {
      final c = s[i];
      if (s.startsWith('//', i)) {
        final nl = s.indexOf('\n', i);
        i = nl < 0 ? s.length : nl + 1;
      } else if (s.startsWith('/*', i)) {
        _blockComment();
      } else if (c == "'" || c == '"') {
        _string(raw: false);
      } else if ((c == 'r' || c == 'R') && i + 1 < s.length && (s[i + 1] == "'" || s[i + 1] == '"') && (i == 0 || !_ident(s[i - 1]))) {
        i++;
        _string(raw: true);
      } else {
        if (untilBrace && c == '{') depth++;
        if (untilBrace && c == '}') {
          if (depth == 0) {
            i++;
            return;
          }
          depth--;
        }
        i++;
      }
    }
  }

  void _blockComment() {
    var depth = 0;
    while (i < s.length) {
      if (s.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (s.startsWith('*/', i)) {
        depth--;
        i += 2;
        if (depth == 0) return;
      } else {
        i++;
      }
    }
  }

  void _string({required bool raw}) {
    final q = s[i];
    final close = s.startsWith(q * 3, i) ? q * 3 : q;
    i += close.length;
    final buf = StringBuffer();
    while (i < s.length) {
      if (s.startsWith(close, i)) {
        i += close.length;
        break;
      }
      final c = s[i];
      if (!raw && c == r'\') {
        if (i + 1 < s.length) buf.write(s[i + 1]);
        i += 2;
      } else if (!raw && c == r'$' && i + 1 < s.length && s[i + 1] == '{') {
        i += 2;
        _code(untilBrace: true);
        buf.write(' ');
      } else if (close.length == 1 && c == '\n') {
        i++;
        break;
      } else {
        buf.write(c);
        i++;
      }
    }
    _out.add(buf.toString());
  }

  static bool _ident(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);
}
