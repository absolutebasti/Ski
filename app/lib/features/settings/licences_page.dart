import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import 'settings_strings.dart';

/// Attribution the data and font licences require to be visible in-app:
/// OpenStreetMap (ODbL), OpenTopoMap and OpenSnowMap (CC BY-SA), Open-Meteo
/// (CC BY 4.0), Inter (OFL). Package licences via Flutter's licence registry.
class LicencesPage extends StatelessWidget {
  const LicencesPage({super.key});

  static const sources = <(String, String, String)>[
    ('OpenStreetMap', '© OpenStreetMap contributors · ODbL 1.0', 'openstreetmap.org/copyright'),
    ('OpenTopoMap', 'Kartendarstellung · CC BY-SA 3.0', 'opentopomap.org'),
    ('OpenSnowMap', 'Pisten und Lifte · CC BY-SA 2.0', 'opensnowmap.org'),
    ('Open-Meteo', 'Wetterdaten · CC BY 4.0', 'open-meteo.com'),
    ('Inter', 'Schrift von Rasmus Andersson · SIL Open Font License 1.1', 'rsms.me/inter'),
    ('Flutter', 'Google · BSD-3-Clause', 'flutter.dev'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = SettingsStrings.of(context);
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, 40),
            children: [
              ScreenHeader(
                title: s.licences,
                caption: s.licencesIntro,
                leading: HeaderButton(glyph: Glyph.back, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop()),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (i, src) in sources.indexed) ...[
                      if (i > 0) const Hairline(inset: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(src.$1, style: AppText.bodyStrong(c.textPrimary)),
                            const SizedBox(height: 2),
                            Text(src.$2, style: AppText.caption(c.textSecondary)),
                            Text(src.$3, style: AppText.caption(c.textTertiary)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SecondaryButton(label: s.packageLicences, onPressed: () => showLicensePage(context: context, applicationName: kAppName)),
            ],
          ),
        ),
      ),
    );
  }
}
