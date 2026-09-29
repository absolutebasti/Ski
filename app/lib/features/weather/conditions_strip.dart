import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/weather/weather_provider.dart';
import '../../data/weather/weather_report.dart';
import '../../data/weather/wmo.dart';
import 'weather_strings.dart';

/// Bedingungen strip (docs/DESIGN.md §Heute — idle, row 2): weather glyph 22
/// ice plus up to three value/overline pairs — '−4° / BERG', '12 cm /
/// NEUSCHNEE', 'Sonnig / HEUTE'. The header caption already names the
/// resort, so the strip never repeats it.
///
/// Hidden (an empty box) while there is no snapshot, or when there is no
/// snow data and it is warmer than 10 °C — a summer strip says nothing.
class ConditionsStrip extends ConsumerWidget {
  const ConditionsStrip({super.key, required this.resort});
  final Resort resort;

  /// Warmer than this with no snow → nothing worth a card.
  static const double warmC = 10;

  /// Whether the strip has anything to say for [w].
  static bool shouldShow(WeatherSnapshot? w) {
    if (w == null) return false;
    final r = WeatherReport.from(w);
    if (!r.hasSnowData && (r.tempC ?? 0) > warmC) return false;
    return pairs(w, const AppLocale(Locale('de'))).isNotEmpty;
  }

  /// (value, overline) pairs in strip order; the overline is upper-cased by MetricStrip.
  static List<(String, String)> pairs(WeatherSnapshot? w, AppLocale l) {
    if (w == null) return const [];
    final s = WeatherStrings(l);
    final r = WeatherReport.from(w);
    final out = <(String, String)>[];
    final t = r.tempC;
    if (t != null) out.add((Fmt.temp(t), r.tempSummitC != null ? s.summit : s.base));
    final fresh = r.freshSnowCm;
    final depth = r.snowDepthCm;
    if (fresh != null && fresh >= 1) {
      out.add((s.cm(fresh.round()), s.freshSnow));
    } else if (depth != null && depth >= 1) {
      out.add((s.cm(depth.round()), s.snowDepth));
    }
    final word = wmoWord(wmoBucket(r.wmoCode), de: l.isGerman);
    if (word.isNotEmpty) out.add((word, s.today));
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(weatherProvider(resort)).asData?.value;
    if (!shouldShow(w)) return const SizedBox.shrink();
    return ConditionsStripBody(weather: w!);
  }
}

/// The strip itself for a known snapshot — pure, so goldens need no provider.
class ConditionsStripBody extends StatelessWidget {
  const ConditionsStripBody({super.key, required this.weather});
  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = WeatherStrings.of(context);
    final items = ConditionsStrip.pairs(weather, l);
    return Semantics(
      label: s.conditions,
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(wmoIcon(wmoBucket(weather.wmoCode)), size: 22, color: c.ice),
            const SizedBox(width: 14),
            Expanded(child: MetricStrip(size: 17, items: items)),
          ],
        ),
      ),
    );
  }
}
