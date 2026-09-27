import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/db/database.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/sync/remote_day.dart';

import 'sync_fixtures.dart';

void main() {
  late AppDatabase db;
  late DaysRepository repo;

  setUp(() {
    db = memoryDb();
    repo = DaysRepository(db);
  });
  tearDown(() => db.close());

  test('country_code travels with the day and is normalised to alpha-2 upper case', () async {
    await seedFinishedDay(repo);
    final row = await (db.select(db.days)..where((d) => d.id.equals('d1'))).getSingle();

    final at = dayRowToRemote(row, userId: 'u1', deviceUpdatedAtMs: 1, countryCode: 'at');
    expect(at['country_code'], 'AT');
    expect(at.containsKey('points'), isFalse, reason: 'points is a generated server column');

    final none = dayRowToRemote(row, userId: 'u1', deviceUpdatedAtMs: 1);
    expect(none.containsKey('country_code'), isTrue, reason: 'null clears a stale team on the server');
    expect(none['country_code'], isNull);

    expect(dayRowToRemote(row, userId: 'u1', deviceUpdatedAtMs: 1, countryCode: 'AUT')['country_code'], isNull);
  });

  test('normaliseCountryCode / remoteCountryCode', () {
    expect(normaliseCountryCode(' ch '), 'CH');
    expect(normaliseCountryCode(''), isNull);
    expect(normaliseCountryCode(null), isNull);
    expect(normaliseCountryCode('A'), isNull);
    expect(remoteCountryCode({'country_code': 'de'}), 'DE');
    expect(remoteCountryCode(const {}), isNull);
  });

  test('round-trip: a remote row with country_code merges into the local db', () async {
    final remote = remoteRow(id: 'r1', deviceUpdatedAt: sampleStartedAt + 1000, countryCode: 'AT');
    expect(remoteCountryCode(remote), 'AT');
    expect(await repo.upsertFromRemote(remote), isTrue);

    final row = await (db.select(db.days)..where((d) => d.id.equals('r1'))).getSingle();
    expect(row.resortId, 'kitzbuehel');
    // Pushing it back out resolves the team from the resort again.
    final out = dayRowToRemote(row, userId: 'u1', deviceUpdatedAtMs: 2, countryCode: 'AT');
    expect(out['country_code'], 'AT');
    expect(out['id'], 'r1');
  });
}
