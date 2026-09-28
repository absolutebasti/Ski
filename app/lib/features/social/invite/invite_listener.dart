import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/widgets.dart';
import 'invite_link_handler.dart';
import 'invite_strings.dart';

/// Starts the [InviteLinkHandler] and turns its events into a toast; on a
/// successful join it asks the shell for the Rangliste tab.
///
/// Mount it inside the Navigator (the toast needs an Overlay):
/// `home: InviteListener(child: RootShell())` in app.dart.
class InviteListener extends ConsumerStatefulWidget {
  const InviteListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<InviteListener> createState() => _InviteListenerState();
}

class _InviteListenerState extends ConsumerState<InviteListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(inviteLinkHandlerProvider).start();
    });
  }

  void _onEvent(InviteEvent? previous, InviteEvent? event) {
    if (event == null || !mounted) return;
    final s = InviteStrings.of(context);
    final text = switch (event.kind) {
      InviteEventKind.duelJoined => s.duelJoined(event.link.code),
      InviteEventKind.friendRequested => s.friendRequested,
      InviteEventKind.friendAccepted => s.friendAccepted,
      InviteEventKind.savedForLater => s.savedForLater(event.link.kind),
      InviteEventKind.failed => s.failed(event.error ?? Object()),
    };
    showToast(context, text, icon: event.success ? Icons.check_rounded : null);
    if (event.success) ref.read(ranglisteRequestProvider.notifier).request();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InviteEvent?>(inviteEventsProvider, _onEvent);
    return widget.child;
  }
}
