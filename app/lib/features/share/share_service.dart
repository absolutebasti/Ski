import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';
import '../../data/db/days_repository.dart';
import '../../data/db/providers.dart';
import 'diagnostics_bundle.dart';
import 'gpx_exporter.dart';
import 'share_card.dart';
import 'share_card_renderer.dart';
import 'share_strings.dart';

/// Hands files to the platform share sheet. Injectable for tests.
typedef ShareSink = Future<void> Function(List<XFile> files, {String? subject, String? text});

Future<void> _systemShare(List<XFile> files, {String? subject, String? text}) async {
  await SharePlus.instance.share(ShareParams(files: files, subject: subject, text: text));
}

/// PNG share card, GPX export and diagnostics bundle (docs/PLAN.md §9, §11).
/// Files go to the temp directory; the share sheet copies them on.
class ShareService {
  ShareService({required this.repo, ShareSink? sink, Future<Directory> Function()? tempDir})
      : _sink = sink ?? _systemShare,
        _tempDir = tempDir ?? getTemporaryDirectory;

  final DaysRepository repo;
  final ShareSink _sink;
  final Future<Directory> Function() _tempDir;

  /// Renders the card off-screen and shares it as PNG. [format] defaults to the
  /// 1080×1350 portrait variant; square and story write their own file name.
  /// [awaitFrame] is injectable for widget tests, which pump frames by hand.
  Future<void> shareDayCard(
    BuildContext context,
    DayDetail detail, {
    Future<void> Function()? awaitFrame,
    ShareFormat format = ShareFormat.portrait,
  }) async {
    final s = ShareStrings.of(context);
    final l = AppLocale.of(context);
    final png = await ShareCardRenderer.render(context, detail, awaitFrame: awaitFrame, format: format);
    final suffix = format == ShareFormat.portrait ? '' : '-${format.slug}';
    final file = await writeTemp('slopetrack-${GpxExporter.isoDate(detail.day.startedAt)}-${GpxExporter.shortId(detail.day.id)}$suffix.png', png);
    final st = detail.day.stats;
    await _sink(
      [XFile(file.path, mimeType: 'image/png')],
      subject: s.shareCardSubject,
      text: s.summaryLine(resort: detail.day.resortName ?? s.freeTerrain, runCount: '${st.runCount}', dropM: Fmt.metres(st.dropM, locale: l.code)),
    );
  }

  /// GPX 1.1 of the day's runs and lifts.
  Future<void> shareGpx(DayDetail detail, {ShareStrings strings = ShareStrings.de}) async {
    final xml = GpxExporter.build(detail, resortFallback: strings.freeTerrain);
    final file = await writeTemp(GpxExporter.fileName(detail), const <int>[], asString: xml);
    await _sink([XFile(file.path, mimeType: 'application/gpx+xml')], subject: strings.gpxSubject);
  }

  /// gzip JSON with all raw points of [dayId], loaded via the repository.
  Future<void> shareDiagnostics(String dayId, {ShareStrings strings = ShareStrings.de}) async {
    final bytes = await buildDiagnostics(dayId);
    final file = await writeTemp(DiagnosticsBundle.fileName(dayId), bytes);
    await _sink([XFile(file.path, mimeType: 'application/gzip')], subject: strings.diagnosticsSubject);
  }

  /// Loads day + segments + raw points and gzips them. Throws [StateError] when the day is unknown.
  Future<List<int>> buildDiagnostics(String dayId) async {
    final day = await repo.day(dayId);
    if (day == null) throw StateError('day $dayId not found');
    final segments = await repo.segmentsOf(dayId);
    final points = await repo.pointsRaw(dayId);
    return DiagnosticsBundle.encode(DiagnosticsBundle.toJson(day: day, segments: segments, points: points));
  }

  @visibleForTesting
  Future<File> writeTemp(String name, List<int> bytes, {String? asString}) async {
    final dir = await _tempDir();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (asString != null) return file.writeAsString(asString, flush: true);
    return file.writeAsBytes(bytes, flush: true);
  }
}

final shareServiceProvider = Provider<ShareService>((ref) => ShareService(repo: ref.watch(daysRepositoryProvider)));
