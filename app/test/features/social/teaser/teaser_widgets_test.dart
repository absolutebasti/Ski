import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/social.dart';
import 'package:slopetrack/features/social/teaser/teaser.dart';

import '../../../support/pump.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await pumpApp(tester, Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: child))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TeaserRows: board rows by points, every tap goes to onRow', (tester) async {
    var taps = 0;
    await _pump(tester, TeaserRows(entries: FakeTeaserApi.sample(3), onRow: () => taps++));

    expect(find.byType(LeaderboardRow), findsNWidgets(3));
    expect(find.text('Lena Bergmann'), findsOneWidget);
    expect(find.text('4.200'), findsOneWidget);
    expect(find.text('Pkt.'), findsNWidgets(3));
    // Trailing the leader: '−300 Pkt.' under the second row's value.
    expect(find.text('−300 Pkt.'), findsOneWidget);
    // No row is drawn as the own row.
    expect(tester.widgetList<LeaderboardRow>(find.byType(LeaderboardRow)).every((r) => !r.own), isTrue);

    await tester.tap(find.text('Paul Moser'));
    await tester.tap(find.text('Nina Aigner'));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('TeaserRows never draws more than ten rows', (tester) async {
    tester.view.physicalSize = const Size(1179, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final rows = [for (var i = 1; i <= 13; i++) TeaserEntry(rank: i, displayName: 'Rider $i', value: 2000.0 - i)];
    await _pump(tester, TeaserRows(entries: rows, onRow: () {}));
    expect(find.byType(LeaderboardRow), findsNWidgets(10));
  });

  testWidgets('TeaserLockedCard: overline, line, lock; one semantics node that names the lock', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      TeaserLockedCard(title: 'Tagesduell', line: 'Duell mit bis zu 3 Freunden · Code teilen', lockedLabel: 'Nach dem Anmelden verfügbar', onTap: () => taps++),
    );
    expect(find.text('TAGESDUELL'), findsOneWidget);
    expect(find.text('Duell mit bis zu 3 Freunden · Code teilen'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tagesduell. Duell mit bis zu 3 Freunden · Code teilen. Nach dem Anmelden verfügbar'),
      findsOneWidget,
    );

    await tester.tap(find.byType(TeaserLockedCard));
    await tester.pumpAndSettle();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('TeaserLockedFilters: the child gets no tap, the block does; read out once', (tester) async {
    final handle = tester.ensureSemantics();
    var selected = 0;
    var blockTaps = 0;
    await _pump(
      tester,
      TeaserLockedFilters(
        label: 'Zeitraum, Gebiet und Wertung. Nach dem Anmelden verfügbar',
        onTap: () => blockTaps++,
        child: SocialSegmentTabs(labels: const ['Saison', 'Monat', 'Woche'], index: 0, onSelect: (i) => selected = i),
      ),
    );

    await tester.tap(find.text('Monat'), warnIfMissed: false);
    await tester.tap(find.text('Woche'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(selected, 0, reason: 'no pointer reaches the tabs');
    expect(blockTaps, 2);

    expect(find.bySemanticsLabel('Zeitraum, Gebiet und Wertung. Nach dem Anmelden verfügbar'), findsOneWidget);
    expect(find.bySemanticsLabel('Monat'), findsNothing, reason: 'dead tabs are not read out as buttons');
    expect(tester.widget<Opacity>(find.descendant(of: find.byType(TeaserLockedFilters), matching: find.byType(Opacity)).first).opacity, 0.5);
    handle.dispose();
  });

  testWidgets('TeaserSignInStrip: headline, line and the sign-in button', (tester) async {
    var taps = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: TeaserSignInStrip(
            headline: 'Hol dir Platz 1.',
            line: 'Melde dich an und fahr gegen Kitzbühel.',
            actionLabel: 'Anmelden',
            onSignIn: () => taps++,
            bottomPadding: 90,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hol dir Platz 1.'), findsOneWidget);
    expect(find.text('Melde dich an und fahr gegen Kitzbühel.'), findsOneWidget);
    final button = tester.getRect(find.byKey(const ValueKey('teaser-sign-in')));
    expect(button.height, greaterThanOrEqualTo(44), reason: 'tap target');
    final strip = tester.getRect(find.byType(TeaserSignInStrip));
    expect(strip.bottom - button.bottom, greaterThanOrEqualTo(90), reason: 'the button clears the tab bar inset');

    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TeaserSignInStrip survives 1.3× text on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(960, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 600), textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TeaserSignInStrip(
              headline: 'Hol dir Platz 1.',
              line: 'Melde dich an und fahr gegen Skicircus Saalbach Hinterglemm Leogang Fieberbrunn.',
              actionLabel: 'Anmelden',
              onSignIn: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('teaser copy: German first, English second, no Platz 1 in the empty line', () {
    const de = SocialStrings(AppLocale(Locale('de')));
    const en = SocialStrings(AppLocale(Locale('en')));
    expect(de.teaserRowToast, 'Anmelden, um Profile zu sehen');
    expect(en.teaserRowToast, 'Sign in to see profiles');
    expect(de.teaserDuelLine, 'Duell mit bis zu 3 Freunden · Code teilen');
    expect(de.teaserEmptyLine('Kitzbühel'), 'In Kitzbühel ist noch niemand gewertet.');
    expect(de.teaserEmptyLine(null), 'Noch ist niemand gewertet.');
    for (final s in [de, en]) {
      for (final line in [s.teaserEmptyLine(null), s.teaserEmptyLine('Ischgl'), s.teaserErrorLine(SocialErrorKind.offline), s.teaserErrorLine(SocialErrorKind.failed)]) {
        expect(line, isNot(contains('Platz 1')));
        expect(line, isNot(contains('first place')));
        expect(line, isNotEmpty);
      }
      expect(s.teaserChallengeLine, isNotEmpty);
      expect(s.teaserLocked, isNotEmpty);
      expect(s.teaserFilters, isNotEmpty);
    }
    expect(de.teaserErrorLine(SocialErrorKind.offline), isNot(de.teaserErrorLine(SocialErrorKind.failed)));
  });
}
