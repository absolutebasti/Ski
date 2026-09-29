import 'package:flutter/foundation.dart';

/// What an invite link points at.
enum InviteKind {
  /// `/d/<CODE>` — a Tagesduell code (`groups.code`).
  duel('d'),

  /// `/f/<CODE>` — a friend code (`profiles.friend_code`).
  friend('f');

  const InviteKind(this.segment);

  /// Path segment of the link.
  final String segment;

  static InviteKind? fromSegment(String s) => switch (s) {
        'd' => duel,
        'f' => friend,
        _ => null,
      };
}

/// A parsed invite: kind + normalised six-character code.
@immutable
class InviteLink {
  const InviteLink(this.kind, this.code);
  final InviteKind kind;
  final String code;

  /// Wire form for SharedPreferences: `d:KMJ4F2`.
  String get wire => '${kind.segment}:$code';

  static InviteLink? fromWire(String? wire) {
    if (wire == null) return null;
    final i = wire.indexOf(':');
    if (i < 0) return null;
    final kind = InviteKind.fromSegment(wire.substring(0, i));
    final code = InviteLinks.normaliseCode(wire.substring(i + 1));
    if (kind == null || !InviteLinks.isValidCode(code)) return null;
    return InviteLink(kind, code);
  }

  @override
  bool operator ==(Object other) => other is InviteLink && other.kind == kind && other.code == code;

  @override
  int get hashCode => Object.hash(kind, code);

  @override
  String toString() => 'InviteLink(${kind.name}, $code)';
}

/// Builds and parses invite links (SOC-DEEPLINK).
///
/// Three forms exist, all of which [parse] understands:
///   * canonical Universal Link — `https://slopetrack.app/d/KMJ4F2`
///   * hosted fallback page — `https://absolutebasti.github.io/Ski/d/?c=KMJ4F2`
///     (GitHub Pages cannot rewrite paths, so the code travels in the query;
///     the page also accepts it in the hash: `/d/#KMJ4F2`)
///   * custom scheme — `slopetrack://d/KMJ4F2` (works without an
///     apple-app-site-association; used by the 'In SlopeTrack öffnen' button)
///
/// Codes use the duel/friend alphabet (no 0/O/1/I/L). Anything that is not
/// six characters of that alphabet is not an invite.
class InviteLinks {
  const InviteLinks._();

  /// The product domain. Not registered yet (2026-09-27) — see
  /// [customDomainLive]. Universal Links and the AASA are prepared for it.
  static const String webBase = 'https://slopetrack.app';

  /// GitHub Pages project site that hosts docs/d and docs/f today.
  static const String pagesBase = 'https://absolutebasti.github.io/Ski';

  /// Flip to `true` once slopetrack.app resolves and serves
  /// docs/.well-known/apple-app-site-association. Until then share texts use
  /// the hosted fallback so a tapped invite always lands on a working page.
  static const bool customDomainLive = false;

  static const String scheme = 'slopetrack';

  /// App Store link placeholder — replace with `kAppStoreUrl` from
  /// app/brand.dart once the App Store Connect record exists (asks_lead).
  static const String appStoreUrlPlaceholder = 'https://apps.apple.com/app/slopetrack/id0000000000';

  /// True once [appStoreUrlPlaceholder] points at a real App Store record.
  /// Share texts carry the 'App laden' line only then — a dead store link in
  /// a message reads as broken.
  static bool get appStoreLinkLive => !appStoreUrlPlaceholder.endsWith('/id0000000000');

  static const String codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int codeLength = 6;

  // --- builders ------------------------------------------------------------

  /// `https://slopetrack.app/d/KMJ4F2`
  static String duel(String code) => canonical(InviteKind.duel, code);

  /// `https://slopetrack.app/f/KMJ4F2`
  static String friend(String code) => canonical(InviteKind.friend, code);

  /// `slopetrack://d/KMJ4F2`
  static String duelScheme(String code) => schemeLink(InviteKind.duel, code);

  /// `slopetrack://f/KMJ4F2`
  static String friendScheme(String code) => schemeLink(InviteKind.friend, code);

  static String canonical(InviteKind kind, String code) => '$webBase/${kind.segment}/${normaliseCode(code)}';

  static String schemeLink(InviteKind kind, String code) => '$scheme://${kind.segment}/${normaliseCode(code)}';

  /// `https://absolutebasti.github.io/Ski/d/?c=KMJ4F2` — the page that works
  /// today (docs/d/index.html).
  static String hosted(InviteKind kind, String code) => '$pagesBase/${kind.segment}/?c=${normaliseCode(code)}';

  /// The link that goes into share texts: canonical once the domain is live,
  /// hosted fallback until then.
  static String share(InviteKind kind, String code) => customDomainLive ? canonical(kind, code) : hosted(kind, code);

  // --- parsing -------------------------------------------------------------

  /// Parses any of the three link forms; null for everything else.
  static InviteLink? parseString(String? link) {
    if (link == null) return null;
    final uri = Uri.tryParse(link.trim());
    return uri == null ? null : parse(uri);
  }

  static InviteLink? parse(Uri uri) {
    final s = uri.scheme.toLowerCase();
    final segments = <String>[];
    if (s == scheme) {
      // slopetrack://d/KMJ4F2 → host 'd', path '/KMJ4F2'.
      if (uri.host.isNotEmpty) segments.add(uri.host.toLowerCase());
    } else if (s != 'https' && s != 'http') {
      return null;
    }
    for (final p in uri.pathSegments) {
      final seg = p.trim();
      if (seg.isEmpty || seg.toLowerCase() == 'index.html') continue;
      segments.add(seg);
    }
    // The last d/f segment wins: '/Ski/d/KMJ4F2' as well as '/d/KMJ4F2'.
    int at = -1;
    InviteKind? kind;
    for (var i = segments.length - 1; i >= 0; i--) {
      final k = InviteKind.fromSegment(segments[i].toLowerCase());
      if (k != null) {
        at = i;
        kind = k;
        break;
      }
    }
    if (kind == null) return null;
    // Anything after the code segment ('/d/KMJ4F2/extra') is not an invite.
    if (at + 2 < segments.length) return null;
    final candidates = <String?>[
      if (at + 1 < segments.length) segments[at + 1],
      uri.queryParameters['c'],
      uri.queryParameters['code'],
      uri.fragment,
    ];
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final code = normaliseCode(c);
      // A path segment after d/f that is not a code means it is not an invite.
      if (!isValidCode(code)) return null;
      return InviteLink(kind, code);
    }
    return null;
  }

  /// Upper case, everything but letters and digits stripped. No folding of
  /// 0→O etc. — the alphabet has no ambiguous glyph, a code containing one was
  /// mistyped and must not be silently rewritten.
  static String normaliseCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValidCode(String code) => code.length == codeLength && code.split('').every(codeAlphabet.contains);
}
