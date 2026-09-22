import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small app settings in shared_preferences. Lead-owned; features read `settingsProvider`.
class Settings {
  const Settings({
    this.locale = 'system',
    this.onboardingDone = false,
    this.notificationsOptIn = false,
    this.notificationsAsked = false,
    this.lastResortId,
    this.diagnosticsUnlocked = false,
    this.seasonGoalHm = 20000,
    this.appearance = 'dark',
  });

  /// 'system' | 'de' | 'en'
  final String locale;
  final bool onboardingDone;
  final bool notificationsOptIn;
  final bool notificationsAsked;
  final String? lastResortId;
  final bool diagnosticsUnlocked;
  /// Season goal in vertical metres (onboarding step 2).
  final int seasonGoalHm;
  /// 'system' | 'light' | 'dark' — dark is the product default (docs/DESIGN.md).
  final String appearance;

  ThemeMode get themeMode => switch (appearance) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  Settings copyWith({
    String? locale, bool? onboardingDone, bool? notificationsOptIn, bool? notificationsAsked,
    String? lastResortId, bool? diagnosticsUnlocked, int? seasonGoalHm, String? appearance,
  }) => Settings(
        locale: locale ?? this.locale,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        notificationsOptIn: notificationsOptIn ?? this.notificationsOptIn,
        notificationsAsked: notificationsAsked ?? this.notificationsAsked,
        lastResortId: lastResortId ?? this.lastResortId,
        diagnosticsUnlocked: diagnosticsUnlocked ?? this.diagnosticsUnlocked,
        seasonGoalHm: seasonGoalHm ?? this.seasonGoalHm,
        appearance: appearance ?? this.appearance,
      );

  static Settings fromPrefs(SharedPreferences p) => Settings(
        locale: p.getString('locale') ?? 'system',
        onboardingDone: p.getBool('onboardingDone') ?? false,
        notificationsOptIn: p.getBool('notificationsOptIn') ?? false,
        notificationsAsked: p.getBool('notificationsAsked') ?? false,
        lastResortId: p.getString('lastResortId'),
        diagnosticsUnlocked: p.getBool('diagnosticsUnlocked') ?? false,
        seasonGoalHm: p.getInt('seasonGoalHm') ?? 20000,
        appearance: p.getString('appearance') ?? 'dark',
      );
}

class SettingsNotifier extends Notifier<Settings> {
  SettingsNotifier(this._prefs, {Settings? initial}) : _initial = initial; // ignore: prefer_initializing_formals
  final SharedPreferences? _prefs;
  final Settings? _initial;

  @override
  Settings build() => _initial ?? (_prefs == null ? const Settings() : Settings.fromPrefs(_prefs));

  Future<void> update(Settings Function(Settings) fn) async {
    final next = fn(state);
    state = next;
    final p = _prefs;
    if (p == null) return;
    await p.setString('locale', next.locale);
    await p.setBool('onboardingDone', next.onboardingDone);
    await p.setBool('notificationsOptIn', next.notificationsOptIn);
    await p.setBool('notificationsAsked', next.notificationsAsked);
    if (next.lastResortId != null) {
      await p.setString('lastResortId', next.lastResortId!);
    } else {
      await p.remove('lastResortId');
    }
    await p.setBool('diagnosticsUnlocked', next.diagnosticsUnlocked);
    await p.setInt('seasonGoalHm', next.seasonGoalHm);
    await p.setString('appearance', next.appearance);
  }

  Future<void> setLocale(String v) => update((s) => s.copyWith(locale: v));
  Future<void> setOnboardingDone() => update((s) => s.copyWith(onboardingDone: true));
  Future<void> setNotifications({required bool optIn}) =>
      update((s) => s.copyWith(notificationsOptIn: optIn, notificationsAsked: true));
  Future<void> setSeasonGoal(int hm) => update((s) => s.copyWith(seasonGoalHm: hm));
  Future<void> setLastResort(String? id) => update((s) => id == null ? s : s.copyWith(lastResortId: id));
  Future<void> setDiagnosticsUnlocked() => update((s) => s.copyWith(diagnosticsUnlocked: true));
  Future<void> setAppearance(String v) => update((s) => s.copyWith(appearance: v));
  Future<void> clearLastResort() => update((s) => Settings(
        locale: s.locale, onboardingDone: s.onboardingDone, notificationsOptIn: s.notificationsOptIn,
        notificationsAsked: s.notificationsAsked, lastResortId: null, diagnosticsUnlocked: s.diagnosticsUnlocked, seasonGoalHm: s.seasonGoalHm,
        appearance: s.appearance,
      ));
}

/// Overridden in main() with the real SharedPreferences instance.
final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(() => SettingsNotifier(null));

/// True while a day is being recorded. Set by the RecordingController (WP-05);
/// read by the tab bar dot and anything that must not import features/.
class IsRecordingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final isRecordingProvider = NotifierProvider<IsRecordingNotifier, bool>(IsRecordingNotifier.new);
