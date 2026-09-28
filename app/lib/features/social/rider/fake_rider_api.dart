import 'dart:async';

import '../social_api.dart';
import 'rider_api.dart';
import 'rider_models.dart';

/// In-memory [RiderApi] for widget tests, previews and the demo mode.
class FakeRiderApi implements RiderApi {
  FakeRiderApi({Map<String, RiderProfile> profiles = const {}, this.failWith, this.gate}) : profiles = {...profiles};

  /// Profiles by user id; a missing id answers null (= private / unknown).
  final Map<String, RiderProfile> profiles;

  /// When set, every call throws it.
  SocialError? failWith;

  /// When set, every call waits for it first — lets a test look at the
  /// loading skeleton before completing the future.
  Completer<void>? gate;

  /// User ids asked for, in order.
  final List<String> calls = [];

  @override
  Future<RiderProfile?> profile(String userId) async {
    calls.add(userId);
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
    return profiles[userId];
  }
}
