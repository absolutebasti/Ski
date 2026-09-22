import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dropline/data/db/database.dart';
import 'package:dropline/data/db/days_repository.dart';
import 'package:dropline/features/share/diagnostics_bundle.dart';
import 'package:dropline/features/share/gpx_exporter.dart';
import 'package:dropline/features/share/share_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import 'synthetic_detail.dart';

void main() {
  late AppDatabase db;
  late DaysRepository repo;
  late Directory tmp;
  final shared = <(List<XFile>, String?, String?)>[];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DaysRepository(db);
    tmp = await Directory.systemTemp.createTemp('dropline-share-');
    shared.clear();
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  ShareService service() => ShareService(
        repo: repo,
        tempDir: () async => tmp,
        sink: (files, {subject, text}) async => shared.add((files, subject, text)),
      );

  test('shareGpx writes the GPX file to temp and hands it to the sink', () async {
    final detail = syntheticDetail();
    await service().shareGpx(detail);
    expect(shared, hasLength(1));
    final file = shared.single.$1.single;
    expect(file.path, endsWith(GpxExporter.fileName(detail)));
    expect(file.mimeType, 'application/gpx+xml');
    expect(shared.single.$2, 'Skitag als GPX');
    final xml = XmlDocument.parse(await File(file.path).readAsString());
    expect(xml.findAllElements('trkseg', namespaceUri: GpxExporter.nsGpx).length, detail.runs.length + detail.lifts.length);
  });

  test('shareDiagnostics loads the day from the repository and shares gzip JSON', () async {
    final detail = syntheticDetail();
    final raw = syntheticRawPoints(id: detail.day.id);
    await repo.createActiveDay(id: detail.day.id, startedAt: detail.day.startedAt, resortId: 'kitzbuehel', resortName: 'Kitzbühel');
    await repo.appendPoints(detail.day.id, raw, stats: detail.day.stats);
    await repo.finishDay(detail.day.id, endedAt: detail.day.endedAt!, stats: detail.day.stats, segments: detail.segments);

    await service().shareDiagnostics(detail.day.id);
    final file = shared.single.$1.single;
    expect(file.path, endsWith('dropline-diag-0192ab.json.gz'));
    expect(file.mimeType, 'application/gzip');
    final json = DiagnosticsBundle.decode(await File(file.path).readAsBytes());
    expect((json['day'] as Map)['id'], detail.day.id);
    expect((json['points'] as List).length, raw.length);
    expect((json['segments'] as List).length, detail.segments.length);
    expect(json['device'], isNotEmpty);
  });

  test('shareDiagnostics throws for an unknown day and shares nothing', () async {
    await expectLater(service().shareDiagnostics('nope'), throwsStateError);
    expect(shared, isEmpty);
  });
}
