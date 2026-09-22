import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import 'days_strings.dart';

/// One finished ski day in the Tage list: date, resort, the three numbers,
/// the pre-rendered map thumbnail and a record badge.
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.day, this.onTap, this.onLongPress});

  final DaySummary day;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    final s = DaysStrings.of(context);
    final st = day.stats;
    final isPb = day.isTopSpeedPb || day.isBiggestDayPb;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        onLongPress: onLongPress,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          Fmt.dateShort(day.startedAt, locale: l.code),
                          style: AppText.title(c.textPrimary, size: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPb) ...[const SizedBox(width: 8), StateChip(text: s.pbBadge, tone: ChipTone.accent, icon: Icons.star_rounded)],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day.resortName ?? s.freeTerrain,
                    style: AppText.bodyText(c.textSecondary, size: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.dayLine(
                      runs: st.runCount,
                      dropM: Fmt.metres(st.dropM, locale: l.code),
                      kmh: Fmt.kmh(st.maxSpeedMs, locale: l.code),
                    ),
                    style: AppText.label(c.textPrimary, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DayThumb(path: day.mapThumbPath),
          ],
        ),
      ),
    );
  }
}

/// The 600×400 PNG written at End, or a quiet placeholder while it is missing.
class DayThumb extends StatefulWidget {
  const DayThumb({super.key, required this.path, this.width = 108});
  final String? path;
  final double width;

  @override
  State<DayThumb> createState() => _DayThumbState();
}

class _DayThumbState extends State<DayThumb> {
  late bool _exists = _check();

  bool _check() {
    final p = widget.path;
    if (p == null || p.isEmpty) return false;
    try {
      return File(p).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  @override
  void didUpdateWidget(DayThumb old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _exists = _check();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = widget.width / 1.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radius - 4),
      child: SizedBox(
        width: widget.width,
        height: height,
        child: _exists
            ? Image.file(
                File(widget.path!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _placeholder(c),
              )
            : _placeholder(c),
      ),
    );
  }

  Widget _placeholder(AppColors c) => ColoredBox(
        color: c.elevated,
        child: Center(child: Icon(Icons.downhill_skiing_rounded, size: 20, color: c.textTertiary)),
      );
}
