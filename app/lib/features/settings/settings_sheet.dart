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
import '../account/account.dart';
import 'diagnostics_page.dart';
import 'licences_page.dart';
import 'settings_providers.dart';
import 'settings_strings.dart';

/// Bottom sheet from the gear on Heute (docs/DESIGN.md §5 "Einstellungen").
/// Grouped surfaces, section overlines, rows ≥ 56 pt. Seven taps on the
/// footer wordmark unlock the hidden Diagnose page.
class SettingsSheet {
  const SettingsSheet._();

  /// [onAccount] overrides what the Konto row opens; by default it opens
  /// [AccountSheet] (features/account).
  static Future<void> show(BuildContext context, {VoidCallback? onAccount}) => AppSheet.show<void>(
        context,
        title: SettingsStrings.of(context).title,
        builder: (_) => SettingsSheetBody(onAccount: onAccount),
      );
}

/// Exposed for tests; use [SettingsSheet.show] in the app.
class SettingsSheetBody extends ConsumerStatefulWidget {
  const SettingsSheetBody({super.key, this.onAccount});

  final VoidCallback? onAccount;

  @override
  ConsumerState<SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends ConsumerState<SettingsSheetBody> {
  static const int _unlockTaps = 7;
  int _versionTaps = 0;
  bool _busy = false;

  Future<void> _setLocale(String value) => ref.read(settingsProvider.notifier).setLocale(value);

  Future<void> _setAppearance(String value) => ref.read(settingsProvider.notifier).setAppearance(value);

  Future<void> _openSystemSettings() async {
    await ref.read(permissionServiceProvider).openSettings();
    ref.read(settingsRefreshProvider.notifier).bump();
  }

  void _openAccount() {
    final onAccount = widget.onAccount;
    if (onAccount != null) {
      onAccount();
      return;
    }
    AccountSheet.show(context);
  }

  Future<void> _toggleNotifications(bool on) async {
    final notifier = ref.read(settingsProvider.notifier);
    if (!on) {
      await notifier.setNotifications(optIn: false);
      return;
    }
    final granted = await ref.read(permissionServiceProvider).requestNotifications();
    await notifier.setNotifications(optIn: granted);
    if (!granted && mounted) showToast(context, SettingsStrings.of(context).notificationsDenied);
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
    ref.read(settingsProvider.notifier).setDiagnosticsUnlocked();
    showToast(context, s.diagnosticsUnlockedToast);
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
    showToast(context, s.deletedToast);
  }

  Future<bool> _confirm(BuildContext context, {required String title, required String body, required String action}) async {
    final s = SettingsStrings.of(context);
    final ok = await AppSheet.show<bool>(
      context,
      title: title,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(body, style: AppText.bodyText(c.textSecondary, size: 15)),
            const SizedBox(height: 20),
            SecondaryButton(
              label: action,
              glyph: Glyph.trash,
              danger: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 10),
            SecondaryButton(label: s.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
            const SizedBox(height: 4),
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
    final s = SettingsStrings.of(context);
    final settings = ref.watch(settingsProvider);
    final location = ref.watch(locationStatusProvider).asData?.value ?? LocationPermissionState.unknown;
    final granted = location == LocationPermissionState.always || location == LocationPermissionState.whileInUse;
    final version = ref.watch(appVersionProvider).asData?.value ?? '–';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            label: s.sectionGeneral,
            first: true,
            children: [
              SettingsRow(
                icon: Icons.contrast_rounded,
                label: s.appearance,
                caption: s.appearanceHint,
                below: SegmentedTextTabs(
                  value: settings.appearance,
                  options: [('system', s.appearanceSystem), ('light', s.appearanceLight), ('dark', s.appearanceDark)],
                  onChanged: _setAppearance,
                ),
              ),
              SettingsRow(
                icon: Icons.language_rounded,
                label: s.language,
                below: SegmentedTextTabs(
                  value: settings.locale,
                  options: [('system', s.system), ('de', s.german), ('en', s.english)],
                  onChanged: _setLocale,
                ),
              ),
              SettingsRow(icon: Icons.straighten_rounded, label: s.units, value: s.unitsValue),
            ],
          ),
          SettingsSection(
            label: s.sectionAccount,
            children: [
              AccountRow(onTap: _openAccount),
            ],
          ),
          SettingsSection(
            label: s.sectionPermissions,
            children: [
              SettingsRow(
                glyph: Glyph.locate,
                label: s.location,
                caption: granted ? null : s.locationHint,
                value: s.locationState(location),
                chevron: true,
                onTap: _openSystemSettings,
                tone: granted ? RowTone.plain : RowTone.warn,
              ),
              SettingsRow(
                icon: Icons.notifications_none_rounded,
                label: s.notifications,
                caption: s.notificationsHint,
                trailing: Switch(
                  value: settings.notificationsOptIn,
                  onChanged: (v) => _toggleNotifications(v),
                ),
              ),
            ],
          ),
          SettingsSection(
            label: s.sectionData,
            children: [
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                label: s.privacy,
                caption: s.privacyHint,
                chevron: true,
                onTap: _openPrivacy,
              ),
              SettingsRow(
                glyph: Glyph.trash,
                label: s.deleteAll,
                caption: s.deleteAllHint,
                danger: true,
                onTap: _busy ? null : _deleteAll,
              ),
              if (settings.diagnosticsUnlocked)
                SettingsRow(
                  icon: Icons.build_outlined,
                  label: s.diagnostics,
                  caption: s.diagnosticsHint,
                  chevron: true,
                  onTap: _openDiagnostics,
                ),
              SettingsRow(
                glyph: Glyph.crest,
                label: s.licences,
                caption: s.licencesHint,
                chevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LicencesPage())),
              ),
            ],
          ),
          _Footer(version: version, onTap: _tapVersion),
        ],
      ),
    );
  }
}

/// Section overline + one grouped surface with hairline-separated rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.label, required this.children, this.first = false});

  final String label;
  final List<Widget> children;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(label.overline, style: AppText.label(c.textTertiary)),
          ),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in children.indexed) ...[
                  if (i > 0) const Hairline(inset: 18),
                  row,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [warn] paints the glyph and the value in danger — a blocked permission is a
/// failure state, and danger is the only token allowed to say so.
enum RowTone { plain, warn }

/// One settings line: 22 pt glyph, title 16, caption 13.5, trailing switch or
/// value + chevron. Minimum height 56, optional stacked control below.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.caption,
    this.trailing,
    this.below,
    this.onTap,
    this.icon,
    this.glyph,
    this.danger = false,
    this.chevron = false,
    this.tone = RowTone.plain,
  });

  final String label;

  /// Right-hand value text (16, secondary).
  final String? value;

  /// Sub-line under the title (13.5, secondary).
  final String? caption;

  /// Right-hand control — a Switch, usually.
  final Widget? trailing;

  /// Control stacked under the title (segmented tabs).
  final Widget? below;

  final VoidCallback? onTap;
  final IconData? icon;
  final Glyph? glyph;
  final bool danger;
  final bool chevron;
  final RowTone tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final titleColor = danger ? c.danger : c.textPrimary;
    final glyphColor = danger || tone == RowTone.warn ? c.danger : c.textTertiary;
    final valueColor = tone == RowTone.warn ? c.danger : c.textSecondary;

    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (glyph != null)
          GlyphIcon(glyph!, size: 22, color: glyphColor)
        else if (icon != null)
          Icon(icon, size: 22, color: glyphColor),
        if (glyph != null || icon != null) const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.bodyStrong(titleColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!, style: AppText.caption(c.textSecondary), maxLines: 3),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        if (value != null) ...[
          const SizedBox(width: 12),
          Text(value!, style: AppText.bodyText(valueColor, size: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (chevron) ...[const SizedBox(width: 8), GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary)],
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Tokens.minTarget - 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            head,
            if (below != null) ...[const SizedBox(height: 12), below!],
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return Pressable(onTap: onTap, child: body);
  }
}

/// Text tabs with a champagne underline — no Material segmented control.
class SegmentedTextTabs extends StatelessWidget {
  const SegmentedTextTabs({super.key, required this.options, required this.value, required this.onChanged});

  /// (value, label) pairs, left to right.
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          const Positioned(left: 0, right: 0, bottom: 0, child: Hairline()),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: o.$1 == value,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(o.$1),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                o.$2,
                                style: AppText.button(o.$1 == value ? c.textPrimary : c.textTertiary, size: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: Tokens.medium,
                            curve: Curves.easeOutCubic,
                            height: 2,
                            color: o.$1 == value ? c.accent : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Brand glyph, app name and version — and the hidden seven-tap unlock.
class _Footer extends StatelessWidget {
  const _Footer({required this.version, required this.onTap});
  final String version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(Glyph.chevron, size: 28, color: c.textQuaternary),
            const SizedBox(height: 10),
            Text(kAppName, style: AppText.title(c.textTertiary)),
            const SizedBox(height: 4),
            Text(version, style: AppText.caption(c.textQuaternary, size: 12)),
          ],
        ),
      ),
    );
  }
}
