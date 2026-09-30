import 'package:flutter/widgets.dart';

import '../../app/l10n/app_locale.dart';
import '../../data/sync/profile_repair.dart' show kFallbackDisplayName;

/// The name a rider is shown under (SOC-NAME-FALLBACK).
///
/// Models keep `display_name` as the server delivers it — nullable, blank
/// folded to null by `parseDisplayName` (social_models.dart) — and only the UI resolves the
/// fallback, in the app
/// language: 'Skifahrer' / 'Skier'. The server column default
/// ([kFallbackDisplayName], also written by profile repair when Apple hides
/// the name) counts as "no name", so a nameless rider reads 'Skier' in
/// English too. Any other name comes back trimmed.
String riderName(BuildContext context, String? displayName) => riderNameFor(AppLocale.of(context), displayName);

/// [riderName] without a context — for strings and share texts that only
/// hold an [AppLocale].
String riderNameFor(AppLocale locale, String? displayName) {
  final name = displayName?.trim();
  if (name == null || name.isEmpty || name == kFallbackDisplayName) return locale.pick(de: 'Skifahrer', en: 'Skier');
  return name;
}
