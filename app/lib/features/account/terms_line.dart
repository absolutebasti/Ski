import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/brand.dart';
import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';

/// Under every switch that makes a profile public (App Review 1.2): the rider
/// agrees to the terms — zero tolerance for offensive names and photos.
class TermsLine extends StatefulWidget {
  const TermsLine({super.key});

  @override
  State<TermsLine> createState() => _TermsLineState();
}

class _TermsLineState extends State<TermsLine> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()..onTap = _open;

  Future<void> _open() => launchUrl(Uri.parse(kTermsUrl), mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final base = AppText.caption(c.textTertiary);
    final (pre, link, post) = l.isGerman
        ? ('Mit dem Einschalten akzeptierst du die ', 'Nutzungsbedingungen', ': null Toleranz für beleidigende Namen und Bilder.')
        : ('By switching this on you accept the ', 'terms of use', ': zero tolerance for offensive names and photos.');
    return Semantics(
      link: true,
      label: '$pre$link$post',
      excludeSemantics: true,
      onTap: _open,
      child: Text.rich(
        TextSpan(style: base, children: [
          TextSpan(text: pre),
          TextSpan(text: link, style: base.copyWith(color: c.textSecondary, decoration: TextDecoration.underline), recognizer: _tap),
          TextSpan(text: post),
        ]),
      ),
    );
  }
}
