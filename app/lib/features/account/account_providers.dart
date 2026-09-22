import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase/supabase_client.dart';
import '../../data/sync/auth_service.dart';
import '../../data/sync/sync_service.dart';

/// Live sync state for the Konto sheet. Seeded by [SyncService.status], so the
/// first frame already shows the current value.
final StreamProvider<SyncStatus> accountSyncStatusProvider =
    StreamProvider<SyncStatus>((ref) => ref.watch(syncServiceProvider).status);

/// Indirection for "Jetzt synchronisieren" so a widget test never builds the
/// real [SyncService] (which would open the database).
typedef SyncTrigger = Future<void> Function();

final Provider<SyncTrigger> accountSyncTriggerProvider =
    Provider<SyncTrigger>((ref) => ref.watch(syncServiceProvider).syncNow);

/// False when the backend is not configured — the Konto sheet then only
/// explains that everything stays local. Overridden in tests.
final Provider<bool> accountAvailableProvider = Provider<bool>((ref) => ref.watch(supabaseProvider) != null);

/// The three auth actions of the sheet, each behind its own hook so tests can
/// record the call without a Supabase client.
typedef SignInAction = Future<AuthUser?> Function();
typedef AccountAction = Future<void> Function();

final Provider<SignInAction> accountSignInProvider =
    Provider<SignInAction>((ref) => ref.read(authServiceProvider).signInWithApple);

final Provider<AccountAction> accountSignOutProvider =
    Provider<AccountAction>((ref) => ref.read(authServiceProvider).signOut);

final Provider<AccountAction> accountDeleteProvider =
    Provider<AccountAction>((ref) => ref.read(authServiceProvider).deleteAccount);

/// The signed-in user without a first-frame flash: while the auth stream is
/// still loading, fall back to the session Supabase already restored.
AuthUser? watchAuthUser(WidgetRef ref) {
  final auth = ref.watch(authStateProvider);
  return auth.value ?? (auth.isLoading ? ref.read(authServiceProvider).currentUser : null);
}
