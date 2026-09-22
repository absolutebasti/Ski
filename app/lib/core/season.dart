/// Ski seasons run 1 July – 30 June; key '2025/26'.
String seasonKey(DateTime t) {
  final startYear = t.month >= 7 ? t.year : t.year - 1;
  return '$startYear/${(startYear + 1) % 100}'.replaceFirstMapped(RegExp(r'/(\d)$'), (m) => '/0${m[1]}');
}

String seasonKeyFromMs(int ts) => seasonKey(DateTime.fromMillisecondsSinceEpoch(ts));

DateTime seasonStart(DateTime t) => DateTime(t.month >= 7 ? t.year : t.year - 1, 7, 1);
