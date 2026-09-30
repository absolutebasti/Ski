import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/app/l10n/app_locale.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/fake_social_api.dart';
import 'package:slopetrack/features/social/social.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'duel_fixtures.dart';

void main() {
  group('retryOnceOnCodeCollision', () {
    test('retries exactly once on a unique violation', () async {
      var calls = 0;
      final result = await retryOnceOnCodeCollision(() async {
        calls++;
        if (calls == 1) throw const PostgrestException(message: 'duplicate key value violates unique constraint "groups_code_key"', code: '23505');
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 2);
    });

    test('a second collision propagates', () async {
      var calls = 0;
      await expectLater(
        retryOnceOnCodeCollision(() async {
          calls++;
          throw const PostgrestException(message: 'duplicate', code: '23505');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 2);
    });

    test('other errors are not retried', () async {
      var calls = 0;
      await expectLater(
        retryOnceOnCodeCollision(() async {
          calls++;
          throw const PostgrestException(message: 'duel_expired', code: 'P0006');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1);
    });
  });

  group('error mapping', () {
    test('duel_expired maps to a readable kind and toast line', () {
      final e = SupabaseSocialApi.mapError(const PostgrestException(message: 'duel_expired', code: 'P0006'));
      expect(e.kind, SocialErrorKind.duelExpired);
      expect(const SocialStrings(AppLocale(Locale('de'))).error(e.kind), 'Dieses Duell ist vorbei.');
      expect(const SocialStrings(AppLocale(Locale('en'))).error(e.kind), 'This duel is over.');
    });

    test('not_a_member maps too', () {
      final e = SupabaseSocialApi.mapError(const PostgrestException(message: 'not_a_member', code: '42501'));
      expect(e.kind, SocialErrorKind.notAMember);
    });
  });

  group('models', () {
    test('DuelMember.fromJson reads the 0009 columns', () {
      final m = DuelMember.fromJson({
        'user_id': 'u1',
        'display_name': 'Anna',
        'run_count': 5,
        'drop_m': 1200.0,
        'ski_distance_m': 9000,
        'max_speed_ms': 15.5,
        'is_live': true,
        'updated_at': '2026-01-15T08:58:00Z',
      });
      expect(m.isLive, isTrue);
      expect(m.dropM, 1200);
      expect(m.updatedAtMs, DateTime.utc(2026, 1, 15, 8, 58).millisecondsSinceEpoch);
      expect(m.minutesAgo(DateTime.utc(2026, 1, 15, 9).millisecondsSinceEpoch), 2);
      expect(m.minutesAgo(DateTime.utc(2026, 1, 15, 8).millisecondsSinceEpoch), 0, reason: 'never negative');
    });

    test('DuelMember.from upgrades a 0005 row without live info', () {
      const base = GroupMemberStats(userId: 'u1', displayName: 'Anna', dropM: 10);
      final m = DuelMember.from(base);
      expect(m.isLive, isFalse);
      expect(m.updatedAtMs, isNull);
      expect(m.dropM, 10);
      expect(identical(DuelMember.from(m), m), isTrue);
    });

    test('DuelSummary.fromJson parses a my_duels row, board sorted by hm', () {
      final d = DuelSummary.fromJson({
        'id': 'g1',
        'code': 'KMJ4F2',
        'name': 'Testduell',
        'day': '2026-01-15',
        'resort_id': null,
        'created_by': 'u2',
        'max_members': 3,
        'tz': 'America/Denver',
        'member_count': 3,
        'board': [
          {'user_id': 'u1', 'display_name': 'Du', 'drop_m': 1804, 'run_count': 9, 'is_live': true, 'updated_at': '2026-01-15T08:58:00Z'},
          {'user_id': 'u2', 'display_name': 'Paul', 'drop_m': 2410, 'run_count': 11, 'is_live': false},
        ],
      });
      expect(d.group.code, 'KMJ4F2');
      expect(d.day, DateTime(2026, 1, 15));
      expect(d.tz, 'America/Denver');
      expect(d.memberCount, 3);
      expect(d.participants, 3);
      expect(d.board.map((m) => m.userId), ['u2', 'u1']);
      expect(d.placeOf('u1'), 2);
      expect(d.placeOf('u9'), isNull);
      expect(d.winner?.userId, 'u2');
      expect(d.anyLive, isTrue);
    });

    test('an empty board has no winner', () {
      expect(duelSummary(day: DateTime(2026, 1, 14), board: const []).winner, isNull);
      expect(duelSummary(day: DateTime(2026, 1, 14), board: const [DuelMember(userId: 'u1', displayName: 'A')]).winner, isNull);
    });

    test('LiveDayPayload is tiny and compares by numbers', () {
      final p = LiveDayPayload(day: DateTime(2026, 1, 15), resortId: 'kitzbuehel', dropM: 500, runCount: 3, skiDistanceM: 4000, maxSpeedMs: 15);
      expect(p.toJson(), {'day': '2026-01-15', 'resort_id': 'kitzbuehel', 'drop_m': 500.0, 'run_count': 3, 'ski_distance_m': 4000.0, 'max_speed_ms': 15.0});
      expect(p.sameNumbers(LiveDayPayload(day: DateTime(2026, 1, 15), resortId: 'ischgl', dropM: 500, runCount: 3, skiDistanceM: 4000, maxSpeedMs: 15)), isTrue);
      expect(p.sameNumbers(LiveDayPayload(day: DateTime(2026, 1, 15), dropM: 501, runCount: 3, skiDistanceM: 4000, maxSpeedMs: 15)), isFalse);
    });
  });

  group('guessIanaZone', () {
    test('known abbreviations', () {
      expect(guessIanaZone('CET', const Duration(hours: 1)), 'Europe/Vienna');
      expect(guessIanaZone('cest', const Duration(hours: 2)), 'Europe/Vienna');
      expect(guessIanaZone('MST', const Duration(hours: -7)), 'America/Denver');
      expect(guessIanaZone('JST', const Duration(hours: 9)), 'Asia/Tokyo');
    });

    test('offset fallback for GMT+x style names', () {
      expect(guessIanaZone('GMT-7', const Duration(hours: -7)), 'America/Denver');
      expect(guessIanaZone('GMT+1', const Duration(hours: 1)), 'Europe/Vienna');
      expect(guessIanaZone('UTC+5:30', const Duration(hours: 5, minutes: 30)), 'Asia/Kolkata');
      expect(guessIanaZone('XYZ', const Duration(hours: 4)), 'Europe/Vienna');
    });
  });

  test('the fake records tz and name on create and applies the day', () async {
    final api = FakeDuelApi(userId: 'u1');
    final g = await api.createDuel(name: 'Crew', day: DateTime(2026, 1, 15, 14), tz: 'America/Denver');
    expect(api.created, ['Crew']);
    expect(api.createdTz, ['America/Denver']);
    expect(g.day, DateTime(2026, 1, 15));
    expect(await api.myDuel(DateTime(2026, 1, 15)), g);
  });

  test('SocialApiDuelAdapter delegates and answers no history', () async {
    final social = FakeSocialApi(userId: 'u1', board: const [GroupMemberStats(userId: 'u1', displayName: 'Du', dropM: 5)]);
    final api = SocialApiDuelAdapter(social);
    expect(api.userId, 'u1');
    final board = await api.groupBoard('g1');
    expect(board.single.isLive, isFalse);
    expect(await api.myDuels(), isEmpty);
    await api.upsertLive(LiveDayPayload(day: DateTime(2026, 1, 15)));
    await api.createDuel(name: 'x', day: DateTime(2026, 1, 15), tz: 'Europe/Vienna');
    expect(social.created, ['x']);
  });

  group('invites (0017)', () {
    test('already_member and invite_not_found map before the shared mapping', () {
      final member = SupabaseDuelApi.mapError(const PostgrestException(message: 'already_member', code: '23505'));
      expect(member.kind, SocialErrorKind.alreadyMember);
      final gone = SupabaseDuelApi.mapError(const PostgrestException(message: 'invite_not_found', code: 'P0002'));
      expect(gone.kind, SocialErrorKind.riderNotFound);
      expect(gone.detail, inviteNotFound);
      expect(SupabaseDuelApi.mapError(const PostgrestException(message: 'duel_full', code: 'P0003')).kind, SocialErrorKind.duelFull);
      expect(SupabaseDuelApi.mapError(const PostgrestException(message: 'rider_not_found', code: 'P0002')).detail, isNull);
    });

    test('DuelInvite.fromJson tolerates string counts and missing optionals', () {
      final invite = DuelInvite.fromJson({'id': 'i', 'from_user': 'u9', 'group_id': 'g', 'code': 'PQRS23', 'day': '2026-01-15', 'member_count': '3', 'max_members': '3'});
      expect(invite.fromName, '');
      expect(invite.fromAvatarUrl, isNull);
      expect(invite.memberCount, 3);
      expect(invite.group.maxMembers, 3);
      expect(invite.full, isTrue);
      expect(invite.tz, 'Europe/Vienna');
      final bare = DuelInvite.fromJson({'id': 'i', 'from_user': 'u9', 'group_id': 'g', 'day': '2026-01-15'});
      expect(bare.memberCount, 1);
      expect(bare.group.maxMembers, 3);
      expect(bare.full, isFalse);
    });

    test('the fake models the server: invite guards, accept joins, decline drops, a failed accept keeps the invite', () async {
      final api = FakeDuelApi(userId: 'u1');
      await expectLater(api.inviteToDuel(userId: 'u9', groupId: 'g1'), throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.notAMember)));
      final g = await api.createDuel(name: 'Crew', day: DateTime(2026, 1, 15), tz: 'Europe/Vienna');
      await expectLater(api.inviteToDuel(userId: 'u1', groupId: g.id), throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.riderNotFound)));
      final sent = await api.inviteToDuel(userId: 'u9', groupId: g.id);
      expect(sent.group, g);
      expect(api.invited.last, ('u9', g.id));

      final other = FakeDuelApi(userId: 'u9', invites: [duelInvite(), duelInvite(id: 'inv-full', memberCount: 3)]);
      expect(await other.myInvites(), hasLength(2));
      await expectLater(other.respondInvite('inv-full', accept: true), throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.duelFull)));
      expect(other.invites, hasLength(2), reason: 'a failed accept leaves the invite pending');
      expect(await other.respondInvite('inv-full', accept: false), isNull);
      final joined = await other.respondInvite('inv-1', accept: true);
      expect(joined?.id, 'g-lena');
      expect(await other.myDuel(DateTime(2026, 1, 15)), joined);
      expect(other.board.map((m) => m.userId), containsAll(['u9']));
      expect(await other.myInvites(), isEmpty);
      await expectLater(
        other.respondInvite('inv-1', accept: true),
        throwsA(isA<SocialError>().having((e) => e.detail, 'detail', inviteNotFound)),
      );
      expect(await FakeDuelApi(invites: [duelInvite()]).myInvites(), isEmpty, reason: 'signed out');
    });

    test('the SocialApi adapter has no invites: flag off, empty list, invite throws', () async {
      final api = SocialApiDuelAdapter(FakeSocialApi(userId: 'u1'));
      expect(api.supportsInvites, isFalse);
      expect(await api.myInvites(), isEmpty);
      await expectLater(api.inviteToDuel(userId: 'u9', groupId: 'g1'), throwsA(isA<SocialError>()));
      await expectLater(api.respondInvite('i', accept: true), throwsA(isA<SocialError>()));
    });

    test('invite copy in both languages', () {
      const de = DuelStrings(AppLocale(Locale('de')));
      const en = DuelStrings(AppLocale(Locale('en')));
      expect(de.inviteFrom('Lena'), 'Duell-Einladung von Lena');
      expect(en.inviteFrom('Lena'), 'Duel invite from Lena');
      expect(de.inviteFrom(''), 'Duell-Einladung');
      expect(de.inviteSent('Lena'), 'Einladung an Lena gesendet');
      expect(en.inviteSent('Lena'), 'Invite sent to Lena');
      expect(de.accept, 'Annehmen');
      expect(de.decline, 'Ablehnen');
      expect(de.moreInvites(1), '+ 1 weitere Einladung');
      expect(de.moreInvites(3), '+ 3 weitere Einladungen');
      expect(en.moreInvites(1), '+ 1 more invite');
    });
  });
}
