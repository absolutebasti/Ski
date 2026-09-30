import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/surfaces.dart';

import '../../support/pump.dart';

void main() {
  const box = SizedBox(key: Key('content'), width: 40, height: 20);
  // The dark hairline border insets the content by its own width on every side.
  const inset = Offset(10.5, 10.5);

  testWidgets('default: no Align wrapper, child stays top-start and the card hugs it', (tester) async {
    await pumpApp(tester, const Scaffold(body: Center(child: SurfaceCard(padding: EdgeInsets.all(10), child: box))));
    expect(find.descendant(of: find.byType(SurfaceCard), matching: find.byType(Align)), findsNothing);
    expect(tester.getSize(find.byType(SurfaceCard)), const Size(61, 41));
    expect(tester.getTopLeft(find.byKey(const Key('content'))), tester.getTopLeft(find.byType(SurfaceCard)) + inset);
  });

  testWidgets('alignment centres the child inside a fixed-size card', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Center(
          child: SizedBox(width: 200, height: 120, child: SurfaceCard(padding: EdgeInsets.all(10), alignment: Alignment.center, child: box)),
        ),
      ),
    );
    expect(find.descendant(of: find.byType(SurfaceCard), matching: find.byType(Align)), findsOneWidget);
    final card = tester.getRect(find.byType(SurfaceCard));
    expect(card.size, const Size(200, 120));
    expect(tester.getCenter(find.byKey(const Key('content'))), card.center);
  });

  testWidgets('alignment is directional and respects the padding', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Center(
          child: SizedBox(width: 200, height: 120, child: SurfaceCard(padding: EdgeInsets.all(10), alignment: AlignmentDirectional.bottomEnd, child: box)),
        ),
      ),
    );
    final card = tester.getRect(find.byType(SurfaceCard));
    expect(tester.getBottomRight(find.byKey(const Key('content'))), card.bottomRight - inset);
  });

  testWidgets('without alignment the same fixed-size card keeps the child top-start', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Center(child: SizedBox(width: 200, height: 120, child: SurfaceCard(padding: EdgeInsets.all(10), child: box))),
      ),
    );
    final card = tester.getRect(find.byType(SurfaceCard));
    expect(tester.getTopLeft(find.byKey(const Key('content'))), card.topLeft + inset);
  });
}
