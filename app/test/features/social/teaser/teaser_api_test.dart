
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/social_api.dart';
import 'package:slopetrack/features/social/teaser/teaser.dart';

const _kitz = TeaserQuery(seasonKey: '2025/26', resortId: 'kitzbuehel');
const _all = TeaserQuery(seasonKey: '2025/26');

void main() {
  group('FakeTeaserApi', () {
    test('records the queries and answers with its rows', () async {
      final api = FakeTeaserApi.topTen();
      final rows = await api.topTen(_kitz);
      expect(rows, hasLength(10));
      expect(rows.first.rank, 1);
      expect(rows.last.rank, 10);
      expect(rows.first.value, greaterThan(rows.last.value));
      expect(api.calls, [_kitz]);
    });

    test('entriesFor answers per query, more than ten rows are cut like the server does', () async {
      final api = FakeTeaserApi(
        entries: FakeTeaserApi.sample(2),
        entriesFor: (q) => q.resortId == null ? [for (var i = 1; i <= 12; i++) TeaserEntry(rank: i, displayName: 'R$i', value: 100.0 - i)] : null,
      );
      expect(await api.topTen(_kitz), hasLength(2));
      expect(await api.topTen(_all), hasLength(10));
    });

    test('failWith throws the SocialError', () async {
      final api = FakeTeaserApi(failWith: const SocialError(SocialErrorKind.offline));
      await expectLater(api.topTen(_kitz), throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.offline)));
      expect(api.calls, [_kitz]);
    });
  });

  group('ThrottledTeaserApi', () {
    test('a second call for the same query inside a second reuses the first', () async {
      var now = DateTime(2026, 1, 15, 9);
      final inner = FakeTeaserApi.topTen();
      final api = ThrottledTeaserApi(inner, clock: () => now);

      final a = api.topTen(_kitz);
      now = now.add(const Duration(milliseconds: 400));
      final b = api.topTen(_kitz);
      expect(identical(a, b), isTrue);
      expect(await b, hasLength(10));
      expect(inner.calls, hasLength(1));

      now = now.add(const Duration(milliseconds: 700));
      await api.topTen(_kitz);
      expect(inner.calls, hasLength(2), reason: '1,1 s after the first call');
    });

    test('another query is not held back', () async {
      final now = DateTime(2026, 1, 15, 9);
      final inner = FakeTeaserApi.topTen();
      final api = ThrottledTeaserApi(inner, clock: () => now);
      await api.topTen(_kitz);
      await api.topTen(_all);
      await api.topTen(_all);
      expect(inner.calls, [_kitz, _all]);
    });

    test('a failure is shared inside the window and retried after it', () async {
      var now = DateTime(2026, 1, 15, 9);
      final inner = FakeTeaserApi(entries: FakeTeaserApi.sample(), failWith: const SocialError(SocialErrorKind.offline));
      final api = ThrottledTeaserApi(inner, clock: () => now);
      await expectLater(api.topTen(_kitz), throwsA(isA<SocialError>()));
      await expectLater(api.topTen(_kitz), throwsA(isA<SocialError>()));
      expect(inner.calls, hasLength(1));

      inner.failWith = null;
      now = now.add(const Duration(seconds: 2));
      expect(await api.topTen(_kitz), hasLength(10));
      expect(inner.calls, hasLength(2));
    });

    test('a clock that jumps backwards does not pin a stale answer', () async {
      var now = DateTime(2026, 1, 15, 9);
      final inner = FakeTeaserApi.topTen();
      final api = ThrottledTeaserApi(inner, clock: () => now);
      await api.topTen(_kitz);
      now = now.subtract(const Duration(hours: 1));
      await api.topTen(_kitz);
      expect(inner.calls, hasLength(2));
    });
  });

  group('teaserProvider', () {
    test('without a backend it fails as offline and does not retry', () async {
      final container = ProviderContainer(overrides: [teaserApiProvider.overrideWithValue(null)]);
      addTearDown(container.dispose);
      final sub = container.listen(teaserProvider(_kitz), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(teaserProvider(_kitz).future),
        throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.offline)),
      );
    });

    test('hands the query to the api and caches per query', () async {
      final api = FakeTeaserApi.topTen();
      final container = ProviderContainer(overrides: [teaserApiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
      final sub = container.listen(teaserProvider(_kitz), (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(teaserProvider(_kitz).future), hasLength(10));
      expect(await container.read(teaserProvider(_kitz).future), hasLength(10));
      expect(api.calls, [_kitz]);

      container.invalidate(teaserProvider);
      expect(await container.read(teaserProvider(_kitz).future), hasLength(10));
      expect(api.calls, [_kitz, _kitz], reason: 'pull-to-refresh drops the cache');
    });

    test('a failing api surfaces the SocialError once', () async {
      final api = FakeTeaserApi(failWith: const SocialError(SocialErrorKind.rateLimited));
      final container = ProviderContainer(overrides: [teaserApiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
      final sub = container.listen(teaserProvider(_kitz), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(teaserProvider(_kitz).future),
        throwsA(isA<SocialError>().having((e) => e.kind, 'kind', SocialErrorKind.rateLimited)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.calls, hasLength(1), reason: 'noRetry');
    });
  });
}
