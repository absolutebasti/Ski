import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/widgets/widgets.dart';
import '../../data/resorts/resort_repository.dart';
import '../../core/settings.dart';
import '../../app/l10n/app_locale.dart';
import '../../core/core.dart';
import '../../platform/providers.dart';
import '../recording/live_state_provider.dart';
import '../recording/recording_badges.dart';
import '../recording/recording_controller.dart';
import '../recording/recovery_service.dart';
import '../settings/settings_providers.dart';
import '../settings/settings_sheet.dart';
import 'live_view.dart';
import 'idle_view.dart';
import 'recovery_card.dart';
import 'today_providers.dart';
import 'today_strings.dart';

/// Tab 0 — one screen with two faces: idle (start a day) and live (the day is
/// running). docs/PLAN.md §3 rows "Heute — idle" and "Heute — live".
class HeuteScreen extends ConsumerStatefulWidget {
  const HeuteScreen({super.key});

  @override
  ConsumerState<HeuteScreen> createState() => _HeuteScreenState();
}

class _HeuteScreenState extends ConsumerState<HeuteScreen> {
  /// Why the last Start attempt failed — drives the inline card above the button.
  RecordingErrorKind? _startError;
  bool _busy = false;

  /// Run-committed banner: shown for 3 s after the engine closes a run.
  String? _banner;
  Segment? _bannerRun;
  Timer? _bannerTimer;
  String? _lastRunId;

  /// Back from iOS Settings (or any app switch): permission and accuracy may
  /// have changed — re-read them so the cards and the Start button follow.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshAccess);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _refreshAccess() {
    if (!mounted) return;
    ref.read(settingsRefreshProvider.notifier).bump();
    if (_startError != null && _startError != RecordingErrorKind.alreadyRecording) setState(() => _startError = null);
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref.read(recordingControllerProvider.notifier).startDay();
      if (mounted) setState(() => _startError = null);
    } on RecordingError catch (e) {
      if (mounted) setState(() => _startError = e.kind);
    } finally {
      // Start may have shown the iOS permission prompt.
      if (mounted) {
        ref.read(settingsRefreshProvider.notifier).bump();
        setState(() => _busy = false);
      }
    }
  }

  /// "Genau ein": ask iOS for temporary full accuracy, then start straight away.
  Future<void> _requestPrecise() async {
    final ok = await ref.read(permissionServiceProvider).requestTemporaryFullAccuracy();
    if (!mounted) return;
    if (!ok) {
      await ref.read(permissionServiceProvider).openSettings();
      return;
    }
    setState(() => _startError = null);
    await _start();
  }

  Future<void> _openSettingsApp() async {
    await ref.read(permissionServiceProvider).openSettings();
    // Coming back from iOS settings: re-check access right away (resume also does).
    unawaited(ref.read(recordingControllerProvider.notifier).recheckAccess());
  }

  Future<void> _end() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = TodayStrings.of(context);
    try {
      final id = await ref.read(recordingControllerProvider.notifier).endDay();
      if (!mounted) return;
      if (id == null) {
        showToast(context, s.tooShort);
        return;
      }
      await AppNav.openSummary(context, id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onLive(LiveState? prev, LiveState next) {
    final run = next.lastRun;
    if (run == null || run.id == _lastRunId) return;
    _lastRunId = run.id;
    // A resume replays stored points: only banner runs that close while we watch.
    if (prev == null || prev.stats.runCount == 0 && next.stats.runCount > 1) return;
    unawaited(HapticFeedback.mediumImpact());
    final s = TodayStrings.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    _bannerTimer?.cancel();
    setState(() {
      _banner = s.runBanner(
        number: run.runNumber ?? next.stats.runCount,
        dropM: Fmt.metres(run.dropM, locale: locale),
        kmh: Fmt.kmh(run.maxSpeedMs, locale: locale),
      );
      _bannerRun = run;
    });
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = TodayStrings.of(context);
    final recording = ref.watch(recordingControllerProvider);
    ref.listen<LiveState>(liveStateProvider, _onLive);

    final recovery = recording.isRecording ? null : ref.watch(recoveryProvider).asData?.value;

    final l = AppLocale.of(context);
    // Recording: the active day's own resort (null until resolved — never the
    // stale last one). Idle: the last resort from settings.
    final String? resortName;
    if (recording.isRecording) {
      resortName = ref.watch(activeDayResortProvider).asData?.value;
    } else {
      final lastResortId = ref.watch(settingsProvider).lastResortId;
      resortName = lastResortId == null ? null : ref.watch(resortRepositoryProvider).asData?.value.byId(lastResortId)?.name;
    }
    final caption = [Fmt.dateShort(DateTime.now().millisecondsSinceEpoch, locale: l.code), ?resortName].join(' · ');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RecordingHintToaster(
        child: recording.isRecording
          ? LiveView(banner: _banner, bannerRun: _bannerRun, busy: _busy, onEnd: _end, resortName: resortName)
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  ScreenHeader(title: s.title, caption: caption, trailing: [HeaderButton(glyph: Glyph.gear, tooltip: s.settings, onTap: () => SettingsSheet.show(context))]),
                  Expanded(
                    child: IdleView(
                error: _startError,
                busy: _busy,
                onStart: _start,
                onOpenSettings: _openSettingsApp,
                onRequestPrecise: _requestPrecise,
                recovery: recovery == null ? null : RecoveryCard(info: recovery),
              ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
