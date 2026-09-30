import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/theme/typography.dart';
import 'package:slopetrack/app/widgets/numbers.dart';

import '../../support/pump.dart';

Future<void> _pumpAt(WidgetTester tester, double width, Widget child, {double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Padding(padding: const EdgeInsets.symmetric(horizontal: Tokens.pad), child: child)),
      ),
    ),
  );
}

void main() {
  const items = [('12', 'Abfahrten'), ('1.849', 'Höhenmeter'), ('69', 'Top-Speed')];

  testWidgets('PbTile strip at 393 pt and 1.3× text: two-line overlines, no overflow, equal heights', (tester) async {
    await _pumpAt(
      tester,
      393,
      const Row(
        children: [
          Expanded(child: PbTile(label: 'Top-Speed', value: '61', unit: 'km/h')),
          SizedBox(width: 8),
          Expanded(child: PbTile(label: 'Größter Tag', value: '1.804', unit: 'hm')),
          SizedBox(width: 8),
          Expanded(child: PbTile(label: 'Längste Abfahrt', value: '312', unit: 'hm')),
        ],
      ),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    final heights = tester.widgetList(find.byType(PbTile)).map((w) => tester.getSize(find.byWidget(w)).height).toSet();
    expect(heights, hasLength(1));
    expect(heights.single, moreOrLessEquals(72 * 1.3));
  });

  testWidgets('PbTile keeps its 72 pt at 1× text', (tester) async {
    await _pumpAt(tester, 393, const PbTile(label: 'Top-Speed', value: '61', unit: 'km/h'));
    expect(tester.getSize(find.byType(PbTile)).height, 72);
  });

  testWidgets('three unit items at 375 pt: numeral, unit beside it, overline below, no overflow', (tester) async {
    await _pumpAt(tester, 375, const MetricStrip(items: items, units: ['Stk', 'hm', 'km/h']));
    expect(tester.takeException(), isNull);

    for (final (value, unit, label) in const [('12', 'Stk', 'ABFAHRTEN'), ('1.849', 'hm', 'HÖHENMETER'), ('69', 'km/h', 'TOP-SPEED')]) {
      final v = tester.getRect(find.text(value));
      final u = tester.getRect(find.text(unit));
      final l = tester.getRect(find.text(label));
      expect(u.left, greaterThan(v.right), reason: '$unit sits right of $value');
      expect(u.height, lessThan(v.height), reason: '$unit is smaller than $value');
      expect(l.top, greaterThanOrEqualTo(v.bottom), reason: '$label sits below $value');
      expect(u.right, lessThanOrEqualTo(375 - Tokens.pad + 0.01));
    }
    // Units are tertiary and never part of the numeral string.
    final unit = tester.widget<Text>(find.text('km/h'));
    expect(unit.style!.color, AppColors.dark.textTertiary);
    expect(unit.style!.fontSize, AppText.unitFor(15));
    // The three overlines share one line.
    final tops = ['ABFAHRTEN', 'HÖHENMETER', 'TOP-SPEED'].map((t) => tester.getRect(find.text(t)).top).toSet();
    expect(tops, hasLength(1));
  });

  testWidgets('unit items never overflow: long values and 2× text scale down instead', (tester) async {
    await _pumpAt(
      tester,
      375,
      const MetricStrip(size: 22, items: [('12.345.678', 'Abfahrten'), ('1.849.000', 'Höhenmeter'), ('169,5', 'Top-Speed')], units: ['Stk', 'hm', 'km/h']),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final tops = ['ABFAHRTEN', 'HÖHENMETER', 'TOP-SPEED'].map((t) => tester.getRect(find.text(t)).top).toSet();
    expect(tops, hasLength(1));
  });

  testWidgets('without units the strip is unchanged: one numeral Text per item, no unit, no FittedBox', (tester) async {
    await _pumpAt(tester, 375, const MetricStrip(items: items));
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(MetricStrip), matching: find.byType(FittedBox)), findsNothing);
    expect(find.descendant(of: find.byType(MetricStrip), matching: find.byType(Text)), findsNWidgets(6));
  });

  testWidgets('a mixed strip keeps unit-less items as they were and aligns all overlines', (tester) async {
    await _pumpAt(tester, 375, const MetricStrip(items: items, units: [null, 'hm']));
    expect(tester.takeException(), isNull);
    expect(find.text('hm'), findsOneWidget);
    expect(find.descendant(of: find.byType(MetricStrip), matching: find.byType(FittedBox)), findsOneWidget);
    final plain = tester.getRect(find.text('12'));
    final withUnit = tester.getRect(find.text('1.849'));
    expect(withUnit.top, moreOrLessEquals(plain.top, epsilon: 0.5));
    expect(withUnit.height, moreOrLessEquals(plain.height, epsilon: 0.5));
    final tops = ['ABFAHRTEN', 'HÖHENMETER', 'TOP-SPEED'].map((t) => tester.getRect(find.text(t)).top).toSet();
    expect(tops.reduce((a, b) => a > b ? a : b) - tops.reduce((a, b) => a < b ? a : b), lessThan(0.5));
  });
}
