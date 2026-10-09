import 'package:flutter/widgets.dart';

import '../features/social/duel/live_duel_uploader.dart';
import '../features/social/invite/invite_listener.dart';

/// The app-wide hosts every home route needs: invite links (toast + tab jump)
/// and the live-duel uploader (Riverpod 3 pauses unwatched providers). Used by
/// app.dart and again when the onboarding replaces the home route with the
/// shell, so the first session after onboarding keeps both.
class AppHome extends StatelessWidget {
  const AppHome({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LiveDuelSyncHost(child: InviteListener(child: child));
}
