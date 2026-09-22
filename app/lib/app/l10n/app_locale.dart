import 'package:flutter/widgets.dart';

/// Two-language copy without codegen (v1). Usage:
///   final l = AppLocale.of(context);
///   Text(l.pick(de: 'Tag starten', en: 'Start day'))
/// Every feature keeps its strings in its own `<feature>_strings.dart`.
class AppLocale {
  const AppLocale(this.locale);
  final Locale locale;

  static const supported = [Locale('de'), Locale('en')];

  static AppLocale of(BuildContext context) => AppLocale(Localizations.localeOf(context));

  bool get isGerman => locale.languageCode != 'en';
  String get code => isGerman ? 'de' : 'en';

  String pick({required String de, required String en}) => isGerman ? de : en;

  /// Resolve the app locale from the settings value ('system' | 'de' | 'en').
  static Locale? fromSetting(String value) => switch (value) {
        'de' => const Locale('de'),
        'en' => const Locale('en'),
        _ => null,
      };
}
