import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/settings.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/account/account.dart';

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

  group('country_code (migration 0004)', () {
    test('fromRow normalises, update patches, null clears', () async {
      final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian', 'country_code': 'at'});
      final service = ProfileService(api: api);
      final profile = await service.load(userId: 'u1');
      expect(profile?.countryCode, 'AT');

      await service.update(countryCode: 'ch');
      expect(api.patches.last, {'country_code': 'CH'});
      expect(service.cached?.countryCode, 'CH');

      await service.update(countryCode: null);
      expect(api.patches.last, {'country_code': null});
      expect(service.cached?.countryCode, isNull);

      await service.update(countryCode: 'AUT');
      expect(api.patches.last, {'country_code': null}, reason: 'anything but alpha-2 would trip the server check');
    });

    test('pushCountry writes once, only when the server differs', () async {
      final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
      final service = ProfileService(api: api);

      await service.pushCountry('AT', userId: 'u1');
      expect(api.patches, [
        {'country_code': 'AT'}
      ]);

      await service.pushCountry('AT', userId: 'u1');
      expect(api.patches, hasLength(1), reason: 'already on the server');

      await service.pushCountry(null, userId: 'u1');
      await service.pushCountry('X', userId: 'u1');
      expect(api.patches, hasLength(1), reason: 'no valid code → no write');

      final offline = ProfileService();
      await offline.pushCountry('AT', userId: 'u1');
      expect(offline.cached, isNull, reason: 'without an api nothing happens');
    });

    test('profileProvider mirrors Settings.countryCode onto the profile', () async {
      final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian', 'country_code': 'DE'});
      final container = ProviderContainer(overrides: [
        profileApiProvider.overrideWithValue(api),
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u1', displayName: 'Sebastian'))),
        settingsProvider.overrideWith(() => SettingsNotifier(null, initial: const Settings(onboardingDone: true, countryCode: 'AT'))),
      ]);
      addTearDown(container.dispose);

      final sub = container.listen(profileProvider, (_, _) {});
      addTearDown(sub.close);
      // First pass: auth stream resolves, profile loads, mismatch is pushed.
      await container.read(profileProvider.future);
      await Future<void>.delayed(Duration.zero);
      final profile = await container.read(profileProvider.future);
      expect(profile?.countryCode, 'AT');
      expect(api.patches.where((p) => p['country_code'] == 'AT'), hasLength(1));
    });
  });

  group('avatar (PROFILE-PAGE)', () {
    final picked = PickedAvatar(Uint8List.fromList([1, 2, 3]));

    test('setAvatar uploads to <uid>/avatar.jpg, then patches avatar_url', () async {
      final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'});
      final service = ProfileService(api: api);
      await service.load(userId: 'u1');

      expect(await service.setAvatar(picked), isTrue);
      expect(api.uploads.single.path, 'u1/avatar.jpg');
      expect(api.uploads.single.contentType, 'image/jpeg');
      final url = '${FakeProfileApi.publicBase}u1/avatar.jpg';
      expect(api.patches, [
        {'avatar_url': url},
      ]);
      expect(service.cached?.avatarUrl, url);

      final png = PickedAvatar(Uint8List.fromList([4]), contentType: 'image/png');
      expect(await service.setAvatar(png), isTrue);
      expect(api.uploads.last.path, 'u1/avatar.png');
    });

    test('a failed upload leaves the row untouched and returns false', () async {
      final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian'}, failUpload: true);
      final service = ProfileService(api: api);
      await service.load(userId: 'u1');
      expect(await service.setAvatar(picked), isFalse);
      expect(api.patches, isEmpty);
      expect(service.cached?.avatarUrl, isNull);
    });

    test('without an api or a user nothing happens', () async {
      expect(await ProfileService().setAvatar(picked), isFalse);
      expect(await ProfileService(api: FakeProfileApi()).setAvatar(picked), isFalse);
    });

    test('update(avatarUrl: null) clears the picture', () async {
      final api = FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Sebastian', 'avatar_url': 'https://x/a.jpg'});
      final service = ProfileService(api: api);
      expect((await service.load(userId: 'u1'))?.avatarUrl, 'https://x/a.jpg');
      await service.update(avatarUrl: null);
      expect(api.patches.last, {'avatar_url': null});
      expect(service.cached?.avatarUrl, isNull);
    });
  });
}
