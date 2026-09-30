import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slopetrack/data/supabase/supabase_client.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/data/sync/profile_repair.dart';
import 'package:slopetrack/data/sync/sync_api.dart';
import 'package:slopetrack/data/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User user({Map<String, dynamic>? meta, String? email}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: meta,
      aud: 'authenticated',
      email: email,
      createdAt: DateTime.utc(2026).toIso8601String(),
    );

/// Stands in for the Edge Function and the local session.
class FakeAccountGateway implements AccountGateway {
  FakeAccountGateway({this.userId = 'u1', this.status = 200});

  @override
  String? userId;

  /// What `delete-account` answers.
  int status;

  /// Thrown instead — no network, or supabase_flutter's FunctionException.
  Object? error;

  int invokes = 0;
  int signOuts = 0;

  @override
  Future<int> invokeDeleteAccount() async {
    invokes++;
    final e = error;
    if (e != null) throw e;
    return status;
  }

  @override
  Future<void> signOutLocal() async {
    signOuts++;
    userId = null;
  }
}

void main() {
  group('deleteAccount', () {
    late FakeAccountGateway gateway;
    late MemoryAppleNameCache cache;
    late ProfileRepair repair;
    late AuthService service;

    setUp(() {
      gateway = FakeAccountGateway();
      cache = MemoryAppleNameCache({'u1': 'Lena Huber'});
      repair = ProfileRepair(api: null, cache: cache);
      service = AuthService(null, gateway: gateway, repair: repair);
    });

    test('Edge Function 500 → false, session intact, nothing wiped', () async {
      gateway.status = 500;
      expect(await service.deleteAccount(), isFalse);
      expect(gateway.invokes, 1);
      expect(gateway.signOuts, 0, reason: 'the Konto still exists — stay signed in and try again later');
      expect(gateway.userId, 'u1');
      expect(cache.names, {'u1': 'Lena Huber'}, reason: 'no local wipe');
    });

    test('an unreachable or throwing function is a failure too, never an exception', () async {
      gateway.error = const FunctionException(status: 500, details: 'storage remove failed');
      expect(await service.deleteAccount(), isFalse);
      gateway.error = const SocketExceptionLike();
      expect(await service.deleteAccount(), isFalse);
      expect(gateway.signOuts, 0);
      expect(gateway.userId, 'u1');
    });

    test('a function that never answers times out as a failure', () async {
      final slow = _HangingGateway();
      final s = AuthService(null, gateway: slow, repair: repair, deleteTimeout: const Duration(milliseconds: 20));
      expect(await s.deleteAccount(), isFalse);
      expect(slow.signOuts, 0);
    });

    test('there is no client-side fallback: a failure is retried by calling again', () async {
      gateway.status = 503;
      expect(await service.deleteAccount(), isFalse);
      gateway.status = 200;
      expect(await service.deleteAccount(), isTrue);
      expect(gateway.invokes, 2);
      expect(gateway.signOuts, 1);
    });

    test('2xx → true, the local session and the cached name are dropped', () async {
      gateway.status = 204;
      expect(await service.deleteAccount(), isTrue);
      expect(gateway.signOuts, 1);
      expect(gateway.userId, isNull);
      expect(cache.names, isEmpty);
    });

    test('signed out → false without calling the function', () async {
      gateway.userId = null;
      expect(await service.deleteAccount(), isFalse);
      expect(gateway.invokes, 0);
    });
  });

  test('display name comes from the Apple full name', () {
    expect(authUserFrom(user(meta: {'full_name': 'Lena Huber'}))?.displayName, 'Lena Huber');
    expect(authUserFrom(user(meta: {'name': 'Max'}))?.displayName, 'Max');
    expect(authUserFrom(user(email: 'a@b.c'))?.email, 'a@b.c');
  });

  test('falls back to Skifahrer when Apple hides the name', () {
    expect(authUserFrom(user())?.displayName, 'Skifahrer');
    expect(authUserFrom(user(meta: {'full_name': '   '}))?.displayName, 'Skifahrer');
    expect(authUserFrom(user(meta: const {}), fallbackDisplayName: 'Tom Ski')?.displayName, 'Tom Ski');
  });

  test('no user, no AuthUser', () => expect(authUserFrom(null), isNull));

  test('without a backend the auth state is null and the service is a no-op', () async {
    final container = ProviderContainer(overrides: [supabaseProvider.overrideWithValue(null)]);
    addTearDown(container.dispose);

    // Riverpod 3 pauses streams without listeners.
    final sub = container.listen(authStateProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(authStateProvider.future), isNull);
    final service = container.read(authServiceProvider);
    expect(service.isAvailable, isFalse);
    expect(service.currentUser, isNull);
    expect(await service.signInWithApple(), isNull);
    await service.signOut();
    expect(await service.deleteAccount(), isFalse);
    expect(container.read(syncApiProvider), isNull);
    expect(container.read(syncServiceProvider).isAvailable, isFalse);
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketException: Failed host lookup';
}

class _HangingGateway extends FakeAccountGateway {
  @override
  Future<int> invokeDeleteAccount() => Completer<int>().future;
}
