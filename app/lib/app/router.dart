import 'package:flutter/material.dart';

import 'placeholders.dart';

/// Named routes. Feature screens are registered here by the lead (WP-12);
/// until then every entry points at a placeholder.
///
/// Contracts (constructors the router expects):
///   HeuteScreen()                      features/today
///   TageScreen()                       features/days
///   DayDetailScreen(dayId: String)     features/days
///   TagesbilanzScreen(dayId: String)   features/summary
///   OnboardingFlow()                   features/onboarding
///   MapSheet.show(context)             features/map      (modal, not a route)
///   SettingsSheet.show(context)        features/settings (modal, not a route)
class AppRoutes {
  const AppRoutes._();
  static const home = '/';
  static const onboarding = '/onboarding';
  static const day = '/day';
  static const summary = '/summary';
}

class AppRouter {
  const AppRouter._();

  static Widget heute() => const PlaceholderScreen('Heute');
  static Widget tage() => const PlaceholderScreen('Tage');
  static Widget onboarding() => const PlaceholderScreen('Onboarding');
  static Widget dayDetail(String dayId) => PlaceholderScreen('Tag', subtitle: dayId);
  static Widget summary(String dayId) => PlaceholderScreen('Tagesbilanz', subtitle: dayId);

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? AppRoutes.home);
    final seg = uri.pathSegments;
    Widget page;
    if (seg.isEmpty) {
      page = const SizedBox.shrink();
    } else if (seg.first == 'day' && seg.length == 2) {
      page = dayDetail(seg[1]);
    } else if (seg.first == 'summary' && seg.length == 2) {
      page = summary(seg[1]);
    } else if (seg.first == 'onboarding') {
      page = onboarding();
    } else {
      page = const PlaceholderScreen('404');
    }
    final fullscreen = seg.isNotEmpty && seg.first == 'summary';
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings, fullscreenDialog: fullscreen);
  }
}

/// Navigation helpers so features never build route strings.
class AppNav {
  const AppNav._();
  static Future<void> openDay(BuildContext context, String dayId) =>
      Navigator.of(context).pushNamed('${AppRoutes.day}/$dayId');
  static Future<void> openSummary(BuildContext context, String dayId) =>
      Navigator.of(context).pushNamed('${AppRoutes.summary}/$dayId');
}
