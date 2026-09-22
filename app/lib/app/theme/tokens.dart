import 'package:flutter/material.dart';

/// Design tokens (docs/PLAN.md §11). Graphite surfaces, cream text, one champagne accent.
class Tokens {
  const Tokens._();

  // Dark (default)
  static const bg = Color(0xFF0B0B0C);
  static const surface = Color(0xFF141416);
  static const elevated = Color(0xFF1E1E21);
  static const hairline = Color(0xFF2A2A2E);
  static const textPrimary = Color(0xFFF5F2EA);
  static const textSecondary = Color(0xFF9A9A9F);
  static const textTertiary = Color(0xFF5C5C62);
  static const champagne = Color(0xFFD9C39A);
  static const champagnePressed = Color(0xFFC4AC80);
  static const champagneSoft = Color(0xFFEFE3C6);
  static const ice = Color(0xFFBFE3F2);
  static const danger = Color(0xFFFF5A4A);
  static const liftGrey = Color(0xFF6B6B70);
  static const ink = Color(0xFF0A0B0E);

  // Light
  static const lightBg = Color(0xFFF5F2EA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFF0ECE2);
  static const lightHairline = Color(0xFFE2DDD2);
  static const lightInk = Color(0xFF101012);
  static const lightSecondary = Color(0xFF6B6B70);
  static const lightTertiary = Color(0xFF9A9A9F);
  static const lightChampagne = Color(0xFF8E6F2E);
  static const lightIce = Color(0xFF0E7BB0);

  // Layout
  static const double grid = 8;
  static const double pad = 20;
  static const double radius = 16;
  static const double radiusLg = 24;
  static const double minTarget = 56;
  static const double startButton = 72;
  static const double holdButton = 64;

  // Motion
  static const countUp = Duration(milliseconds: 400);
  static const hold = Duration(milliseconds: 1200);
  static const pulse = Duration(milliseconds: 1200);
  static const fast = Duration(milliseconds: 180);

  static LinearGradient get champagneGradient => const LinearGradient(
        colors: [champagneSoft, champagne, champagnePressed],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Semantic colours that depend on brightness; read via `AppColors.of(context)`.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.ice,
    required this.danger,
    required this.liftGrey,
    required this.run,
  });

  final Color bg, surface, elevated, hairline, textPrimary, textSecondary, textTertiary;
  final Color accent, accentPressed, onAccent, ice, danger, liftGrey, run;

  static const dark = AppColors(
    bg: Tokens.bg, surface: Tokens.surface, elevated: Tokens.elevated, hairline: Tokens.hairline,
    textPrimary: Tokens.textPrimary, textSecondary: Tokens.textSecondary, textTertiary: Tokens.textTertiary,
    accent: Tokens.champagne, accentPressed: Tokens.champagnePressed, onAccent: Tokens.ink,
    ice: Tokens.ice, danger: Tokens.danger, liftGrey: Tokens.liftGrey, run: Tokens.champagne,
  );

  static const light = AppColors(
    bg: Tokens.lightBg, surface: Tokens.lightSurface, elevated: Tokens.lightElevated, hairline: Tokens.lightHairline,
    textPrimary: Tokens.lightInk, textSecondary: Tokens.lightSecondary, textTertiary: Tokens.lightTertiary,
    accent: Tokens.lightChampagne, accentPressed: Tokens.champagnePressed, onAccent: Tokens.lightBg,
    ice: Tokens.lightIce, danger: Tokens.danger, liftGrey: Tokens.liftGrey, run: Tokens.lightChampagne,
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({Color? bg}) => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : (other ?? this);
}
