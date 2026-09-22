import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/settings.dart';
import 'features/recording/recording_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [settingsProvider.overrideWith(() => SettingsNotifier(prefs))],
  );
  // Crash safety (docs/PLAN.md §6): if a day is still active and its last fix
  // is recent — or iOS relaunched us via the location watchdog — resume the
  // stream before the first frame. Older days surface as the recovery card.
  try {
    await container.read(recordingControllerProvider.notifier).resumeIfActive();
  } catch (_) {
    // never block launch on recovery problems
  }
  runApp(UncontrolledProviderScope(container: container, child: const SchwungApp()));
}
