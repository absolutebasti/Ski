import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../support/pump.dart';

const _metrics = ['Höhenmeter', 'Abfahrten', 'Ski-km', 'Top-Speed', 'Skitage', 'Punkte'];

/// The metric row at phone width: six chips, four fit — the right edge fades
/// over 16 pt so the rest reads as scrollable. Re-gold with
/// `flutter test test/features/social --update-goldens`.
Future<void> _pumpRow(WidgetTester tester, {double width = 300, List<String> labels = _metrics}) async {
  tester.view.physicalSize = const Size(400, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: const ValueKey('row'),
          child: SizedBox(width: width, child: SocialChipRow(labels: labels, selected: 0, onSelect: (_) {})),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('metric chip row fades the right edge while chips are off screen', (tester) async {
    await _pumpRow(tester);
    final fade = tester.widget<ChipRowFade>(find.byType(ChipRowFade));
    expect(fade.left, isFalse, reason: 'at the start the first chip is fully visible');
    expect(fade.right, isTrue);
    expect(find.byType(ShaderMask), findsOneWidget);
    await expectLater(find.byKey(const ValueKey('row')), matchesGoldenFile('goldens/chip_row_fade.png'));
  });

  testWidgets('scrolled to the end the fade swaps to the left edge', (tester) async {
    await _pumpRow(tester);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(-600, 0));
    await tester.pumpAndSettle();
    final fade = tester.widget<ChipRowFade>(find.byType(ChipRowFade));
    expect(fade.left, isTrue);
    expect(fade.right, isFalse);
  });

  testWidgets('a row that fits has no mask at all', (tester) async {
    await _pumpRow(tester, labels: const ['Freunde', 'Alle']);
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('the picker chip shows label and chevron and is tappable', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: SocialPickerChip(label: 'Gebiet: Kitzbühel', onTap: () => taps++)));
    await tester.pumpAndSettle();
    expect(find.text('Gebiet: Kitzbühel'), findsOneWidget);
    await tester.tap(find.text('Gebiet: Kitzbühel'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('the friends header button caps the badge at 9+', (tester) async {
    await pumpApp(tester, const Scaffold(body: FriendsHeaderButton(pending: 12)));
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, const Scaffold(body: FriendsHeaderButton(pending: 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friends-badge')), findsNothing);
  });
}
