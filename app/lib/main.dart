import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/demo.dart';
import 'core/settings.dart';
import 'data/supabase/supabase_client.dart';
import 'data/sync/sync_service.dart';
import 'features/recording/recording_controller.dart';
import 'platform/providers.dart';
import 'platform/watch/watch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  await SupabaseBoot.init(); // backend is optional; the app is local-first
  await Demo.load(); // debug-only launch switches (demo.json / dart-define)
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(prefs)),
      heartRateSourceProvider.overrideWith((ref) => WatchHeartRateSource(ref.watch(watchTransportProvider))),
      if (kDebugMode && Demo.seedDays) permissionServiceProvider.overrideWithValue(DemoPermissionService()),
    ],
  );
  // Apple Watch bridge follows the recording state; attach before resume so a
  // relaunched day reaches the wrist.
  container.read(watchBridgeProvider.notifier).attach();
  container.read(autoSyncProvider); // backend sync loop (no-op without a signed-in user)
  await Demo.apply(container); // debug-only launch switches, no-op in release
  // Crash safety (docs/PLAN.md §6): if a day is still active and its last fix
  // is recent — or iOS relaunched us via the location watchdog — resume the
  // stream before the first frame. Older days surface as the recovery card.
  try {
    await container.read(recordingControllerProvider.notifier).resumeIfActive();
  } catch (_) {
    // never block launch on recovery problems
  }
  runApp(UncontrolledProviderScope(container: container, child: const SlopeTrackApp()));
}
