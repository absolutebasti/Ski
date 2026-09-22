import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import '../features/account/account.dart';
import '../features/settings/settings.dart';
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
        default:
          Navigator.of(context).pushNamed(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocale.of(context);
    final recording = ref.watch(isRecordingProvider);
    return Scaffold(
      extendBody: true,
      body: PageBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: IndexedStack(
              index: _index,
              children: [
                // TickerMode: hidden tabs stop their tickers (duel polling, pulses).
                for (final (i, page) in [AppRouter.heute(), AppRouter.tage(), AppRouter.social()].indexed)
                  TickerMode(enabled: i == _index, child: page),
              ],
            ),
          ),
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
