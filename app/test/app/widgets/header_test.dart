import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/theme/typography.dart';
import 'package:slopetrack/app/widgets/header.dart';

import '../../support/pump.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('SectionLabel: overline left, trailing flush right at 1×', (tester) async {
    await _pump(tester, SectionLabel('Tage', trailing: Text('2 Tage · 14 Abfahrten', style: AppText.numXs(AppColors.dark.textSecondary))));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('TAGE')).dx, Tokens.pad);
    expect(tester.getTopRight(find.text('2 Tage · 14 Abfahrten')).dx, moreOrLessEquals(393 - Tokens.pad));
  });

  testWidgets('SectionLabel at 1.3×: a long trailing wraps right-aligned instead of overflowing', (tester) async {
    await _pump(
      tester,
      SectionLabel('Tage', trailing: Text('2 Tage · 14 Abfahrten · 3.608 Höhenmeter', style: AppText.numXs(AppColors.dark.textSecondary))),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    final trailing = find.text('2 Tage · 14 Abfahrten · 3.608 Höhenmeter');
    expect(tester.getTopRight(trailing).dx, moreOrLessEquals(393 - Tokens.pad));
    expect(tester.getSize(trailing).height, greaterThan(15 * 1.3 * 1.5)); // two lines
    expect(tester.getTopLeft(find.text('TAGE')).dx, Tokens.pad);
    expect(tester.getTopRight(find.text('TAGE')).dx + 12, lessThanOrEqualTo(tester.getTopLeft(trailing).dx + 0.01));
  });

  testWidgets('SectionLabel: a long overline keeps its full width next to a short trailing (medals sheet)', (tester) async {
    await _pump(tester, SectionLabel('Höhenmeter am Tag', trailing: Text('3 / 5', style: AppText.numXs(AppColors.dark.textSecondary))));
    expect(tester.takeException(), isNull);
    final title = find.text('HÖHENMETER AM TAG');
    expect(tester.renderObject<RenderParagraph>(title).didExceedMaxLines, isFalse); // not ellipsised
    final width = tester.getSize(title).width;
    expect(width, lessThan(393 - 2 * Tokens.pad - 12 - 96));
    expect(width, greaterThan((393 - 2 * Tokens.pad) * 0.4)); // wider than an even 40 % share would allow
    expect(tester.getTopRight(find.text('3 / 5')).dx, moreOrLessEquals(393 - Tokens.pad));
  });

  testWidgets('SectionLabel: an overline that would push the trailing out is ellipsised, 96 pt stay for the trailing', (tester) async {
    await _pump(tester, SectionLabel('Eine sehr lange Überschrift, die nicht in eine Zeile passt und deshalb gekürzt wird', trailing: const Text('3 / 5')));
    expect(tester.takeException(), isNull);
    final title = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('EINE SEHR'));
    expect(tester.getSize(title).width, moreOrLessEquals(393 - 2 * Tokens.pad - 12 - 96));
    expect(tester.getTopRight(find.text('3 / 5')).dx, moreOrLessEquals(393 - Tokens.pad));
  });

  testWidgets('SectionLabel without trailing keeps the overline at the left edge and ellipsises', (tester) async {
    await _pump(tester, const SectionLabel('Eine sehr lange Überschrift, die nicht in eine Zeile passt und deshalb gekürzt wird'), textScale: 1.3);
    expect(tester.takeException(), isNull);
    final t = tester.widget<Text>(find.byType(Text));
    expect(t.maxLines, 1);
    expect(t.overflow, TextOverflow.ellipsis);
    expect(tester.getTopLeft(find.byType(Text)).dx, Tokens.pad);
  });
}
