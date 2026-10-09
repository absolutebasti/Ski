import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../achievements/achievement_models.dart';
import '../achievements/achievements_strings.dart';
import '../achievements/ui/level_ring.dart' show tierColor;
import 'share_card.dart';
import 'share_card_data.dart';
import 'share_strings.dart';
import '../social/rider_name.dart';

/// Renders the share card for any [ShareCardData] at the requested
/// [ShareFormat]. `day` is the existing [ShareCard]; medal, level, season,
/// rank and duel reuse its graphite / champagne-radial / grain system
/// (docs/DESIGN.md §5 "Share Card"). Always dark, independent of the theme.
///
/// [showRider] puts the mascot (rider-celebrate) on the medal and level cards.
/// Golden tests switch it off so the PNG stays deterministic without asset
/// decoding.
class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key, required this.data, this.format = ShareFormat.portrait, this.showRider = true});
  final ShareCardData data;
  final ShareFormat format;
  final bool showRider;

  /// Mascot pose used on the medal and level cards.
  static const riderPose = 'celebrate';

  @override
  Widget build(BuildContext context) => switch (data) {
    DayCardData(:final detail) => ShareCard(detail: detail, format: format),
    final MedalCardData d => MedalShareCard(data: d, format: format, showRider: showRider),
    final LevelCardData d => LevelShareCard(data: d, format: format, showRider: showRider),
    final SeasonCardData d => SeasonShareCard(data: d, format: format),
    final RankCardData d => RankShareCard(data: d, format: format),
    final DuelCardData d => DuelShareCard(data: d, format: format),
  };
}

/// Per-format sizes. Portrait is the reference; square tightens, story grows
/// and keeps the wordmark 120 px above the bottom edge (IG safe area).
class _Spec {
  const _Spec(this.format);
  final ShareFormat format;

  T pick<T>(T portrait, T square, T story) => switch (format) {
    ShareFormat.portrait => portrait,
    ShareFormat.square => square,
    ShareFormat.story => story,
  };

  double get ring => pick(320, 260, 320);
  double get title => pick(88, 72, 96);
  double get numeral => pick(120, 100, 136);
  double get hero => pick(160, 128, 180);
  double get stat => pick(72, 60, 80);
  double get footer => pick(200, 120, 260);
  double get podium => pick(300, 220, 360);
  double get duelRow => pick(160, 124, 190);
  double get bottomPad => pick(ShareCard.pad, ShareCard.pad, 120);
}

/// Graphite field, champagne radial top-right, grain, padding 72.
class _Frame extends StatelessWidget {
  const _Frame({required this.format, required this.child});
  final ShareFormat format;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final size = format.size;
    final spec = _Spec(format);
    return MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: 1, textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Tokens.bg),
          child: Stack(
            children: [
              Positioned(
                right: -180,
                top: -180,
                width: 700,
                height: 700,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [c.accent.withValues(alpha: 0.08), c.accent.withValues(alpha: 0)]),
                  ),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: const GrainPainter(), isComplex: true)),
              Padding(padding: EdgeInsets.fromLTRB(ShareCard.pad, ShareCard.pad, ShareCard.pad, spec.bottomPad), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overline 22 secondary + one-line title 44 cream (scaled down, never clipped).
class _Header extends StatelessWidget {
  const _Header({required this.overline, required this.title});
  final String overline;
  final String title;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(overline.overline, style: AppText.label(c.textSecondary, size: 22), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        _OneLine(title, style: AppText.headline(c.textPrimary, size: 44)),
      ],
    );
  }
}

/// Single line of text that scales down instead of clipping or wrapping.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    ),
  );
}

/// Overline above a numeral with a baseline-aligned unit (docs/DESIGN.md §3).
class _Numeral extends StatelessWidget {
  const _Numeral({required this.label, required this.value, required this.size, this.unit, this.color, this.trailing});
  final String label;
  final String value;
  final String? unit;
  final double size;
  final Color? color;

  /// Secondary text after the unit ('von 128').
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final unitSize = (size * 0.28).clamp(22.0, 44.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.overline, style: AppText.label(c.textSecondary, size: 22), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: AppText.numXxl(color ?? c.textPrimary).copyWith(fontSize: size), maxLines: 1, softWrap: false),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 10),
              Text(
                unit!,
                style: AppText.unit(c.textSecondary, size: unitSize).copyWith(fontSize: unitSize),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 18), Text(trailing!, style: AppText.bodyText(c.textSecondary, size: unitSize))],
          ],
        ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => SizedBox(height: 0.5, child: ColoredBox(color: Colors.white.withValues(alpha: 0.10)));
}

/// Bottom row: optional mascot left, wordmark right. Always the last block.
class _Footer extends StatelessWidget {
  const _Footer({required this.height, this.rider = false});
  final double height;
  final bool rider;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (rider) Rider(pose: ShareCardView.riderPose, size: height, alignment: Alignment.bottomLeft),
        const Spacer(),
        const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomRight, child: Wordmark()),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Medal
// ---------------------------------------------------------------------------

/// Tier ring 320 px, metric overline, title, threshold numeral, earned date.
/// The ring is the card's single accent element; numerals stay cream.
class MedalShareCard extends StatelessWidget {
  const MedalShareCard({super.key, required this.data, this.format = ShareFormat.portrait, this.showRider = true});
  final MedalCardData data;
  final ShareFormat format;
  final bool showRider;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final a = AchievementsStrings(l);
    final spec = _Spec(format);
    final def = data.def;
    final (value, unit) = a.threshold(def);
    return _Frame(
      format: format,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            overline: s.medal,
            title: Fmt.dateLong(data.earnedAt, locale: l.code),
          ),
          const Spacer(flex: 3),
          Center(
            child: BigTierRing(tier: def.tier, size: spec.ring),
          ),
          const Spacer(flex: 3),
          Text(a.metric(def.metric).overline, style: AppText.label(c.textSecondary, size: 22), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),
          _OneLine(a.medalTitle(def), style: AppText.headline(c.textPrimary, size: spec.title)),
          const SizedBox(height: 28),
          _Numeral(label: a.tier(def.tier), value: value, unit: unit, size: spec.numeral),
          const SizedBox(height: 28),
          const _Hairline(),
          const SizedBox(height: 24),
          _Footer(height: spec.footer, rider: showRider),
        ],
      ),
    );
  }
}

/// The tier ring at card scale: solid disc in the tier colour with an ink
/// core; the black tier is an ink disc with a champagne ring.
class BigTierRing extends StatelessWidget {
  const BigTierRing({super.key, required this.tier, required this.size});
  final MedalTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final colour = tierColor(c, tier);
    final black = tier == MedalTier.black;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colour,
        border: Border.all(color: black ? c.accent : colour, width: black ? size / 40 : 0),
      ),
      child: Center(
        child: Container(
          width: size * 0.28,
          height: size * 0.28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: black ? c.accent : c.ink),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level
// ---------------------------------------------------------------------------

/// Level ring 320 px with the progress arc (accent), 'Level 4 · Carver',
/// lifetime km and the next-level line.
class LevelShareCard extends StatelessWidget {
  const LevelShareCard({super.key, required this.data, this.format = ShareFormat.portrait, this.showRider = true});
  final LevelCardData data;
  final ShareFormat format;
  final bool showRider;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final spec = _Spec(format);
    final level = data.level;
    final title = l.pick(de: level.titleDe, en: level.titleEn);
    final nextAt = level.nextAtM;
    final next = nextAt == null ? s.topLevel : s.nextLevel((nextAt - level.distanceM).clamp(0, double.infinity), level.index + 1);
    return _Frame(
      format: format,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(overline: s.level, title: '${s.level} ${level.index} · $title'),
          const Spacer(flex: 3),
          Center(
            child: BigLevelRing(index: level.index, progress: nextAt == null ? 1 : level.progress, size: spec.ring),
          ),
          const Spacer(flex: 3),
          _OneLine(title, style: AppText.headline(c.textPrimary, size: spec.title)),
          const SizedBox(height: 28),
          _Numeral(
            label: s.skiKilometres,
            value: Fmt.km(level.distanceM, decimals: 0, locale: l.code),
            unit: s.unitKm,
            size: spec.numeral,
          ),
          const SizedBox(height: 18),
          Text(next, style: AppText.bodyText(c.textSecondary, size: 30), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 28),
          const _Hairline(),
          const SizedBox(height: 24),
          _Footer(height: spec.footer, rider: showRider),
        ],
      ),
    );
  }
}

/// The level ring at card scale: champagne arc on a dim track, ink disc,
/// the level index as a large cream numeral.
class BigLevelRing extends StatelessWidget {
  const BigLevelRing({super.key, required this.index, required this.progress, required this.size});
  final int index;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final stroke = size / 14;
    final inner = size - stroke * 2 - size * 0.06;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress.clamp(0.0, 1.0), arc: c.accent, track: c.accent.withValues(alpha: 0.16), stroke: stroke),
        child: Center(
          child: Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$index', style: AppText.numXxl(c.textPrimary).copyWith(fontSize: size * 0.42)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.arc, required this.track, required this.stroke});
  final double progress;
  final Color arc;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.arc != arc || old.track != track || old.stroke != stroke;
}

// ---------------------------------------------------------------------------
// Season
// ---------------------------------------------------------------------------

/// 'Saison 2026/27 · 12 Skitage' and four numerals: vertical as the champagne
/// hero, runs / km / top speed in cream below.
class SeasonShareCard extends StatelessWidget {
  const SeasonShareCard({super.key, required this.data, this.format = ShareFormat.portrait});
  final SeasonCardData data;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final spec = _Spec(format);
    return _Frame(
      format: format,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(overline: s.season(data.seasonKey), title: s.skiDays(data.dayCount)),
          const Spacer(flex: 2),
          _Numeral(
            label: s.vertical,
            value: Fmt.metres(data.dropM, locale: l.code),
            unit: s.unitHm,
            size: spec.hero,
            color: c.accent,
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: _Numeral(label: s.runs, value: '${data.runCount}', size: spec.stat),
              ),
              Expanded(
                flex: 4,
                child: _Numeral(
                  label: s.skiKm,
                  value: Fmt.km(data.skiDistanceM, decimals: 0, locale: l.code),
                  unit: s.unitKm,
                  size: spec.stat,
                ),
              ),
              Expanded(
                flex: 4,
                child: _Numeral(
                  label: s.topSpeed,
                  value: Fmt.kmh(data.maxSpeedMs, locale: l.code),
                  unit: s.unitKmh,
                  size: spec.stat,
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          const _Hairline(),
          const SizedBox(height: 24),
          _Footer(height: spec.footer * 0.5),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rank
// ---------------------------------------------------------------------------

/// Mini podium (own step champagne) + 'Platz 3 in Kitzbühel · Saison 26/27'
/// + the own value.
class RankShareCard extends StatelessWidget {
  const RankShareCard({super.key, required this.data, this.format = ShareFormat.portrait});
  final RankCardData data;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final spec = _Spec(format);
    final period = data.periodLabel ?? s.seasonShort(data.seasonKey);
    final (value, unit) = s.metricValue(data.metric, data.value);
    return _Frame(
      format: format,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(overline: s.leaderboard, title: s.rankLine(data.rank, data.scopeName, period)),
          const Spacer(flex: 2),
          SizedBox(
            height: spec.podium,
            width: double.infinity,
            child: CustomPaint(
              painter: PodiumPainter(rank: data.rank, colors: AppColors.dark),
            ),
          ),
          const Spacer(flex: 2),
          _Numeral(label: s.place, value: '${data.rank}', size: spec.hero, trailing: data.total > 0 ? s.ofTotal(data.total) : null),
          const SizedBox(height: 36),
          _Numeral(label: s.metricLabel(data.metric), value: value, unit: unit, size: spec.stat),
          const Spacer(),
          const _Hairline(),
          const SizedBox(height: 24),
          _Footer(height: spec.footer * 0.5),
        ],
      ),
    );
  }
}

/// Three steps (2 · 1 · 3); the own step is champagne. Ranks beyond the
/// podium add a low fourth step carrying the own rank.
class PodiumPainter extends CustomPainter {
  const PodiumPainter({required this.rank, required this.colors});
  final int rank;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final extra = rank > 3;
    final slots = extra ? <int>[2, 1, 3, rank] : <int>[2, 1, 3];
    final gap = size.width * 0.02;
    final w = (size.width - gap * (slots.length - 1)) / slots.length;
    final step = Paint()..color = colors.hairlineStrong;
    final own = Paint()..color = colors.accent;
    for (var i = 0; i < slots.length; i++) {
      final r = slots[i];
      final hFactor = switch (r) {
        1 => 1.0,
        2 => 0.72,
        3 => 0.52,
        _ => 0.30,
      };
      final h = size.height * hFactor;
      final rect = Rect.fromLTWH(i * (w + gap), size.height - h, w, h);
      final radius = Radius.circular(math.min(24, w * 0.12));
      final mine = r == rank;
      canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius), mine ? own : step);
      final label = TextPainter(
        text: TextSpan(
          text: '$r',
          style: AppText.numXl(mine ? colors.onAccent : colors.textPrimary).copyWith(fontSize: math.min(64, h * 0.5)),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: w);
      label.paint(canvas, Offset(rect.left + (w - label.width) / 2, rect.top + math.min(28, h * 0.18)));
    }
  }

  @override
  bool shouldRepaint(PodiumPainter old) => old.rank != rank || old.colors != colors;
}

// ---------------------------------------------------------------------------
// Duel
// ---------------------------------------------------------------------------

/// Three rows sorted by vertical, the winner's rank numeral ringed in
/// champagne (the single accent), the own row tagged 'Du'.
class DuelShareCard extends StatelessWidget {
  const DuelShareCard({super.key, required this.data, this.format = ShareFormat.portrait});
  final DuelCardData data;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = ShareStrings(l);
    final spec = _Spec(format);
    final board = data.board;
    final date = Fmt.dateLong(data.day, locale: l.code);
    final title = data.resortName == null ? date : '$date · ${data.resortName}';
    final overline = data.name == null ? s.duel : '${s.duel} · ${data.name}';
    return _Frame(
      format: format,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(overline: overline, title: title),
          const Spacer(flex: 2),
          for (var i = 0; i < board.length; i++) ...[
            if (i > 0) const _Hairline(),
            _DuelRow(place: i + 1, row: board[i], winner: i == 0, height: spec.duelRow, strings: s, locale: l),
          ],
          const Spacer(flex: 3),
          const _Hairline(),
          const SizedBox(height: 24),
          _Footer(height: spec.footer * 0.5),
        ],
      ),
    );
  }
}

class _DuelRow extends StatelessWidget {
  const _DuelRow({required this.place, required this.row, required this.winner, required this.height, required this.strings, required this.locale});
  final int place;
  final DuelCardRow row;
  final bool winner;
  final double height;
  final ShareStrings strings;
  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.dark;
    final ring = height * 0.6;
    final numeral = height * 0.55;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: ring,
            height: ring,
            alignment: Alignment.center,
            decoration: winner
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.accent, width: ring / 20),
                  )
                : null,
            child: Text('$place', style: AppText.numL(c.textPrimary).copyWith(fontSize: ring * 0.5)),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (row.isMe) ...[Text(strings.you.overline, style: AppText.label(c.textSecondary, size: 20)), const SizedBox(height: 6)],
                _OneLine(riderNameFor(locale, row.displayName), style: AppText.headline(c.textPrimary, size: height * 0.27)),
                const SizedBox(height: 8),
                Text(
                  strings.duelCaption(row.runCount, Fmt.kmh(row.maxSpeedMs, locale: locale.code)),
                  style: AppText.bodyText(c.textSecondary, size: height * 0.16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Fmt.metres(row.dropM, locale: locale.code),
                style: AppText.numXxl(c.textPrimary).copyWith(fontSize: numeral),
              ),
              const SizedBox(width: 8),
              Text(strings.unitHm, style: AppText.unit(c.textSecondary, size: 26).copyWith(fontSize: numeral * 0.28)),
            ],
          ),
        ],
      ),
    );
  }
}
