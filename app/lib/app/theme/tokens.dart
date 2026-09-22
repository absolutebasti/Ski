import 'package:flutter/material.dart';

/// Design tokens v2 "Instrument" (docs/DESIGN.md §2). Dark-first graphite,
/// one champagne accent, ice for live/GPS, danger for failure.
class Tokens {
  const Tokens._();

  // ---- Dark ramp ----
  static const bg = Color(0xFF0B0C0E);
  static const bgTop = Color(0xFF121316);
  static const ink = Color(0xFF07070A);
  static const surface = Color(0xFF16181C);
  static const surfaceRaised = Color(0xFF1D2026);
  static const hairline = Color(0xFF24272D);
  static const hairlineStrong = Color(0xFF31353D);
  static const textPrimary = Color(0xFFF6F4EE);
  static const textSecondary = Color(0xFFA2A7B0);
  static const textTertiary = Color(0xFF6A6F79);
  static const textQuaternary = Color(0xFF474C55);
  static const champagne = Color(0xFFE3C88C);
  static const champagneHi = Color(0xFFF2DDB0);
  static const champagnePressed = Color(0xFFC9AC6E);
  static const champagneDim = Color(0xFF8A7645);
  static const ice = Color(0xFF8FD8F5);
  static const iceDim = Color(0xFF2C5A6E);
  static const danger = Color(0xFFFF5A4A);
  static const dangerDim = Color(0xFF4A1C18);
  static const liftGrey = Color(0xFF5B616B);
  static const pauseColor = Color(0xFF24272D);

  // ---- Glare (live screen) ----
  static const glareBg = Color(0xFF000000);
  static const glareSurface = Color(0xFF0E0F11);
  static const glareAccent = Color(0xFFFFD98A);
  static const glareIce = Color(0xFFA8E4FB);

  // ---- Light ramp (cold snow) ----
  static const lightBg = Color(0xFFF4F2ED);
  static const lightBgTop = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFBFAF7);
  static const lightHairline = Color(0xFFE4E0D7);
  static const lightHairlineStrong = Color(0xFFD2CCBE);
  static const lightInk = Color(0xFF0E1013);
  static const lightSecondary = Color(0xFF5A5F68);
  static const lightTertiary = Color(0xFF8B9098);
  static const lightQuaternary = Color(0xFFAFB4BB);
  static const lightAccent = Color(0xFF7A5E1E);
  static const lightAccentPressed = Color(0xFF634C16);
  static const lightIce = Color(0xFF0A6E9E);
  static const lightDanger = Color(0xFFD6321F);
  static const lightLiftGrey = Color(0xFF8B9098);

  // ---- Brand field (icon, onboarding hero, share card only) ----
  static const cream = Color(0xFFF4F1EA);
  static const brandInk = Color(0xFF0A0B0E);

  // ---- Radii ----
  static const double r4 = 4, r10 = 10, r14 = 14, r20 = 20, r28 = 28, rPill = 999;
  /// Legacy names kept for older call sites.
  static const double radius = r20;
  static const double radiusLg = r28;

  // ---- Spacing (4 pt base) ----
  static const double grid = 4;
  static const double pad = 20;
  static const double cardPad = 18;
  static const double cardGap = 12;
  static const double sectionGap = 28;
  static const double minTarget = 56;
  static const double startButton = 76;
  static const double holdButton = 64;
  static const double hairlineWidthDark = 0.5;
  static const double hairlineWidthLight = 1.0;

  // ---- Motion ----
  static const countUp = Duration(milliseconds: 400);
  static const hold = Duration(milliseconds: 1200);
  static const pulse = Duration(milliseconds: 1200);
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const sheetUp = Duration(milliseconds: 320);
  static const routeDraw = Duration(milliseconds: 900);

  // ---- Elevation (L2 floating) ----
  static const double glassBlur = 30;
  static List<BoxShadow> get floatingShadow => const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 8), spreadRadius: -8)];

  /// Legacy gradient (onboarding hero / share card only — never on controls).
  static LinearGradient get champagneGradient => const LinearGradient(
        colors: [champagneHi, champagne, champagnePressed],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Semantic colours per brightness (and the glare variant for the live screen).
/// Read via `AppColors.of(context)`; features never use `Tokens.*` directly.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.bgTop,
    required this.ink,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.hairlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.accent,
    required this.accentPressed,
    required this.accentDim,
    required this.onAccent,
    required this.ice,
    required this.iceDim,
    required this.danger,
    required this.dangerDim,
    required this.liftGrey,
    required this.pause,
    required this.glassFill,
    required this.glassStroke,
    required this.hairlineWidth,
    required this.isDark,
  });

  final Color bg, bgTop, ink, surface, surfaceRaised, hairline, hairlineStrong;
  final Color textPrimary, textSecondary, textTertiary, textQuaternary;
  final Color accent, accentPressed, accentDim, onAccent, ice, iceDim, danger, dangerDim, liftGrey, pause;
  final Color glassFill, glassStroke;
  final double hairlineWidth;
  final bool isDark;

  // Semantic aliases
  Color get run => accent;
  Color get lift => liftGrey;
  Color get signalLoss => danger.withValues(alpha: 0.6);
  Color get accentWash => accent.withValues(alpha: 0.10);
  Color get accentGlow => accent.withValues(alpha: 0.18);
  Color get iceWash => ice.withValues(alpha: 0.12);
  Color get dangerWash => danger.withValues(alpha: 0.10);
  /// Legacy name.
  Color get elevated => surfaceRaised;

  static const dark = AppColors(
    bg: Tokens.bg, bgTop: Tokens.bgTop, ink: Tokens.ink, surface: Tokens.surface, surfaceRaised: Tokens.surfaceRaised,
    hairline: Tokens.hairline, hairlineStrong: Tokens.hairlineStrong,
    textPrimary: Tokens.textPrimary, textSecondary: Tokens.textSecondary, textTertiary: Tokens.textTertiary, textQuaternary: Tokens.textQuaternary,
    accent: Tokens.champagne, accentPressed: Tokens.champagnePressed, accentDim: Tokens.champagneDim, onAccent: Tokens.bg,
    ice: Tokens.ice, iceDim: Tokens.iceDim, danger: Tokens.danger, dangerDim: Tokens.dangerDim, liftGrey: Tokens.liftGrey, pause: Tokens.pauseColor,
    glassFill: Color(0x0EFFFFFF), glassStroke: Color(0x13FFFFFF), hairlineWidth: Tokens.hairlineWidthDark, isDark: true,
  );

  /// Pure-black high-contrast variant for the recording screen (sun glare).
  static const glare = AppColors(
    bg: Tokens.glareBg, bgTop: Tokens.glareBg, ink: Tokens.glareBg, surface: Tokens.glareSurface, surfaceRaised: Color(0xFF17191C),
    hairline: Color(0xFF2A2D33), hairlineStrong: Color(0xFF3A3E46),
    textPrimary: Color(0xFFFFFFFF), textSecondary: Color(0xFFB4B9C2), textTertiary: Color(0xFF7C818B), textQuaternary: Color(0xFF50555E),
    accent: Tokens.glareAccent, accentPressed: Tokens.champagnePressed, accentDim: Tokens.champagneDim, onAccent: Tokens.glareBg,
    ice: Tokens.glareIce, iceDim: Tokens.iceDim, danger: Tokens.danger, dangerDim: Tokens.dangerDim, liftGrey: Color(0xFF6B717B), pause: Color(0xFF2A2D33),
    glassFill: Color(0x14FFFFFF), glassStroke: Color(0x1AFFFFFF), hairlineWidth: Tokens.hairlineWidthDark, isDark: true,
  );

  static const light = AppColors(
    bg: Tokens.lightBg, bgTop: Tokens.lightBgTop, ink: Tokens.lightInk, surface: Tokens.lightSurface, surfaceRaised: Tokens.lightSurfaceRaised,
    hairline: Tokens.lightHairline, hairlineStrong: Tokens.lightHairlineStrong,
    textPrimary: Tokens.lightInk, textSecondary: Tokens.lightSecondary, textTertiary: Tokens.lightTertiary, textQuaternary: Tokens.lightQuaternary,
    accent: Tokens.lightAccent, accentPressed: Tokens.lightAccentPressed, accentDim: Tokens.champagneDim, onAccent: Color(0xFFFFFFFF),
    ice: Tokens.lightIce, iceDim: Tokens.iceDim, danger: Tokens.lightDanger, dangerDim: Tokens.dangerDim, liftGrey: Tokens.lightLiftGrey, pause: Tokens.lightHairline,
    glassFill: Color(0xB8FFFFFF), glassStroke: Color(0x1A000000), hairlineWidth: Tokens.hairlineWidthLight, isDark: false,
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? bg, Color? bgTop, Color? ink, Color? surface, Color? surfaceRaised, Color? hairline, Color? hairlineStrong,
    Color? textPrimary, Color? textSecondary, Color? textTertiary, Color? textQuaternary, Color? accent, Color? accentPressed,
    Color? accentDim, Color? onAccent, Color? ice, Color? iceDim, Color? danger, Color? dangerDim, Color? liftGrey, Color? pause,
    Color? glassFill, Color? glassStroke, double? hairlineWidth, bool? isDark,
  }) => AppColors(
        bg: bg ?? this.bg, bgTop: bgTop ?? this.bgTop, ink: ink ?? this.ink, surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised, hairline: hairline ?? this.hairline, hairlineStrong: hairlineStrong ?? this.hairlineStrong,
        textPrimary: textPrimary ?? this.textPrimary, textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary, textQuaternary: textQuaternary ?? this.textQuaternary,
        accent: accent ?? this.accent, accentPressed: accentPressed ?? this.accentPressed, accentDim: accentDim ?? this.accentDim,
        onAccent: onAccent ?? this.onAccent, ice: ice ?? this.ice, iceDim: iceDim ?? this.iceDim, danger: danger ?? this.danger,
        dangerDim: dangerDim ?? this.dangerDim, liftGrey: liftGrey ?? this.liftGrey, pause: pause ?? this.pause,
        glassFill: glassFill ?? this.glassFill, glassStroke: glassStroke ?? this.glassStroke,
        hairlineWidth: hairlineWidth ?? this.hairlineWidth, isDark: isDark ?? this.isDark,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg), bgTop: l(bgTop, other.bgTop), ink: l(ink, other.ink), surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised), hairline: l(hairline, other.hairline), hairlineStrong: l(hairlineStrong, other.hairlineStrong),
      textPrimary: l(textPrimary, other.textPrimary), textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary), textQuaternary: l(textQuaternary, other.textQuaternary),
      accent: l(accent, other.accent), accentPressed: l(accentPressed, other.accentPressed), accentDim: l(accentDim, other.accentDim),
      onAccent: l(onAccent, other.onAccent), ice: l(ice, other.ice), iceDim: l(iceDim, other.iceDim), danger: l(danger, other.danger),
      dangerDim: l(dangerDim, other.dangerDim), liftGrey: l(liftGrey, other.liftGrey), pause: l(pause, other.pause),
      glassFill: l(glassFill, other.glassFill), glassStroke: l(glassStroke, other.glassStroke),
      hairlineWidth: t < 0.5 ? hairlineWidth : other.hairlineWidth, isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
