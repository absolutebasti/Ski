import 'package:intl/intl.dart';

/// Locale-aware number/time formatting. All inputs are SI.
class Fmt {
  const Fmt._();

  static String _n(num v, int decimals, [String? locale]) =>
      NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals).format(v);

  /// '61' or '61,4' (km/h) from m/s.
  static String kmh(double ms, {int decimals = 0, String? locale}) => _n(ms * 3.6, decimals, locale);

  /// '1.804' (metres, thousands separator).
  static String metres(double m, {String? locale}) => _n(m.round(), 0, locale);

  /// '12,4' (km, one decimal).
  static String km(double m, {int decimals = 1, String? locale}) => _n(m / 1000, decimals, locale);

  /// '5h 37' / '48 min' / '0:37' style, compact.
  static String durationCompact(int ms, {String? locale}) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}';
    if (m > 0) return '$m min';
    return '${s % 60} s';
  }

  /// 'h:mm:ss' running clock.
  static String clock(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// '10:42'.
  static String timeOfDay(int ts, {String? locale}) =>
      DateFormat.Hm(locale).format(DateTime.fromMillisecondsSinceEpoch(ts));

  /// 'Sa., 27. Dez.' (de) / 'Sat, Dec 27' (en).
  static String dateShort(int ts, {String? locale}) =>
      DateFormat.MMMEd(locale).format(DateTime.fromMillisecondsSinceEpoch(ts));

  /// '27. Dezember 2025'.
  static String dateLong(int ts, {String? locale}) =>
      DateFormat.yMMMMd(locale).format(DateTime.fromMillisecondsSinceEpoch(ts));

  /// '14 %'.
  static String percent(double pct, {String? locale}) => '${_n(pct.round(), 0, locale)} %';

  /// '−4°'.
  static String temp(double c) => '${c.round() < 0 ? '−' : ''}${c.round().abs()}°';
}
