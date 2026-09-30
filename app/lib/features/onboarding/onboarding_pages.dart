import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../social/rider_name.dart';
import '../../app/l10n/app_locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/widgets.dart';
import '../../core/core.dart';
import '../../data/resorts/resort_repository.dart';
import '../../data/sync/auth_service.dart';
import 'onboarding_countries.dart';
import 'onboarding_strings.dart';
import 'route_hook.dart';

/// Shared scrolling skeleton for P2/P3: headline 22 + one line, then content.
/// P1 ([HookPage]) lays itself out as a centred Column instead.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.headline, required this.body, required this.child});
  final String headline;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 24),
      children: [
        Text(headline, style: AppText.headline(c.textPrimary)),
        const SizedBox(height: 10),
        Text(body, style: AppText.bodyText(c.textSecondary)),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

/// Page 1 — the hook: the rider stands over a card in which the route draws
/// itself and three numerals count up once.
///
/// Unlike P2/P3 this is a Column, not a ListView. The copy keeps its natural
/// height; rider + card take what is left between pager and dock (the route
/// band is the flexible part, [routeMin]..[routeMax]) and the whole block is
/// centred when a tall phone leaves more than that. The rider stands
/// [riderOverlap] pt into the card and grows from [riderMin] to [riderMax]
/// once the route has [routeComfort].
/// When even the minimum does not fit (small phone at a large text size) the
/// page scrolls with a fixed [routeScroll] band instead of squeezing.
/// Under reduced motion everything is drawn on the first frame.
class HookPage extends StatelessWidget {
  const HookPage({super.key, this.animate = true});
  final bool animate;

  static const int runs = 12;
  static const double dropM = 4120;
  static const double topKmh = 68;

  /// Rider height window (docs/BACKLOG-2.md UX-ONBOARDING-A11Y: 160–200 pt).
  static const double riderMax = 200;
  static const double riderMin = 160;
  /// How far the rider's boots stand into the card.
  static const double riderOverlap = 24;
  /// Route band: never flatter than [routeMin] (below that the page scrolls
  /// with [routeScroll]), the rider only grows once the band has
  /// [routeComfort], and it stops growing at [routeMax].
  static const double routeMin = 56;
  static const double routeComfort = 100;
  static const double routeMax = 240;
  static const double routeScroll = 130;
  static const double numeralSize = 30;

  static const EdgeInsets _pagePad = EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 24);
  static const EdgeInsets _cardPad = EdgeInsets.fromLTRB(20, 18, 20, 18);
  static const double _headGap = 10;
  static const double _cardGap = 22;
  static const double _routeGap = 14;

  static double _textHeight(BuildContext context, String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final h = painter.height;
    painter.dispose();
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    final headStyle = AppText.headlineL(c.textPrimary);
    final bodyStyle = AppText.bodyText(c.textSecondary);
    final copy = <Widget>[
      Text(s.p1Headline, style: headStyle),
      const SizedBox(height: _headGap),
      Text(s.p1Body, style: bodyStyle),
      const SizedBox(height: _cardGap),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        // Estimates: they pick the layout and split rider/route. The flex
        // layout below does the exact arithmetic, so a point off here only
        // moves a point between rider and route.
        final width = math.max(0.0, box.maxWidth - _pagePad.horizontal);
        final copyH = _textHeight(context, s.p1Headline, headStyle, width) + _headGap + _textHeight(context, s.p1Body, bodyStyle, width) + _cardGap;
        final cardFixed = _cardPad.vertical +
            _routeGap +
            _textHeight(context, s.p1Runs.overline, AppText.label(c.textTertiary), double.infinity) +
            8 +
            _textHeight(context, '0', HeroNumber.numeralStyle(c.textPrimary, numeralSize), double.infinity);
        final blockMin = riderMin - riderOverlap + cardFixed + routeMin;
        final fits = box.hasBoundedHeight && box.maxHeight >= _pagePad.vertical + copyH + blockMin;
        if (!fits) {
          return SingleChildScrollView(
            padding: _pagePad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...copy, _HookBlock(rider: riderMin, routeHeight: routeScroll, animate: animate)],
            ),
          );
        }
        return Padding(
          padding: _pagePad,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...copy,
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: riderMax - riderOverlap + cardFixed + routeMax),
                  child: LayoutBuilder(
                    builder: (context, block) {
                      final h = block.maxHeight;
                      final rider = (h + riderOverlap - cardFixed - routeComfort).clamp(riderMin, riderMax);
                      return SizedBox(height: h, child: _HookBlock(rider: rider, routeHeight: null, animate: animate));
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rider over the card. With a tight height the card fills what the rider
/// leaves ([routeHeight] null → the route band flexes); otherwise the card is
/// as tall as its [routeHeight] makes it.
class _HookBlock extends StatelessWidget {
  const _HookBlock({required this.rider, required this.routeHeight, required this.animate});
  final double rider;
  final double? routeHeight;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: rider - HookPage.riderOverlap),
          child: _HookCard(routeHeight: routeHeight, animate: animate),
        ),
        // Decorative: the headline already says what the page is about.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExcludeSemantics(child: Center(child: Rider(pose: 'hero', size: rider))),
        ),
      ],
    );
  }
}

/// The card under the rider: route band + three numerals that count up once
/// (or sit on their final value under reduced motion).
class _HookCard extends StatelessWidget {
  const _HookCard({required this.routeHeight, required this.animate});
  /// Null = the band takes the card's remaining height.
  final double? routeHeight;
  final bool animate;

  /// 9 : 12 : 10 — the middle column carries '4.120 hm' and the longest overline.
  static const List<int> _flex = [9, 12, 10];
  /// Air between a column and its right-hand neighbour.
  static const double _colGap = 8;
  /// HeroNumber's space between numeral and unit (does not scale with text).
  static const double _unitGap = 6;

  static double _width(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  /// The text scale for the numeral row: the system's, or — at large text
  /// sizes — the largest one at which every column still shows its final
  /// value in full. One factor for all three, so the overlines stay one size.
  static TextScaler _rowScaler(BuildContext context, double rowWidth, List<_HookStat> stats) {
    final c = AppColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final flexSum = _flex.fold<int>(0, (a, b) => a + b);
    var fit = 1.0;
    for (var i = 0; i < stats.length; i++) {
      final st = stats[i];
      final room = rowWidth * _flex[i] / flexSum - (i == stats.length - 1 ? 0 : _colGap);
      final label = _width(st.label.overline, AppText.label(c.textTertiary), scaler);
      final numeral = _width(st.format(1), HeroNumber.numeralStyle(c.textPrimary, HookPage.numeralSize), scaler);
      final unit = st.unit == null ? 0.0 : _width(st.unit!, AppText.unit(c.textTertiary, size: AppText.unitFor(HookPage.numeralSize)), scaler);
      final fixed = st.unit == null ? 0.0 : _unitGap;
      if (label > room) fit = math.min(fit, room / label);
      if (numeral + unit + fixed > room && numeral + unit > 0) fit = math.min(fit, (room - fixed) / (numeral + unit));
    }
    if (fit >= 1) return scaler;
    return TextScaler.linear(scaler.scale(HookPage.numeralSize) / HookPage.numeralSize * math.max(fit, 0.5));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    final live = animate && !Tokens.reduced(context);
    final stats = [
      _HookStat(s.p1Runs, null, (t) => '${(HookPage.runs * t).round()}'),
      _HookStat(s.p1Vertical, s.unitHm, (t) => Fmt.metres(HookPage.dropM * t, locale: l.code)),
      _HookStat(s.p1TopSpeed, s.unitKmh, (t) => '${(HookPage.topKmh * t).round()}'),
    ];
    return SurfaceCard(
      padding: HookPage._cardPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: routeHeight == null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (routeHeight == null) Expanded(child: RouteHook(height: null, animate: animate)) else RouteHook(height: routeHeight, animate: animate),
          const SizedBox(height: HookPage._routeGap),
          LayoutBuilder(
            builder: (context, row) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: _rowScaler(context, row.maxWidth, stats)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: live ? 0 : 1, end: 1),
                duration: Tokens.routeDraw,
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < stats.length; i++)
                      Expanded(
                        flex: _flex[i],
                        child: Padding(
                          padding: EdgeInsets.only(right: i == stats.length - 1 ? 0 : _colGap),
                          // Safety net only: [_rowScaler] already made the final values fit.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: HeroNumber(value: stats[i].format(t), label: stats[i].label, unit: stats[i].unit, size: HookPage.numeralSize),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One demo numeral on the hook card; [format] maps count-up progress 0–1 to text.
class _HookStat {
  const _HookStat(this.label, this.unit, this.format);
  final String label;
  final String? unit;
  final String Function(double t) format;
}

/// Page 2 — the team: five country tiles + 'Anderes', and an optional home resort.
class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key, required this.countryCode, required this.onCountry, required this.resortId, required this.onResort});
  /// Selected ISO-3166 alpha-2 (may be a sheet country), null = nothing chosen.
  final String? countryCode;
  final ValueChanged<String> onCountry;
  final String? resortId;
  final ValueChanged<Resort> onResort;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  bool _resortOpen = false;
  String _query = '';

  Future<void> _pickOther() async {
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    final sorted = [...kOtherCountries]..sort((a, b) => a.name(l).compareTo(b.name(l)));
    final code = await AppSheet.show<String>(
      context,
      title: s.p2OtherTitle,
      expand: true,
      builder: (ctx) => _OtherCountrySheet(countries: sorted, selected: widget.countryCode),
    );
    if (code == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onCountry(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final s = OnboardingStrings.of(context);
    final other = isGridCountry(widget.countryCode) ? null : teamCountry(widget.countryCode);
    final tiles = <Widget>[
      for (final k in kTeamCountries)
        _CountryTile(
          key: ValueKey('onboarding-country-${k.code}'),
          flag: k.flag,
          name: k.name(l),
          selected: widget.countryCode == k.code,
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            widget.onCountry(k.code);
          },
        ),
      _CountryTile(
        key: const ValueKey('onboarding-country-other'),
        flag: other?.flag,
        name: other?.name(l) ?? s.p2Other,
        selected: other != null,
        onTap: _pickOther,
      ),
    ];
    return OnboardingPage(
      headline: s.p2Headline,
      body: s.p2Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: tiles[row * 2]),
                const SizedBox(width: 10),
                Expanded(child: tiles[row * 2 + 1]),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _ResortSection(
            open: _resortOpen,
            query: _query,
            selectedId: widget.resortId,
            onToggle: () => setState(() => _resortOpen = !_resortOpen),
            onQuery: (v) => setState(() => _query = v),
            onResort: widget.onResort,
          ),
        ],
      ),
    );
  }
}

/// Large country tile: flag + name, champagne ring when selected.
class _CountryTile extends StatelessWidget {
  const _CountryTile({super.key, required this.flag, required this.name, required this.selected, required this.onTap});
  final String? flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      selected: selected,
      label: name,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            color: selected ? Color.alphaBlend(c.accentWash, c.surface) : c.surface,
            shape: Squircle.border(Tokens.r20, side: selected ? c.accent : c.hairline, width: selected ? 2 : c.hairlineWidth),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (flag != null)
                Text(flag!, style: const TextStyle(fontSize: 30, height: 1.1))
              else
                Icon(Icons.more_horiz_rounded, size: 30, color: c.textSecondary),
              const SizedBox(height: 6),
              Text(name, style: AppText.bodyStrong(c.textPrimary, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 'Anderes' list: one row per country, tap returns the code.
class _OtherCountrySheet extends StatelessWidget {
  const _OtherCountrySheet({required this.countries, required this.selected});
  final List<TeamCountry> countries;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocale.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Tokens.pad, 8, Tokens.pad, Tokens.pad),
      itemCount: countries.length,
      separatorBuilder: (_, _) => const Hairline(),
      itemBuilder: (context, i) {
        final k = countries[i];
        final on = k.code == selected;
        return Pressable(
          key: ValueKey('onboarding-country-${k.code}'),
          onTap: () => Navigator.of(context).pop(k.code),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Text(k.flag, style: const TextStyle(fontSize: 24, height: 1.1)),
                const SizedBox(width: 14),
                Expanded(child: Text(k.name(l), style: AppText.bodyText(on ? c.accent : c.textPrimary, size: 16, weight: on ? FontWeight.w600 : FontWeight.w400))),
                Text(k.code, style: AppText.label(c.textTertiary)),
                if (on) ...[const SizedBox(width: 10), GlyphIcon(Glyph.check, size: 18, color: c.accent)],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Collapsed row 'Heimatgebiet wählen (optional)' → resort search + list.
class _ResortSection extends ConsumerWidget {
  const _ResortSection({
    required this.open,
    required this.query,
    required this.selectedId,
    required this.onToggle,
    required this.onQuery,
    required this.onResort,
  });
  final bool open;
  final String query;
  final String? selectedId;
  final VoidCallback onToggle;
  final ValueChanged<String> onQuery;
  final ValueChanged<Resort> onResort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    final repo = ref.watch(resortRepositoryProvider).asData?.value;
    final all = repo?.all ?? const <Resort>[];
    final q = query.trim().toLowerCase();
    final list = (q.isEmpty ? all : all.where((r) => r.name.toLowerCase().contains(q))).toList()..sort((a, b) => a.name.compareTo(b.name));
    final selected = selectedId == null ? null : repo?.byId(selectedId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: onToggle,
          child: Container(
            key: const ValueKey('onboarding-resort-toggle'),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: ShapeDecoration(color: c.glassFill, shape: Squircle.border(Tokens.r14, side: c.glassStroke, width: c.hairlineWidth)),
            child: Row(
              children: [
                GlyphIcon(Glyph.map, size: 20, color: selected == null ? c.textTertiary : c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: selected == null
                      ? Text(s.p2Resort, style: AppText.bodyText(c.textSecondary, size: 15, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.p2ResortLabel.overline, style: AppText.label(c.textTertiary)),
                            const SizedBox(height: 2),
                            Text(selected.name, style: AppText.bodyStrong(c.textPrimary, size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                ),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: Tokens.motion(context, Tokens.medium),
                  child: const RowChevron(),
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 10),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(color: c.surface, shape: Squircle.border(Tokens.r14, side: c.hairline, width: c.hairlineWidth)),
            child: Row(
              children: [
                GlyphIcon(Glyph.search, size: 20, color: c.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('onboarding-resort-search'),
                    autofocus: true,
                    onChanged: onQuery,
                    style: AppText.bodyText(c.textPrimary, size: 16),
                    cursorColor: c.accent,
                    decoration: InputDecoration.collapsed(hintText: s.p2Search, hintStyle: AppText.bodyText(c.textTertiary, size: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 200,
              child: list.isEmpty
                  ? Center(child: Text(s.p2NoMatch, style: AppText.caption(c.textTertiary)))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Hairline(inset: 16),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        final on = r.id == selectedId;
                        return Pressable(
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            onResort(r);
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: on ? c.accentWash : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(child: Text(r.name, style: AppText.bodyText(on ? c.accent : c.textPrimary, size: 16, weight: on ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Text(r.country, style: AppText.label(c.textTertiary)),
                                if (on) ...[const SizedBox(width: 10), GlyphIcon(Glyph.check, size: 18, color: c.accent)],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hook for tests: the sign-in action the flow uses.
final onboardingSignInProvider = Provider<Future<AuthUser?> Function()>((ref) => ref.read(authServiceProvider).signInWithApple);

/// The shared [AppleButton] under the onboarding test key. (It used to draw
/// ink on ink in the light theme — the label disappeared.)
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({super.key, required this.label, this.onPressed, this.height = 60});
  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: const ValueKey('onboarding-apple'), child: AppleButton(label: label, onPressed: onPressed, height: height));
}

/// Page 3 — ready: account state, then what iOS will ask.
class ReadyPage extends StatelessWidget {
  const ReadyPage({
    super.key,
    required this.user,
    required this.skipped,
    required this.failed,
    required this.denied,
    required this.granted,
    required this.grantedAlways,
    required this.onOpenSettings,
    this.optIn = true,
    this.onOptIn,
  });
  final AuthUser? user;
  final bool skipped;
  final bool failed;
  final bool denied;
  final bool granted;
  final bool grantedAlways;
  final VoidCallback onOpenSettings;
  /// Leaderboard opt-in shown once the account exists (default on, docs/BACKLOG.md UX-ONBOARDING).
  final bool optIn;
  final ValueChanged<bool>? onOptIn;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = OnboardingStrings.of(context);
    final Widget account;
    if (user != null) {
      account = AppCard(
        tone: CardTone.accent,
        header: s.p3Account,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconLine(leading: GlyphIcon(Glyph.check, size: 22, color: c.accent), title: s.p3SignedIn(riderName(context, user!.displayName)), caption: s.p3Benefit),
            const SizedBox(height: 12),
            const Hairline(),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.p3OptIn, style: AppText.bodyStrong(c.textPrimary)),
                      const SizedBox(height: 2),
                      Text(s.p3OptInHint, style: AppText.caption(c.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppSwitch(key: const ValueKey('onboarding-optin'), value: optIn, onChanged: onOptIn),
              ],
            ),
          ],
        ),
      );
    } else if (skipped) {
      account = AppCard(
        header: s.p3Account,
        child: _IconLine(leading: GlyphIcon(Glyph.person, size: 22, color: c.textTertiary), title: s.p3Skipped, caption: s.p3SkippedBody),
      );
    } else {
      account = AppCard(
        header: s.p3Account,
        child: _IconLine(leading: Icon(Icons.apple, color: c.textPrimary, size: 22), title: s.p3SignIn, caption: s.p3Benefit, danger: failed ? s.p3Failed : null),
      );
    }
    return OnboardingPage(
      headline: s.p3Headline,
      body: s.p3Body,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          account,
          SectionLabel(s.p3Asks, padding: const EdgeInsets.fromLTRB(0, Tokens.sectionGap, 0, 10)),
          _Row(glyph: Glyph.locate, text: s.p3ItemA),
          const SizedBox(height: 10),
          _Row(glyph: Glyph.gauge, text: s.p3ItemB),
          if (denied) ...[
            const SizedBox(height: 16),
            AppCard(
              tone: CardTone.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.location_off_rounded, size: 20, color: c.danger), const SizedBox(width: 8), Expanded(child: Text(s.denied, style: AppText.bodyText(c.textPrimary, size: 15)))]),
                  const SizedBox(height: 12),
                  SecondaryButton(label: s.openSettings, onPressed: onOpenSettings, height: Tokens.buttonMd),
                ],
              ),
            ),
          ] else if (granted) ...[
            const SizedBox(height: 16),
            AppCard(
              tone: CardTone.accent,
              child: Row(children: [GlyphIcon(Glyph.check, size: 20, color: c.accent), const SizedBox(width: 8), Expanded(child: Text(grantedAlways ? s.grantedAlways : s.grantedWhileInUse, style: AppText.bodyText(c.textPrimary, size: 15)))]),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.leading, required this.title, required this.caption, this.danger});
  /// 22 pt glyph (or the Apple logo, which has no glyph).
  final Widget leading;
  final String title;
  final String caption;
  final String? danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: leading),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.title(c.textPrimary)),
              const SizedBox(height: 2),
              Text(caption, style: AppText.caption(c.textSecondary)),
              if (danger != null) ...[const SizedBox(height: 8), Text(danger!, style: AppText.caption(c.danger))],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.glyph, required this.text});
  final Glyph glyph;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlyphIcon(glyph, size: 22, color: c.textTertiary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.bodyText(c.textPrimary, size: 15))),
        ],
      ),
    );
  }
}

/// Line pager: 24×2 bars, active champagne.
class LinePager extends StatelessWidget {
  const LinePager({super.key, required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Tokens.motion(context, Tokens.medium),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 28 : 16,
            height: 3,
            decoration: BoxDecoration(color: i == index ? c.accent : c.hairlineStrong, borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
  }
}
