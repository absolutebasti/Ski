import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_client.dart';
import '../../../data/sync/sync_api.dart';
import '../social_api.dart';
import 'rider_models.dart';

/// The one remote call of the rider profile, behind an interface so the sheet
/// is testable without Supabase ([FakeRiderApi] in fake_rider_api.dart).
///
/// Failures are [SocialError]s — the same vocabulary the rest of the Social
/// tab speaks, so the strings already exist.
abstract class RiderApi {
  /// RPC `rider_profile(p_user_id)`. Null when the profile is not visible to
  /// the caller (private, no shared duel, no friendship) or does not exist.
  /// Throws [SocialErrorKind.notSignedIn] while signed out.
  Future<RiderProfile?> profile(String userId);
}

/// Supabase implementation; 10 s timeout, network failures become
/// [SocialErrorKind.offline].
class SupabaseRiderApi implements RiderApi {
  SupabaseRiderApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<RiderProfile?> profile(String userId) async {
    if (_client.auth.currentUser == null) throw const SocialError(SocialErrorKind.notSignedIn);
    try {
      final raw = await _client.rpc<dynamic>('rider_profile', params: {'p_user_id': userId}).timeout(timeout);
      if (raw is! List || raw.isEmpty) return null;
      final row = raw.first;
      if (row is! Map) return null;
      return RiderProfile.fromJson(Map<String, Object?>.from(row));
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.contains('not_signed_in')) throw const SocialError(SocialErrorKind.notSignedIn);
      throw SocialError(SocialErrorKind.failed, '$e');
    } on SocialError {
      rethrow;
    } catch (e) {
      if (SupabaseSyncApi.isOfflineError(e)) throw SocialError(SocialErrorKind.offline, '$e');
      throw SocialError(SocialErrorKind.failed, '$e');
    }
  }
}

/// Null while the backend is unavailable — the sheet then shows its offline
/// state. Override with a [FakeRiderApi] in tests.
final riderApiProvider = Provider<RiderApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseRiderApi(client);
});
