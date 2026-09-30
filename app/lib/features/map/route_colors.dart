import 'package:flutter/material.dart';

/// Ground colour under every drawn route (list thumbnail, hero flight, contour
/// fallback, PNG). Dark: graphite #101216, darker than `surface` so the route
/// dominates. Light: warm paper #EDEAE2 under the dark champagne `run`.
///
/// The PNG is rendered at End, where there is no [BuildContext] and therefore
/// no `AppColors.of(context)` — these constants are the headless mirror of the
/// two themes and must stay in sync with `AppColors.dark` / `AppColors.light`.
class RouteColors {
  const RouteColors._();

  static const Color darkGround = Color(0xFF101216);
  static const Color lightGround = Color(0xFFEDEAE2);

  /// Route line of the light theme: the darker champagne, readable on paper.
  static const Color lightRun = Color(0xFF8B6C1F);
  static const Color lightLift = Color(0xFF9AA0A6);

  /// Relative luminance above this reads as "not near-black" (light golden guard).
  static bool isNearBlack(Color c) => c.computeLuminance() < 0.05;
}
