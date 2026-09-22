import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schwung/app/shell.dart';
import 'package:schwung/app/widgets/widgets.dart';
import 'package:schwung/core/core.dart';

import '../support/pump.dart';
import '../support/screen_overrides.dart';

void main() {
  testWidgets('shell shows two tabs with the real screens', (tester) async {
    await pumpApp(tester, const RootShell(), overrides: screenOverrides());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Tage'), findsWidgets);
  });

  testWidgets('hold-to-confirm fires only after the hold duration', (tester) async {
    var fired = 0;
    await pumpApp(tester, Scaffold(body: Center(child: HoldToConfirmButton(label: 'Tag beenden', onConfirmed: () => fired++))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Tag beenden')));
    await tester.pump(); // ticker t0
    await tester.pump(const Duration(milliseconds: 400));
    expect(fired, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(fired, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(fired, 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  test('season key spans July to June', () {
    expect(seasonKey(DateTime(2025, 12, 27)), '2025/26');
    expect(seasonKey(DateTime(2026, 3, 1)), '2025/26');
    expect(seasonKey(DateTime(2026, 7, 1)), '2026/27');
  });

  test('formatting', () {
    expect(Fmt.kmh(18.83, locale: 'de'), '68');
    expect(Fmt.metres(1804, locale: 'de'), '1.804');
    expect(Fmt.clock(3725000), '1:02:05');
  });
}
