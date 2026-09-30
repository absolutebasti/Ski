import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/theme/tokens.dart';

/// WCAG 2.x contrast guard for the three palettes (docs/DESIGN.md §2).
/// Text: primary/secondary ≥ 4.5 on bg/surface/surfaceRaised, accent and
/// onAccent ≥ 4.5, tertiary ≥ 3.0 (large text / overlines only).
/// A token that misses its floor goes into [knownBelowFloor] with the measured
/// value and is listed for the lead; the guard fails once the lead fixes it so
/// the entry gets removed.
double _linear(double channel) => channel <= 0.03928 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double relativeLuminance(Color c) => 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const _palettes = {'dark': AppColors.dark, 'light': AppColors.light, 'glare': AppColors.glare};

/// Pairs that miss their floor today; measured 2026-09-29. Lead: lightTertiary
/// #8B9098 → e.g. #83888F gives 3.19 on bg and 3.57 on surface.
const knownBelowFloor = <String, double>{};

class _Check {
  const _Check(this.name, this.fg, this.bg, this.floor);
  final String name;
  final Color fg, bg;
  final double floor;
}

List<_Check> _checks(String palette, AppColors c) {
  final grounds = {'bg': c.bg, 'surface': c.surface, 'surfaceRaised': c.surfaceRaised};
  return [
    for (final g in grounds.entries) ...[
      _Check('$palette textPrimary on ${g.key}', c.textPrimary, g.value, 4.5),
      _Check('$palette textSecondary on ${g.key}', c.textSecondary, g.value, 4.5),
      _Check('$palette textTertiary on ${g.key}', c.textTertiary, g.value, 3.0),
      _Check('$palette accent on ${g.key}', c.accent, g.value, 4.5),
    ],
    _Check('$palette onAccent on accent', c.onAccent, c.accent, 4.5),
  ];
}

void main() {
  test('contrast formula matches the WCAG reference points', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
    expect(contrastRatio(const Color(0xFF777777), Colors.white), closeTo(4.48, 0.02));
  });

  for (final p in _palettes.entries) {
    test('${p.key} palette meets its contrast floors', () {
      final failures = <String>[];
      for (final k in _checks(p.key, p.value)) {
        final ratio = contrastRatio(k.fg, k.bg);
        final known = knownBelowFloor[k.name];
        if (known != null) {
          expect(ratio, lessThan(k.floor), reason: '${k.name} now passes (${ratio.toStringAsFixed(2)}) – remove it from knownBelowFloor');
          expect(ratio, closeTo(known, 0.01), reason: '${k.name} changed – update knownBelowFloor');
          continue;
        }
        if (ratio < k.floor) failures.add('${k.name}: ${ratio.toStringAsFixed(2)} < ${k.floor}');
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  test('every known exception is still listed against a real token', () {
    final names = {for (final p in _palettes.entries) for (final k in _checks(p.key, p.value)) k.name};
    for (final name in knownBelowFloor.keys) {
      expect(names, contains(name));
    }
  });
}
