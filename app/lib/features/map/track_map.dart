import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/tokens.dart';
import '../../core/core.dart';
import 'tile_config.dart';
import 'track_geometry.dart';

/// Raster map with the day's track: runs champagne 4 px + 12 px 25 % glow,
/// lifts dashed liftGrey 2 px, stops hidden. Start/end markers, optional scrub
/// marker at [scrubTs]. Detail mode fits the bounds (padding 48); [follow] mode
/// centres on the latest point at zoom 15 with a heading puck fed from [points]
/// (no GPS subscription of its own) and rebuilds polylines at most every 2 s.
class TrackMap extends ConsumerStatefulWidget {
  const TrackMap({
    super.key,
    required this.points,
    required this.segments,
    this.follow = false,
    this.center,
    this.interactive = true,
    this.scrubTs,
    this.tilesEnabled = true,
    this.locateSignal,
    this.darkTiles = true,
  });

  final List<TrackPoint> points;
  final List<Segment> segments;
  final bool follow;
  final LatLng? center;
  final bool interactive;
  final int? scrubTs;

  /// `false` in widget tests: no tile layers, no network, no path_provider.
  final bool tilesEnabled;

  /// Bump the value to re-centre on the latest point (the sheet's locate button).
  final ValueListenable<int>? locateSignal;

  /// Desaturate + darken the raster and lay an ink veil under the track, so the
  /// champagne route is the brightest thing on the map (docs/DESIGN.md §0.9).
  final bool darkTiles;

  static const double followZoom = 15;
  static const double fitPadding = 48;
  static const Duration rebuildInterval = Duration(seconds: 2);
  static const double runWidth = 4;
  static const double glowWidth = 12;
  static const double liftWidth = 2;

  /// Somewhere in the Alps when there is neither a track nor a [center].
  static const LatLng fallbackCenter = LatLng(47.0, 11.0);

  @override
  ConsumerState<TrackMap> createState() => _TrackMapState();
}

class _TrackMapState extends ConsumerState<TrackMap> {
  final MapController _map = MapController();
  bool _ready = false;

  List<TrackLine> _lines = const [];
  int _drawableCount = 0;
  Timer? _throttle;
  int _lastBuildMs = 0;

  // Position / heading feed for the puck. Late subscribers get the latest value.
  final _positionCtrl = StreamController<LocationMarkerPosition?>.broadcast();
  final _headingCtrl = StreamController<LocationMarkerHeading?>.broadcast();
  final _alignCtrl = StreamController<double?>.broadcast();
  LocationMarkerPosition? _lastPosition;
  LocationMarkerHeading? _lastHeading;
  late final Stream<LocationMarkerPosition?> _positionStream = _replay(_positionCtrl, () => _lastPosition);
  late final Stream<LocationMarkerHeading?> _headingStream = _replay(_headingCtrl, () => _lastHeading);
  late final Stream<double?> _alignStream = _replay(_alignCtrl, () => TrackMap.followZoom);
  AlignOnUpdate _alignMode = AlignOnUpdate.never;

  static Stream<T?> _replay<T>(StreamController<T?> ctrl, T? Function() latest) => Stream<T?>.multi((out) {
        final v = latest();
        if (v != null) out.add(v);
        final sub = ctrl.stream.listen(out.add, onError: out.addError, onDone: out.close);
        out.onCancel = sub.cancel;
      });

  @override
  void initState() {
    super.initState();
    _alignMode = widget.follow ? AlignOnUpdate.always : AlignOnUpdate.never;
    _rebuildLines();
    _pushPosition();
    widget.locateSignal?.addListener(_locate);
  }

  @override
  void didUpdateWidget(TrackMap old) {
    super.didUpdateWidget(old);
    if (old.locateSignal != widget.locateSignal) {
      old.locateSignal?.removeListener(_locate);
      widget.locateSignal?.addListener(_locate);
    }
    final changed = !identical(old.points, widget.points) || !identical(old.segments, widget.segments);
    if (!changed) return;
    _pushPosition();
    if (widget.follow) {
      _scheduleRebuild();
    } else {
      _rebuildLines();
      final n = TrackGeometry.drawableCount(widget.points);
      if (n != _drawableCount) {
        _drawableCount = n;
        _fit();
      }
    }
  }

  @override
  void dispose() {
    widget.locateSignal?.removeListener(_locate);
    _throttle?.cancel();
    _positionCtrl.close();
    _headingCtrl.close();
    _alignCtrl.close();
    _map.dispose();
    super.dispose();
  }

  // --- track lines ---------------------------------------------------------

  void _rebuildLines() {
    _lines = TrackGeometry.split(widget.points, widget.segments);
    _drawableCount = TrackGeometry.drawableCount(widget.points);
    _lastBuildMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Follow mode: at most one polyline rebuild per [TrackMap.rebuildInterval].
  void _scheduleRebuild() {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastBuildMs;
    if (elapsed >= TrackMap.rebuildInterval.inMilliseconds) {
      setState(_rebuildLines);
      return;
    }
    if (_throttle != null) return;
    _throttle = Timer(TrackMap.rebuildInterval - Duration(milliseconds: elapsed), () {
      _throttle = null;
      if (mounted) setState(_rebuildLines);
    });
  }

  // --- puck ----------------------------------------------------------------

  void _pushPosition() {
    final p = _latestPoint();
    if (p == null) return;
    _lastPosition = LocationMarkerPosition(latitude: p.lat!, longitude: p.lon!, accuracy: p.hAccM ?? 0);
    _positionCtrl.add(_lastPosition);
    final course = p.courseDeg;
    if (course != null && (p.speedMs ?? 0) > 0.5) {
      _lastHeading = LocationMarkerHeading(heading: (course % 360) * math.pi / 180, accuracy: math.pi / 8);
      _headingCtrl.add(_lastHeading);
    }
  }

  TrackPoint? _latestPoint() {
    for (var i = widget.points.length - 1; i >= 0; i--) {
      final p = widget.points[i];
      if (p.accepted && p.hasPosition) return p;
    }
    return null;
  }

  void _locate() {
    if (!mounted) return;
    setState(() => _alignMode = AlignOnUpdate.always);
    _alignCtrl.add(TrackMap.followZoom);
    final p = _lastPosition;
    if (p != null && _ready) _map.move(p.latLng, TrackMap.followZoom);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && widget.follow && _alignMode != AlignOnUpdate.never) {
      setState(() => _alignMode = AlignOnUpdate.never);
    }
  }

  // --- camera --------------------------------------------------------------

  CameraFit? _boundsFit() {
    if (widget.follow || TrackGeometry.drawableCount(widget.points) < 2) return null;
    final b = TrackGeometry.bounds(widget.points);
    if (b == null) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds(b.$1, b.$2),
      padding: const EdgeInsets.all(TrackMap.fitPadding),
      maxZoom: TileConfig.maxZoom.toDouble(),
    );
  }

  void _fit() {
    if (!_ready) return;
    final fit = _boundsFit();
    if (fit != null) _map.fitCamera(fit);
  }

  LatLng _initialCenter() => widget.center ?? TrackGeometry.last(widget.points) ?? TrackMap.fallbackCenter;

  double _initialZoom() {
    if (widget.follow) return TrackMap.followZoom;
    if (widget.center != null || TrackGeometry.drawableCount(widget.points) >= 1) return 14;
    return 6;
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tiles = widget.tilesEnabled ? ref.watch(tileProviderProvider).asData?.value : null;
    final scrub = widget.scrubTs == null ? null : TrackGeometry.nearest(widget.points, widget.scrubTs!);
    final start = TrackGeometry.first(widget.points);
    final end = widget.follow ? null : TrackGeometry.last(widget.points);

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _initialCenter(),
        initialZoom: _initialZoom(),
        initialCameraFit: _boundsFit(),
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: c.bg,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onMapReady: () {
          _ready = true;
          _fit();
        },
        onPositionChanged: _onPositionChanged,
      ),
      children: [
        if (tiles != null) ...TileConfig.layers(tiles, dark: widget.darkTiles),
        // Glow under the runs, then runs, then lifts — so lifts read as separate.
        PolylineLayer(
          polylines: [
            for (final l in _lines)
              if (l.kind == TrackLineKind.run)
                Polyline(points: l.points, strokeWidth: TrackMap.glowWidth, color: c.run.withValues(alpha: 0.25)),
            for (final l in _lines)
              if (l.kind == TrackLineKind.run) Polyline(points: l.points, strokeWidth: TrackMap.runWidth, color: c.run),
            for (final l in _lines)
              if (l.kind == TrackLineKind.lift)
                Polyline(
                  points: l.points,
                  strokeWidth: TrackMap.liftWidth,
                  color: c.liftGrey,
                  pattern: StrokePattern.dashed(segments: const [8, 6]),
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (start != null) Marker(point: start, width: 14, height: 14, child: _Dot(fill: c.textPrimary, ring: c.bg)),
            if (end != null && end != start) Marker(point: end, width: 14, height: 14, child: _Dot(fill: c.run, ring: c.bg)),
            if (scrub != null)
              Marker(
                point: LatLng(scrub.lat!, scrub.lon!),
                width: 20,
                height: 20,
                child: _Dot(fill: c.ice, ring: c.textPrimary, ringWidth: 3),
              ),
          ],
        ),
        if (widget.follow)
          CurrentLocationLayer(
            positionStream: _positionStream,
            headingStream: _headingStream,
            alignPositionStream: _alignStream,
            alignPositionOnUpdate: _alignMode,
            style: LocationMarkerStyle(
              marker: DefaultLocationMarker(color: c.ice),
              markerSize: const Size.square(18),
              accuracyCircleColor: c.ice.withValues(alpha: 0.10),
              headingSectorColor: c.ice.withValues(alpha: 0.55),
              headingSectorRadius: 48,
            ),
          ),
        if (tiles != null) TileConfig.attribution(),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.fill, required this.ring, this.ringWidth = 2});
  final Color fill;
  final Color ring;
  final double ringWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: ring, width: ringWidth)),
      );
}
