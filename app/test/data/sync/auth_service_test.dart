import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dropline/data/supabase/supabase_client.dart';
import 'package:dropline/data/sync/auth_service.dart';
import 'package:dropline/data/sync/sync_api.dart';
import 'package:dropline/data/sync/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User user({Map<String, dynamic>? meta, String? email}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: meta,
      aud: 'authenticated',
      email: email,
      createdAt: DateTime.utc(2026).toIso8601String(),
    );

void main() {
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
    await service.deleteAccount();
    expect(container.read(syncApiProvider), isNull);
    expect(container.read(syncServiceProvider).isAvailable, isFalse);
  });
}
