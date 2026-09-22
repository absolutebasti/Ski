import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/features/account/account.dart';

void main() {
  test('without an api everything stays local and uses the auth fallback name', () async {
    final service = ProfileService();
    final profile = await service.load(userId: 'u1', fallbackName: 'Sebastian');
    expect(profile?.id, 'u1');
    expect(profile?.displayName, 'Sebastian');
    expect(profile?.shareLeaderboards, isFalse);

    await service.update(shareLeaderboards: true, displayName: 'Basti');
    expect(service.cached?.shareLeaderboards, isTrue);
    expect(service.cached?.displayName, 'Basti');
  });

  test('a missing row becomes a placeholder, an existing row is mapped', () async {
    final empty = FakeProfileApi(userId: 'u1');
    expect((await ProfileService(api: empty).load(userId: 'u1'))?.displayName, Profile.fallbackName);

    final api = FakeProfileApi(userId: 'u1', row: {
      'id': 'u1',
      'display_name': 'Sebastian',
      'home_resort_id': 'kitzbuehel',
      'share_leaderboards': true,
    });
    final profile = await ProfileService(api: api).load(userId: 'u1');
    expect(profile?.displayName, 'Sebastian');
    expect(profile?.homeResortId, 'kitzbuehel');
    expect(profile?.shareLeaderboards, isTrue);
    expect(profile?.initial, 'S');
  });

  test('update sends only the touched columns and clears with an explicit null', () async {
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
    final service = ProfileService(api: api);
    await service.load(userId: 'u1');

    await service.update(shareLeaderboards: true);
    expect(api.patches.last, {'share_leaderboards': true});

    await service.update(homeResortId: 'ischgl');
    expect(api.patches.last, {'home_resort_id': 'ischgl'});
    expect(service.cached?.displayName, 'Sebastian', reason: 'untouched columns keep their value');

    await service.update(homeResortId: null);
    expect(api.patches.last, {'home_resort_id': null});
    expect(service.cached?.homeResortId, isNull);
  });

  test('a failing backend keeps the local value and never throws', () async {
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'}, failUpdate: true);
    final service = ProfileService(api: api);
    await service.load(userId: 'u1');
    await service.update(displayName: 'Basti');
    expect(service.cached?.displayName, 'Basti');

    final offline = ProfileService(api: FakeProfileApi(userId: 'u1', failFetch: true));
    expect((await offline.load(userId: 'u1', fallbackName: 'Sebastian'))?.displayName, 'Sebastian');
  });

  test('load caches per session, force refetches, clear drops it', () async {
    final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
    final service = ProfileService(api: api);
    await service.load(userId: 'u1');
    await service.load(userId: 'u1');
    expect(api.fetchCount, 1);
    await service.load(userId: 'u1', force: true);
    expect(api.fetchCount, 2);
    service.clear();
    expect(service.cached, isNull);
  });

  test('onChanged fires once per real change', () async {
    var calls = 0;
    final service = ProfileService(api: FakeProfileApi(userId: 'u1'), onChanged: () => calls++);
    await service.load(userId: 'u1');
    await service.update(shareLeaderboards: true);
    expect(calls, 1);
    await service.update(shareLeaderboards: true);
    expect(calls, 1, reason: 'same value → no re-emit');
  });
}
