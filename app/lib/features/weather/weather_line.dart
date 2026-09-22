import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/core.dart';
import '../../data/weather/weather_provider.dart';
import '../../data/weather/wmo.dart';

/// 'Kitzbühel · −4° Berg · 12 cm Neuschnee' — omits whatever is missing.
class WeatherLine extends ConsumerWidget {
  const WeatherLine({super.key, required this.resort});
  final Resort resort;

  static String format(Resort r, WeatherSnapshot? w, {required bool de}) {
    final parts = <String>[r.name];
    if (w != null) {
      final t = w.tempSummitC ?? w.tempBaseC;
      if (t != null) parts.add('${Fmt.temp(t)} ${w.tempSummitC != null ? (de ? 'Berg' : 'summit') : (de ? 'Tal' : 'base')}');
      final snow = w.freshSnowCm;
      if (snow != null && snow >= 1) parts.add('${snow.round()} cm ${de ? 'Neuschnee' : 'fresh snow'}');
      final word = wmoWord(wmoBucket(w.wmoCode), de: de);
      if (word.isNotEmpty && (snow == null || snow < 1)) parts.add(word);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final w = ref.watch(weatherProvider(resort)).asData?.value;
    return Row(
      children: [
        Icon(wmoIcon(wmoBucket(w?.wmoCode)), size: 16, color: c.textSecondary),
        const SizedBox(width: 6),
        Flexible(child: Text(format(resort, w, de: l.isGerman), style: AppText.bodyText(c.textSecondary, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
