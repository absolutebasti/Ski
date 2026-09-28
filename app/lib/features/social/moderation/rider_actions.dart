import 'package:flutter/widgets.dart';

import '../../../app/widgets/widgets.dart';
import '../rider/rider_models.dart';
import 'block_confirm_sheet.dart';
import 'moderation_strings.dart';
import 'report_sheet.dart';

/// The two handlers SOC-MODERATION puts into the RiderSheet's actions slot
/// (`RiderActions.report` / `.block` in rider_providers.dart).
///
/// 'Melden' opens the [ReportSheet]; 'Blockieren' asks via
/// [BlockConfirmSheet], which performs the block, then a toast says 'Blockiert'
/// and the profile switches to its blocked state (rider_sheet.dart watches
/// `blockedIdsProvider`).
Future<void> reportRider(BuildContext context, RiderProfile rider) => ReportSheet.show(context, targetUserId: rider.userId, displayName: rider.displayName);

Future<void> blockRider(BuildContext context, RiderProfile rider) async {
  final blocked = await BlockConfirmSheet.show(context, targetUserId: rider.userId, displayName: rider.displayName);
  if (blocked && context.mounted) showToast(context, ModerationStrings.of(context).blocked);
}
