import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// Builds the Material theme from the semantic colours. Dark is the default;
/// [AppColors.glare] wraps the live screen via [glareTheme].
ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return _build(c, brightness);
}

/// Pure-black high-contrast theme for the recording screen.
ThemeData glareTheme() => _build(AppColors.glare, Brightness.dark);

ThemeData _build(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.ice,
    onSecondary: Tokens.ink,
    error: c.danger,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.textPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: AppText.body,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [c],
    textTheme: TextTheme(
      displayLarge: AppText.numXl(c.textPrimary),
      headlineMedium: AppText.headline(c.textPrimary),
      titleLarge: AppText.title(c.textPrimary),
      bodyLarge: AppText.bodyText(c.textPrimary),
      bodyMedium: AppText.bodyText(c.textSecondary, size: 15),
      labelSmall: AppText.label(c.textTertiary),
    ),
    iconTheme: IconThemeData(color: c.textTertiary, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.displayTitle(c.textPrimary, size: 24),
      systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    dividerColor: c.hairline,
    dividerTheme: DividerThemeData(color: c.hairline, thickness: c.hairlineWidth, space: c.hairlineWidth),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.r20)),
      titleTextStyle: AppText.headline(c.textPrimary),
      contentTextStyle: AppText.bodyText(c.textSecondary, size: 15),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceRaised,
      contentTextStyle: AppText.bodyText(c.textPrimary, size: 15, weight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.rPill)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceRaised),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : c.hairlineStrong),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent, textStyle: AppText.button(c.accent, size: 16)),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.textTertiary, textColor: c.textPrimary),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: c.surface, indicatorColor: Colors.transparent),
  );
}
