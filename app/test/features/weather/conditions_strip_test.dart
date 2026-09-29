import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/data/weather/weather_provider.dart';
import 'package:slopetrack/data/weather/weather_report.dart';
import 'package:slopetrack/features/weather/conditions_strip.dart';
import 'package:slopetrack/features/weather/weather_line.dart';

import '../../support/pump.dart';
import '../days/golden_fonts.dart';

const _de = AppLocale(Locale('de'));
const _en = AppLocale(Locale('en'));
const _resort = Resort(id: 'kitzbuehel', name: 'Kitzbühel', country: 'AT', lat: 47.44, lon: 12.39, radiusKm: 12, baseAltM: 800, summitAltM: 2000);

/// −4° at the summit, 12 cm fresh, 85 cm depth, snowing.
const _winter = WeatherReport(fetchedAt: 1, tempBaseC: -1.2, tempSummitC: -4.4, freshSnowCm: 12.4, snowDepthCm: 85, wmoCode: 71);
/// Sunny, no fresh snow but a base — depth shows instead.
const _sunny = WeatherReport(fetchedAt: 1, tempBaseC: 2, tempSummitC: -3, freshSnowCm: 0, snowDepthCm: 64, wmoCode: 0);
/// 15 °C, nothing white anywhere.
const _summer = WeatherReport(fetchedAt: 1, tempBaseC: 15, tempSummitC: 11, freshSnowCm: 0, snowDepthCm: 0, wmoCode: 0);

void main() {
  setUpAll(loadInterFonts);

  group('WeatherLine.format', () {
    const w = WeatherSnapshot(fetchedAt: 1, tempBaseC: -1.2, tempSummitC: -6.5, freshSnowCm: 12.4, wmoCode: 71);
    test('includeResort: false drops the name, the rest stays', () {
      expect(WeatherLine.format(_resort, w, de: true), 'Kitzbühel · −7° Berg · 12 cm Neuschnee');
      expect(WeatherLine.format(_resort, w, de: true, includeResort: false), '−7° Berg · 12 cm Neuschnee');
      expect(WeatherLine.format(_resort, null, de: true, includeResort: false), '');
    });
  });

  group('ConditionsStrip.pairs', () {
    test('temperature, fresh snow and the weather word', () {
      expect(ConditionsStrip.pairs(_winter, _de), [('−4°', 'Berg'), ('12 cm', 'Neuschnee'), ('Schneefall', 'Heute')]);
      expect(ConditionsStrip.pairs(_winter, _en), [('−4°', 'Summit'), ('12 cm', 'Fresh snow'), ('Snowfall', 'Today')]);
    });

    test('no fresh snow → the snow depth takes the middle slot', () {
      expect(ConditionsStrip.pairs(_sunny, _de), [('−3°', 'Berg'), ('64 cm', 'Schneehöhe'), ('Sonnig', 'Heute')]);
    });

    test('base-only temperature reads Tal; a plain snapshot works too', () {
      const base = WeatherSnapshot(fetchedAt: 1, tempBaseC: 1.6, wmoCode: 3);
      expect(ConditionsStrip.pairs(base, _de), [('2°', 'Tal'), ('Bewölkt', 'Heute')]);
      expect(ConditionsStrip.pairs(null, _de), isEmpty);
    });
  });

  group('ConditionsStrip.shouldShow', () {
    test('hidden without a snapshot and for 15 °C without snow data', () {
      expect(ConditionsStrip.shouldShow(null), isFalse);
      expect(ConditionsStrip.shouldShow(_summer), isFalse);
    });

    test('shown in winter, and when warm but with a snow base', () {
      expect(ConditionsStrip.shouldShow(_winter), isTrue);
      expect(ConditionsStrip.shouldShow(_sunny), isTrue);
      const warmBase = WeatherReport(fetchedAt: 1, tempBaseC: 14, snowDepthCm: 30, wmoCode: 0);
      expect(ConditionsStrip.shouldShow(warmBase), isTrue);
      const coolDry = WeatherSnapshot(fetchedAt: 1, tempBaseC: 4, wmoCode: 2);
      expect(ConditionsStrip.shouldShow(coolDry), isTrue, reason: '≤ 10 °C stays even without snow data');
    });
  });

  testWidgets('the provider-backed strip renders nothing at 15 °C without snow', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: ConditionsStrip(resort: _resort)),
      overrides: [weatherProvider.overrideWith((ref, resort) async => _summer)],
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(MetricStrip), findsNothing);
    expect(find.byType(SurfaceCard), findsNothing);
  });

  testWidgets('the provider-backed strip shows three pairs in winter', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: ConditionsStrip(resort: _resort)),
      overrides: [weatherProvider.overrideWith((ref, resort) async => _winter)],
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('−4°'), findsOneWidget);
    expect(find.text('BERG'), findsOneWidget);
    expect(find.text('12 cm'), findsOneWidget);
    expect(find.text('NEUSCHNEE'), findsOneWidget);
    expect(find.text('HEUTE'), findsOneWidget);
    expect(find.textContaining('Kitzbühel'), findsNothing, reason: 'the header caption names the resort');
  });

  testWidgets('golden: value/overline pairs at 393 pt', (tester) async {
    tester.view.physicalSize = const Size(393, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: RepaintBoundary(key: ValueKey('strip'), child: ConditionsStripBody(weather: _winter)),
        ),
      ),
    );
    await tester.pump();
    await expectLater(find.byKey(const ValueKey('strip')), matchesGoldenFile('goldens/conditions_strip_winter.png'));
    expect(tester.takeException(), isNull);
  });
}
