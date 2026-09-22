import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/brand.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/settings.dart';
import '../../data/db/providers.dart';
import '../../platform/permission_service.dart';
import '../../platform/providers.dart';
import 'diagnostics_page.dart';
import 'settings_providers.dart';
import 'settings_strings.dart';

/// Bottom sheet from the gear on Heute (docs/PLAN.md §3 row "Einstellungen").
/// Seven taps on the version row unlock the hidden Diagnose page.
class SettingsSheet {
  const SettingsSheet._();

  static Future<void> show(BuildContext context) =>
      AppSheet.show<void>(context, builder: (_) => const SettingsSheetBody());
}

/// Exposed for tests; use [SettingsSheet.show] in the app.
class SettingsSheetBody extends ConsumerStatefulWidget {
  const SettingsSheetBody({super.key});

  @override
  ConsumerState<SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends ConsumerState<SettingsSheetBody> {
  static const int _unlockTaps = 7;
  int _versionTaps = 0;
  bool _busy = false;

  Future<void> _setLocale(String value) => ref.read(settingsProvider.notifier).setLocale(value);

  Future<void> _openSystemSettings() async {
    await ref.read(permissionServiceProvider).openSettings();
    ref.read(settingsRefreshProvider.notifier).bump();
  }

  Future<void> _toggleNotifications(bool on) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (!on) {
      await notifier.setNotifications(optIn: false);
      return;
    }
    final granted = await ref.read(permissionServiceProvider).requestNotifications();
    await notifier.setNotifications(optIn: granted);
    if (!granted && mounted) {
      final s = SettingsStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.notificationsDenied)));
    }
  }

  Future<void> _openPrivacy() async {
    await launchUrl(Uri.parse(kPrivacyUrl), mode: LaunchMode.externalApplication);
  }

  void _tapVersion() {
    if (ref.read(settingsProvider).diagnosticsUnlocked) return;
    _versionTaps++;
    if (_versionTaps < _unlockTaps) return;
    _versionTaps = 0;
    final s = SettingsStrings.of(context);
    ref.read(settingsProvider.notifier).update((v) => v.copyWith(diagnosticsUnlocked: true));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.diagnosticsUnlockedToast)));
  }

  Future<void> _deleteAll() async {
    if (_busy) return;
    final s = SettingsStrings.of(context);
    final first = await _confirm(context, title: s.deleteTitle, body: s.deleteBody, action: s.delete);
    if (!first || !mounted) return;
    final second = await _confirm(context, title: s.deleteConfirmTitle, body: s.deleteConfirmBody, action: s.deleteConfirm);
    if (!second || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(daysRepositoryProvider).deleteAll();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deletedToast)));
  }

  Future<bool> _confirm(BuildContext context, {required String title, required String body, required String action}) async {
    final s = SettingsStrings.of(context);
    final ok = await AppSheet.show<bool>(
      context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(title, style: AppText.title(c.textPrimary)),
            const SizedBox(height: 8),
            Text(body, style: AppText.bodyText(c.textSecondary, size: 15)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: action,
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [SecondaryButton(label: s.cancel, onPressed: () => Navigator.of(ctx).pop(false))],
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  Future<void> _openDiagnostics() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SettingsStrings.of(context);
    final settings = ref.watch(settingsProvider);
    final location = ref.watch(locationStatusProvider).asData?.value ?? LocationPermissionState.unknown;
    final version = ref.watch(appVersionProvider).asData?.value ?? '–';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(s.title, style: AppText.headline(c.textPrimary, size: 24)),
            const SizedBox(height: 12),
            SettingsRow(
              label: s.language,
              trailing: _LanguagePicker(value: settings.locale, onChanged: _setLocale),
              stacked: true,
            ),
            SettingsRow(label: s.units, value: s.unitsValue),
            SettingsRow(
              label: s.location,
              value: s.locationState(location),
              trailing: SecondaryButton(label: s.openSettings, height: 40, onPressed: _openSystemSettings),
            ),
            SettingsRow(
              label: s.notifications,
              value: s.notificationsHint,
              trailing: Switch(
                value: settings.notificationsOptIn,
                onChanged: (v) => _toggleNotifications(v),
              ),
            ),
            SettingsRow(label: s.privacy, icon: Icons.open_in_new_rounded, onTap: _openPrivacy),
            SettingsRow(label: s.deleteAll, danger: true, icon: Icons.delete_outline_rounded, onTap: _busy ? null : _deleteAll),
            SettingsRow(label: s.version, value: version, onTap: _tapVersion),
            if (settings.diagnosticsUnlocked)
              SettingsRow(label: s.diagnostics, icon: Icons.chevron_right_rounded, onTap: _openDiagnostics),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// One line in the sheet: label left, value / control right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.icon,
    this.danger = false,
    this.stacked = false,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool danger;

  /// Put [trailing] under the label instead of next to it (language picker).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = danger ? c.danger : c.textPrimary;
    final head = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.bodyText(color, size: 17, weight: FontWeight.w600)),
              if (value != null) ...[
                const SizedBox(height: 2),
                Text(value!, style: AppText.bodyText(c.textSecondary, size: 14)),
              ],
            ],
          ),
        ),
        if (!stacked && trailing != null) trailing!,
        if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20, color: danger ? c.danger : c.textTertiary)],
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Tokens.minTarget - 20),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [head, if (trailing != null) ...[const SizedBox(height: 10), trailing!]],
              )
            : head,
      ),
    );
    if (onTap == null) return body;
    return InkWell(borderRadius: BorderRadius.circular(Tokens.radius), onTap: onTap, child: body);
  }
}

/// System · Deutsch · English.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SettingsStrings.of(context);
    final options = <(String, String)>[('system', s.system), ('de', s.german), ('en', s.english)];
    return Row(
      children: [
        for (final o in options) ...[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(o.$1),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == o.$1 ? c.accent.withValues(alpha: 0.18) : c.elevated,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: value == o.$1 ? c.accent : c.hairline),
                ),
                child: Text(
                  o.$2,
                  style: AppText.label(value == o.$1 ? c.accent : c.textSecondary, size: 13),
                ),
              ),
            ),
          ),
          if (o != options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
