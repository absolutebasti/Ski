import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/supabase/supabase_client.dart';
import '../social_api.dart';
import 'teaser_models.dart';

/// The one remote call the Rangliste makes without a Konto: the public top 10
/// (RPC `public_board_teaser`, migration 0016 — granted to `anon`).
///
/// Implementations never throw raw Postgrest/network errors — they map to
/// [SocialError] like every other social call.
abstract class TeaserApi {
  /// Top 10 opted-in riders by points for [query]; empty when nobody is
  /// ranked. Rows carry no user id.
  Future<List<TeaserEntry>> topTen(TeaserQuery query);
}

/// Supabase implementation; runs with the publishable key while signed out.
class SupabaseTeaserApi implements TeaserApi {
  SupabaseTeaserApi(this._client, {this.timeout = const Duration(seconds: 10)});

  final SupabaseClient _client;
  final Duration timeout;

  @override
  Future<List<TeaserEntry>> topTen(TeaserQuery query) async {
    try {
      final raw = await _client.rpc<dynamic>('public_board_teaser', params: {
        'p_resort_id': query.resortId,
        'p_season_key': query.seasonKey,
      }).timeout(timeout);
      return parseTeaserRows(raw);
    } catch (e) {
      throw SupabaseSocialApi.mapError(e);
    }
  }
}

/// At most one request per [minInterval] and query: a second call inside the
/// window gets the first call's future. The server has no per-caller counter
/// for this anonymous read (see the header of migration 0016), so the client
/// keeps itself polite — a pull-to-refresh storm costs one call per second.
class ThrottledTeaserApi implements TeaserApi {
  ThrottledTeaserApi(this._inner, {this.minInterval = const Duration(seconds: 1), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final TeaserApi _inner;
  final Duration minInterval;
  final DateTime Function() _clock;
  final Map<TeaserQuery, (DateTime, Future<List<TeaserEntry>>)> _recent = {};

  @override
  Future<List<TeaserEntry>> topTen(TeaserQuery query) {
    final now = _clock();
    _recent.removeWhere((_, call) => now.difference(call.$1).abs() >= minInterval);
    final hit = _recent[query];
    if (hit != null) return hit.$2;
    final call = _inner.topTen(query);
    _recent[query] = (now, call);
    return call;
  }
}

/// Null while the backend is unavailable (not configured, init failed).
final teaserApiProvider = Provider<TeaserApi?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : ThrottledTeaserApi(SupabaseTeaserApi(client));
});

/// The public top 10 for one resort/season. Throws a [SocialError]
/// ([SocialErrorKind.offline] without a backend); never retried on its own —
/// the screen refetches on pull-to-refresh and on tab re-entry.
final teaserProvider = FutureProvider.family<List<TeaserEntry>, TeaserQuery>((ref, query) async {
  final api = ref.watch(teaserApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  return api.topTen(query);
}, retry: noRetry);
