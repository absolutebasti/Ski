import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_client.dart';

/// Every remote call of the Konto sheet goes through this interface, so the
/// profile logic is testable without a Supabase client.
abstract class ProfileApi {
  /// Id of the signed-in Konto, null when signed out.
  String? get userId;

  /// One `profiles` row (snake_case server columns), null when it does not
  /// exist yet.
  Future<Map<String, Object?>?> fetch(String userId);

  /// Writes the given columns; creates the row when it is missing.
  Future<void> update(String userId, Map<String, Object?> patch);
}

/// Supabase implementation — 10 s timeout on every call, RLS restricts the row
/// to the signed-in user.
class SupabaseProfileApi implements ProfileApi {
  SupabaseProfileApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  static const String columns = 'id, display_name, avatar_url, home_resort_id, share_leaderboards';

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<Map<String, Object?>?> fetch(String userId) async {
    final row = await _client.from('profiles').select(columns).eq('id', userId).maybeSingle().timeout(timeout);
    return row == null ? null : Map<String, Object?>.from(row);
  }

  @override
  Future<void> update(String userId, Map<String, Object?> patch) async {
    await _client.from('profiles').upsert(<String, Object?>{
      'id': userId,
      ...patch,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id').timeout(timeout);
  }
}

/// In-memory stand-in for widget tests and offline development: records every
/// patch so a test can assert what the sheet wrote.
@visibleForTesting
class FakeProfileApi implements ProfileApi {
  FakeProfileApi({this.userId, Map<String, Object?>? row, this.failFetch = false, this.failUpdate = false})
      : row = row == null ? null : Map<String, Object?>.from(row);

  @override
  final String? userId;

  /// The stored row; null means "no profiles row yet".
  Map<String, Object?>? row;

  final bool failFetch;
  final bool failUpdate;

  /// Every patch handed to [update], oldest first.
  final List<Map<String, Object?>> patches = [];

  int fetchCount = 0;

  @override
  Future<Map<String, Object?>?> fetch(String userId) async {
    fetchCount++;
    if (failFetch) throw StateError('fetch failed');
    final r = row;
    return r == null ? null : Map<String, Object?>.from(r);
  }

  @override
  Future<void> update(String userId, Map<String, Object?> patch) async {
    patches.add(Map<String, Object?>.from(patch));
    if (failUpdate) throw StateError('update failed');
    row = <String, Object?>{'id': userId, ...?row, ...patch};
  }
}

/// Null while the backend is unavailable — the Konto sheet then only offers
/// the local state.
final Provider<ProfileApi?> profileApiProvider = Provider<ProfileApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseProfileApi(client);
});
