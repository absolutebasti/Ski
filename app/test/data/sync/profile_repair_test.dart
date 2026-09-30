import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slopetrack/data/supabase/supabase_client.dart';
import 'package:slopetrack/data/sync/profile_repair.dart';

/// The `profiles` table as [ProfileRepair] sees it.
class FakeProfileRepairApi implements ProfileRepairApi {
  FakeProfileRepairApi({this.userId = 'u1', Map<String, String>? rows}) : rows = {...?rows};

  @override
  String? userId;

  /// id → display_name.
  final Map<String, String> rows;

  final List<String> selects = [];
  final List<(String, String)> inserts = [];
  final List<(String, String)> renames = [];

  /// Thrown by every call while set (offline, 500 …).
  Object? failure;

  /// Thrown by the writes only — the select still answers.
  Object? writeFailure;

  /// When set, [displayNameOf] waits for it — a round-trip that is still running.
  Completer<void>? selectGate;

  @override
  Future<String?> displayNameOf(String uid) async {
    selects.add(uid);
    await selectGate?.future;
    if (failure != null) throw failure!;
    return rows[uid];
  }

  @override
  Future<void> insertProfile(String uid, String displayName) async {
    if (failure != null) throw failure!;
    if (writeFailure != null) throw writeFailure!;
    inserts.add((uid, displayName));
    rows.putIfAbsent(uid, () => displayName); // on conflict do nothing
  }

  @override
  Future<void> renameProfile(String uid, String displayName) async {
    if (failure != null) throw failure!;
    if (writeFailure != null) throw writeFailure!;
    renames.add((uid, displayName));
    if (rows.containsKey(uid)) rows[uid] = displayName;
  }
}

void main() {
  late FakeProfileRepairApi api;
  late MemoryAppleNameCache cache;
  late ProfileRepair repair;

  setUp(() {
    api = FakeProfileRepairApi();
    cache = MemoryAppleNameCache();
    repair = ProfileRepair(api: api, cache: cache);
  });

  test('a user without a profiles row gets one upsert with the cached Apple name; success clears the cache', () async {
    cache.names['u1'] = 'Lena Huber';

    expect(await repair.repairIfMissing(), isTrue);
    expect(api.inserts, [('u1', 'Lena Huber')]);
    expect(api.renames, isEmpty);
    expect(cache.names, isEmpty, reason: 'the name reached the row');
    expect(repair.verifiedFor, 'u1');

    // every further tick is free
    expect(await repair.repairIfMissing(), isFalse);
    expect(await repair.repairIfMissing(), isFalse);
    expect(api.inserts, hasLength(1));
    expect(api.selects, hasLength(1), reason: 'no round-trip once the row was seen');
  });

  test('without a cached name the row is created as Skifahrer', () async {
    expect(await repair.repairIfMissing(), isTrue);
    expect(api.inserts, [('u1', 'Skifahrer')]);
  });

  test('a failed insert keeps the cached name and the next tick retries', () async {
    cache.names['u1'] = 'Lena Huber';
    api.writeFailure = StateError('503');
    expect(await repair.repairIfMissing(), isFalse);
    expect(cache.names['u1'], 'Lena Huber', reason: 'Apple hands the name over only once');
    expect(repair.verifiedFor, isNull);
    expect(api.rows, isEmpty);

    // offline on the select is the same story
    api
      ..writeFailure = null
      ..failure = StateError('offline');
    expect(await repair.repairIfMissing(), isFalse);
    expect(cache.names['u1'], 'Lena Huber');

    api.failure = null;
    expect(await repair.repairIfMissing(), isTrue);
    expect(api.inserts, [('u1', 'Lena Huber')]);
    expect(cache.names, isEmpty);
  });

  test('sign-in with a name caches it first and creates the row with it', () async {
    expect(await repair.repairIfMissing(userId: 'u1', appleName: '  Tom Ski '), isTrue);
    expect(api.rows['u1'], 'Tom Ski');
    expect(cache.names, isEmpty);
  });

  test('sign-in while the backend is down: the name waits in the cache', () async {
    api.failure = StateError('offline');
    expect(await repair.repairIfMissing(userId: 'u1', appleName: 'Tom Ski'), isFalse);
    expect(cache.names['u1'], 'Tom Ski');
    api.failure = null;
    expect(await repair.repairIfMissing(), isTrue);
    expect(api.rows['u1'], 'Tom Ski');
  });

  test('a row that still carries the fallback is renamed to the cached name', () async {
    api.rows['u1'] = 'Skifahrer';
    cache.names['u1'] = 'Lena Huber';
    expect(await repair.repairIfMissing(), isTrue);
    expect(api.inserts, isEmpty);
    expect(api.renames, [('u1', 'Lena Huber')]);
    expect(cache.names, isEmpty);
  });

  test('a row with a name of its own is never overwritten', () async {
    api.rows['u1'] = 'Pistenkönig';
    cache.names['u1'] = 'Lena Huber';
    expect(await repair.repairIfMissing(), isFalse);
    expect(api.inserts, isEmpty);
    expect(api.renames, isEmpty);
    expect(api.rows['u1'], 'Pistenkönig');
    expect(cache.names, isEmpty, reason: 'nothing left to repair');
    expect(repair.verifiedFor, 'u1');
  });

  test('the name that arrives while a check is already running is not lost', () async {
    // The auth-state listener starts a check the moment the session appears …
    api.selectGate = Completer<void>();
    final fromListener = repair.repairIfMissing(userId: 'u1');
    await pumpEventQueue();
    expect(api.selects, hasLength(1));
    // … and the sign-in hands the Apple name over a moment later.
    final fromSignIn = repair.repairIfMissing(userId: 'u1', appleName: 'Lena Huber');
    await pumpEventQueue();
    api.selectGate!.complete();
    api.selectGate = null;
    await Future.wait([fromListener, fromSignIn]);

    expect(api.rows['u1'], 'Lena Huber');
    expect(cache.names, isEmpty);
  });

  test('ticks collapse into the running check', () async {
    api.selectGate = Completer<void>();
    final a = repair.repairIfMissing();
    await pumpEventQueue();
    final b = repair.repairIfMissing();
    final c = repair.repairIfMissing();
    api.selectGate!.complete();
    expect(await Future.wait([a, b, c]), [true, true, true]);
    expect(api.selects, hasLength(1));
    expect(api.inserts, hasLength(1));
  });

  test('a name cached for one Konto never lands on another', () async {
    cache.names['u1'] = 'Lena Huber';
    api.userId = 'u2';
    expect(await repair.repairIfMissing(), isTrue);
    expect(api.inserts, [('u2', 'Skifahrer')]);
    expect(cache.names['u1'], 'Lena Huber', reason: 'still waiting for its own Konto');
  });

  test('reset after a sign-out makes the next Konto get its own check', () async {
    await repair.repairIfMissing();
    repair.reset();
    api.userId = 'u2';
    await repair.repairIfMissing();
    expect(api.selects, ['u1', 'u2']);
    expect(api.inserts.map((e) => e.$1), ['u1', 'u2']);
  });

  test('signed out or without a backend nothing happens', () async {
    cache.names['u1'] = 'Lena Huber';
    api.userId = null;
    expect(await repair.repairIfMissing(), isFalse);
    expect(await ProfileRepair(api: null, cache: cache).repairIfMissing(userId: 'u1', appleName: 'X'), isFalse);
    expect(api.selects, isEmpty);
    expect(cache.names, {'u1': 'Lena Huber'});
  });

  test('names are clipped to the 24 characters the server allows', () async {
    cache.names['u1'] = 'Maximilian-Alexander von Hohenstein';
    await repair.repairIfMissing();
    expect(api.rows['u1'], 'Maximilian-Alexander von');
    expect(clipDisplayName('   '), kFallbackDisplayName);
    expect(clipDisplayName('Lena'), 'Lena');
    // code points, not UTF-16 units: no emoji is cut in half
    expect(clipDisplayName('${'a' * 23}⛷️⛷️').runes.length, lessThanOrEqualTo(24));
    expect(clipDisplayName('${'a' * 23}🎿🎿'), '${'a' * 23}🎿');
  });

  test('forget drops the cached name and the verified user', () async {
    await repair.repairIfMissing();
    cache.names['u1'] = 'Lena Huber';
    await repair.forget('u1');
    expect(cache.names, isEmpty);
    expect(repair.verifiedFor, isNull);
  });

  test('PrefsAppleNameCache keeps one name per user in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    const prefsCache = PrefsAppleNameCache();
    expect(await prefsCache.read('u1'), isNull);
    await prefsCache.write('u1', 'Lena Huber');
    await prefsCache.write('u2', 'Tom Ski');
    expect(await prefsCache.read('u1'), 'Lena Huber');
    expect((await SharedPreferences.getInstance()).getString('profile.appleName.u1'), 'Lena Huber');
    await prefsCache.clear('u1');
    expect(await prefsCache.read('u1'), isNull);
    expect(await prefsCache.read('u2'), 'Tom Ski');
  });

  test('profileRepairProvider is a no-op without a backend', () async {
    final container = ProviderContainer(overrides: [supabaseProvider.overrideWithValue(null)]);
    addTearDown(container.dispose);
    final r = container.read(profileRepairProvider);
    expect(r.api, isNull);
    expect(await r.repairIfMissing(), isFalse);
  });
}
