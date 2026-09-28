import 'package:shared_preferences/shared_preferences.dart';

import 'invite_links.dart';

/// Holds the one invite that arrived while signed out (or while auth was
/// still resolving) until the handler can act on it.
abstract class PendingInviteStore {
  Future<InviteLink?> load();
  Future<void> save(InviteLink link);
  Future<void> clear();
}

/// SharedPreferences-backed store, key [key]. Value is [InviteLink.wire].
class SharedPrefsPendingInviteStore implements PendingInviteStore {
  const SharedPrefsPendingInviteStore();

  static const String key = 'invite.pending';

  @override
  Future<InviteLink?> load() async {
    final p = await SharedPreferences.getInstance();
    return InviteLink.fromWire(p.getString(key));
  }

  @override
  Future<void> save(InviteLink link) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, link.wire);
  }

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}

/// In-memory store for unit tests.
class MemoryPendingInviteStore implements PendingInviteStore {
  MemoryPendingInviteStore([this.value]);

  InviteLink? value;
  int saves = 0;
  int clears = 0;

  @override
  Future<InviteLink?> load() async => value;

  @override
  Future<void> save(InviteLink link) async {
    saves++;
    value = link;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}
