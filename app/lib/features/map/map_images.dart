import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart' show FileImage, PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../data/db/providers.dart';
import '../../data/resorts/resort_repository.dart';
import '../../platform/map_snapshot.dart';
import 'thumbnail_renderer.dart';

/// Bumped whenever a map image lands on disk. DayCard and the Tagesbilanz
/// RouteBlock watch it and re-check their files, so an image that arrives
/// seconds after End (or on a later online launch) appears without a reload.
class MapImageRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final mapImageRevisionProvider = NotifierProvider<MapImageRevision, int>(MapImageRevision.new);

/// Background renderer for the Apple-Maps day images (ThumbnailRenderer.renderMap).
///
/// - [render] runs once after End, fire-and-forget: ending a day never waits
///   for the network.
/// - [ensure] is the retry: a day card whose `<id>_map.png` is missing (day
///   ended offline, or recorded before this feature) asks once per app
///   session. The missing file is the whole signal — no DB column.
/// - One snapshot at a time; after a null answer (offline) further retries
///   pause for [backoff] and stay eligible for the next visit.
class MapImages {
  MapImages(this._ref, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Ref _ref;
  final DateTime Function() _now;
  final Set<String> _attempted = {};
  final Set<String> _queued = {};
  Future<void> _tail = Future.value();
  DateTime? _pausedUntil;

  static const Duration backoff = Duration(minutes: 2);

  MapSnapshotSource get _source => _ref.read(mapSnapshotSourceProvider);

  bool get _paused {
    final until = _pausedUntil;
    return until != null && _now().isBefore(until);
  }

  /// Renders (or re-renders) the map images of [dayId] in the background.
  /// The returned future completes with the `_map.png` path or null; callers
  /// normally ignore it.
  Future<String?> render(String dayId) {
    if (!_source.isAvailable) return Future.value();
    _attempted.add(dayId);
    return _enqueue(dayId, retry: false);
  }

  /// Retry for a day without `<id>_map.png`: at most once per session per day,
  /// skipped while offline was just detected. No-op where MapKit is absent.
  void ensure(String dayId) {
    if (!_source.isAvailable || _paused || _attempted.contains(dayId)) return;
    _attempted.add(dayId);
    unawaited(_enqueue(dayId, retry: true));
  }

  Future<String?> _enqueue(String dayId, {required bool retry}) {
    if (!_queued.add(dayId)) return Future.value();
    final done = Completer<String?>();
    _tail = _tail.then((_) async {
      try {
        if (retry && _paused) {
          _attempted.remove(dayId); // eligible again once back online
          done.complete(null);
          return;
        }
        final (path, offline) = await _run(dayId);
        if (offline) {
          _pausedUntil = _now().add(backoff);
        } else if (path != null) {
          _pausedUntil = null;
          _evict(path);
          _ref.read(mapImageRevisionProvider.notifier).bump();
        }
        done.complete(path);
      } catch (_) {
        if (!done.isCompleted) done.complete(null);
      } finally {
        _queued.remove(dayId);
      }
    });
    return done.future;
  }

  /// A re-render keeps the file names: drop the decoded card and hero images
  /// so the widgets that re-check on the revision bump show the new pixels.
  static void _evict(String mapPath) {
    try {
      final base = ThumbnailRenderer.basePathForMap(mapPath);
      final cache = PaintingBinding.instance.imageCache;
      cache.evict(FileImage(File(mapPath)));
      cache.evict(FileImage(File(ThumbnailRenderer.heroPathFor(base))));
    } catch (_) {}
  }

  /// `(path, offline)`: offline = there was something to draw but no image came back.
  Future<(String?, bool)> _run(String dayId) async {
    final repo = _ref.read(daysRepositoryProvider);
    final detail = await repo.dayDetail(dayId);
    if (detail == null || detail.day.status != DayStatus.finished) return (null, false);
    Resort? resort;
    final resortId = detail.day.resortId;
    if (resortId != null) {
      try {
        resort = (await _ref.read(resortRepositoryProvider.future)).byId(resortId);
      } catch (_) {}
    }
    if (ThumbnailRenderer.mapBounds(detail, resort: resort) == null) return (null, false);
    final map = await ThumbnailRenderer.renderMap(detail, resort: resort, source: _source);
    if (map == null) return (null, true);
    final base = ThumbnailRenderer.basePathForMap(map);
    if (detail.day.mapThumbPath != base) {
      // A day without a stored path (resort-only), or a path from an older app
      // container: point the row at the current thumbs dir and redraw the
      // path PNGs there so the offline fallback exists next to the map.
      if (detail.points.length >= 2 && !File(base).existsSync()) {
        try {
          await ThumbnailRenderer.renderBoth(detail, dir: File(base).parent.parent);
        } catch (_) {}
      }
      await repo.updateMapThumb(dayId, base);
      // The list streams the new path; the Tagesbilanz reads a one-shot detail.
      _ref.invalidate(dayDetailProvider(dayId));
    }
    return (map, false);
  }
}

final mapImagesProvider = Provider<MapImages>((ref) => MapImages(ref));
