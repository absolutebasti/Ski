import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/core/core.dart';
import 'package:dropline/features/share/gpx_exporter.dart';
import 'package:xml/xml.dart';

import 'synthetic_detail.dart';

void main() {
  final detail = syntheticDetail();

  group('GpxExporter', () {
    late XmlDocument doc;
    late XmlElement gpx;
    setUpAll(() {
      doc = XmlDocument.parse(GpxExporter.build(detail));
      gpx = doc.rootElement;
    });

    test('root carries GPX 1.1 namespaces, creator and schemaLocation', () {
      expect(gpx.name.local, 'gpx');
      expect(gpx.name.namespaceUri, GpxExporter.nsGpx);
      expect(gpx.getAttribute('version'), '1.1');
      expect(gpx.getAttribute('creator'), 'Dropline');
      expect(gpx.getAttribute('xmlns:xsi'), GpxExporter.nsXsi);
      expect(gpx.getAttribute('xmlns:gpxtpx'), GpxExporter.nsGpxtpx);
      expect(gpx.getAttribute('schemaLocation', namespaceUri: GpxExporter.nsXsi), contains('gpx.xsd'));
      expect(doc.toXmlString(), startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    });

    test('metadata time and one track named "date · resort"', () {
      final meta = gpx.getElement('metadata', namespaceUri: GpxExporter.nsGpx)!;
      expect(meta.getElement('time', namespaceUri: GpxExporter.nsGpx)!.innerText, GpxExporter.isoUtc(detail.day.startedAt));
      final trks = gpx.findElements('trk', namespaceUri: GpxExporter.nsGpx).toList();
      expect(trks, hasLength(1));
      final name = trks.single.getElement('name', namespaceUri: GpxExporter.nsGpx)!.innerText;
      expect(name, '${GpxExporter.isoDate(detail.day.startedAt)} · Kitzbühel');
    });

    test('one trkseg per run/lift, in day order, stops omitted', () {
      final segs = gpx.findAllElements('trkseg', namespaceUri: GpxExporter.nsGpx).toList();
      final runs = detail.runs.length, lifts = detail.lifts.length;
      expect(runs, greaterThan(0));
      expect(lifts, greaterThan(0));
      expect(segs.length, runs + lifts);
      expect(detail.segments.any((s) => s.kind == SegmentKind.stop), isTrue, reason: 'fixture should contain stops');
      // every trkseg has points and they are time-ordered and inside the segment
      final tracked = detail.segments.where((s) => s.kind == SegmentKind.run || s.kind == SegmentKind.lift).toList();
      for (var i = 0; i < segs.length; i++) {
        final pts = segs[i].findElements('trkpt', namespaceUri: GpxExporter.nsGpx).toList();
        expect(pts, isNotEmpty, reason: 'trkseg $i');
        final times = pts.map((p) => DateTime.parse(p.getElement('time', namespaceUri: GpxExporter.nsGpx)!.innerText).millisecondsSinceEpoch).toList();
        expect(times.first, greaterThanOrEqualTo(tracked[i].startTs));
        expect(times.last, lessThanOrEqualTo(tracked[i].endTs));
        for (var k = 1; k < times.length; k++) {
          expect(times[k], greaterThanOrEqualTo(times[k - 1]));
        }
      }
    });

    test('first trkpt has lat/lon, ele = fusedAltM, UTC time and gpxtpx:speed', () {
      final first = gpx.findAllElements('trkpt', namespaceUri: GpxExporter.nsGpx).first;
      final lat = double.parse(first.getAttribute('lat')!);
      final lon = double.parse(first.getAttribute('lon')!);
      expect(lat, closeTo(47.449, 0.01));
      expect(lon, closeTo(12.391, 0.01));
      final ele = double.parse(first.getElement('ele', namespaceUri: GpxExporter.nsGpx)!.innerText);
      final time = first.getElement('time', namespaceUri: GpxExporter.nsGpx)!.innerText;
      expect(time, endsWith('Z'));
      final ts = DateTime.parse(time).millisecondsSinceEpoch;
      final src = detail.points.firstWhere((p) => p.ts == ts);
      expect(ele, closeTo(src.fusedAltM!, 0.06));
      final speed = first.findAllElements('speed', namespaceUri: GpxExporter.nsGpxtpx).single;
      expect(double.parse(speed.innerText), closeTo(src.speedMs!, 0.006));
    });

    test('rejected and position-less points are skipped, speed omitted when null', () {
      const t0 = 1700000000000;
      final pts = [
        const TrackPoint(ts: t0, lat: 47, lon: 12, fusedAltM: 1000, accepted: true, speedMs: null),
        const TrackPoint(ts: t0 + 1000, lat: 47.0001, lon: 12, fusedAltM: 990, accepted: false, speedMs: 3),
        const TrackPoint(ts: t0 + 2000, fusedAltM: 980, accepted: true, speedMs: 3),
        const TrackPoint(ts: t0 + 3000, lat: 47.0002, lon: 12, fusedAltM: 970, accepted: true, speedMs: 12.5),
      ];
      final d = DayDetail(
        day: const DayRecord(id: 'abc', startedAt: t0, status: DayStatus.finished, stats: DayStats.empty),
        segments: const [
          Segment(id: 's1', dayId: 'abc', kind: SegmentKind.run, idx: 0, runNumber: 1, startTs: t0, endTs: t0 + 3000),
        ],
        points: pts,
      );
      final x = XmlDocument.parse(GpxExporter.build(d));
      final trkpts = x.findAllElements('trkpt', namespaceUri: GpxExporter.nsGpx).toList();
      expect(trkpts, hasLength(2));
      expect(trkpts.first.findAllElements('speed', namespaceUri: GpxExporter.nsGpxtpx), isEmpty);
      expect(trkpts.last.findAllElements('speed', namespaceUri: GpxExporter.nsGpxtpx).single.innerText, '12.50');
      expect(x.rootElement.getElement('trk', namespaceUri: GpxExporter.nsGpx)!.getElement('name', namespaceUri: GpxExporter.nsGpx)!.innerText, endsWith('· Freies Gelände'));
    });

    test('file name is dropline-YYYY-MM-DD-<id6>.gpx', () {
      expect(GpxExporter.fileName(detail), matches(RegExp(r'^dropline-\d{4}-\d{2}-\d{2}-0192ab\.gpx$')));
      expect(GpxExporter.shortId('abc'), 'abc');
    });
  });
}
