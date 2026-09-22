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

/// Every remote call of WP-14 goes through this interface so the sync loop can
/// be tested without a Supabase client.
abstract class SyncApi {
  /// Id of the signed-in user, null when signed out.
  String? get userId;

  /// Inserts or updates one `days` row (snake_case keys, server column names).
  Future<void> upsertDay(Map<String, Object?> row);

  /// Own `days` rows with `updated_at > sinceMs` (all rows when null),
  /// tombstones included.
  Future<List<Map<String, Object?>>> fetchDays({int? sinceMs});

  /// Uploads the gzip track backup, returns the storage path.
  Future<String> uploadTrack(String dayId, List<int> gzipBytes);

  /// Points the `days` row at an uploaded track.
  Future<void> setTrackPath(String dayId, String path);
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

  @override
  Future<void> upsertDay(Map<String, Object?> row) =>
      _guard(() => _client.from('days').upsert(row, onConflict: 'id'));

  @override
  Future<List<Map<String, Object?>>> fetchDays({int? sinceMs}) => _guard(() async {
        var query = _client.from('days').select();
        if (sinceMs != null) {
          query = query.gt('updated_at', DateTime.fromMillisecondsSinceEpoch(sinceMs, isUtc: true).toIso8601String());
        }
        final rows = await query.order('updated_at');
        return [for (final r in rows) Map<String, Object?>.from(r)];
      });

  @override
  Future<String> uploadTrack(String dayId, List<int> gzipBytes) => _guard(() async {
        final uid = userId;
        if (uid == null) throw StateError('not signed in');
        final path = '$uid/$dayId.json.gz';
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
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection closed') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable');
  }
}

/// Null while the backend is unavailable — the app stays fully local.
final syncApiProvider = Provider<SyncApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : SupabaseSyncApi(client);
});
