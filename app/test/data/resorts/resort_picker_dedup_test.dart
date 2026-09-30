import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/resorts/resort_repository.dart';
import 'package:slopetrack/features/account/resort_picker.dart';
import 'package:slopetrack/features/days/resort_picker.dart';

import '../../support/pump.dart';

/// The pickers over the real, de-duplicated resorts.json: searching 'Arlberg'
/// must not offer the same Verbund twice (DATA-RESORTS-2).
final ResortRepository _real = ResortRepository.fromJsonString(File('assets/data/resorts.json').readAsStringSync());

/// Keys of the resort rows the home-resort picker currently shows.
List<String> _rowKeys() => [
      for (final e in find.byWidgetPredicate((w) => _isResortRow(w.key)).evaluate()) (e.widget.key! as ValueKey<String>).value,
    ];

bool _isResortRow(Key? k) => k is ValueKey<String> && k.value.startsWith('resort-') && k.value != 'resort-none' && k.value != 'resort-search';

void main() {
  testWidgets('home-resort picker: one row for Arlberg, one for Damüls', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(builder: (context) => Center(child: TextButton(onPressed: () => ResortPicker.show(context), child: const Text('open')))),
      overrides: [resortRepositoryProvider.overrideWith((ref) async => _real)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('resort-search')), 'Arlberg');
    await tester.pumpAndSettle();
    // 'Skidbacke Karlbergsskogen' (SE) matches the substring too; Austria must have one row.
    final arlberg = _rowKeys().where((k) => _real.byId(k.substring('resort-'.length))?.country == 'AT').toList();
    expect(arlberg, ['resort-st-anton'], reason: '$arlberg');
    expect(find.text('Ski Arlberg'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('resort-search')), 'Damüls');
    await tester.pumpAndSettle();
    final damuels = _rowKeys();
    expect(damuels, hasLength(1), reason: '$damuels');

    await tester.enterText(find.byKey(const ValueKey('resort-search')), 'Lech');
    await tester.pumpAndSettle();
    expect(_rowKeys(), isNot(contains('resort-lech-zuers')));
  });

  testWidgets('day resort picker: no duplicate names for Arlberg', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => ResortPickerSheet.show(context, resorts: _real.all, lat: 47.1297, lon: 10.2683), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resort-picker-search')), 'Arlberg');
    await tester.pumpAndSettle();
    expect(find.text('Ski Arlberg'), findsOneWidget);
    // one Austrian row (captions read 'AT · 0,5 km'); Karlbergsskogen (SE) also matches the filter
    expect(find.textContaining(RegExp(r'^AT ·')), findsOneWidget);
  });

  test('the picker list has no duplicate names within one country', () {
    final names = [for (final r in _real.all) '${r.name}|${r.country}'];
    expect(names.toSet().length, names.length);
  });
}
