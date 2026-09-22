import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import 'l10n/app_locale.dart';
import 'demo.dart';
import 'router.dart';
import 'theme/tokens.dart';

/// Two tabs: Heute · Tage. The Heute icon carries a dot while a day is recording.
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
    final c = AppColors.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: [AppRouter.heute(), AppRouter.tage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: recording,
              smallSize: 8,
              backgroundColor: c.ice,
              child: const Icon(Icons.radio_button_checked_rounded),
            ),
            label: l.pick(de: 'Heute', en: 'Today'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_rounded),
            label: l.pick(de: 'Tage', en: 'Days'),
          ),
        ],
      ),
    );
  }
}
