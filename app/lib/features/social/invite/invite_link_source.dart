import 'dart:async';

/// Where incoming links come from. The real adapter wraps `app_links`
/// (package added by the lead — see the snippet below); tests and the
/// package-less build use [NoInviteLinkSource] / [FakeInviteLinkSource].
///
/// app_links adapter (lib/app or wherever the lead keeps platform glue):
/// ```dart
/// import 'package:app_links/app_links.dart';
/// class AppLinksInviteLinkSource implements InviteLinkSource {
///   final _links = AppLinks();
///   @override
///   Future<Uri?> initialLink() => _links.getInitialLink();
///   @override
///   Stream<Uri> get links => _links.uriLinkStream;
/// }
/// // ProviderScope(overrides: [inviteLinkSourceProvider.overrideWithValue(AppLinksInviteLinkSource())])
/// ```
/// Note: app_links delivers the initial link on `uriLinkStream` as well, so
/// the handler de-duplicates identical links arriving within a few seconds.
abstract class InviteLinkSource {
  /// The link the app was launched with, null for a plain launch.
  Future<Uri?> initialLink();

  /// Links arriving while the app runs (Universal Link or slopetrack://).
  Stream<Uri> get links;
}

/// No platform integration — offline builds and the state before the lead
/// adds app_links. Never emits.
class NoInviteLinkSource implements InviteLinkSource {
  const NoInviteLinkSource();

  @override
  Future<Uri?> initialLink() async => null;

  @override
  Stream<Uri> get links => const Stream.empty();
}

/// Test double: set [initial] before the handler starts, push with [emit].
class FakeInviteLinkSource implements InviteLinkSource {
  FakeInviteLinkSource({this.initial});

  Uri? initial;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> get links => _controller.stream;

  void emit(String link) => _controller.add(Uri.parse(link));

  Future<void> close() => _controller.close();
}
