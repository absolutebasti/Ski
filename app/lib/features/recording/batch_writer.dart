import '../../core/core.dart';
import '../../data/db/days_repository.dart';

/// Buffers points and flushes them in one transaction every N points or S seconds.
class BatchWriter {
  BatchWriter(this._repo, this.dayId);
  final DaysRepository _repo;
  final String dayId;
  final List<TrackPoint> _buf = [];
  int? _lastFlushMs;
  DayStats? _pendingStats;
  int? _pendingRestarts;
  Future<void>? _inFlight;

  int get buffered => _buf.length;

  void add(TrackPoint p, {DayStats? stats, int? streamRestarts}) {
    _buf.add(p);
    if (stats != null) _pendingStats = stats;
    if (streamRestarts != null) _pendingRestarts = streamRestarts;
  }

  bool due(int nowMs) {
    if (_buf.isEmpty) return false;
    _lastFlushMs ??= nowMs;
    return _buf.length >= TrackingConfig.batchFlushPoints || nowMs - _lastFlushMs! >= TrackingConfig.batchFlushS * 1000;
  }

  Future<void> flush(int nowMs) async {
    if (_buf.isEmpty && _pendingStats == null) return;
    if (_inFlight != null) await _inFlight;
    final points = List<TrackPoint>.of(_buf);
    final stats = _pendingStats;
    final restarts = _pendingRestarts;
    _buf.clear();
    _pendingStats = null;
    _pendingRestarts = null;
    _lastFlushMs = nowMs;
    _inFlight = _repo.appendPoints(dayId, points, stats: stats, streamRestarts: restarts);
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
    }
  }
}
