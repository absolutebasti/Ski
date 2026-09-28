/// Display-name rules (SOC-MODERATION). Pure Dart, no Flutter — used by the
/// Konto name field (PROFILE-PAGE) and onboarding before a name goes to
/// `profiles.display_name` (the server enforces 1…24 characters).
///
/// Length counts Unicode code points (`String.runes`), so an umlaut or an
/// emoji is one character, not two UTF-16 units.
library;

/// Why a name was rejected.
enum NameRejectReason { empty, tooLong, listedWord }

/// Result of [NameRules.check]: either the normalised [name] or a [reason].
class NameCheck {
  const NameCheck.ok(this.name) : reason = null;
  const NameCheck.reject(this.reason) : name = null;

  /// Trimmed, whitespace-collapsed name; null when rejected.
  final String? name;
  final NameRejectReason? reason;

  bool get isOk => reason == null;

  @override
  String toString() => isOk ? 'NameCheck.ok($name)' : 'NameCheck.reject(${reason!.name})';

  @override
  bool operator ==(Object other) => other is NameCheck && other.name == name && other.reason == reason;

  @override
  int get hashCode => Object.hash(name, reason);
}

class NameRules {
  const NameRules._();

  /// Same limit as the `profiles.display_name` check constraint.
  static const int maxLength = 24;

  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Slurs and profanity (DE/EN) plus names that impersonate the app. Words
  /// with ≥ 5 letters also hit as part of a longer token ('Arschloch99'),
  /// shorter ones only as a whole token so real names survive.
  static const List<String> listedWords = [
    // de
    'arsch', 'arschloch', 'fick', 'ficker', 'fotze', 'hure', 'hurensohn', 'wichser', 'schlampe', 'nutte',
    'scheisse', 'missgeburt', 'spasti', 'schwuchtel', 'kanake', 'neger', 'nazi', 'hitler', 'judensau',
    // en
    'fuck', 'fucker', 'shit', 'bitch', 'cunt', 'asshole', 'pussy', 'nigger', 'nigga', 'faggot', 'retard',
    'whore', 'slut', 'wanker', 'twat', 'bastard', 'motherfucker',
    // impersonation
    'slopetrack', 'admin', 'moderator',
  ];

  static final Set<String> _whole = listedWords.toSet();
  static final List<String> _partial = listedWords.where((w) => w.length >= 5).toList();

  /// Trim and collapse inner whitespace: ' Lena  B. ' → 'Lena B.'.
  static String normalize(String raw) => raw.trim().replaceAll(_ws, ' ');

  /// Number of characters as the rule counts them (code points).
  static int length(String name) => name.runes.length;

  /// Lower-case, ß → ss, diacritics folded for the letters the list uses.
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('ß', 'ss')
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e');

  /// True when [name] contains a listed word (whole token, or as part of a
  /// token for the longer words).
  static bool containsListedWord(String name) {
    final folded = _fold(name);
    final tokens = folded.split(_nonWord).where((t) => t.isNotEmpty);
    for (final t in tokens) {
      if (_whole.contains(t)) return true;
      for (final w in _partial) {
        if (t.contains(w)) return true;
      }
    }
    return false;
  }

  /// The rule: normalise → not empty → ≤ [maxLength] characters → no listed word.
  static NameCheck check(String raw) {
    final name = normalize(raw);
    if (name.isEmpty) return const NameCheck.reject(NameRejectReason.empty);
    if (length(name) > maxLength) return const NameCheck.reject(NameRejectReason.tooLong);
    if (containsListedWord(name)) return const NameCheck.reject(NameRejectReason.listedWord);
    return NameCheck.ok(name);
  }
}
