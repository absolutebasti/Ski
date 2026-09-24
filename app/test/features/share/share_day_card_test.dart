import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/features/share/share_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../support/pump.dart';
import 'synthetic_detail.dart';

/// shareDayCard is the only path that combines the off-screen render, the temp
/// file and the share sheet — so it gets its own widget test. All file I/O is
/// synchronous or inside runAsync: awaiting real I/O in the fake-async zone of
/// a widget test would hang forever.
void main() {
  testWidgets('shareDayCard writes a PNG to temp and hands it to the sink with a summary line', (tester) async {
    tester.view.physicalSize = const Size(1080, 1350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    final tmp = Directory.systemTemp.createTempSync('slopetrack-card-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final shared = <(List<XFile>, String?, String?)>[];
    final service = ShareService(
      repo: DaysRepository(db),
      tempDir: () async => tmp,
      sink: (files, {subject, text}) async => shared.add((files, subject, text)),
    );

    final detail = syntheticDetail();
    late BuildContext ctx;
    await pumpApp(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox.shrink();
    }));

    await tester.runAsync(() async {
      await service.shareDayCard(ctx, detail, awaitFrame: () => tester.pump());
      await db.close();
    });

    expect(shared, hasLength(1));
    final (files, subject, text) = shared.single;
    final file = files.single;
    expect(file.mimeType, 'image/png');
    expect(file.path, endsWith('-0192ab.png'));
    expect(File(file.path).existsSync(), isTrue);
    expect(File(file.path).lengthSync(), greaterThan(1000));
    expect(subject, 'Mein Skitag');
    expect(text, startsWith('Skitag in Kitzbühel · ${detail.day.stats.runCount} Abfahrten · '));
    await tester.pump();
  });
}
