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
import 'share_card_data.dart';
import 'share_card_renderer.dart';
import 'share_cards.dart';
import 'share_strings.dart';

/// Hands files to the platform share sheet. Injectable for tests.
typedef ShareSink = Future<void> Function(List<XFile> files, {String? subject, String? text});

Future<void> _systemShare(List<XFile> files, {String? subject, String? text}) async {
  await SharePlus.instance.share(ShareParams(files: files, subject: subject, text: text));
}

/// PNG share cards (day, medal, level, season, rank, duel), GPX export and
/// diagnostics bundle (docs/PLAN.md §9, §11). Files go to the temp directory;
/// the share sheet copies them on.
class ShareService {
  ShareService({this.repo, ShareSink? sink, Future<Directory> Function()? tempDir}) : _sink = sink ?? _systemShare, _tempDir = tempDir ?? getTemporaryDirectory;

  /// Needed for [buildDiagnostics] only; the cards work without a database.
  final DaysRepository? repo;
  final ShareSink _sink;
  final Future<Directory> Function() _tempDir;

  /// Default output size of the Show-Säule cards (medal, level, season, rank,
  /// duel): the 9:16 story. The day card keeps 4:5 for compatibility.
  static const ShareFormat defaultCardFormat = ShareFormat.story;

  /// Renders the card for [data] off-screen and shares it as PNG with a
  /// localised one-liner. [kind] must match `data.kind`; the pair exists so
  /// call sites read `shareCard(context, ShareCardKind.medal, data)`.
  /// [awaitFrame] is injectable for widget tests, which pump frames by hand.
  Future<void> shareCard(
    BuildContext context,
    ShareCardKind kind,
    ShareCardData data, {
    ShareFormat format = defaultCardFormat,
    Future<void> Function()? awaitFrame,
  }) async {
    if (kind != data.kind) throw ArgumentError.value(kind, 'kind', 'does not match data.kind (${data.kind})');
    if (kind == ShareCardKind.day) {
      return shareDayCard(context, (data as DayCardData).detail, awaitFrame: awaitFrame, format: format);
    }
    final s = ShareStrings.of(context);
    final l = AppLocale.of(context);
    if (kind == ShareCardKind.medal || kind == ShareCardKind.level) await _precacheRider(context);
    if (!context.mounted) return;
    final png = await ShareCardRenderer.renderCard(context, data, awaitFrame: awaitFrame, format: format);
    final file = await writeTemp('slopetrack-${kind.name}-${data.slug}-${format.slug}.png', png);
    final (subject, text) = _cardText(s, l, data);
    await _sink(
      [XFile(file.path, mimeType: 'image/png')],
      subject: subject,
      text: text,
    );
  }

  /// The mascot is an asset image; decode it before the one-frame render so
  /// it is painted into the PNG. Failures (missing asset) are ignored.
  Future<void> _precacheRider(BuildContext context) async {
    try {
      await precacheImage(const AssetImage('assets/mascot/rider-${ShareCardView.riderPose}.png'), context, onError: (_, _) {});
    } catch (_) {
      // No asset bundle (tests) or decode failure: the card renders without the rider.
    }
  }

  (String, String) _cardText(ShareStrings s, AppLocale l, ShareCardData data) {
    final (subject, text) = _cardLine(s, l, data);
    return (subject, s.withLink(text));
  }

  (String, String) _cardLine(ShareStrings s, AppLocale l, ShareCardData data) => switch (data) {
    DayCardData(:final detail) => (
      s.shareCardSubject,
      s.summaryLine(
        resort: detail.day.resortName,
        runCount: '${detail.day.stats.runCount}',
        dropM: Fmt.metres(detail.day.stats.dropM, locale: l.code),
      ),
    ),
    MedalCardData(:final def) => (s.medalSubject, s.medalText(l.pick(de: def.titleDe, en: def.titleEn))),
    LevelCardData(:final level) => (
      s.levelSubject,
      s.levelText(level.index, l.pick(de: level.titleDe, en: level.titleEn), Fmt.km(level.distanceM, decimals: 0, locale: l.code)),
    ),
    SeasonCardData(:final seasonKey, :final dayCount, :final dropM) => (s.seasonSubject, s.seasonText(seasonKey, dayCount, Fmt.metres(dropM, locale: l.code))),
    RankCardData(:final rank, :final scopeName, :final seasonKey, :final periodLabel) => (
      s.rankSubject,
      s.rankText(rank, scopeName, periodLabel ?? s.seasonShort(seasonKey)),
    ),
    final DuelCardData d => (s.duelSubject, s.duelText(d.myPlace, d.board.length)),
  };

  /// Renders the card off-screen and shares it as PNG. [format] defaults to the
  /// 1080×1350 portrait variant; square and story write their own file name.
  /// [awaitFrame] is injectable for widget tests, which pump frames by hand.
  Future<void> shareDayCard(BuildContext context, DayDetail detail, {Future<void> Function()? awaitFrame, ShareFormat format = ShareFormat.story}) async {
    final s = ShareStrings.of(context);
    final l = AppLocale.of(context);
    final png = await ShareCardRenderer.render(context, detail, awaitFrame: awaitFrame, format: format);
    final suffix = format == ShareFormat.portrait ? '' : '-${format.slug}';
    final file = await writeTemp('slopetrack-${GpxExporter.isoDate(detail.day.startedAt)}-${GpxExporter.shortId(detail.day.id)}$suffix.png', png);
    final st = detail.day.stats;
    await _sink(
      [XFile(file.path, mimeType: 'image/png')],
      subject: s.shareCardSubject,
      text: s.withLink(s.summaryLine(
        resort: detail.day.resortName,
        runCount: '${st.runCount}',
        dropM: Fmt.metres(st.dropM, locale: l.code),
      )),
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
    final repo = this.repo;
    if (repo == null) throw StateError('ShareService has no repository');
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
