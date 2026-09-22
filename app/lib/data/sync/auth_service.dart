import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart';

/// The signed-in Konto as the app sees it.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.displayName, this.email});

  final String id;
  final String? email;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);

  @override
  String toString() => 'AuthUser($id, $displayName)';
}

/// Sign in with Apple is the only provider (App Review requirement).
///
/// Every method is a no-op when the backend is unavailable
/// ([supabaseProvider] == null), so the app keeps working offline.
class AuthService {
  AuthService(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient? _client;
  final Duration timeout;

  /// Used when Apple hides the name (it is only handed over on first consent).
  static const String fallbackName = 'Skifahrer';

  bool get isAvailable => _client != null;

  AuthUser? get currentUser => authUserFrom(_client?.auth.currentUser);

  Future<AuthUser?> signInWithApple() async {
    final client = _client;
    if (client == null) return null;
    final rawNonce = _rawNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    final idToken = credential.identityToken;
    if (idToken == null) throw const AuthException('Apple lieferte kein Identity-Token');
    final response = await client.auth
        .signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken, nonce: rawNonce)
        .timeout(timeout);
    final user = response.user;
    if (user == null) return null;
    final appleName = _fullName(credential.givenName, credential.familyName);
    await _ensureProfile(client, user, appleName);
    return authUserFrom(user, fallbackDisplayName: appleName);
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut().timeout(timeout);
  }

  /// Deletes every row the user owns, then signs out.
  ///
  /// TODO(WP-14): the `auth.users` entry itself can only be removed with the
  /// service role — needs an edge function `delete-account` (see report).
  Future<void> deleteAccount() async {
    final client = _client;
    if (client == null) return;
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      await client.from('days').delete().eq('user_id', uid).timeout(timeout);
      await client.from('group_members').delete().eq('user_id', uid).timeout(timeout);
      await client.from('challenge_progress').delete().eq('user_id', uid).timeout(timeout);
      await client.from('profiles').delete().eq('id', uid).timeout(timeout);
    }
    await client.auth.signOut().timeout(timeout);
  }

  /// A profiles row must exist before anything social works.
  Future<void> _ensureProfile(SupabaseClient client, User user, String? appleName) async {
    try {
      final existing =
          await client.from('profiles').select('id, display_name').eq('id', user.id).maybeSingle().timeout(timeout);
      if (existing == null) {
        await client
            .from('profiles')
            .insert({'id': user.id, 'display_name': appleName ?? fallbackName}).timeout(timeout);
      } else if (appleName != null && (existing['display_name'] as String?) == fallbackName) {
        await client.from('profiles').update({'display_name': appleName}).eq('id', user.id).timeout(timeout);
      }
    } catch (e) {
      // Never block the sign-in on the profile round-trip; WP-15 retries.
      debugPrint('ensure profile failed: $e');
    }
  }

  static String? _fullName(String? given, String? family) {
    final parts = [given, family].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String _rawNonce() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }
}

/// Maps a Supabase user onto [AuthUser]; display name from the Apple full name
/// in the user metadata, else [AuthService.fallbackName].
AuthUser? authUserFrom(User? user, {String? fallbackDisplayName}) {
  if (user == null) return null;
  final meta = user.userMetadata ?? const <String, dynamic>{};
  final name = [meta['full_name'], meta['name'], meta['display_name'], fallbackDisplayName]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .firstOrNull;
  return AuthUser(id: user.id, email: user.email, displayName: name ?? AuthService.fallbackName);
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(supabaseProvider)));

/// Current Konto, seeded with the restored session; always null when the
/// backend is unavailable.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client == null) return Stream<AuthUser?>.value(null);
  return _authStream(client);
});

Stream<AuthUser?> _authStream(SupabaseClient client) async* {
  yield authUserFrom(client.auth.currentUser);
  yield* client.auth.onAuthStateChange.map((state) => authUserFrom(state.session?.user));
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
