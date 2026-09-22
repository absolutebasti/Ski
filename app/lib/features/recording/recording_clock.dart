import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Time source + periodic ticker, injectable so tests never sleep.
abstract class RecordingClock {
  int now();
  TickerHandle periodic(Duration period, void Function() callback);
}

class TickerHandle {
  TickerHandle(this.cancel);
  final void Function() cancel;
}

class SystemClock implements RecordingClock {
  @override
  int now() => DateTime.now().millisecondsSinceEpoch;

  @override
  TickerHandle periodic(Duration period, void Function() callback) {
    final t = Timer.periodic(period, (_) => callback());
    return TickerHandle(t.cancel);
  }
}

/// Manual clock for tests: `advance()` moves time and fires due tickers.
class FakeClock implements RecordingClock {
  FakeClock(this._now);
  int _now;
  final List<_FakeTicker> _tickers = [];

  @override
  int now() => _now;

  @override
  TickerHandle periodic(Duration period, void Function() callback) {
    final t = _FakeTicker(period.inMilliseconds, _now, callback);
    _tickers.add(t);
    return TickerHandle(() => _tickers.remove(t));
  }

  /// Advance by [ms], firing tickers in order.
  void advance(int ms) {
    final target = _now + ms;
    while (true) {
      _FakeTicker? next;
      for (final t in _tickers) {
        if (next == null || t.nextAt < next.nextAt) next = t;
      }
      if (next == null || next.nextAt > target) break;
      _now = next.nextAt;
      next.nextAt += next.period;
      next.callback();
    }
    _now = target;
  }
}

class _FakeTicker {
  _FakeTicker(this.period, int start, this.callback) : nextAt = start + period;
  final int period;
  int nextAt;
  final void Function() callback;
}

final recordingClockProvider = Provider<RecordingClock>((ref) => SystemClock());
