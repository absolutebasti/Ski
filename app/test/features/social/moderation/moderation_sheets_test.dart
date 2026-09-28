import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/widgets/widgets.dart';
import 'package:slopetrack/data/sync/auth_service.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';

import '../../../support/pump.dart';

const _user = AuthUser(id: 'u1', displayName: 'Sebastian Fackelmann');

List<Override> _overrides(FakeModerationApi mod, {FakeFriendsApi? friends}) => [
      moderationApiProvider.overrideWithValue(mod),
      socialApiProvider.overrideWithValue(FakeSocialApi(userId: 'u1')),
      friendsApiProvider.overrideWithValue(friends ?? FakeFriendsApi(userId: 'u1')),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
    ];

/// Lets the floating toast expire so no timer outlives the test.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  group('ReportSheet', () {
    testWidgets('three reason chips, note, submit disabled until a reason is picked', (tester) async {
      final mod = FakeModerationApi(userId: 'u1');
      await pumpApp(tester, const Scaffold(body: ReportSheetBody(targetUserId: 'u9', displayName: 'Lena Bergmann')), overrides: _overrides(mod));
      await tester.pumpAndSettle();

      expect(find.text('Was stimmt mit dem Profil von Lena Bergmann nicht?'), findsOneWidget);
      expect(find.text('Anstößiger Name'), findsOneWidget);
      expect(find.text('Betrug/unrealistische Werte'), findsOneWidget);
      expect(find.text('Sonstiges'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('report-submit'))).onPressed, isNull);

      await tester.tap(find.text('Betrug/unrealistische Werte'));
      await tester.pump();
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('report-submit'))).onPressed, isNotNull);
      await tester.enterText(find.byKey(const ValueKey('report-details')), ' 4.000 hm in 10 Minuten ');
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pump();

      expect(mod.reports, [('u9', 'cheating: 4.000 hm in 10 Minuten')]);
      expect(find.text('Danke, wir schauen uns das an'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('a reason without a note sends the wire key only; errors become a toast', (tester) async {
      final mod = FakeModerationApi(userId: 'u1');
      await pumpApp(tester, const Scaffold(body: ReportSheetBody(targetUserId: 'u9', displayName: 'Lena')), overrides: _overrides(mod));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anstößiger Name'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pump();
      expect(mod.reports, [('u9', 'offensive_name')]);
      await _settleToast(tester);

      mod.failWith = const ModerationError(ModerationErrorKind.offline);
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pump();
      expect(find.text('Keine Verbindung'), findsOneWidget);
      expect(mod.reports, hasLength(1));
      await _settleToast(tester);
    });

    testWidgets('English copy', (tester) async {
      await pumpApp(tester, const Scaffold(body: ReportSheetBody(targetUserId: 'u9', displayName: 'Lena')), overrides: _overrides(FakeModerationApi(userId: 'u1')), locale: const Locale('en'));
      await tester.pumpAndSettle();
      expect(find.text('Offensive name'), findsOneWidget);
      expect(find.text('Cheating / unrealistic values'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
    });
  });

  group('BlockConfirmSheet', () {
    testWidgets('confirm blocks, removes the friend and closes with true; cancel closes with false', (tester) async {
      final mod = FakeModerationApi(userId: 'u1');
      final friends = FakeFriendsApi(userId: 'u1', friends: const [Friend(userId: 'u9', displayName: 'Lena Bergmann')]);
      bool? result;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => result = await BlockConfirmSheet.show(context, targetUserId: 'u9', displayName: 'Lena Bergmann'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: _overrides(mod, friends: friends),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Lena Bergmann blockieren?'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('block-cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(mod.blocked, isEmpty);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('block-confirm')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(mod.blocked, {'u9'});
      expect(friends.removed, ['u9']);
      expect(find.byKey(const ValueKey('block-sheet')), findsNothing);
    });

    testWidgets('a failed block keeps the sheet open and shows the error', (tester) async {
      final mod = FakeModerationApi(userId: 'u1', failWith: const ModerationError(ModerationErrorKind.failed));
      await pumpApp(tester, const Scaffold(body: BlockConfirmSheetBody(targetUserId: 'u9', displayName: 'Lena')), overrides: _overrides(mod));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('block-confirm')));
      await tester.pump();
      expect(find.text('Hat nicht geklappt. Versuch es gleich noch einmal.'), findsOneWidget);
      expect(find.byKey(const ValueKey('block-sheet')), findsOneWidget);
      await _settleToast(tester);
    });
  });
}
