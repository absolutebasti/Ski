import 'package:flutter/material.dart';

/// Type scale v2 (docs/DESIGN.md §3). InterDisplay 900 is the numeral face;
/// every numeric style is tabular. The overline label always sits ABOVE a numeral.
class AppText {
  const AppText._();

  static const String display = 'InterDisplay';
  static const String body = 'Inter';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle _num(Color c, double size, {FontWeight weight = FontWeight.w900, double height = 0.94, double track = -0.03}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: weight, height: height, letterSpacing: size * track, color: c, fontFeatures: tabular);

  // Numerals
  static TextStyle numXxl(Color c) => _num(c, 92, height: 0.88, track: -0.045);
  static TextStyle numXl(Color c) => _num(c, 64, height: 0.90, track: -0.040);
  static TextStyle numL(Color c) => _num(c, 44, height: 0.94, track: -0.032);
  static TextStyle numM(Color c) => _num(c, 34, weight: FontWeight.w800, height: 0.96, track: -0.028);
  static TextStyle numS(Color c) => _num(c, 22, weight: FontWeight.w800, height: 1.0, track: -0.018);
  static TextStyle numXs(Color c) => _num(c, 15, weight: FontWeight.w800, height: 1.0, track: -0.010);

  /// Unit next to a numeral: 0.30 × numeral size, clamped 11–26, Inter 600.
  static TextStyle unit(Color c, {double size = 15}) =>
      TextStyle(fontFamily: body, fontSize: size.clamp(11, 26).toDouble(), fontWeight: FontWeight.w600, height: 1.0, color: c);
  static double unitFor(double numeralSize) => (numeralSize * 0.30).clamp(11, 26).toDouble();

  // Display / headings
  static TextStyle displayTitle(Color c, {double size = 30}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -size * 0.020, color: c);
  static TextStyle displayS(Color c) => displayTitle(c, size: 19);
  static TextStyle headline(Color c, {double size = 22}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -size * 0.015, color: c);
  static TextStyle headlineL(Color c) =>
      TextStyle(fontFamily: display, fontSize: 34, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -34 * 0.025, color: c);
  static TextStyle title(Color c, {double size = 17}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w700, height: 1.25, color: c);
  static TextStyle bodyText(Color c, {double size = 16, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: weight, height: 1.45, color: c);
  static TextStyle bodyStrong(Color c, {double size = 16}) => bodyText(c, size: size, weight: FontWeight.w600);
  static TextStyle caption(Color c, {double size = 13.5}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w500, height: 1.35, color: c);
  /// The overline: 11 pt, +0.10 em, uppercase (callers pass uppercase text).
  static TextStyle label(Color c, {double size = 11}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w700, letterSpacing: size * 0.10, height: 1.1, color: c);
  static TextStyle button(Color c, {double size = 17}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: size * 0.01, color: c);

  // ---- Legacy names (v1 call sites) ----
  static TextStyle hero(Color c, {double size = 88}) => _num(c, size, height: 0.9, track: -0.04);
  static TextStyle stat(Color c, {double size = 34}) => numM(c).copyWith(fontSize: size, letterSpacing: -size * 0.028);
}

/// Overline casing: uppercase with German ß → SS (Dart's toUpperCase keeps ß).
extension OverlineCase on String {
  String get overline => replaceAll('ß', 'SS').replaceAll('ẞ', 'SS').toUpperCase();
}
