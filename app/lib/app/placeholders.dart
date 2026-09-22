import 'package:flutter/material.dart';

import 'l10n/app_locale.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';

/// Stub screens used until WP-12 wires the real features into router.dart.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.pad),
          child: Text(
            subtitle ?? l.pick(de: 'Kommt bald.', en: 'Coming soon.'),
            style: AppText.bodyText(c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
