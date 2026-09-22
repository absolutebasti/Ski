import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/settings.dart';
import 'brand.dart';
import 'l10n/app_locale.dart';
import 'router.dart';
import 'shell.dart';
import 'theme/theme.dart';

class DroplineApp extends ConsumerStatefulWidget {
  const DroplineApp({super.key});

  @override
  ConsumerState<DroplineApp> createState() => _DroplineAppState();
}

class _DroplineAppState extends ConsumerState<DroplineApp> {
  /// Read once: OnboardingFlow navigates to RootShell itself, so `home` must
  /// not flip underneath it when the flag is written.
  late final bool _onboardingDone = ref.read(settingsProvider).onboardingDone;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = AppLocale.fromSetting(settings.locale);
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode, // dark by default (docs/DESIGN.md); Einstellungen › Erscheinungsbild
      locale: locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, supported) {
        final resolved = locale ??
            supported.firstWhere((s) => s.languageCode == device?.languageCode, orElse: () => const Locale('de'));
        Intl.defaultLocale = resolved.languageCode;
        return resolved;
      },
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: _onboardingDone ? const RootShell() : AppRouter.onboarding(),
    );
  }
}
