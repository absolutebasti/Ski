import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// Result of [ResortPickerSheet.show]: `resort == null` means "Freies Gelände".
class ResortPick {
  const ResortPick(this.resort);
  final Resort? resort;
}

/// 'Skigebiet ändern': every bundled resort, nearest to the day's first point
/// first, with a name filter on top. Returns null when dismissed.
class ResortPickerSheet extends StatefulWidget {
  const ResortPickerSheet({super.key, required this.resorts, this.lat, this.lon, this.currentId});

  final List<Resort> resorts;
  /// The day's first point; without it the list is alphabetical.
  final double? lat;
  final double? lon;
  final String? currentId;

  /// How many rows the list shows at once (the filter narrows 4.9 k resorts).
  static const int maxRows = 40;

  static Future<ResortPick?> show(BuildContext context, {required List<Resort> resorts, double? lat, double? lon, String? currentId}) {
    final s = DaysStrings.of(context);
    return AppSheet.show<ResortPick>(
      context,
      title: s.changeResort,
      expand: true,
      builder: (_) => ResortPickerSheet(resorts: resorts, lat: lat, lon: lon, currentId: currentId),
    );
  }

  /// Resorts sorted by distance to (lat, lon) — alphabetical when unknown.
  static List<(Resort, double?)> ranked(List<Resort> resorts, {double? lat, double? lon}) {
    if (lat == null || lon == null) {
      final out = [for (final r in resorts) (r, null as double?)];
      out.sort((a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()));
      return out;
    }
    final out = [for (final r in resorts) (r, haversineM(lat, lon, r.lat, r.lon) as double?)];
    out.sort((a, b) => a.$2!.compareTo(b.$2!));
    return out;
  }

  @override
  State<ResortPickerSheet> createState() => _ResortPickerSheetState();
}

class _ResortPickerSheetState extends State<ResortPickerSheet> {
  late final List<(Resort, double?)> _ranked = ResortPickerSheet.ranked(widget.resorts, lat: widget.lat, lon: widget.lon);
  String _query = '';

  List<(Resort, double?)> get _visible {
    final q = _query.trim().toLowerCase();
    final it = q.isEmpty ? _ranked : _ranked.where((e) => e.$1.name.toLowerCase().contains(q));
    return it.take(ResortPickerSheet.maxRows).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final rows = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(color: c.surface, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: c.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('resort-picker-search'),
                    onChanged: (v) => setState(() => _query = v),
                    style: AppText.bodyText(c.textPrimary, size: 16),
                    cursorColor: c.accent,
                    decoration: InputDecoration.collapsed(hintText: s.searchResort, hintStyle: AppText.bodyText(c.textTertiary, size: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, Tokens.pad),
            children: [
              if (_query.trim().isEmpty)
                _Row(
                  title: s.freeTerrain,
                  caption: s.freeTerrainHint,
                  selected: widget.currentId == null,
                  onTap: () => Navigator.of(context).pop(const ResortPick(null)),
                ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(s.noResortMatch, style: AppText.bodyText(c.textSecondary, size: 15), textAlign: TextAlign.center),
                ),
              for (final (r, d) in rows)
                _Row(
                  title: r.name,
                  caption: [r.country, if (d != null) s.distanceKm(Fmt.km(d, locale: l.code, decimals: d < 10000 ? 1 : 0))].join(' · '),
                  selected: r.id == widget.currentId,
                  onTap: () => Navigator.of(context).pop(ResortPick(r)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.caption, required this.selected, required this.onTap});
  final String title;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: Tokens.minTarget,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline, width: c.hairlineWidth))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyStrong(selected ? c.accent : c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(caption, style: AppText.caption(c.textTertiary, size: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (selected) GlyphIcon(Glyph.crest, size: 16, color: c.accent) else GlyphIcon(Glyph.chevronRight, size: 16, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
