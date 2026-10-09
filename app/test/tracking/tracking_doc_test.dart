import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';

import 'cable_support.dart';

/// `docs/TRACKING.md` is the page the founder reads when he asks "why does it say
/// that?". A page whose numbers no longer match the code is worse than no page, so
/// every threshold it prints is checked against the constant it names.
///
/// The doc lists thresholds as `| \`constantName\` | value | meaning |`. This test
/// parses those rows and compares the first number of the value cell with the
/// constant. Rows for constants that are not in [_values] are reported, so a new
/// threshold cannot be documented without being pinned here too.
const Map<String, num> _values = {
  // cable window
  'cableWindowS': TrackingConfig.cableWindowS,
  'cableMinSpanS': TrackingConfig.cableMinSpanS,
  'cableMinSamples': TrackingConfig.cableMinSamples,
  'cableMinSpeedMs': TrackingConfig.cableMinSpeedMs,
  'cableMaxSpeedMs': TrackingConfig.cableMaxSpeedMs,
  'cableMaxSpeedCv': TrackingConfig.cableMaxSpeedCv,
  'cableMaxSpeedSdMs': TrackingConfig.cableMaxSpeedSdMs,
  'cableSlices': TrackingConfig.cableSlices,
  'cableMinStraightness': TrackingConfig.cableMinStraightness,
  'cableMinAltMonotonicity': TrackingConfig.cableMinAltMonotonicity,
  'cableFlatSliceM': TrackingConfig.cableFlatSliceM,
  'cableMinAltChangeM': TrackingConfig.cableMinAltChangeM,
  'cableMinGradientPct': TrackingConfig.cableMinGradientPct,
  'cableStaleS': TrackingConfig.cableStaleS,
  'cableEnterS': TrackingConfig.cableEnterS,
  'cableRunVetoCoverage': TrackingConfig.cableRunVetoCoverage,
  'cableStationS': TrackingConfig.cableStationS,
  'liftSliverMergeS': TrackingConfig.liftSliverMergeS,
  'finalizeLookbackS': TrackingConfig.finalizeLookbackS,
  // ascending confirmation
  'cableAscentBaroWindowS': TrackingConfig.cableAscentBaroWindowS,
  'cableAscentStationLookbackS': TrackingConfig.cableAscentStationLookbackS,
  'cableAscentStationHoldS': TrackingConfig.cableAscentStationHoldS,
  'cableAscentMaxBowFactor': TrackingConfig.cableAscentMaxBowFactor,
  'cableAscentBowWindowS': TrackingConfig.cableAscentBowWindowS,
  'cableAscentRampS': TrackingConfig.cableAscentRampS,
  'cableAscentMinSamples': TrackingConfig.cableAscentMinSamples,
  // descending (switched off, still documented)
  'descentMinDurationS': TrackingConfig.descentMinDurationS,
  'descentMaxRideS': TrackingConfig.descentMaxRideS,
  'descentMinDropM': TrackingConfig.descentMinDropM,
  'descentMinGradientPct': TrackingConfig.descentMinGradientPct,
  'descentMinVerticalMs': TrackingConfig.descentMinVerticalMs,
  'descentMinSpeedMs': TrackingConfig.descentMinSpeedMs,
  'descentSpeedSdFactor': TrackingConfig.descentSpeedSdFactor,
  'descentSpeedSdFloorMs': TrackingConfig.descentSpeedSdFloorMs,
  'descentSpeedSmoothS': TrackingConfig.descentSpeedSmoothS,
  'descentRampS': TrackingConfig.descentRampS,
  'descentMaxChordOffsetFactor': TrackingConfig.descentMaxChordOffsetFactor,
  'descentMaxChordOffsetFloorM': TrackingConfig.descentMaxChordOffsetFloorM,
  'descentMaxChordOffsetCapM': TrackingConfig.descentMaxChordOffsetCapM,
  'descentMaxAltResidualM': TrackingConfig.descentMaxAltResidualM,
  'descentStationLookbackS': TrackingConfig.descentStationLookbackS,
  'descentStationSpeedMs': TrackingConfig.descentStationSpeedMs,
  'descentStationHoldS': TrackingConfig.descentStationHoldS,
  'descentMinSamples': TrackingConfig.descentMinSamples,
  'descentMidStationS': TrackingConfig.descentMidStationS,
  'descentLiveMinSamples': TrackingConfig.descentLiveMinSamples,
  'descentLiveBoundSlack': TrackingConfig.descentLiveBoundSlack,
  'descentLiveBreakS': TrackingConfig.descentLiveBreakS,
  'descentHoldGraceS': TrackingConfig.descentHoldGraceS,
  // road guard
  'roadMinSpeedMs': TrackingConfig.roadMinSpeedMs,
  'roadMinDurationS': TrackingConfig.roadMinDurationS,
  'roadMaxGradientPct': TrackingConfig.roadMaxGradientPct,
  'roadMaxChordOverPath': TrackingConfig.roadMaxChordOverPath,
  'roadMinHairpins': TrackingConfig.roadMinHairpins,
  'roadHairpinMinTurnDeg': TrackingConfig.roadHairpinMinTurnDeg,
  'roadHairpinMinPathM': TrackingConfig.roadHairpinMinPathM,
  'roadLiveMinDurationS': TrackingConfig.roadLiveMinDurationS,
  'roadLiveMinHairpins': TrackingConfig.roadLiveMinHairpins,
};

void main() {
  final file = File('../docs/TRACKING.md');

  test('docs/TRACKING.md exists next to the app', () {
    expect(file.existsSync(), isTrue, reason: 'expected ${file.absolute.path}');
  });

  test('every threshold the page prints is the threshold in the code', () {
    final rows = RegExp(r'^\|\s*`([A-Za-z]+)`\s*\|\s*([^|]+?)\s*\|', multiLine: true);
    final seen = <String>{};
    final unknown = <String>[];
    for (final m in rows.allMatches(file.readAsStringSync())) {
      final name = m.group(1)!;
      final cell = m.group(2)!;
      // The master switch is a bool; the last test checks its row.
      if (name == 'descentRidesEnabled') continue;
      final expected = _values[name];
      if (expected == null) {
        unknown.add(name);
        continue;
      }
      seen.add(name);
      final num_ = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(cell);
      expect(num_, isNotNull, reason: '$name: no number in "$cell"');
      final printed = double.parse(num_!.group(0)!.replaceAll(',', '.'));
      expect(printed, closeTo(expected.toDouble(), 1e-9),
          reason: 'docs/TRACKING.md prints $name = $printed, the code says $expected');
    }
    expect(unknown, isEmpty,
        reason: 'the page documents thresholds this test does not pin: $unknown — add them to _values');
    expect(seen.length, greaterThan(40), reason: 'only ${seen.length} thresholds found; did the tables move?');
  });

  test('the page says what the code decided about valley rides', () {
    final text = file.readAsStringSync();
    if (descentRides) {
      expect(text, contains('descentRidesEnabled` | **true**'),
          reason: 'the rule is on but the page says it is off');
    } else {
      expect(text, contains('descentRidesEnabled` | **false**'),
          reason: 'the rule is off but the page does not say so');
      expect(text, contains('abgeschaltet'), reason: 'the decision has to be findable');
      expect(text, contains('427'), reason: 'and the measurement that made it');
    }
  });
}
