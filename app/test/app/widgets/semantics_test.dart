import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/widgets.dart';

import '../../support/pump.dart';

void main() {
  group('AppSheet close control', () {
    for (final (locale, expected) in const [(Locale('de'), 'Schließen'), (Locale('en'), 'Close')]) {
      testWidgets('is a button labelled "$expected" (${locale.languageCode}) and closes the sheet', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => AppSheet.show<void>(context, title: 'Einstellungen', builder: (_) => const Text('Inhalt')),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          locale: locale,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final label = MaterialLocalizations.of(tester.element(find.text('Inhalt'))).closeButtonLabel;
        expect(label, expected);
        final close = find.bySemanticsLabel(label);
        expect(close, findsOneWidget);
        expect(tester.getSemantics(close), matchesSemantics(label: label, isButton: true, hasTapAction: true));

        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.text('Inhalt'), findsNothing);
        handle.dispose();
      });
    }

    testWidgets('a sheet without title has no close control', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => AppSheet.show<void>(context, builder: (_) => const Text('Inhalt')), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Schließen'), findsNothing);
      handle.dispose();
    });
  });

  group('PbTile / StatTile', () {
    testWidgets('PbTile exposes one merged node "label value unit"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: Row(
            children: [
              Expanded(child: PbTile(label: 'Top-Speed', value: '69', unit: 'km/h')),
              Expanded(child: PbTile(label: 'Größte Abfahrt', value: '1.849')),
            ],
          ),
        ),
      );
      expect(tester.getSemantics(find.byType(PbTile).first), matchesSemantics(label: 'Top-Speed 69 km/h'));
      expect(tester.getSemantics(find.byType(PbTile).last), matchesSemantics(label: 'Größte Abfahrt 1.849'));
      // The fragments are no longer separate nodes (the visible overline is uppercased).
      expect(find.bySemanticsLabel('TOP-SPEED'), findsNothing);
      expect(find.bySemanticsLabel('69'), findsNothing);
      expect(find.bySemanticsLabel('km/h'), findsNothing);
      expect(find.text('TOP-SPEED'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a tappable PbTile is a button and the tap action reaches onTap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(tester, Scaffold(body: PbTile(label: 'Top-Speed', value: '69', unit: 'km/h', onTap: () => taps++)));
      final node = tester.getSemantics(find.byType(PbTile));
      expect(node, matchesSemantics(label: 'Top-Speed 69 km/h', isButton: true, hasTapAction: true));
      tester.semantics.tap(find.semantics.byLabel('Top-Speed 69 km/h'));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('StatTile exposes one merged node "label value unit"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: Column(
            children: [
              StatTile(label: 'Höhenmeter', value: '1.849', unit: 'hm', sparkline: [1, 3, 2]),
              StatTile(label: 'Abfahrten', value: '12'),
            ],
          ),
        ),
      );
      expect(tester.getSemantics(find.byType(StatTile).first), matchesSemantics(label: 'Höhenmeter 1.849 hm'));
      expect(tester.getSemantics(find.byType(StatTile).last), matchesSemantics(label: 'Abfahrten 12'));
      expect(find.bySemanticsLabel('HÖHENMETER'), findsNothing);
      expect(find.bySemanticsLabel('1.849'), findsNothing);
      handle.dispose();
    });

    testWidgets('a tappable StatTile is a button and the tap action reaches onTap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(tester, Scaffold(body: StatTile(label: 'Abfahrten', value: '12', onTap: () => taps++)));
      expect(tester.getSemantics(find.byType(StatTile)), matchesSemantics(label: 'Abfahrten 12', isButton: true, hasTapAction: true));
      tester.semantics.tap(find.semantics.byLabel('Abfahrten 12'));
      await tester.pump();
      expect(taps, 1);
      await tester.tap(find.byType(StatTile));
      expect(taps, 2);
      handle.dispose();
    });
  });

  group('StackedTimeBar', () {
    const labels = ['Abfahrt', 'Lift', 'Pause', 'Kein Signal'];

    testWidgets('semanticsLabel becomes one container node that replaces the legend nodes', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: StackedTimeBar(skiMs: 2520000, liftMs: 1800000, pauseMs: 720000, labels: labels, semanticsLabel: 'Abfahrt 42 min, Lift 30 min, Pause 12 min'),
        ),
      );
      final node = tester.getSemantics(find.byType(StackedTimeBar));
      expect(node, matchesSemantics(label: 'Abfahrt 42 min, Lift 30 min, Pause 12 min'));
      expect(node.childrenCount, 0);
      final semantics = tester.widget<Semantics>(
        find.descendant(of: find.byType(StackedTimeBar), matching: find.byType(Semantics)).first,
      );
      expect(semantics.container, isTrue);
      expect(find.bySemanticsLabel(RegExp('LIFT')), findsNothing);
      handle.dispose();
    });

    testWidgets('without semanticsLabel the legend is read as before', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const Scaffold(body: StackedTimeBar(skiMs: 2520000, liftMs: 1800000, pauseMs: 720000, labels: labels)));
      expect(find.descendant(of: find.byType(StackedTimeBar), matching: find.byType(ExcludeSemantics)), findsNothing);
      expect(find.bySemanticsLabel(RegExp('42 min')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('LIFT')), findsOneWidget);
      handle.dispose();
    });
  });

  group('showToast', () {
    testWidgets('text is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      late BuildContext ctx;
      await pumpApp(tester, Scaffold(body: Builder(builder: (context) {
        ctx = context;
        return const SizedBox.expand();
      })));
      showToast(ctx, 'Tag gespeichert');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final node = tester.getSemantics(find.text('Tag gespeichert'));
      expect(node.label, 'Tag gespeichert');
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node, matchesSemantics(label: 'Tag gespeichert', isLiveRegion: true));

      // Let the toast finish so no timer outlives the test.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Tag gespeichert'), findsNothing);
      handle.dispose();
    });
  });

  group('HoldToConfirmButton', () {
    Future<SemanticsNode> pumpHold(WidgetTester tester, {required Locale locale, String? hint}) async {
      await pumpApp(
        tester,
        Scaffold(body: Center(child: HoldToConfirmButton(label: 'Tag beenden', onConfirmed: () {}, semanticsHint: hint))),
        locale: locale,
      );
      return tester.getSemantics(find.byType(HoldToConfirmButton));
    }

    testWidgets('German locale: one button node, hint "Halten"', (tester) async {
      final handle = tester.ensureSemantics();
      final node = await pumpHold(tester, locale: const Locale('de'));
      expect(node, matchesSemantics(label: 'Tag beenden', hint: 'Halten', isButton: true));
      // The label is painted twice (base + inverted sweep) but spoken once.
      expect(find.text('Tag beenden'), findsNWidgets(2));
      expect(find.bySemanticsLabel('Tag beenden'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('other locales: hint "Hold"', (tester) async {
      final handle = tester.ensureSemantics();
      final node = await pumpHold(tester, locale: const Locale('en'));
      expect(node, matchesSemantics(label: 'Tag beenden', hint: 'Hold', isButton: true));
      handle.dispose();
    });

    testWidgets('semanticsHint overrides the default', (tester) async {
      final handle = tester.ensureSemantics();
      final node = await pumpHold(tester, locale: const Locale('de'), hint: 'Gedrückt halten, um den Tag zu beenden');
      expect(node, matchesSemantics(label: 'Tag beenden', hint: 'Gedrückt halten, um den Tag zu beenden', isButton: true));
      handle.dispose();
    });

    testWidgets('without Localizations the hint falls back to "Hold"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: Center(child: HoldToConfirmButton(label: 'End day', onConfirmed: () {}))),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSemantics(find.byType(HoldToConfirmButton)), matchesSemantics(label: 'End day', hint: 'Hold', isButton: true));
      handle.dispose();
    });

    testWidgets('the hold still confirms through the semantics wrapper', (tester) async {
      var confirmed = 0;
      await pumpApp(
        tester,
        Scaffold(body: Center(child: HoldToConfirmButton(label: 'Tag beenden', duration: const Duration(milliseconds: 400), onConfirmed: () => confirmed++))),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(confirmed, 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(confirmed, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
