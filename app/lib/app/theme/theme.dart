import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
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
    extensions: [c],
    textTheme: TextTheme(
      displayLarge: AppText.hero(c.textPrimary),
      headlineMedium: AppText.headline(c.textPrimary),
      titleLarge: AppText.title(c.textPrimary),
      bodyLarge: AppText.bodyText(c.textPrimary),
      bodyMedium: AppText.bodyText(c.textSecondary, size: 15),
      labelSmall: AppText.label(c.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.headline(c.textPrimary, size: 24),
      systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.elevated,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => AppText.label(s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary, size: 12),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary, size: 26),
      ),
    ),
    dividerColor: c.hairline,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusLg))),
      showDragHandle: true,
      dragHandleColor: c.hairline,
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.elevated, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius))),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.elevated,
      contentTextStyle: AppText.bodyText(c.textPrimary, size: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.elevated),
    ),
  );
}
