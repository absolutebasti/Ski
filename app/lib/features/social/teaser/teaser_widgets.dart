import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/widgets.dart';
import '../leaderboard_view.dart';
import '../social_models.dart';
import 'teaser_models.dart';

/// The public top 10 as plain board rows (no podium — a podium column opens a
/// rider, and a teaser row has no rider to open). Every row calls [onRow],
/// which the screen answers with 'Anmelden, um Profile zu sehen'.
class TeaserRows extends StatelessWidget {
  const TeaserRows({super.key, required this.entries, required this.onRow});

  /// Rank order, at most [kTeaserLimit].
  final List<TeaserEntry> entries;
  final VoidCallback onRow;

  @override
  Widget build(BuildContext context) {
    final rows = entries.length > kTeaserLimit ? entries.sublist(0, kTeaserLimit) : entries;
    return LeaderboardRows(
      entries: [for (final e in rows) e.toEntry()],
      metric: SocialMetric.points,
      onRider: (_, _) => onRow(),
    );
  }
}

/// A Tagesduell / Wochen-Challenge card as the signed-out rider sees it: the
/// overline of the real card, one line that says what it does, and a lock.
/// No action inside — the whole card leads to the sign-in.
class TeaserLockedCard extends StatelessWidget {
  const TeaserLockedCard({super.key, required this.title, required this.line, required this.lockedLabel, this.onTap});

  /// Overline, same as the live card ('Tagesduell', 'Wochen-Challenge').
  final String title;
  final String line;

  /// Read out after the line ('Nach dem Anmelden verfügbar').
  final String lockedLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title. $line. $lockedLabel',
      excludeSemantics: true,
      child: AppCard(
        header: title,
        trailing: Icon(Icons.lock_outline_rounded, size: 16, color: c.textTertiary),
        onTap: onTap,
        child: Text(line, style: AppText.bodyText(c.textSecondary, size: 15)),
      ),
    );
  }
}

/// Period tabs and filter chips shown but switched off: drawn at half
/// strength, no pointer reaches them, VoiceOver reads [label] once instead of
/// a row of dead buttons. A tap anywhere on the block calls [onTap].
class TeaserLockedFilters extends StatelessWidget {
  const TeaserLockedFilters({super.key, required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: IgnorePointer(child: Opacity(opacity: 0.5, child: child)),
        ),
      ),
    );
  }
}

/// The sign-in call pinned above the tab bar — the L2 glass strip with the
/// accent wash that carries the own rank once a Konto exists
/// (docs/DESIGN.md §5 "Rangliste" 5.).
class TeaserSignInStrip extends StatelessWidget {
  const TeaserSignInStrip({
    super.key,
    required this.headline,
    required this.line,
    required this.actionLabel,
    required this.onSignIn,
    this.bottomPadding = 0,
  });

  final String headline;
  final String line;
  final String actionLabel;
  final VoidCallback onSignIn;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      child: GlassLayer(
        topHairline: true,
        child: ColoredBox(
          color: c.accentWash,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Tokens.pad, 12, Tokens.pad, 12 + bottomPadding),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(c.textPrimary, size: 15)),
                      const SizedBox(height: 2),
                      Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption(c.textSecondary, size: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  child: PrimaryButton(key: const ValueKey('teaser-sign-in'), label: actionLabel, height: Tokens.buttonMd, expand: false, glow: false, onPressed: onSignIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
