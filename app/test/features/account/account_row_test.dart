import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/account/account.dart';

import '../../support/pump.dart';

const _de = AccountStrings(AppLocale(Locale('de')));
const _user = AuthUser(id: 'u1', displayName: 'Sebastian', email: 'ski@example.com');

List<Override> _overrides({AuthUser? user, FakeProfileApi? api}) => [
      accountAvailableProvider.overrideWithValue(true),
      authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(user)),
      profileApiProvider.overrideWithValue(api),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed out: person glyph, "Konto" and the sign-in caption', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AccountRow(onTap: () => taps++)), overrides: _overrides());
    await tester.pumpAndSettle();

    expect(find.text('Konto'), findsOneWidget);
    expect(find.text(_de.signIn), findsNothing, reason: 'the title is the page name, not the action');
    expect(find.text('Anmelden – Sichern, Ranglisten, Freunde'), findsOneWidget);
    expect(find.text(_de.rowHint), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-row')));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('signed in: initial in the circle, profile name and email', (tester) async {
    await pumpApp(
      tester,
      Scaffold(body: AccountRow(onTap: () {})),
      overrides: _overrides(
        user: _user,
        api: FakeProfileApi(userId: 'u1', row: {'id': 'u1', 'display_name': 'Basti'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Basti'), findsOneWidget);
    expect(find.text('ski@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
  });
}
