import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/auth_service.dart';
import 'invite_actions.dart';
import 'invite_link_source.dart';
import 'invite_links.dart';
import 'pending_invite_store.dart';

/// What the handler did with a link — the UI ([InviteListener]) turns it into
/// a toast and, on success, switches to the Rangliste tab.
enum InviteEventKind {
  /// Joined the duel; [InviteEvent.link] carries the code.
  duelJoined,

  /// Friend request sent.
  friendRequested,

  /// The other side had asked first — now connected.
  friendAccepted,

  /// Signed out: the code is kept and used after the next sign-in.
  savedForLater,

  /// The join threw; [InviteEvent.error] is a SocialError / FriendsError.
  failed,
}

@immutable
class InviteEvent {
  const InviteEvent(this.kind, this.link, {this.error, this.seq = 0});

  final InviteEventKind kind;
  final InviteLink link;
  final Object? error;

  /// Monotonic per handler so two identical outcomes still notify listeners.
  final int seq;

  bool get success => kind == InviteEventKind.duelJoined || kind == InviteEventKind.friendRequested || kind == InviteEventKind.friendAccepted;

  @override
  String toString() => 'InviteEvent(${kind.name}, $link${error == null ? '' : ', $error'})';
}

/// Join flow for invite links.
///
/// Every parsed link goes through the pending store first, so the same path
/// serves 'link while running', 'launched by link' and 'link while signed out':
///   1. link arrives → parse → save as pending
///   2. auth known + signed in → consume: clear store, run the action, emit
///   3. auth known + signed out → emit [InviteEventKind.savedForLater] once;
///      the next sign-in ([onAuth]) consumes the pending link
/// Malformed links are ignored. Pure Dart apart from Riverpod-free callbacks;
/// [inviteLinkHandlerProvider] wires it.
class InviteLinkHandler {
  InviteLinkHandler({
    required this.source,
    required this.store,
    required this.actions,
    required this.emit,
    this.duplicateWindow = const Duration(seconds: 3),
  });

  final InviteLinkSource source;
  final PendingInviteStore store;
  final InviteActions actions;
  final void Function(InviteEvent event) emit;

  /// app_links delivers the launch link on the stream too; identical links
  /// inside this window are handled once.
  final Duration duplicateWindow;

  StreamSubscription<Uri>? _sub;
  bool _started = false;
  bool _authKnown = false;
  bool _signedIn = false;
  bool _announcedSaved = false;
  bool _consuming = false;
  int _seq = 0;
  Uri? _lastUri;
  DateTime? _lastAt;

  bool get isStarted => _started;

  /// Subscribes to the link source and reads the launch link. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _sub = source.links.listen(handleUri, onError: (Object _) {});
    final initial = await source.initialLink();
    if (initial != null) await handleUri(initial);
    // A pending link from a previous session (signed out then) is consumed as
    // soon as auth is known.
    await _tryConsume();
  }

  /// Sign-in state changed (or became known). Null = signed out.
  Future<void> onAuth(AuthUser? user) async {
    final wasSignedIn = _signedIn;
    _authKnown = true;
    _signedIn = user != null;
    if (_signedIn && !wasSignedIn) _announcedSaved = false;
    await _tryConsume();
  }

  /// Handles one incoming link; anything that is not an invite is ignored.
  Future<void> handleUri(Uri uri) async {
    final now = DateTime.now();
    if (_lastUri == uri && _lastAt != null && now.difference(_lastAt!) < duplicateWindow) return;
    _lastUri = uri;
    _lastAt = now;
    final link = InviteLinks.parse(uri);
    if (link == null) return;
    await store.save(link);
    _announcedSaved = false;
    await _tryConsume();
  }

  Future<void> _tryConsume() async {
    if (!_authKnown || _consuming) return;
    final link = await store.load();
    if (link == null) return;
    if (!_signedIn) {
      if (!_announcedSaved) {
        _announcedSaved = true;
        _emit(InviteEventKind.savedForLater, link);
      }
      return;
    }
    _consuming = true;
    try {
      // Cleared before the call: a failing join is not retried on every
      // auth event — the user still sees the toast and can enter the code.
      await store.clear();
      switch (link.kind) {
        case InviteKind.duel:
          await actions.joinDuel(link.code);
          _emit(InviteEventKind.duelJoined, link);
        case InviteKind.friend:
          final accepted = await actions.addFriend(link.code);
          _emit(accepted ? InviteEventKind.friendAccepted : InviteEventKind.friendRequested, link);
      }
    } catch (e) {
      _emit(InviteEventKind.failed, link, error: e);
    } finally {
      _consuming = false;
    }
  }

  void _emit(InviteEventKind kind, InviteLink link, {Object? error}) => emit(InviteEvent(kind, link, error: error, seq: ++_seq));

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Convenience for app.dart: `InviteLinkHandler.startWith(ref)` in
  /// initState. [InviteListener] does the same, so either wiring point is
  /// enough — but whoever starts the handler must also `ref.watch`
  /// [inviteLinkHandlerProvider] in build (see the provider's note).
  static Future<void> startWith(WidgetRef ref) => ref.read(inviteLinkHandlerProvider).start();
}

/// Link source — [NoInviteLinkSource] until the lead overrides it with the
/// app_links adapter (see invite_link_source.dart).
final inviteLinkSourceProvider = Provider<InviteLinkSource>((ref) => const NoInviteLinkSource());

final pendingInviteStoreProvider = Provider<PendingInviteStore>((ref) => const SharedPrefsPendingInviteStore());

/// Last outcome of the join flow; null until the first link. Listen, do not
/// watch — the value is an event, not state.
class InviteEvents extends Notifier<InviteEvent?> {
  @override
  InviteEvent? build() => null;

  void emit(InviteEvent event) => state = event;
}

final inviteEventsProvider = NotifierProvider<InviteEvents, InviteEvent?>(InviteEvents.new);

/// Counter the shell listens to: every increment = 'show the Rangliste tab'.
/// Wiring (lead, RootShell): `ref.listen(ranglisteRequestProvider, (_, __) => setState(() => _index = 2));`
class RanglisteRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}

final ranglisteRequestProvider = NotifierProvider<RanglisteRequests, int>(RanglisteRequests.new);

/// The one handler of the app. Follows [authStateProvider]; alive as long as
/// the ProviderScope.
///
/// Must be *watched* (or `ref.listen`ed / `container.listen`ed) by someone —
/// [InviteListener] does it. Riverpod 3 pauses a provider without active
/// listeners, and with it the `ref.listen(authStateProvider)` below; a
/// handler that is only `ref.read` never learns the sign-in state.
final inviteLinkHandlerProvider = Provider<InviteLinkHandler>((ref) {
  final handler = InviteLinkHandler(
    source: ref.watch(inviteLinkSourceProvider),
    store: ref.watch(pendingInviteStoreProvider),
    actions: ref.watch(inviteActionsProvider),
    emit: (e) => ref.read(inviteEventsProvider.notifier).emit(e),
  );
  ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, next) {
    // Loading keeps auth 'unknown'; an error means no session.
    if (next.isLoading && !next.hasValue) return;
    handler.onAuth(next.asData?.value);
  }, fireImmediately: true);
  ref.onDispose(handler.dispose);
  return handler;
});
