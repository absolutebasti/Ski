import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../friends/friends_api.dart';
import '../friends/friends_models.dart';
import '../friends/friends_providers.dart';
import '../social.dart';

/// What the handler does with a parsed link once the user is signed in.
/// Behind an interface so the join flow can be tested without Supabase and
/// so SOC-LIVE-DUEL can point [joinDuel] at its DuelApi later.
abstract class InviteActions {
  /// Joins the Tagesduell with [code]. Throws [SocialError].
  Future<void> joinDuel(String code);

  /// Sends (or accepts) the friend request for [code]. Returns true when the
  /// other side had asked first and the pair is now connected. Throws
  /// [FriendsError].
  Future<bool> addFriend(String code);
}

/// Default: `SocialApi.joinDuel` + `FriendsApi.addFriendByCode`, followed by
/// the provider invalidations the Rangliste needs to show the result.
class ProviderInviteActions implements InviteActions {
  ProviderInviteActions(this._ref);
  final Ref _ref;

  @override
  Future<void> joinDuel(String code) async {
    final api = _ref.read(socialApiProvider);
    if (api == null) throw const SocialError(SocialErrorKind.offline);
    await api.joinDuel(code);
    _ref.invalidate(myDuelProvider);
  }

  @override
  Future<bool> addFriend(String code) async {
    final api = _ref.read(friendsApiProvider);
    if (api == null) throw const FriendsError(FriendsErrorKind.offline);
    final friend = await api.addFriendByCode(code);
    _ref.invalidate(friendshipsProvider);
    _ref.invalidate(friendsBoardProvider);
    return friend.status == FriendshipStatus.accepted;
  }
}

/// Recording fake for handler tests.
class FakeInviteActions implements InviteActions {
  FakeInviteActions({this.duelError, this.friendError, this.friendAccepted = false});

  final List<String> duels = [];
  final List<String> friends = [];
  Object? duelError;
  Object? friendError;
  bool friendAccepted;

  @override
  Future<void> joinDuel(String code) async {
    duels.add(code);
    final e = duelError;
    if (e != null) throw e;
  }

  @override
  Future<bool> addFriend(String code) async {
    friends.add(code);
    final e = friendError;
    if (e != null) throw e;
    return friendAccepted;
  }
}

final inviteActionsProvider = Provider<InviteActions>((ref) => ProviderInviteActions(ref));
