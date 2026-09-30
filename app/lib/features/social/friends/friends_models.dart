import 'package:flutter/foundation.dart';

import '../social_models.dart' show parseDisplayName;

/// State of a `friendships` row as the client sees it.
enum FriendshipStatus {
  pending,
  accepted;

  static FriendshipStatus fromWire(String? wire) => wire == 'accepted' ? accepted : pending;
}

/// One row of the `friends_list` RPC — the other party of a friendship.
@immutable
class Friend {
  const Friend({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.countryCode,
    this.status = FriendshipStatus.accepted,
    this.incoming = false,
    this.createdAt,
  });

  final String userId;

  /// As delivered, blank folded to null; render via `riderName`.
  final String? displayName;
  final String? avatarUrl;

  /// Team country (ISO-3166 alpha-2, upper case) or null.
  final String? countryCode;
  final FriendshipStatus status;

  /// True when the other party sent the request — a pending incoming row is a
  /// request waiting for our answer, a pending outgoing row is 'Wartet'.
  final bool incoming;
  final DateTime? createdAt;

  bool get isAccepted => status == FriendshipStatus.accepted;
  bool get isIncomingRequest => status == FriendshipStatus.pending && incoming;
  bool get isOutgoingRequest => status == FriendshipStatus.pending && !incoming;

  factory Friend.fromJson(Map<String, Object?> j) => Friend(
        userId: (j['user_id'] as String?) ?? '',
        displayName: parseDisplayName(j['display_name']),
        avatarUrl: j['avatar_url'] as String?,
        countryCode: _country(j['country_code']),
        status: FriendshipStatus.fromWire(j['status'] as String?),
        incoming: j['incoming'] == true,
        createdAt: j['created_at'] == null ? null : DateTime.tryParse('${j['created_at']}'),
      );

  Friend copyWith({FriendshipStatus? status, bool? incoming}) => Friend(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        countryCode: countryCode,
        status: status ?? this.status,
        incoming: incoming ?? this.incoming,
        createdAt: createdAt,
      );

  static String? _country(Object? v) {
    final c = (v as String?)?.trim().toUpperCase();
    return c == null || c.length != 2 ? null : c;
  }

  @override
  bool operator ==(Object other) =>
      other is Friend &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.countryCode == countryCode &&
      other.status == status &&
      other.incoming == incoming;

  @override
  int get hashCode => Object.hash(userId, displayName, avatarUrl, countryCode, status, incoming);

  @override
  String toString() => 'Friend($userId, $displayName, ${status.name}${incoming ? ', incoming' : ''})';
}

/// Friend codes: six characters, the duel alphabet without 0/O/1/I/L.
class FriendCode {
  const FriendCode._();

  static const String alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int length = 6;

  /// Base of the invite link; SOC-DEEPLINK owns the handler for it.
  static const String linkBase = 'https://slopetrack.app/f/';

  /// Upper case, everything but letters and digits stripped. No folding of
  /// 0→O etc.: the alphabet has no ambiguous glyph, a code containing one was
  /// mistyped and must not be silently rewritten.
  static String normalise(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValid(String code) => code.length == length && code.split('').every(alphabet.contains);

  static String link(String code) => '$linkBase${normalise(code)}';
}
