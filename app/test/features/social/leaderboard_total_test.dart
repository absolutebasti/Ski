import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/social/social_models.dart';

void main() {
  test('MyRank uses the server participant count when the RPC provides it', () {
    final entries = [
      LeaderboardEntry.fromJson({'rank': 1, 'user_id': 'a', 'display_name': 'A', 'value': 9000.0, 'total': 250}),
      LeaderboardEntry.fromJson({'rank': 14, 'user_id': 'me', 'display_name': 'Me', 'value': 1200.0, 'total': 250}),
    ];
    expect(myRankOf(entries, 'me'), const MyRank(rank: 14, total: 250, value: 1200));
  });

  test('without a total the fetched slice size is the fallback', () {
    final entries = [
      LeaderboardEntry.fromJson({'rank': 1, 'user_id': 'a', 'display_name': 'A', 'value': 9000.0}),
      LeaderboardEntry.fromJson({'rank': 2, 'user_id': 'me', 'display_name': 'Me', 'value': 1200.0}),
    ];
    expect(myRankOf(entries, 'me')!.total, 2);
  });
}
