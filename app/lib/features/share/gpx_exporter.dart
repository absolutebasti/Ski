import 'package:xml/xml.dart';

import '../../core/core.dart';

/// GPX 1.1 export of one day (docs/PLAN.md §9): one `<trk>`, one `<trkseg>`
/// per run/lift in day order, `<ele>` = fused altitude, times in UTC,
/// `gpxtpx:speed` when a Doppler speed exists. Pure Dart, no Flutter.
class GpxExporter {
  const GpxExporter._();

  static const String creator = 'Schwung';
  static const String nsGpx = 'http://www.topografix.com/GPX/1/1';
  static const String nsXsi = 'http://www.w3.org/2001/XMLSchema-instance';
  static const String nsGpxtpx = 'http://www.garmin.com/xmlschemas/TrackPointExtension/v2';
  static const String schemaLocation = '$nsGpx http://www.topografix.com/GPX/1/1/gpx.xsd '
      '$nsGpxtpx http://www.garmin.com/xmlschemas/TrackPointExtensionv2.xsd';

  /// 'schwung-2024-12-27-0192ab.gpx' (local date of the start, first 6 id chars).
  static String fileName(DayDetail d) => 'schwung-${isoDate(d.day.startedAt)}-${shortId(d.day.id)}.gpx';

  static String build(DayDetail d, {String resortFallback = 'Freies Gelände'}) {
    final day = d.day;
    final segs = [...d.segments]..sort((a, b) => a.idx.compareTo(b.idx));
    final tracked = segs.where((s) => s.kind == SegmentKind.run || s.kind == SegmentKind.lift).toList();
    final pts = d.points.where((p) => p.accepted && p.hasPosition).toList()..sort((a, b) => a.ts.compareTo(b.ts));

    final b = XmlBuilder();
    b.declaration(encoding: 'UTF-8');
    b.element('gpx', nest: () {
      b.namespaceUri(null, nsGpx);
      b.namespaceUri('xsi', nsXsi);
      b.namespaceUri('gpxtpx', nsGpxtpx);
      b.attribute('version', '1.1');
      b.attribute('creator', creator);
      b.attribute('schemaLocation', schemaLocation, namespaceUri: nsXsi);
      b.element('metadata', nest: () {
        b.element('name', nest: '${isoDate(day.startedAt)} · ${day.resortName ?? resortFallback}');
        b.element('time', nest: isoUtc(day.startedAt));
      });
      b.element('trk', nest: () {
        b.element('name', nest: '${isoDate(day.startedAt)} · ${day.resortName ?? resortFallback}');
        b.element('type', nest: 'ski');
        var cursor = 0;
        for (final s in tracked) {
          // points are sorted, segments are in time order → single forward pass
          while (cursor < pts.length && pts[cursor].ts < s.startTs) {
            cursor++;
          }
          var i = cursor;
          b.element('trkseg', nest: () {
            for (; i < pts.length && pts[i].ts <= s.endTs; i++) {
              _trkpt(b, pts[i]);
            }
          });
          cursor = i;
        }
      });
    });
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static void _trkpt(XmlBuilder b, TrackPoint p) {
    b.element('trkpt', nest: () {
      b.attribute('lat', p.lat!.toStringAsFixed(7));
      b.attribute('lon', p.lon!.toStringAsFixed(7));
      final ele = p.fusedAltM ?? p.gpsAltM;
      if (ele != null) b.element('ele', nest: ele.toStringAsFixed(1));
      b.element('time', nest: isoUtc(p.ts));
      final v = p.speedMs;
      if (v != null) {
        b.element('extensions', nest: () {
          b.element('TrackPointExtension', namespaceUri: nsGpxtpx, nest: () {
            b.element('speed', namespaceUri: nsGpxtpx, nest: v.toStringAsFixed(2));
          });
        });
      }
    });
  }

  /// '2024-12-27' in local time.
  static String isoDate(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// '2024-12-27T08:00:00Z'.
  static String isoUtc(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}Z';
  }

  /// First six alphanumerics of the id.
  static String shortId(String id) {
    final clean = id.replaceAll(RegExp('[^0-9A-Za-z]'), '');
    return clean.length <= 6 ? clean : clean.substring(0, 6);
  }
}
