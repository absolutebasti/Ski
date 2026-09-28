import 'package:flutter/widgets.dart';

import '../../../app/l10n/app_locale.dart';
import 'moderation_strings.dart';
import 'name_rules.dart';

/// The display-name rule as a form validator: null = fine, otherwise the
/// localised hint the Konto / onboarding name field shows inline.
///
///   final hint = DisplayNamePolicy.validate(text, locale: AppLocale.of(context));
///
/// Pure rule without copy: [NameRules.check].
class DisplayNamePolicy {
  const DisplayNamePolicy._();

  static const int maxLength = NameRules.maxLength;

  /// German by default; pass the widget's [AppLocale] for the right language.
  static String? validate(String raw, {AppLocale locale = const AppLocale(Locale('de'))}) {
    final check = NameRules.check(raw);
    if (check.isOk) return null;
    return ModerationStrings(locale).nameRejected(check.reason!);
  }

  /// The name as it should be stored (trimmed, single spaces), or null when
  /// the rule rejects it.
  static String? normalized(String raw) => NameRules.check(raw).name;
}
