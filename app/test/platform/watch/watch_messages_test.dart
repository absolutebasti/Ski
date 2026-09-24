import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/core/core.dart';
import 'package:slopetrack/platform/watch/watch.dart';

void main() {
  group('WatchLivePayload', () {
    test('encodes the live state as plist-safe values', () {
      const live = LiveState(
        stats: DayStats(dropM: 1234.5, runCount: 7, maxSpeedMs: 24.5, elapsedMs: 3600000),
        speedMs: 11.1,
        altM: 1850.25,
      );
      final map = WatchLivePayload.recording(live, dayId: 'day-1').toMap();

      expect(map['status'], 'recording');
      expect(map['dayId'], 'day-1');
      expect(map['dropM'], 1234.5);
      expect(map['runCount'], 7);
      expect(map['maxSpeedMs'], 24.5);
      expect(map['elapsedMs'], 3600000);
      expect(map['speedMs'], 11.1);
      expect(map['altM'], 1850.25);
      for (final v in map.values) {
        expect(v is String || v is num || v is bool, isTrue, reason: '$v is not plist-safe');
      }
    });

    test('omits null fields and round-trips', () {
      final map = WatchLivePayload.idle.toMap();
      expect(map.containsKey('dayId'), isFalse);
      expect(map.containsKey('altM'), isFalse);

      final back = WatchLivePayload.fromMap(map);
      expect(back.status, 'idle');
      expect(back.isRecording, isFalse);
      expect(back.dayId, isNull);
      expect(back.altM, isNull);
      expect(back.runCount, 0);
    });

    test('decodes ints that arrived as doubles and survives junk', () {
      final p = WatchLivePayload.fromMap({'status': 'recording', 'runCount': 5.0, 'dropM': 12, 'elapsedMs': 'x'});
      expect(p.runCount, 5);
      expect(p.dropM, 12.0);
      expect(p.elapsedMs, 0);
    });

    test('status and day change count as structural', () {
      const a = WatchLivePayload(status: 'recording', dayId: 'a');
      expect(a.differsStructurally(null), isTrue);
      expect(a.differsStructurally(const WatchLivePayload(status: 'idle')), isTrue);
      expect(a.differsStructurally(const WatchLivePayload(status: 'recording', dayId: 'b')), isTrue);
      expect(a.differsStructurally(const WatchLivePayload(status: 'recording', dayId: 'a', runCount: 3)), isFalse);
    });
  });

  group('watch → phone', () {
    test('parses commands', () {
      expect(watchCommandFrom({'cmd': 'start'}), WatchCommand.start);
      expect(watchCommandFrom({'cmd': 'end'}), WatchCommand.end);
      expect(watchCommandFrom({'cmd': 'nonsense'}), isNull);
      expect(watchCommandFrom({'hr': 120}), isNull);
    });

    test('parses heart rate and rejects implausible values', () {
      expect(watchHeartRateFrom({'hr': 142}), 142);
      expect(watchHeartRateFrom({'hr': 142.6}), 143);
      expect(watchHeartRateFrom({'hr': 0}), isNull);
      expect(watchHeartRateFrom({'hr': 400}), isNull);
      expect(watchHeartRateFrom({'hr': 'fast'}), isNull);
      expect(watchHeartRateFrom({'cmd': 'start'}), isNull);
    });
  });
}
