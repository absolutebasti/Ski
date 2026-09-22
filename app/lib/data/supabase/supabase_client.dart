import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend endpoint. The publishable key is a public client key by design;
/// override both with --dart-define(-from-file) for other environments.
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://svzmmpzevmpodcelzvit.supabase.co');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_CdmyIpZ_2-wpzQ7cm5yGSA_8SouIUAn');

/// Initialised once in main(); the app works fully without it (local-first).
class SupabaseBoot {
  const SupabaseBoot._();
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready || kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty) return;
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        publishableKey: kSupabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      );
      _ready = true;
    } catch (e) {
      debugPrint('supabase init failed: $e');
    }
  }
}

/// Null when the backend is not configured or failed to initialise.
final supabaseProvider = Provider<SupabaseClient?>((ref) => SupabaseBoot.isReady ? Supabase.instance.client : null);
