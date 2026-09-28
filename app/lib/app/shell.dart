import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import '../features/account/account.dart';
import '../features/achievements/ui/ui.dart';
import '../features/settings/settings.dart';
import '../features/social/invite/invite_link_handler.dart';
import 'demo.dart';
import 'l10n/app_locale.dart';
import 'router.dart';
import 'theme/surfaces.dart';
import 'widgets/glyphs.dart';
import 'widgets/tab_bar.dart';

/// Three tabs: Heute · Tage · Rangliste. Content scrolls under the glass tab
/// bar; the Heute icon pulses ice while a day is recording.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});
  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = demoInitialTab();
  // Built once: the tabs must keep their identity across rebuilds.
  late final List<Widget> _pages = [AppRouter.heute(), AppRouter.tage(), AppRouter.social()];

  @override
  void initState() {
    super.initState();
    final route = demoInitialRoute();
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (route) {
        case 'settings':
          SettingsSheet.show(context);
        case 'account':
          AccountSheet.show(context);
        case 'medals':
          MedalsSheet.show(context);
        case 'profile':
          ProfilePage.open(context);
        default:
          Navigator.of(context).pushNamed(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final recording = ref.watch(isRecordingProvider);
    // A joined duel or friend request wants the Rangliste tab.
    ref.listen(ranglisteRequestProvider, (_, _) => setState(() => _index = 2));
    return Scaffold(
      extendBody: true,
      body: PageBackground(
        // A plain IndexedStack keeps every tab's state (scroll position, sheets,
        // polling) across switches; the previous AnimatedSwitcher re-keyed the
        // whole stack on every tap and rebuilt all three tabs.
        child: IndexedStack(
          index: _index,
          children: [
            // TickerMode: hidden tabs stop their tickers (duel polling, pulses).
            for (final (i, page) in _pages.indexed) TickerMode(enabled: i == _index, child: page),
          ],
        ),
      ),
      bottomNavigationBar: AppTabBar(
        index: _index,
        recording: recording,
        onSelect: (i) => setState(() => _index = i),
        tabs: [
          AppTab(label: l.pick(de: 'Heute', en: 'Today'), glyph: Glyph.chevron),
          AppTab(label: l.pick(de: 'Tage', en: 'Days'), glyph: Glyph.calendar),
          AppTab(label: l.pick(de: 'Rangliste', en: 'Ranks'), glyph: Glyph.podium),
        ],
      ),
    );
  }
}
