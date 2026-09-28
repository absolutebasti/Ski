import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UX-DAYS acceptance: Tage/Heute never spin and never use the Material
/// SnackBar — skeleton rows and `showToast` instead. Reads the sources, so
/// a regression fails here before anyone opens the app.
void main() {
  const dirs = ['lib/features/days', 'lib/features/today'];
  const banned = ['CircularProgressIndicator', 'ScaffoldMessenger.of(', 'showSnackBar('];

  test('no CircularProgressIndicator or SnackBar in features/days and features/today', () {
    final hits = <String>[];
    for (final dir in dirs) {
      final files = Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty, reason: '$dir must exist (test runs from app/)');
      for (final f in files) {
        final src = f.readAsStringSync();
        for (final b in banned) {
          if (src.contains(b)) hits.add('${f.path}: $b');
        }
      }
    }
    expect(hits, isEmpty);
  });
}
