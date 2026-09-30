import '../social_api.dart';
import 'teaser_api.dart';
import 'teaser_models.dart';

/// In-memory [TeaserApi] for widget tests, previews and the demo mode. Every
/// call is recorded so a test can assert what the screen asked for.
class FakeTeaserApi implements TeaserApi {
  FakeTeaserApi({this.entries = const [], this.entriesFor, this.failWith});

  /// Ten riders, rank 1…10, points descending from 4.200 in steps of 300.
  factory FakeTeaserApi.topTen() => FakeTeaserApi(entries: sample());

  /// Rows returned for every query unless [entriesFor] answers first.
  List<TeaserEntry> entries;

  /// Per-query rows; return null to fall back to [entries].
  final List<TeaserEntry>? Function(TeaserQuery query)? entriesFor;

  /// When set, every call throws it — the offline / failed state.
  SocialError? failWith;

  /// Queries `topTen` was asked for.
  final List<TeaserQuery> calls = [];

  static const List<String> _names = [
    'Lena Bergmann',
    'Paul Moser',
    'Nina Aigner',
    'Tom Huber',
    'Mara Keller',
    'Jonas Falk',
    'Eva Lindner',
    'Felix Brandt',
    'Clara Vogt',
    'Max Steiner',
  ];

  /// [n] rows (capped at ten) in rank order.
  static List<TeaserEntry> sample([int n = kTeaserLimit]) => [
        for (var i = 0; i < n && i < _names.length; i++) TeaserEntry(rank: i + 1, displayName: _names[i], value: 4200 - i * 300),
      ];

  @override
  Future<List<TeaserEntry>> topTen(TeaserQuery query) async {
    calls.add(query);
    final f = failWith;
    if (f != null) throw f;
    final rows = entriesFor?.call(query) ?? entries;
    return rows.length > kTeaserLimit ? rows.sublist(0, kTeaserLimit) : rows;
  }
}
