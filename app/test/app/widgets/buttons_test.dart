import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/app/theme/theme.dart';
import 'package:slopetrack/app/theme/tokens.dart';
import 'package:slopetrack/app/widgets/widgets.dart';

import '../../support/golden_fonts.dart';

/// Button audit guard (.context/plan/buttons-audit.md): every button variant,
/// enabled and disabled, in both themes, on a 375 pt phone at 1.3× text —
/// no RenderFlex overflow, one height ramp, disabled reads as disabled, and
/// every control takes taps on at least 44 × 44 pt.
const _phone = Size(375, 812);

void _noop() {}

/// Every variant with the longest real German labels of the app.
List<Widget> _variants({required bool enabled}) {
  final VoidCallback? tap = enabled ? _noop : null;
  return [
    PrimaryButton(key: const ValueKey('start'), label: 'Tag starten', glyph: Glyph.play, height: Tokens.startButton, onPressed: tap),
    PrimaryButton(key: const ValueKey('primary-lg'), label: 'Einstellungen öffnen', onPressed: tap),
    PrimaryButton(key: const ValueKey('primary-md'), label: 'Herausfordern', glyph: Glyph.podium, height: Tokens.buttonMd, glow: false, onPressed: tap),
    SecondaryButton(key: const ValueKey('secondary-lg'), label: 'Ohne Konto weiter', onPressed: tap),
    SecondaryButton(key: const ValueKey('secondary-md'), label: 'Jetzt synchronisieren', icon: Icons.sync_rounded, height: Tokens.buttonMd, onPressed: tap),
    SecondaryButton(key: const ValueKey('secondary-danger'), label: 'Alle Daten löschen', glyph: Glyph.trash, danger: true, onPressed: tap),
    AppleButton(key: const ValueKey('apple'), label: 'Mit Apple anmelden', onPressed: tap),
    HoldToConfirmButton(key: const ValueKey('hold'), label: 'Tag beenden', onConfirmed: _noop),
    Center(child: GhostButton(key: const ValueKey('ghost'), label: 'Überspringen', onPressed: tap)),
    // Dock pair: Teilen + Löschen side by side.
    Row(
      children: [
        Expanded(child: PrimaryButton(key: const ValueKey('pair-primary'), label: 'Teilen', onPressed: tap)),
        const SizedBox(width: 12),
        SecondaryButton(key: const ValueKey('pair-danger'), label: 'Löschen', danger: true, onPressed: tap),
      ],
    ),
    // Sheet pair: Melden + Blockieren.
    Row(
      children: [
        Expanded(child: SecondaryButton(key: const ValueKey('report'), label: 'Melden', height: Tokens.buttonMd, onPressed: tap)),
        const SizedBox(width: 10),
        Expanded(child: SecondaryButton(key: const ValueKey('block'), label: 'Blockieren', height: Tokens.buttonMd, danger: true, onPressed: tap)),
      ],
    ),
    // Inline row action beside text; live dock icon-only + hold.
    Row(
      children: [
        const Expanded(child: Text('Österreich', maxLines: 1, overflow: TextOverflow.ellipsis)),
        SecondaryButton(key: const ValueKey('secondary-sm'), label: 'Team ändern', height: Tokens.buttonSm, onPressed: tap),
      ],
    ),
    Row(
      children: [
        SecondaryButton(key: const ValueKey('icon-only'), label: '', glyph: Glyph.map, height: Tokens.holdButton, semanticsLabel: 'Karte', onPressed: tap),
        const SizedBox(width: 12),
        const Expanded(child: HoldToConfirmButton(label: 'Tag beenden', onConfirmed: _noop)),
      ],
    ),
    Row(
      children: [
        HeaderButton(key: const ValueKey('header'), glyph: Glyph.share, tooltip: 'Teilen', onTap: tap),
        const SizedBox(width: 8),
        HeaderButton(key: const ValueKey('close'), glyph: Glyph.close, size: 32, tooltip: 'Schließen', onTap: tap),
        const SizedBox(width: 8),
        Flexible(child: StateChip(key: const ValueKey('chip'), text: 'Unangemessener Name', onTap: tap, selected: false)),
      ],
    ),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StateChip(text: '3 Tage am Stück', tone: ChipTone.accent),
        StateChip(text: 'Im Lift', tone: ChipTone.ice, icon: Icons.airline_seat_recline_normal_rounded),
        StateChip(text: 'Kein GPS – Höhe über Barometer', tone: ChipTone.danger, icon: Icons.satellite_alt_rounded),
        RecordingPill(text: 'Aufnahme läuft · GPS gut', active: false),
      ],
    ),
    SegmentedPill<String>(
      key: const ValueKey('segmented'),
      options: const [('system', 'System'), ('light', 'Hell'), ('dark', 'Dunkel')],
      value: 'dark',
      onChanged: enabled ? (_) {} : null,
    ),
    Align(alignment: Alignment.centerLeft, child: AppSwitch(key: const ValueKey('switch'), value: enabled, onChanged: enabled ? (_) {} : null)),
  ];
}

Future<void> _pump(WidgetTester tester, Widget child, {Brightness brightness = Brightness.dark, double scale = 1.0}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(brightness),
      locale: const Locale('de'),
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _column(List<Widget> children) => SingleChildScrollView(
      padding: const EdgeInsets.all(Tokens.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: w)],
      ),
    );

BoxDecoration _decoration(WidgetTester tester, Key key) =>
    tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(key), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;

double _labelSize(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.descendant(of: find.byKey(key), matching: find.byType(Text)).first).style!.fontSize!;

void main() {
  setUpAll(loadInterFonts);

  for (final brightness in Brightness.values) {
    for (final enabled in [true, false]) {
      testWidgets('every variant, ${enabled ? 'enabled' : 'disabled'}, ${brightness.name}: no overflow at 375 pt and 1.3× text', (tester) async {
        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) {
            overflows.add(d.exceptionAsString().split('\n').first);
          } else {
            previous?.call(d);
          }
        };
        await _pump(tester, _column(_variants(enabled: enabled)), brightness: brightness, scale: 1.3);
        FlutterError.onError = previous;
        expect(overflows, isEmpty, reason: overflows.join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('one height ramp: Start 76 · Lg 60 · Md 48 · Sm 44, and one label size per height', (tester) async {
    await _pump(tester, _column(_variants(enabled: true)));
    double h(String k) => tester.getSize(find.byKey(ValueKey(k))).height;
    expect(h('start'), Tokens.startButton);
    for (final k in ['primary-lg', 'secondary-lg', 'secondary-danger', 'apple', 'pair-primary', 'pair-danger']) {
      expect(h(k), Tokens.buttonLg, reason: k);
    }
    for (final k in ['primary-md', 'secondary-md', 'report', 'block']) {
      expect(h(k), Tokens.buttonMd, reason: k);
    }
    expect(h('secondary-sm'), Tokens.buttonSm);
    expect(h('ghost'), Tokens.tapTarget);
    expect(tester.getSize(find.byKey(const ValueKey('icon-only'))), const Size.square(Tokens.holdButton), reason: 'the live dock pair shares one height');

    // Primary and secondary of the same height share the label size.
    expect(_labelSize(tester, const ValueKey('pair-primary')), _labelSize(tester, const ValueKey('pair-danger')));
    expect(_labelSize(tester, const ValueKey('primary-lg')), 17);
    expect(_labelSize(tester, const ValueKey('primary-md')), _labelSize(tester, const ValueKey('secondary-md')));
    expect(_labelSize(tester, const ValueKey('secondary-sm')), 15);
    expect(_labelSize(tester, const ValueKey('start')), 19);
  });

  testWidgets('disabled reads as disabled: no champagne, no glass, quaternary label', (tester) async {
    await _pump(tester, _column(_variants(enabled: false)));
    final c = AppColors.dark;
    expect(_decoration(tester, const ValueKey('primary-lg')).color, c.surfaceRaised);
    expect(_decoration(tester, const ValueKey('secondary-lg')).color, Colors.transparent);
    Color label(String k) => tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(Text)).first).style!.color!;
    for (final k in ['primary-lg', 'secondary-lg', 'secondary-danger', 'apple', 'ghost']) {
      expect(label(k), c.textQuaternary, reason: k);
    }
    expect(tester.widget<GlyphIcon>(find.descendant(of: find.byKey(const ValueKey('header')), matching: find.byType(GlyphIcon))).color, c.textQuaternary);
  });

  testWidgets('pressed: champagne darkens to accentPressed, glass to hairline — no ripple', (tester) async {
    await _pump(tester, _column(_variants(enabled: true)));
    final c = AppColors.dark;
    expect(_decoration(tester, const ValueKey('primary-lg')).color, c.accent);
    final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('primary-lg'))));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_decoration(tester, const ValueKey('primary-lg')).color, c.accentPressed);
    await g.up();
    await tester.pumpAndSettle();
    expect(_decoration(tester, const ValueKey('primary-lg')).color, c.accent);

    final g2 = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('secondary-lg'))));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_decoration(tester, const ValueKey('secondary-lg')).color, c.hairline);
    await g2.up();
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
  });

  testWidgets('glass circles and chips take taps on the 44 pt target around them', (tester) async {
    final taps = <String>[];
    // HitSlop needs room in its parent (a Row is as tall as its tallest
    // child) — a 64 pt row, like the header rows the circles sit in.
    await _pump(
      tester,
      Center(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HeaderButton(key: const ValueKey('header'), glyph: Glyph.share, onTap: () => taps.add('header')),
              const SizedBox(width: 40),
              HeaderButton(key: const ValueKey('close'), glyph: Glyph.close, size: 32, onTap: () => taps.add('close')),
              const SizedBox(width: 40),
              StateChip(key: const ValueKey('chip'), text: 'Spam', onTap: () => taps.add('chip')),
            ],
          ),
        ),
      ),
    );
    for (final (k, size) in [('header', 40.0), ('close', 32.0)]) {
      final r = tester.getRect(find.byKey(ValueKey(k)));
      expect(r.size, Size.square(size));
      final slop = (Tokens.tapTarget - size) / 2;
      await tester.tapAt(Offset(r.center.dx, r.top - slop + 0.5)); // inside the 44 pt target
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(r.center.dx, r.bottom + slop + 3)); // outside it
      await tester.pumpAndSettle();
    }
    final chip = tester.getRect(find.byKey(const ValueKey('chip')));
    expect(chip.height, 32);
    await tester.tapAt(Offset(chip.center.dx, chip.bottom + 5)); // 6 pt slop below a 32 pt chip
    await tester.pumpAndSettle();
    expect(taps, ['header', 'close', 'chip']);
  });

  testWidgets('the sheet close circle is 32 pt inside a real 44 pt tap box', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: PrimaryButton(label: 'öffnen', expand: false, onPressed: () => AppSheet.show<void>(context, title: 'Saisonziel', builder: (_) => const SizedBox(height: 80))),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    final circle = find.byWidgetPredicate((w) => w is HeaderButton && w.glyph == Glyph.close);
    expect(tester.getSize(circle), const Size.square(32));
    final box = tester.getRect(find.ancestor(of: circle, matching: find.byType(SizedBox)).first);
    expect(box.size, const Size.square(Tokens.tapTarget));
    expect(box.right, _phone.width - Tokens.pad + 6, reason: 'the circle keeps its 20 pt inset');
    await tester.tapAt(box.topLeft + const Offset(1, 1)); // a corner of the box, outside the circle
    await tester.pumpAndSettle();
    expect(find.text('Saisonziel'), findsNothing);
  });

  testWidgets('SegmentedPill: a raised selected segment that moves with the value; AppSwitch toggles', (tester) async {
    var value = 'dark';
    var on = false;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => _column([
          SegmentedPill<String>(
            options: const [('system', 'System'), ('light', 'Hell'), ('dark', 'Dunkel')],
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
          Align(alignment: Alignment.centerLeft, child: AppSwitch(value: on, onChanged: (v) => setState(() => on = v))),
        ]),
      ),
    );
    expect(tester.getSize(find.byType(SegmentedPill<String>)).height, 40);
    final thumb = find.descendant(of: find.byType(SegmentedPill<String>), matching: find.byType(FractionallySizedBox));
    final before = tester.getRect(thumb);
    expect(before.center.dx, greaterThan(tester.getCenter(find.text('Hell')).dx), reason: 'Dunkel is the right segment');

    await tester.tap(find.text('Hell'));
    await tester.pumpAndSettle();
    expect(value, 'light');
    expect(tester.getRect(thumb).center.dx, moreOrLessEquals(tester.getCenter(find.text('Hell')).dx, epsilon: 1));

    expect(tester.getSize(find.byType(AppSwitch)), AppSwitch.size);
    await tester.tap(find.byType(AppSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue);
  });
}
