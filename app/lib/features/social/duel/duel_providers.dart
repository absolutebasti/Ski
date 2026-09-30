import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/auth_service.dart';
import '../social_api.dart';
import '../social_models.dart';
import 'duel_api.dart';
import 'duel_models.dart';

/// The Tagesduell of today the user is a member of — null when there is none.
final myDuelProvider = FutureProvider<DuelGroup?>((ref) async {
  final api = ref.watch(duelApiProvider);
  if (api == null || api.userId == null) return null;
  return api.myDuel(today());
}, retry: noRetry);

/// Board of one duel (RPC `group_board`, migration 0009 shape), sorted by
/// Höhenmeter; live rows carry `isLive`. Typed as the 0005 contract
/// (`List<GroupMemberStats>`) — every row is a [DuelMember].
final groupBoardProvider = FutureProvider.family<List<GroupMemberStats>, String>((ref, groupId) async {
  final api = ref.watch(duelApiProvider);
  if (api == null) throw const SocialError(SocialErrorKind.offline);
  return api.groupBoard(groupId);
}, retry: noRetry);

/// Pending in-app invites into somebody's Tagesduell (RPC `my_duel_invites`,
/// migration 0017), newest first. Empty while signed out, without a backend
/// or when the call fails — the invite card simply stays away. Refetched by
/// the `DuelCard` poll ([duelPollIntervalProvider]).
final duelInvitesProvider = FutureProvider<List<DuelInvite>>((ref) async {
  final api = ref.watch(duelApiProvider);
  if (api == null) return const <DuelInvite>[];
  // Keyed on the effective user id: a sign-in / sign-out refetches, the auth
  // stream's first emission of the same user does not (no double RPC).
  final uid = ref.watch(authStateProvider.select((a) => a.asData?.value?.id ?? api.userId));
  if (uid == null) return const <DuelInvite>[];
  try {
    return await api.myInvites();
  } on SocialError {
    return const <DuelInvite>[];
  }
}, retry: noRetry);

/// How often the duel board and the invites are refetched while the tab is
/// visible.
/// Override with `null` in widget tests so no timer outlives the test.
final duelPollIntervalProvider = Provider<Duration?>((ref) => const Duration(seconds: 60));

/// How often the live uploader writes the own `live_days` row while
/// recording inside a duel (a finished run writes at once). Override with a
/// short duration in tests.
final liveUploadIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 120));

/// The caller's duels, newest day first, with their boards (RPC `my_duels`).
/// Empty while signed out or without a backend.
final myDuelsProvider = FutureProvider<List<DuelSummary>>((ref) async {
  final api = ref.watch(duelApiProvider);
  if (api == null) return const <DuelSummary>[];
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null && api.userId == null) return const <DuelSummary>[];
  return api.myDuels();
}, retry: noRetry);

/// The duel whose day is the local date of [dayStartMs] — the Tagesbilanz
/// asks for the day it shows. Null when the user was in no duel that day.
/// autoDispose and its own fetch: the Tagesbilanz opens right after endDay and
/// must not show the Rangliste's cached board from earlier in the day.
final dayDuelProvider = FutureProvider.autoDispose.family<DuelSummary?, int>((ref, dayStartMs) async {
  final api = ref.watch(duelApiProvider);
  if (api == null || api.userId == null) return null;
  final t = DateTime.fromMillisecondsSinceEpoch(dayStartMs);
  final day = DateTime(t.year, t.month, t.day);
  for (final d in await api.myDuels(limit: 10)) {
    if (d.day == day) return d;
  }
  return null;
}, retry: noRetry);

/// IANA zone sent with `createDuel` (`groups.tz`). Dart has no IANA name of
/// its own; [guessIanaZone] maps the abbreviation/offset of the device clock.
/// The lead can override this with `flutter_timezone` once the package is in
/// (see the SOC-LIVE-DUEL report).
final deviceTimeZoneProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return guessIanaZone(now.timeZoneName, now.timeZoneOffset);
});

/// Best-effort IANA zone from what `DateTime` exposes. Central Europe (the
/// home market) is exact; the other entries cover the ski destinations the
/// resort database knows. Anything unknown becomes Europe/Vienna — the
/// server default, wrong only for riders far from the Alps whose duel day then
/// spans a shifted window (still a full local day, just Vienna's).
String guessIanaZone(String abbreviation, Duration offset) {
  const byName = <String, String>{
    'CET': 'Europe/Vienna',
    'CEST': 'Europe/Vienna',
    'MEZ': 'Europe/Vienna',
    'MESZ': 'Europe/Vienna',
    'GMT': 'Europe/London',
    'BST': 'Europe/London',
    'WET': 'Europe/Lisbon',
    'WEST': 'Europe/Lisbon',
    'EET': 'Europe/Helsinki',
    'EEST': 'Europe/Helsinki',
    'MSK': 'Europe/Moscow',
    'EST': 'America/New_York',
    'EDT': 'America/New_York',
    'CST': 'America/Chicago',
    'CDT': 'America/Chicago',
    'MST': 'America/Denver',
    'MDT': 'America/Denver',
    'PST': 'America/Los_Angeles',
    'PDT': 'America/Los_Angeles',
    'AKST': 'America/Anchorage',
    'AKDT': 'America/Anchorage',
    'JST': 'Asia/Tokyo',
    'KST': 'Asia/Seoul',
    'NZST': 'Pacific/Auckland',
    'NZDT': 'Pacific/Auckland',
    'AEST': 'Australia/Sydney',
    'AEDT': 'Australia/Sydney',
    'ART': 'America/Argentina/Buenos_Aires',
    'CLT': 'America/Santiago',
    'CLST': 'America/Santiago',
    'IST': 'Asia/Kolkata',
  };
  final named = byName[abbreviation.toUpperCase()];
  if (named != null) return named;
  // iOS often reports the zone name as 'GMT+1' / 'UTC-7' style: fall back to
  // a representative zone per offset (whole minutes, so 5:30 stays distinct).
  return switch (offset.inMinutes) {
    -600 => 'Pacific/Honolulu',
    -540 => 'America/Anchorage',
    -480 => 'America/Los_Angeles',
    -420 => 'America/Denver',
    -360 => 'America/Chicago',
    -300 => 'America/New_York',
    -240 => 'America/Santiago',
    -180 => 'America/Argentina/Buenos_Aires',
    0 => 'Europe/London',
    60 || 120 => 'Europe/Vienna',
    180 => 'Europe/Moscow',
    330 => 'Asia/Kolkata',
    540 => 'Asia/Tokyo',
    600 || 660 => 'Australia/Sydney',
    720 || 780 => 'Pacific/Auckland',
    _ => 'Europe/Vienna',
  };
}

/// Drops every cached duel result — after create / join / leave and after a
/// day was ended (the finished day replaces the live row).
void invalidateDuels(WidgetRef ref) {
  ref.invalidate(myDuelProvider);
  ref.invalidate(groupBoardProvider);
  ref.invalidate(myDuelsProvider);
  ref.invalidate(dayDuelProvider);
  ref.invalidate(duelInvitesProvider);
}
