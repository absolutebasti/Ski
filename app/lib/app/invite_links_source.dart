import 'package:app_links/app_links.dart';

import '../features/social/invite/invite_link_source.dart';

/// Platform adapter for invite links: Universal Links (applinks: entitlement)
/// and the `slopetrack://` scheme, both delivered by app_links. Overrides
/// `inviteLinkSourceProvider` in main.dart; tests use the fakes.
class AppLinksInviteLinkSource implements InviteLinkSource {
  AppLinksInviteLinkSource();
  final AppLinks _links = AppLinks();

  @override
  Future<Uri?> initialLink() => _links.getInitialLink();

  @override
  Stream<Uri> get links => _links.uriLinkStream;
}
