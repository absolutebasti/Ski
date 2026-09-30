import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slopetrack/features/social/duel/duel.dart';
import 'package:slopetrack/features/social/social.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseDuelApi against a recording HTTP client: which RPC is called with
/// which parameters, how the rows are parsed and how the 0014 / 0017 errors
/// map. No network, no Supabase.initialize.

const _uid = 'a0000000-0000-4000-8000-000000000001';

/// One recorded PostgREST call.
typedef _Call = ({String method, String path, Object? body});

String _segment(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// An unsigned JWT that expires in 2100 — enough for `recoverSession`.
String _jwt() => '${_segment({'alg': 'HS256', 'typ': 'JWT'})}.${_segment({'sub': _uid, 'exp': 4102444800, 'role': 'authenticated'})}.sig';

Future<(SupabaseDuelApi, List<_Call>, SupabaseClient)> _api(
  http.Response Function(http.Request request) respond, {
  bool signedIn = true,
}) async {
  final calls = <_Call>[];
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: MockClient((request) async {
      calls.add((method: request.method, path: request.url.path, body: request.body.isEmpty ? null : jsonDecode(request.body)));
      return respond(request);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  if (signedIn) {
    await client.auth.recoverSession(jsonEncode({
      'access_token': _jwt(),
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh',
      'user': {'id': _uid, 'aud': 'authenticated', 'app_metadata': <String, Object?>{}, 'user_metadata': <String, Object?>{}, 'created_at': '2026-01-01T00:00:00Z'},
    }));
  }
  addTearDown(client.dispose);
  return (SupabaseDuelApi(client), calls, client);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'}, request: http.Request('POST', Uri.parse('https://example.supabase.co')));

http.Response _error(String code, String message, [int status = 400]) => _json({'code': code, 'message': message, 'details': null, 'hint': null}, status);

const _groupRow = {
  'id': 'g-1',
  'code': 'KMJ4F2',
  'name': 'Hahnenkamm-Crew',
  'day': '2026-01-15',
  'resort_id': null,
  'created_by': _uid,
  'max_members': 3,
  'tz': 'Europe/Vienna',
};

void main() {
  test('createDuel is one create_duel RPC with p_name, p_day (yyyy-MM-dd), p_tz, p_resort_id', () async {
    final (api, calls, _) = await _api((_) => _json([_groupRow]));
    expect(api.userId, _uid);
    expect(api.supportsInvites, isTrue);

    final group = await api.createDuel(name: 'Hahnenkamm-Crew', day: DateTime(2026, 1, 15, 14, 30), tz: 'Europe/Vienna', resortId: 'kitzbuehel');

    expect(calls, hasLength(1), reason: 'no direct insert into groups / group_members any more');
    expect(calls.single.method, 'POST');
    expect(calls.single.path, '/rest/v1/rpc/create_duel');
    expect(calls.single.body, {'p_name': 'Hahnenkamm-Crew', 'p_day': '2026-01-15', 'p_tz': 'Europe/Vienna', 'p_resort_id': 'kitzbuehel'});
    expect(group.id, 'g-1');
    expect(group.code, 'KMJ4F2');
    expect(group.name, 'Hahnenkamm-Crew');
    expect(group.day, DateTime(2026, 1, 15));
    expect(group.maxMembers, 3);
  });

  test('createDuel signed out throws notSignedIn without a request', () async {
    final (api, calls, _) = await _api((_) => _json([_groupRow]), signedIn: false);
    await expectLater(
      api.createDuel(name: 'x', day: DateTime(2026, 1, 15), tz: 'Europe/Vienna'),
      throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.notSignedIn)),
    );
    expect(calls, isEmpty);
    expect(await api.myInvites(), isEmpty, reason: 'my_duel_invites is not called while signed out');
    expect(calls, isEmpty);
  });

  test('inviteToDuel calls invite_to_duel(p_user_id, p_group_id) and reads the bare invite row', () async {
    final (api, calls, _) = await _api((_) => _json([
          {'id': 'inv-1', 'from_user': _uid, 'to_user': 'u9', 'group_id': 'g-1', 'day': '2026-01-15', 'status': 'pending', 'created_at': '2026-01-15T08:00:00Z'},
        ]));

    final invite = await api.inviteToDuel(userId: 'u9', groupId: 'g-1');

    expect(calls.single.path, '/rest/v1/rpc/invite_to_duel');
    expect(calls.single.body, {'p_user_id': 'u9', 'p_group_id': 'g-1'});
    expect(invite.id, 'inv-1');
    expect(invite.fromUserId, _uid);
    expect(invite.group.id, 'g-1');
    expect(invite.group.day, DateTime(2026, 1, 15));
  });

  test('invite errors map: already_member, duel_full, duel_expired, rider_not_found, not_a_member, rate_limited', () async {
    const cases = {
      ('23505', 'already_member'): SocialErrorKind.alreadyMember,
      ('P0003', 'duel_full'): SocialErrorKind.duelFull,
      ('P0006', 'duel_expired'): SocialErrorKind.duelExpired,
      ('P0002', 'rider_not_found'): SocialErrorKind.riderNotFound,
      ('42501', 'not_a_member'): SocialErrorKind.notAMember,
      ('P0005', 'rate_limited'): SocialErrorKind.rateLimited,
    };
    for (final MapEntry(key: (code, message), value: kind) in cases.entries) {
      final (api, _, _) = await _api((_) => _error(code, message));
      await expectLater(
        api.inviteToDuel(userId: 'u9', groupId: 'g-1'),
        throwsA(isA<SocialError>().having((e) => e.kind, 'kind', kind)),
        reason: message,
      );
    }
  });

  test('respondInvite accept returns the group of respond_duel_invite; decline returns null', () async {
    final (api, calls, _) = await _api((request) => (jsonDecode(request.body) as Map)['p_accept'] == true ? _json([_groupRow]) : _json(<Object>[]));

    final joined = await api.respondInvite('inv-1', accept: true);
    expect(calls.last.path, '/rest/v1/rpc/respond_duel_invite');
    expect(calls.last.body, {'p_id': 'inv-1', 'p_accept': true});
    expect(joined?.id, 'g-1');
    expect(joined?.code, 'KMJ4F2');

    expect(await api.respondInvite('inv-2', accept: false), isNull);
    expect(calls.last.body, {'p_id': 'inv-2', 'p_accept': false});
  });

  test('respondInvite: invite_not_found carries its detail, duel_full stays duelFull', () async {
    final (gone, _, _) = await _api((_) => _error('P0002', 'invite_not_found'));
    await expectLater(
      gone.respondInvite('inv-1', accept: true),
      throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.riderNotFound).having((e) => e.detail, 'detail', inviteNotFound)),
    );
    final (full, _, _) = await _api((_) => _error('P0003', 'duel_full'));
    await expectLater(
      full.respondInvite('inv-1', accept: true),
      throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.duelFull)),
    );
  });

  test('myInvites calls my_duel_invites and parses sender, group and member count', () async {
    final (api, calls, _) = await _api((_) => _json([
          {
            'id': 'inv-1',
            'from_user': 'u9',
            'from_name': 'Lena',
            'from_avatar_url': 'https://example.org/lena.jpg',
            'group_id': 'g-9',
            'code': 'PQRS23',
            'name': 'Hahnenkamm-Crew',
            'day': '2026-01-15',
            'tz': 'Europe/Zurich',
            'member_count': 2,
            'max_members': 3,
            'created_at': '2026-01-15T08:00:00+00:00',
          },
        ]));

    final invites = await api.myInvites();

    expect(calls.single.path, '/rest/v1/rpc/my_duel_invites');
    final invite = invites.single;
    expect(invite.id, 'inv-1');
    expect(invite.fromUserId, 'u9');
    expect(invite.fromName, 'Lena');
    expect(invite.fromAvatarUrl, 'https://example.org/lena.jpg');
    expect(invite.group.id, 'g-9');
    expect(invite.group.code, 'PQRS23');
    expect(invite.group.name, 'Hahnenkamm-Crew');
    expect(invite.group.day, DateTime(2026, 1, 15));
    expect(invite.group.createdBy, 'u9');
    expect(invite.group.maxMembers, 3);
    expect(invite.tz, 'Europe/Zurich');
    expect(invite.memberCount, 2);
    expect(invite.full, isFalse);
    expect(invite.createdAtMs, DateTime.utc(2026, 1, 15, 8).millisecondsSinceEpoch);
  });
}
