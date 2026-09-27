import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../social_api.dart';
import 'rider_api.dart';
import 'rider_models.dart';

/// Profile of one rider (RPC `rider_profile`). Null = not visible to the
/// caller. Throws a [SocialError]; the sheet renders offline / error from it.
/// No automatic retry — the user taps 'Erneut versuchen'.
///
/// autoDispose: the sheet is transient and a rider's numbers change with
/// every synced day, so each opening fetches fresh instead of serving a
/// session-long cache.
final riderProfileProvider = FutureProvider.autoDispose.family<RiderProfile?, String>((ref, userId) async {
  final api = ref.watch(riderApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  return api.profile(userId);
}, retry: noRetry);

/// An action on another rider, e.g. 'Freund hinzufügen'.
typedef RiderAction = Future<void> Function(BuildContext context, RiderProfile rider);

/// The actions slot of the RiderSheet. Every handler is optional; a null
/// handler hides its button/row. Wave-2 packages fill the slots:
///   * [addFriend] — SOC-FRIENDS / SOC-RANGLISTE (FriendsApi.addFriend)
///   * [report], [block] — SOC-MODERATION (ReportSheet, BlockConfirmSheet)
/// Fill them either by overriding [riderActionsProvider] in the ProviderScope
/// or by replacing the default below.
@immutable
class RiderActions {
  const RiderActions({this.addFriend, this.report, this.block});
  final RiderAction? addFriend;
  final RiderAction? report;
  final RiderAction? block;
}

final riderActionsProvider = Provider<RiderActions>((ref) => const RiderActions());

/// Hands a text to the system share sheet.
typedef ShareTextSink = Future<void> Function({required String text, required String subject});

/// Share sink of the sheet — SharePlus in the app, a recording fake in tests.
final riderShareProvider = Provider<ShareTextSink>(
  (ref) => ({required text, required subject}) => SharePlus.instance.share(ShareParams(text: text, subject: subject)),
);
