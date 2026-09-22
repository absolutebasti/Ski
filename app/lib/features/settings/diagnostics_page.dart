import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/db/providers.dart';
import '../../platform/providers.dart';
import '../recording/live_state_provider.dart';
import '../recording/recording_controller.dart';
import '../share/share_service.dart';
import 'settings_providers.dart';
import 'settings_sheet.dart';
import 'settings_strings.dart';

/// Hidden behind seven taps on the settings footer (docs/DESIGN.md §5):
/// sensor status, today's fix counters and two repair tools. Same visual
/// language as the Einstellungen sheet — grouped surfaces, overlines, no
/// Material defaults.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  String? _selectedId;
  bool _busy = false;

  Future<void> _recompute(String dayId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = SettingsStrings.of(context);
    try {
      await ref.read(recordingControllerProvider.notifier).recomputeDay(dayId);
      ref.invalidate(dayDetailProvider(dayId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    showToast(context, s.recomputed);
  }

  Future<void> _share(String dayId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(shareServiceProvider).shareDiagnostics(dayId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDay(List<DaySummary> days, String selected) async {
    final s = SettingsStrings.of(context);
    final l = AppLocale.of(context);
    final picked = await AppSheet.show<String>(
      context,
      title: s.pickDay,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return SingleChildScrollView(
          child: SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, d) in days.indexed) ...[
                  if (i > 0) const Hairline(inset: 18),
                  Pressable(
                    onTap: () => Navigator.of(ctx).pop(d.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Fmt.dateShort(d.startedAt, locale: l.code),
                              style: AppText.bodyStrong(c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (d.resortName != null) ...[
                            const SizedBox(width: 12),
                            Flexible(child: Text(d.resortName!, style: AppText.caption(c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          if (d.id == selected) ...[const SizedBox(width: 10), GlyphIcon(Glyph.crest, size: 16, color: c.accent)],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = SettingsStrings.of(context);
    final live = ref.watch(liveStateProvider);
    final location = ref.watch(locationStatusProvider).asData?.value;
    final precise = ref.watch(preciseLocationProvider).asData?.value;
    final baro = ref.watch(barometerAvailableProvider).asData?.value;
    final days = ref.watch(daysListProvider).asData?.value ?? const <DaySummary>[];
    final selected = days.any((d) => d.id == _selectedId) ? _selectedId! : (days.isEmpty ? null : days.first.id);
    final day = selected == null ? null : days.firstWhere((d) => d.id == selected);

    return Scaffold(
      backgroundColor: c.bg,
      body: PageBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ScreenHeader(
                title: s.diagnostics,
                caption: s.diagnosticsCaption,
                leading: HeaderButton(glyph: Glyph.back, onTap: () => Navigator.of(context).maybePop()),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, 32),
                  children: [
                    SettingsSection(
                      label: s.sectionSensors,
                      first: true,
                      children: [
                        _Line(label: s.gps, value: location == null ? '…' : s.locationState(location)),
                        _Line(label: s.precise, value: precise == null ? '…' : (precise ? s.yes : s.no)),
                        _Line(label: s.barometer, value: baro == null ? '…' : (baro ? s.yes : s.no)),
                        _Line(
                          label: s.fixesToday,
                          value: s.fixes(
                            accepted: Fmt.metres(live.stats.acceptedFixes.toDouble(), locale: l.code),
                            rejected: Fmt.metres(live.stats.rejectedFixes.toDouble(), locale: l.code),
                          ),
                        ),
                        _Line(label: s.streamRestarts, value: '${ref.watch(locationSourceProvider).restartCount}'),
                      ],
                    ),
                    if (selected == null || day == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.noDaysHeadline, style: AppText.headline(c.textPrimary, size: 19)),
                              const SizedBox(height: 6),
                              Text(s.noDays, style: AppText.bodyText(c.textSecondary, size: 15)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      SettingsSection(
                        label: s.sectionDay,
                        children: [
                          SettingsRow(
                            glyph: Glyph.calendar,
                            label: s.selectedDay,
                            caption: day.resortName,
                            value: Fmt.dateShort(day.startedAt, locale: l.code),
                            chevron: true,
                            onTap: days.length < 2 ? null : () => _pickDay(days, selected),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SecondaryButton(
                        label: s.recompute,
                        icon: Icons.refresh_rounded,
                        onPressed: _busy ? null : () => _recompute(selected),
                      ),
                      const SizedBox(height: 10),
                      SecondaryButton(
                        label: s.shareDiagnostics,
                        glyph: Glyph.share,
                        onPressed: _busy ? null : () => _share(selected),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label left, tabular value right — a read-only settings row.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.bodyText(c.textSecondary, size: 15))),
          const SizedBox(width: 12),
          Text(value, style: AppText.bodyStrong(c.textPrimary, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
