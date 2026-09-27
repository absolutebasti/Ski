import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../support/pump.dart';
import 'social_fixtures.dart';

Future<void> _pump(WidgetTester tester, {FakeSocialApi? api, String? own = 'AT', Locale locale = const Locale('de')}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: CountryBoardCard(seasonKey: '2025/26', period: LeaderboardPeriod.season, ownCountryCode: own),
      ),
    ),
    overrides: socialOverrides(api: api, user: kUser),
    locale: locale,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rows in points order, own country ringed and washed', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', countries: kCountries));

    final rows = tester.widgetList<CountryRow>(find.byType(CountryRow)).toList();
    expect(rows.map((r) => r.entry.countryCode), ['CH', 'AT', 'DE']);
    expect(rows.map((r) => r.rank), [1, 2, 3]);
    expect(rows.where((r) => r.own).single.entry.countryCode, 'AT');

    final flags = tester.widgetList<CountryFlag>(find.byType(CountryFlag)).toList();
    expect(flags.where((f) => f.ring).single.countryCode, 'AT');

    expect(find.text('120.000'), findsOneWidget);
    expect(find.text('90 Fahrer'), findsOneWidget);
    expect(find.text('Pkt.'), findsNWidgets(3));
  });

  testWidgets('no own country → nothing ringed; english names', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1', countries: kCountries), own: null, locale: const Locale('en'));
    expect(tester.widgetList<CountryFlag>(find.byType(CountryFlag)).where((f) => f.ring), isEmpty);
    expect(find.text('Switzerland'), findsOneWidget);
    expect(find.text('250 riders'), findsOneWidget);
    expect(find.text('Team ranking · Season'), findsOneWidget);
  });

  testWidgets('the own team stays visible below the cut', (tester) async {
    final many = [
      for (var i = 0; i < 10; i++) CountryEntry(countryCode: 'A${String.fromCharCode(0x42 + i)}', riders: 10 - i, points: 10000.0 - i * 100),
      const CountryEntry(countryCode: 'AT', riders: 1, points: 50),
    ];
    await _pump(tester, api: FakeSocialApi(userId: 'u1', countries: many));
    final rows = tester.widgetList<CountryRow>(find.byType(CountryRow)).toList();
    expect(rows, hasLength(9), reason: '8 shown + the own team');
    expect(rows.last.entry.countryCode, 'AT');
    expect(rows.last.rank, 11);
  });

  testWidgets('empty and offline shrink to one caption line', (tester) async {
    await _pump(tester, api: FakeSocialApi(userId: 'u1'));
    expect(find.text('Noch kein Land gewertet.'), findsOneWidget);
    expect(find.byType(CountryRow), findsNothing);

    await _pump(tester, api: FakeSocialApi(userId: 'u1', failWith: const SocialError(SocialErrorKind.offline)));
    expect(find.text('Keine Verbindung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
