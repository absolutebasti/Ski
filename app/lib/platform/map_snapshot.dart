import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Imagery for a [MapSnapshotRequest]. `muted` is the dark, label-free
/// standard map; the native side falls back to it when satellite fails.
enum MapSnapshotStyle { satellite, hybrid, muted }

/// One static map image: a region (centre + spans in degrees), an output size
/// in points × [scale], and an optional route the native side draws on top
/// (round caps, [routeColor] ARGB, [routeWidth] pt). An empty [route] returns
/// the bare imagery — the Tagesbilanz draws its own animated route over it.
class MapSnapshotRequest {
  const MapSnapshotRequest({
    required this.lat,
    required this.lon,
    required this.latSpan,
    required this.lonSpan,
    required this.width,
    required this.height,
    this.scale = 2,
    this.style = MapSnapshotStyle.satellite,
    this.route = const [],
    this.routeColor = 0xFFE3C88C, // Tokens.champagne
    this.routeWidth = 2.5,
  });

  final double lat, lon, latSpan, lonSpan;
  final double width, height, scale;
  final MapSnapshotStyle style;
  /// `(lat, lon)` pairs in drawing order.
  final List<(double, double)> route;
  final int routeColor;
  final double routeWidth;

  Map<String, Object?> toArgs() => {
        'lat': lat,
        'lon': lon,
        'latSpan': latSpan,
        'lonSpan': lonSpan,
        'width': width,
        'height': height,
        'scale': scale,
        'style': style.name,
        'route': [for (final p in route) [p.$1, p.$2]],
        'routeColor': routeColor,
        'routeWidth': routeWidth,
      };
}

/// Renders a static map to PNG bytes. `null` = no image (offline, not iOS,
/// imagery failed, timeout) — callers keep their drawn fallback. Never throws.
abstract class MapSnapshotSource {
  /// false where no native renderer exists (Android, tests on the host) —
  /// callers skip the work entirely instead of asking and getting null.
  bool get isAvailable;

  Future<Uint8List?> snapshot(MapSnapshotRequest request);
}

/// iOS: MKMapSnapshotter behind `ios/Runner/MapSnapshot.swift`. Apple Maps
/// imagery needs no token or tile URL; it needs network, so offline the
/// answer is null and the path thumbnails stay in place.
class MethodChannelMapSnapshotSource implements MapSnapshotSource {
  const MethodChannelMapSnapshotSource({this.timeout = const Duration(seconds: 20)});

  static const channel = MethodChannel('de.torchtechnology.slopetrack/map_snapshot');
  final Duration timeout;

  @override
  bool get isAvailable => Platform.isIOS;

  @override
  Future<Uint8List?> snapshot(MapSnapshotRequest request) async {
    if (!Platform.isIOS) return null;
    try {
      return await channel.invokeMethod<Uint8List>('snapshot', request.toArgs()).timeout(timeout, onTimeout: () => null);
    } on MissingPluginException {
      return null; // old build without the Swift side
    } on PlatformException {
      return null;
    }
  }
}

/// Test double: records every request and answers with [bytes] (null = the
/// native side had no image).
class FakeMapSnapshotSource implements MapSnapshotSource {
  FakeMapSnapshotSource({this.bytes, this.bytesFor, this.isAvailable = true});

  @override
  bool isAvailable;
  Uint8List? bytes;
  /// Optional per-request answer; wins over [bytes].
  Uint8List? Function(MapSnapshotRequest request)? bytesFor;
  final List<MapSnapshotRequest> requests = [];

  @override
  Future<Uint8List?> snapshot(MapSnapshotRequest request) async {
    requests.add(request);
    return bytesFor != null ? bytesFor!(request) : bytes;
  }
}

final mapSnapshotSourceProvider = Provider<MapSnapshotSource>((ref) => const MethodChannelMapSnapshotSource());
