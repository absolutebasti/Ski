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
import 'settings_strings.dart';

/// Hidden behind seven taps on the version row (docs/PLAN.md §3 row
/// "Einstellungen"): sensor status, today's fix counters and two repair tools.
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.recomputed)));
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

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(s.diagnostics)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 32),
        children: [
          AppCard(
            child: Column(
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
          ),
          const SizedBox(height: 20),
          if (selected == null)
            Text(s.noDays, style: AppText.bodyText(c.textSecondary, size: 15))
          else ...[
            Text(s.selectedDay.toUpperCase(), style: AppText.label(c.textSecondary)),
            const SizedBox(height: 8),
            _DayPicker(
              days: days,
              value: selected,
              onChanged: (id) => setState(() => _selectedId = id),
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: s.recompute,
              icon: Icons.refresh_rounded,
              onPressed: _busy ? null : () => _recompute(selected),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: s.shareDiagnostics,
              icon: Icons.bug_report_outlined,
              onPressed: _busy ? null : () => _share(selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.bodyText(c.textSecondary, size: 15))),
          Text(value, style: AppText.bodyText(c.textPrimary, size: 15, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.days, required this.value, required this.onChanged});
  final List<DaySummary> days;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: c.elevated,
          style: AppText.bodyText(c.textPrimary, size: 15),
          onChanged: (v) => v == null ? null : onChanged(v),
          items: [
            for (final d in days)
              DropdownMenuItem<String>(
                value: d.id,
                child: Text(
                  '${Fmt.dateShort(d.startedAt, locale: l.code)}${d.resortName == null ? '' : ' · ${d.resortName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
