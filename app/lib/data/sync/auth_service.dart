import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart';
import 'profile_repair.dart';

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

/// The remote side of [AuthService.deleteAccount]; a fake stands in for
/// tests (SYNC-2).
abstract class AccountGateway {
  /// Id of the signed-in user, null when signed out.
  String? get userId;

  /// Calls the `delete-account` Edge Function and returns its HTTP status.
  /// May throw instead (network failure; supabase_flutter also throws a
  /// `FunctionException` on non-2xx) — both mean 'not deleted'.
  Future<int> invokeDeleteAccount();

  /// Drops the session on this device only — the user no longer exists
  /// server-side, there is nothing left to revoke there.
  Future<void> signOutLocal();
}

class SupabaseAccountGateway implements AccountGateway {
  SupabaseAccountGateway(this._client);
  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<int> invokeDeleteAccount() async => (await _client.functions.invoke('delete-account')).status;

  @override
  Future<void> signOutLocal() => _client.auth.signOut(scope: SignOutScope.local);
}

/// Sign in with Apple is the only provider (App Review requirement).
///
/// Every method is a no-op when the backend is unavailable
/// ([supabaseProvider] == null), so the app keeps working offline.
class AuthService {
  AuthService(
    this._client, {
    this.timeout = const Duration(seconds: 10),
    this.deleteTimeout = const Duration(seconds: 30),
    AccountGateway? gateway,
    ProfileRepair? repair,
  })
      : _gateway = gateway ?? (_client == null ? null : SupabaseAccountGateway(_client)),
        repair = repair ?? ProfileRepair(api: _client == null ? null : SupabaseProfileRepairApi(_client));

  final SupabaseClient? _client;
  final AccountGateway? _gateway;
  final Duration timeout;

  /// `delete-account` walks the storage folder before it removes the user;
  /// giving up early would report a failure for a deletion that still lands.
  final Duration deleteTimeout;

  /// Creates the `profiles` row on sign-in and caches the Apple name until
  /// the insert went through; the sync loop retries via the same object.
  final ProfileRepair repair;

  /// Used when Apple hides the name (it is only handed over on first consent).
  static const String fallbackName = kFallbackDisplayName;

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
    // Never fails the sign-in: the Apple name is cached first and the sync
    // tick retries until the profiles row exists.
    await repair.repairIfMissing(userId: user.id, appleName: appleName);
    return authUserFrom(user, fallbackDisplayName: appleName);
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    repair.reset();
    await client.auth.signOut().timeout(timeout);
  }

  /// Deletes the account completely: the `delete-account` Edge Function
  /// removes the track backups and the auth user (rows cascade), then the
  /// local session is dropped and true comes back.
  ///
  /// Returns false — session intact, nothing touched, locally or remotely —
  /// when nobody is signed in, the function is unreachable or it answers
  /// non-2xx. The Konto UI then says 'Löschen hat nicht geklappt, bitte später
  /// erneut' instead of 'Konto gelöscht'. There is no partial client-side
  /// fallback any more (SYNC-2): a half-deleted account that still signs in
  /// is worse than a retry. Never throws.
  Future<bool> deleteAccount() async {
    final gateway = _gateway;
    final uid = gateway?.userId;
    if (gateway == null || uid == null) return false;
    try {
      final status = await gateway.invokeDeleteAccount().timeout(deleteTimeout);
      if (status < 200 || status >= 300) return false;
    } catch (e) {
      debugPrint('delete-account failed: $e');
      return false;
    }
    await repair.forget(uid);
    try {
      await gateway.signOutLocal().timeout(timeout);
    } catch (e) {
      // The user is gone server-side either way; the next token refresh ends
      // whatever is left of the session.
      debugPrint('sign-out after delete-account failed: $e');
    }
    return true;
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

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(supabaseProvider), repair: ref.watch(profileRepairProvider)));

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
