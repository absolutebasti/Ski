import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../onboarding/onboarding_countries.dart';
import 'account_strings.dart';

/// Full-height list of the team countries (onboarding grid first, then the
/// rest by localised name). Pops the alpha-2 code; null when dismissed.
class CountryPickerSheet {
  const CountryPickerSheet._();

  static Future<String?> show(BuildContext context, {String? selected}) => AppSheet.show<String>(
        context,
        title: AccountStrings.of(context).team,
        expand: true,
        builder: (_) => CountryPickerBody(selected: selected),
      );

  /// Grid countries in their onboarding order, then the others A–Z in [l].
  static List<TeamCountry> entries(AppLocale l) => [
        ...kTeamCountries,
        ...(List<TeamCountry>.of(kOtherCountries)..sort((a, b) => a.name(l).toLowerCase().compareTo(b.name(l).toLowerCase()))),
      ];
}

/// Exposed for tests; use [CountryPickerSheet.show] in the app.
class CountryPickerBody extends StatelessWidget {
  const CountryPickerBody({super.key, this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = AccountStrings.of(context);
    final list = CountryPickerSheet.entries(l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 12),
          child: Text(s.teamHint, style: AppText.caption(c.textSecondary)),
        ),
        const Hairline(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: Tokens.pad),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Hairline(inset: Tokens.pad + 44),
            itemBuilder: (context, i) {
              final k = list[i];
              final isSelected = k.code == selected?.toUpperCase();
              return Pressable(
                key: ValueKey('country-${k.code}'),
                onTap: () => Navigator.of(context).pop(k.code),
                child: Container(
                  height: Tokens.minTarget,
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.pad),
                  color: isSelected ? c.accentWash : Colors.transparent,
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text(k.flag, style: const TextStyle(fontSize: 22, height: 1))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          k.name(l),
                          style: AppText.bodyText(isSelected ? c.accent : c.textPrimary, size: 16, weight: isSelected ? FontWeight.w600 : FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(k.code, style: AppText.label(c.textTertiary)),
                      if (isSelected) ...[const SizedBox(width: 10), Icon(Icons.check_rounded, size: 18, color: c.accent)],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
