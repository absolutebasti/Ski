import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';
import '../../../support/screen_overrides.dart';
import '../social_fixtures.dart';
import 'rider_fixtures.dart';

/// SOC-LOOP: every place that shows a rider passes `avatar_url` into
/// [AvatarCircle] — a network image when the row carries one, initials when
/// null. (The test HTTP client answers 400, so the image falls back to its
/// errorBuilder; the assertion is on the provider the widget asked for.)
const _url = 'https://svzmmpzevmpodcelzvit.supabase.co/storage/v1/object/public/avatars/u9.jpg';

NetworkImage? _networkImage(WidgetTester tester) {
  final images = find.byType(Image);
  if (images.evaluate().isEmpty) return null;
  final provider = tester.widget<Image>(images.first).image;
  return provider is NetworkImage ? provider : null;
}

void main() {
  group('RiderSheet', () {
    Future<void> pump(WidgetTester tester, RiderProfile rider) async {
      await pumpApp(
        tester,
        Scaffold(backgroundColor: Colors.transparent, body: Padding(padding: const EdgeInsets.all(20), child: RiderSheetBody(userId: rider.userId))),
        overrides: [
          ...screenOverrides(resorts: kResorts),
          ...socialOverrides(api: FakeSocialApi(userId: 'u1'), user: kUser),
          ...riderOverrides(api: FakeRiderApi(profiles: {rider.userId: rider})),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('network image when the profile carries avatar_url', (tester) async {
      await pump(tester, RiderProfile.fromJson({...kLenaJson, 'avatar_url': _url}));
      final avatar = tester.widget<AvatarCircle>(find.byType(AvatarCircle));
      expect(avatar.avatarUrl, _url);
      expect(_networkImage(tester)?.url, _url);
      expect(tester.takeException(), isNull);
    });

    testWidgets('initials when avatar_url is null', (tester) async {
      await pump(tester, kLena);
      expect(tester.widget<AvatarCircle>(find.byType(AvatarCircle)).avatarUrl, isNull);
      expect(_networkImage(tester), isNull);
      expect(find.text('LB'), findsOneWidget);
    });
  });

  group('FriendsSheet identity row', () {
    Future<void> pump(WidgetTester tester, Friend friend) async {
      tester.view.physicalSize = const Size(1179, 3600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final overrides = <Override>[
        friendsApiProvider.overrideWithValue(FakeFriendsApi(userId: 'u1', friends: [friend])),
        authStateProvider.overrideWith((ref) => Stream.value(kUser)),
      ];
      await pumpApp(tester, const Scaffold(body: FriendsSheetBody()), overrides: overrides);
      await tester.pumpAndSettle();
    }

    testWidgets('network image when the friend carries avatar_url', (tester) async {
      await pump(tester, Friend.fromJson(const {'user_id': 'u9', 'display_name': 'Lena Bergmann', 'avatar_url': _url, 'status': 'accepted', 'incoming': false}));
      expect(find.text('Lena Bergmann'), findsOneWidget);
      final avatars = tester.widgetList<AvatarCircle>(find.byType(AvatarCircle)).where((a) => a.name == 'Lena Bergmann');
      expect(avatars.single.avatarUrl, _url);
      expect(_networkImage(tester)?.url, _url);
      expect(tester.takeException(), isNull);
    });

    testWidgets('initials when avatar_url is null', (tester) async {
      await pump(tester, const Friend(userId: 'u9', displayName: 'Lena Bergmann', countryCode: 'AT'));
      final avatars = tester.widgetList<AvatarCircle>(find.byType(AvatarCircle)).where((a) => a.name == 'Lena Bergmann');
      expect(avatars.single.avatarUrl, isNull);
      expect(_networkImage(tester), isNull);
      expect(find.text('LB'), findsOneWidget);
    });
  });

  group('ChallengeBoardRow', () {
    Future<void> pump(WidgetTester tester, ChallengeBoardEntry entry) async {
      await pumpApp(tester, Scaffold(body: ChallengeBoardRow(entry: entry, metric: SocialMetric.dropM)));
      await tester.pumpAndSettle();
    }

    testWidgets('network image when the entry carries avatar_url', (tester) async {
      await pump(tester, ChallengeBoardEntry.fromJson(const {'rank': 1, 'user_id': 'u9', 'display_name': 'Lena Bergmann', 'avatar_url': _url, 'value': 6200}));
      expect(tester.widget<AvatarCircle>(find.byType(AvatarCircle)).avatarUrl, _url);
      expect(_networkImage(tester)?.url, _url);
      expect(tester.takeException(), isNull);
    });

    testWidgets('initials when avatar_url is null', (tester) async {
      await pump(tester, const ChallengeBoardEntry(rank: 1, userId: 'u9', displayName: 'Lena Bergmann', value: 6200));
      expect(tester.widget<AvatarCircle>(find.byType(AvatarCircle)).avatarUrl, isNull);
      expect(_networkImage(tester), isNull);
      expect(find.text('LB'), findsOneWidget);
    });
  });
}
