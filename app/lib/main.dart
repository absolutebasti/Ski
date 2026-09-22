import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  // WP-12: before runApp, ask RecoveryService whether an active day exists and
  // resume the location stream headlessly (see docs/PLAN.md §6, crash safety).
  runApp(
    ProviderScope(
      overrides: [settingsProvider.overrideWith(() => SettingsNotifier(prefs))],
      child: const SchwungApp(),
    ),
  );
}
