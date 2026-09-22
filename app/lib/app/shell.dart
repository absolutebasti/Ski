import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
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
            child: IndexedStack(index: _index, children: [AppRouter.heute(), AppRouter.tage(), AppRouter.social()]),
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
