import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/data/db/days_repository.dart';
import 'package:slopetrack/data/db/providers.dart';
import 'package:slopetrack/data/supabase/supabase_client.dart';
import 'package:slopetrack/data/sync/sync_service.dart';

import 'sync_fixtures.dart';

void main() {
  testWidgets('startAutoSync runs and disposes cleanly without a backend', (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    await seedFinishedDay(DaysRepository(db));

    final container = ProviderContainer(overrides: [
      supabaseProvider.overrideWithValue(null),
      databaseProvider.overrideWithValue(db),
    ]);
    container.read(autoSyncProvider);
    // the 30 s outbox poll must not throw while the backend is missing
    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));

    final service = container.read(syncServiceProvider);
    expect(service.current.state, SyncState.idle);
    expect(await service.pendingCount(), 1, reason: 'nothing can be pushed, the day stays queued');

    // disposing the container must cancel the poll timer
    container.dispose();
  });
}
