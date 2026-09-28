/// Einladungslinks (SOC-DEEPLINK): link builders/parser, the join flow for
/// `/d/<CODE>` and `/f/<CODE>`, share texts and the toast listener.
///
/// Wiring (lead):
///   * app.dart: `home: InviteListener(child: RootShell())` — starts the
///     handler and shows the toasts; or `InviteLinkHandler.startWith(ref)`.
///   * shell.dart: `ref.listen(ranglisteRequestProvider, (_, __) => setState(() => _index = 2))`.
///   * main.dart: override [inviteLinkSourceProvider] with the app_links
///     adapter (snippet in invite_link_source.dart) once the package is in.
library;

export 'invite_actions.dart';
export 'invite_link_handler.dart';
export 'invite_link_source.dart';
export 'invite_links.dart';
export 'invite_listener.dart';
export 'invite_strings.dart';
export 'pending_invite_store.dart';
