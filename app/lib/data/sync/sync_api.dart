import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart';

/// Thrown when a remote call could not reach the backend (no network, DNS
/// failure, timeout). The sync loop treats it as "try again later" and keeps
/// the outbox intact — it never counts as a failed attempt.
class SyncOffline implements Exception {
  const SyncOffline(this.message);
  final String message;
  @override
  String toString() => 'SyncOffline: $message';
}

/// The session is gone for good: a 401 survived one `refreshSession`. The
/// Konto sheet shows 'Bitte neu anmelden'; nothing counts as a failed attempt.
class SyncNeedsSignIn implements Exception {
  const SyncNeedsSignIn(this.message);
  final String message;
  @override
  String toString() => 'SyncNeedsSignIn: $message';
}

/// Every remote call of WP-14 goes through this interface so the sync loop can
/// be tested without a Supabase client.
abstract class SyncApi {
  /// Id of the signed-in user, null when signed out.
  String? get userId;

  /// Inserts or updates one `days` row (snake_case keys, server column names).
  Future<void> upsertDay(Map<String, Object?> row);

  /// One page of own `days` rows with `updated_at > sinceMs` (all rows when
  /// null), tombstones included, ordered by `updated_at, id`. The caller keeps
  /// paging while a page is full.
  Future<List<Map<String, Object?>>> fetchDays({int? sinceMs, int offset = 0, int limit = 500});

  /// Uploads the gzip track backup, returns the storage path.
  Future<String> uploadTrack(String dayId, List<int> gzipBytes);

  /// Points the `days` row at an uploaded track.
  Future<void> setTrackPath(String dayId, String path);

  /// `days.track_path` of an own day, null when there is no backup (or no row).
  Future<String?> trackPathOf(String dayId);

  /// The gzip bundle behind `days.track_path`, null when the day has none.
  Future<List<int>?> downloadTrack(String dayId);

  /// Deletes the storage object of a day; a missing object is not an error.
  Future<void> removeTrack(String dayId);

  /// Asks the auth backend for a fresh access token. False when the refresh
  /// token is gone too — the user has to sign in again.
  Future<bool> refreshSession();
}

/// Supabase implementation. Every call has a 10 s timeout and maps network
/// failures to [SyncOffline].
class SupabaseSyncApi implements SyncApi {
  SupabaseSyncApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  static const String bucket = 'tracks';

  @override
  String? get userId => _client.auth.currentUser?.id;

  /// Storage path of a day's backup; deterministic so a delete needs no lookup.
  static String trackPath(String uid, String dayId) => '$uid/$dayId.json.gz';

  @override
  Future<void> upsertDay(Map<String, Object?> row) =>
      _guard(() => _client.from('days').upsert(row, onConflict: 'id'));

  @override
  Future<List<Map<String, Object?>>> fetchDays({int? sinceMs, int offset = 0, int limit = 500}) => _guard(() async {
        var query = _client.from('days').select();
        if (sinceMs != null) {
          query = query.gt('updated_at', DateTime.fromMillisecondsSinceEpoch(sinceMs, isUtc: true).toIso8601String());
        }
        final rows = await query.order('updated_at', ascending: true).order('id', ascending: true).range(offset, offset + limit - 1);
        return [for (final r in rows) Map<String, Object?>.from(r)];
      });

  @override
  Future<String> uploadTrack(String dayId, List<int> gzipBytes) => _guard(() async {
        final uid = userId;
        if (uid == null) throw StateError('not signed in');
        final path = trackPath(uid, dayId);
        await _client.storage.from(bucket).uploadBinary(
              path,
              Uint8List.fromList(gzipBytes),
              fileOptions: const FileOptions(upsert: true, contentType: 'application/gzip'),
            );
        return path;
      });

  @override
  Future<void> setTrackPath(String dayId, String path) =>
      _guard(() => _client.from('days').update({'track_path': path}).eq('id', dayId));

  @override
  Future<String?> trackPathOf(String dayId) => _guard(() async {
        final row = await _client.from('days').select('track_path').eq('id', dayId).maybeSingle();
        return row?['track_path'] as String?;
      });

  @override
  Future<List<int>?> downloadTrack(String dayId) async {
    final path = await trackPathOf(dayId);
    if (path == null || path.isEmpty) return null;
    return _guard(() async {
      try {
        return await _client.storage.from(bucket).download(path);
      } on StorageException catch (e) {
        if (e.statusCode == '404' || e.statusCode == '400') return null;
        rethrow;
      }
    });
  }

  @override
  Future<void> removeTrack(String dayId) => _guard(() async {
        final uid = userId;
        if (uid == null) return;
        await _client.storage.from(bucket).remove([trackPath(uid, dayId)]);
      });

  @override
  Future<bool> refreshSession() => _guard(() async {
        try {
          final res = await _client.auth.refreshSession();
          return res.session != null;
        } on AuthRetryableFetchException {
          rethrow; // offline, not a dead session — _guard maps it to SyncOffline
        } on AuthException {
          return false;
        }
      });

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op().timeout(timeout);
    } catch (e) {
      if (isOfflineError(e)) throw SyncOffline('$e');
      rethrow;
    }
  }

  /// Network-ish failures: no connection, DNS, TLS, timeout, gotrue retry.
  static bool isOfflineError(Object e) {
    if (e is SyncOffline || e is SocketException || e is TimeoutException || e is HandshakeException) return true;
    if (e is AuthRetryableFetchException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection closed') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable');
  }

  /// A rejected or expired token: gotrue [AuthException], PostgREST 401 /
  /// PGRST301 (JWT expired) / PGRST303, storage 401.
  static bool isAuthError(Object e) {
    if (e is SyncNeedsSignIn) return true;
    if (e is AuthRetryableFetchException) return false;
    if (e is AuthException) {
      final code = e.statusCode;
      return code == null || code == '401' || code == '403';
    }
    if (e is PostgrestException) {
      final code = e.code;
      return code == '401' || code == 'PGRST301' || code == 'PGRST303';
    }
    if (e is StorageException) return e.statusCode == '401';
    return false;
  }
}

/// Null while the backend is unavailable — the app stays fully local.
final syncApiProvider = Provider<SyncApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseSyncApi(client);
});
