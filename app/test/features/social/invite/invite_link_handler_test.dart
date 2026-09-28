import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/invite/invite.dart';
import 'package:slopetrack/features/social/social_api.dart';

const _user = AuthUser(id: 'u1', displayName: 'Sebastian');
const _duel = 'https://slopetrack.app/d/KMJ4F2';

class _Rig {
  _Rig({Uri? initial, InviteLink? pending})
      : source = FakeInviteLinkSource(initial: initial),
        store = MemoryPendingInviteStore(pending);

  final FakeInviteLinkSource source;
  final MemoryPendingInviteStore store;
  final FakeInviteActions actions = FakeInviteActions();
  final List<InviteEvent> events = [];

  late final InviteLinkHandler handler = InviteLinkHandler(
    source: source,
    store: store,
    actions: actions,
    emit: events.add,
    duplicateWindow: Duration.zero,
  );

  Future<void> tick() => Future<void>.delayed(Duration.zero);
}

void main() {
  test('signed in: link → joinDuel with the code, duelJoined event, store cleared', () async {
    final r = _Rig();
    await r.handler.start();
    await r.handler.onAuth(_user);

    r.source.emit(_duel);
    await r.tick();

    expect(r.actions.duels, ['KMJ4F2']);
    expect(r.events.map((e) => e.kind), [InviteEventKind.duelJoined]);
    expect(r.events.single.link, const InviteLink(InviteKind.duel, 'KMJ4F2'));
    expect(r.store.value, isNull);
  });

  test('signed in: /f link → addFriend; accepted flag picks the event', () async {
    final r = _Rig();
    await r.handler.start();
    await r.handler.onAuth(_user);

    r.source.emit('slopetrack://f/ABC234');
    await r.tick();
    expect(r.actions.friends, ['ABC234']);
    expect(r.events.last.kind, InviteEventKind.friendRequested);

    r.actions.friendAccepted = true;
    r.source.emit('https://absolutebasti.github.io/Ski/f/?c=DEF567');
    await r.tick();
    expect(r.actions.friends, ['ABC234', 'DEF567']);
    expect(r.events.last.kind, InviteEventKind.friendAccepted);
  });

  test('signed out: code persisted and announced once, consumed once on sign-in', () async {
    final r = _Rig();
    await r.handler.start();
    await r.handler.onAuth(null);

    r.source.emit(_duel);
    await r.tick();

    expect(r.store.value, const InviteLink(InviteKind.duel, 'KMJ4F2'));
    expect(r.actions.duels, isEmpty);
    expect(r.events.map((e) => e.kind), [InviteEventKind.savedForLater]);

    // Another auth tick while still signed out does not nag again.
    await r.handler.onAuth(null);
    expect(r.events, hasLength(1));

    await r.handler.onAuth(_user);
    expect(r.actions.duels, ['KMJ4F2']);
    expect(r.store.value, isNull);
    expect(r.events.last.kind, InviteEventKind.duelJoined);

    // Same user emitted again (token refresh): nothing left to consume.
    await r.handler.onAuth(_user);
    await r.handler.onAuth(null);
    await r.handler.onAuth(_user);
    expect(r.actions.duels, ['KMJ4F2']);
    expect(r.events, hasLength(2));
  });

  test('auth still loading: link waits silently, then joins when the session arrives', () async {
    final r = _Rig();
    await r.handler.start();
    r.source.emit(_duel);
    await r.tick();
    expect(r.events, isEmpty, reason: 'no toast before auth is known');
    expect(r.store.value, isNotNull);

    await r.handler.onAuth(_user);
    expect(r.actions.duels, ['KMJ4F2']);
  });

  test('launch link (initialLink) is handled on start', () async {
    final r = _Rig(initial: Uri.parse('slopetrack://d/KMJ4F2'));
    await r.handler.onAuth(_user);
    await r.handler.start();
    expect(r.actions.duels, ['KMJ4F2']);
  });

  test('pending link from a previous session is consumed after start once signed in', () async {
    final r = _Rig(pending: const InviteLink(InviteKind.friend, 'ABC234'));
    await r.handler.start();
    await r.handler.onAuth(_user);
    expect(r.actions.friends, ['ABC234']);
    expect(r.store.value, isNull);
  });

  test('malformed links are ignored completely', () async {
    final r = _Rig();
    await r.handler.start();
    await r.handler.onAuth(_user);
    for (final bad in ['https://slopetrack.app/privacy.html', 'slopetrack://d/KMJ0F2', 'https://slopetrack.app/d/']) {
      r.source.emit(bad);
    }
    await r.tick();
    expect(r.actions.duels, isEmpty);
    expect(r.actions.friends, isEmpty);
    expect(r.events, isEmpty);
    expect(r.store.saves, 0);
  });

  test('a failing join emits failed with the error and is not retried on the next auth tick', () async {
    final r = _Rig();
    r.actions.duelError = const SocialError(SocialErrorKind.duelFull);
    await r.handler.start();
    await r.handler.onAuth(_user);
    r.source.emit(_duel);
    await r.tick();

    expect(r.events.single.kind, InviteEventKind.failed);
    expect(r.events.single.error, isA<SocialError>());
    expect(r.store.value, isNull);

    await r.handler.onAuth(_user);
    expect(r.actions.duels, ['KMJ4F2']);
  });

  test('the same link twice inside the duplicate window is handled once', () async {
    final source = FakeInviteLinkSource();
    final actions = FakeInviteActions();
    final handler = InviteLinkHandler(source: source, store: MemoryPendingInviteStore(), actions: actions, emit: (_) {});
    await handler.start();
    await handler.onAuth(_user);
    source.emit(_duel);
    source.emit(_duel);
    await Future<void>.delayed(Duration.zero);
    expect(actions.duels, ['KMJ4F2']);
    await handler.dispose();
  });

  test('start is idempotent', () async {
    final r = _Rig(initial: Uri.parse(_duel));
    await r.handler.onAuth(_user);
    await r.handler.start();
    await r.handler.start();
    expect(r.actions.duels, ['KMJ4F2']);
  });

  group('SharedPrefsPendingInviteStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('save / load / clear round-trip', () async {
      const store = SharedPrefsPendingInviteStore();
      expect(await store.load(), isNull);
      await store.save(const InviteLink(InviteKind.duel, 'KMJ4F2'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPrefsPendingInviteStore.key), 'd:KMJ4F2');
      expect(await store.load(), const InviteLink(InviteKind.duel, 'KMJ4F2'));
      await store.clear();
      expect(await store.load(), isNull);
      expect(prefs.containsKey(SharedPrefsPendingInviteStore.key), isFalse);
    });

    test('garbage in prefs reads as no pending link', () async {
      SharedPreferences.setMockInitialValues({SharedPrefsPendingInviteStore.key: 'nonsense'});
      expect(await const SharedPrefsPendingInviteStore().load(), isNull);
    });
  });

  group('inviteLinkHandlerProvider', () {
    late FakeInviteLinkSource source;
    late FakeSocialApi social;
    late StreamController<AuthUser?> auth;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      source = FakeInviteLinkSource();
      social = FakeSocialApi(userId: 'u1');
      auth = StreamController<AuthUser?>();
      container = ProviderContainer(
        overrides: [
          inviteLinkSourceProvider.overrideWithValue(source),
          socialApiProvider.overrideWithValue(social),
          authStateProvider.overrideWith((ref) => auth.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.close);
      addTearDown(source.close);
    });

    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('follows authStateProvider while it has an active listener', () async {
      final events = <InviteEvent?>[];
      container.listen(inviteEventsProvider, (_, e) => events.add(e));
      container.listen(inviteLinkHandlerProvider, (_, _) {});
      await container.read(inviteLinkHandlerProvider).start();

      auth.add(_user);
      await tick();
      source.emit(_duel);
      await tick();

      expect(social.joined, ['KMJ4F2']);
      expect(events.map((e) => e?.kind), [InviteEventKind.duelJoined]);
      expect(container.read(ranglisteRequestProvider), 0, reason: 'the tab switch is the listener widget\'s job');
    });

    test('regression: a handler that is only read is paused and never learns the auth state', () async {
      // Riverpod 3 pauses providers without active listeners together with
      // their ref.listen subscriptions. InviteListener therefore watches the
      // provider; this documents what happens without that.
      await container.read(inviteLinkHandlerProvider).start();
      auth.add(_user);
      await tick();
      source.emit(_duel);
      await tick();

      expect(social.joined, isEmpty);
      expect(container.read(authStateProvider), isA<AsyncLoading<AuthUser?>>());

      // The moment a listener appears the paused subscriptions resume and the
      // pending link is consumed.
      container.listen(inviteLinkHandlerProvider, (_, _) {});
      await tick();
      expect(social.joined, ['KMJ4F2']);
    });
  });
}
