import 'package:flutter/material.dart';

/// Inter for UI, InterDisplay for big numbers and headlines. Numbers are tabular.
class AppText {
  const AppText._();

  static const String display = 'InterDisplay';
  static const String body = 'Inter';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle hero(Color c, {double size = 88}) => TextStyle(
      fontFamily: display, fontSize: size, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -size * 0.03,
      color: c, fontFeatures: tabular);

  static TextStyle stat(Color c, {double size = 34}) => TextStyle(
      fontFamily: display, fontSize: size, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -0.8,
      color: c, fontFeatures: tabular);

  static TextStyle headline(Color c, {double size = 28}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5, color: c);

  static TextStyle title(Color c, {double size = 20}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w700, height: 1.2, color: c);

  static TextStyle bodyText(Color c, {double size = 17, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: weight, height: 1.35, color: c);

  static TextStyle label(Color c, {double size = 11}) => TextStyle(
      fontFamily: body, fontSize: size, fontWeight: FontWeight.w600, letterSpacing: size * 0.06, height: 1.2, color: c);

  static TextStyle unit(Color c, {double size = 15}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w600, height: 1.0, color: c);

  static TextStyle button(Color c, {double size = 18}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w800, height: 1.0, color: c);
}
