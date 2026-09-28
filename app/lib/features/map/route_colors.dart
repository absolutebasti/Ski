import 'package:flutter/material.dart';


/// Ground colour under every drawn route (list thumbnail, hero flight, contour
/// fallback, PNG). Dark: graphite #101216, darker than `surface` so the route
/// dominates. Light: warm paper #EDEAE2 under the dark champagne `run`.
///

class RouteColors {
  const RouteColors._();

  static const Color darkGround = Color(0xFF101216);
  static const Color lightGround = Color(0xFFEDEAE2);

  /// Relative luminance above this reads as "not near-black" (light golden guard).
  static bool isNearBlack(Color c) => c.computeLuminance() < 0.05;
}
