import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../app/widgets/numbers.dart' show HeroNumber;

/// MapKit stamps the Apple Maps wordmark into the bottom-left corner of every
/// snapshot (measured on iOS 26 at 2×: ≈ 49×15 pt, 15 pt from the left edge,
/// 11 pt from the bottom). Apple's terms forbid removing or obscuring it, so
/// every layout over a snapshot shows the image's bottom-left corner uncropped,
/// keeps [clearance] pt above the image bottom free of text and opens its
/// scrim over the box (≤ 0.5 opacity, see [WordmarkScrim]).
class AppleWordmark {
  const AppleWordmark._();

  /// The wordmark box in image points from the bottom-left, padded ~1 pt.
  static const double left = 14, bottom = 10, width = 52, height = 17;

  /// Image points above the bottom edge that stay free of text: the box top
  /// plus the scrim window's margin (3 pt + blur), so no text sits in it.
  static const double clearance = bottom + height + 7;

  /// The box on screen for an image drawn into [image] at [scale] screen pt
  /// per image pt.
  static Rect rectIn(Rect image, double scale) =>
      Rect.fromLTWH(image.left + left * scale, image.bottom - (bottom + height) * scale, width * scale, height * scale);

  /// Where an image of [imageSize] pt lands when drawn BoxFit.cover,
  /// bottom-left aligned (the corner with the wordmark is never cropped) into
  /// [canvas]; `scale` = screen pt per image pt.
  static (Rect, double) coverBottomLeft(Size imageSize, Size canvas) {
    final k = math.max(canvas.width / imageSize.width, canvas.height / imageSize.height);
    final w = imageSize.width * k, h = imageSize.height * k;
    return (Rect.fromLTWH(0, canvas.height - h, w, h), k);
  }
}

/// Geometry of the satellite day card (DayCard with `<id>_map.png`), shared by
/// the renderer — the snapshot is requested at exactly this size — and the
/// card layout, so the image is shown 1:1:
///
/// - top: the free route band ([band] pt, route from [bandTop]),
/// - middle: date, resort and the metric row (grows with the text size),
/// - bottom: [AppleWordmark.clearance] pt — the Apple wordmark bottom-left,
///   'Karten: © Apple' bottom-right, no text over the wordmark.
class MapCardGeometry {
  const MapCardGeometry._();

  /// Card height at the default text size (60 + 82 text + 34 wordmark strip).
  static const double minHeight = 176;
  static const double band = 56;
  static const double bandTop = 12;
  static const double bandGap = 4;
  /// Horizontal inset of the route area (the card shows the full width).
  static const double routeSide = 20;
  static const double textSide = 14;
  /// App-wide text scale cap (app.dart: MediaQuery.withClampedTextScaling).
  static const double maxTextScale = 1.3;

  /// Padding of DayCard's text column over the image.
  static const EdgeInsets textPadding = EdgeInsets.fromLTRB(textSide, band + bandGap, textSide, AppleWordmark.clearance);

  /// Height of DayCard's text column: title, 2, resort caption, 10, numerals,
  /// 3, overline — keep in step with DayCard.build (day_card_test checks it).
  /// Lines are rounded up so the estimate never falls short of the laid-out
  /// column: the card then is exactly [height] and the image shows 1:1.
  static double textHeight(TextScaler t) {
    const c = Color(0xFF000000);
    double line(TextStyle s) => (t.scale(s.fontSize!) * (s.height ?? 1)).ceilToDouble();
    return line(AppText.title(c)) + 2 + line(AppText.caption(c)) + 10 + line(HeroNumber.numeralStyle(c, 15)) + 3 + line(AppText.label(c, size: 10));
  }

  /// Card height for [t]: [minHeight], or taller when larger text needs it.
  static double height(TextScaler t) => math.max(minHeight, textPadding.vertical + textHeight(t));

  /// Snapshot width for a phone [screenWidth] pt wide: the list's 20 pt
  /// margins and the card's 0.5 pt hairlines off.
  static double width(double screenWidth) => screenWidth - 2 * Tokens.pad - 1;

  static Size imageSize({required double screenWidth, required TextScaler textScaler}) =>
      Size(width(screenWidth), height(textScaler));

  /// The route area of a card image of [image] pt: the band, [routeSide] in.
  static EdgeInsets routeInset(Size image) => EdgeInsets.fromLTRB(routeSide, bandTop, routeSide, image.height - band);

  /// Screen width and text scaler of the running app (renderer default at End;
  /// the list shows the image on the same phone). Falls back to 402 pt.
  static (double, TextScaler) current() {
    try {
      final view = ui.PlatformDispatcher.instance.implicitView;
      if (view != null) {
        final mq = MediaQueryData.fromView(view);
        final w = mq.size.width;
        if (w > 0) return (w.clamp(320.0, 480.0), mq.textScaler.clamp(maxScaleFactor: maxTextScale));
      }
    } catch (_) {}
    return (402, TextScaler.noScaling);
  }
}

/// A vertical scrim over a map snapshot with a window over the Apple wordmark:
/// [gradient] fills the canvas (or its bottom [gradientHeight] pt); around the
/// wordmark of an image of [imageSize] pt (drawn cover, bottom-left) the scrim
/// is cut out with soft edges and replaced by a light dark [veil], so the
/// white wordmark reads in both themes and nothing above 0.5 opacity lies on it.
class WordmarkScrim extends CustomPainter {
  const WordmarkScrim({required this.gradient, this.imageSize, this.gradientHeight, this.veil = defaultVeil});

  static const Color defaultVeil = Color(0x40101216); // RouteColors.darkGround @ 25 %

  final LinearGradient gradient;
  /// Size of the snapshot under the scrim; null = no wordmark, no window.
  final Size? imageSize;
  final double? gradientHeight;
  final Color veil;

  /// The wordmark box on a canvas of [size], or null.
  Rect? wordmarkIn(Size size) {
    final img = imageSize;
    if (img == null || img.isEmpty || size.isEmpty) return null;
    final (rect, k) = AppleWordmark.coverBottomLeft(img, size);
    return AppleWordmark.rectIn(rect, k);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = gradientHeight;
    final area = h == null ? Offset.zero & size : Rect.fromLTWH(0, size.height - h, size.width, h);
    final fill = Paint()..shader = gradient.createShader(area);
    final box = wordmarkIn(size);
    if (box == null) {
      canvas.drawRect(area, fill);
      return;
    }
    // A small rounded badge behind the wordmark (crisp enough to read as
    // intentional; 3 pt = 2σ margin keeps the box itself fully open).
    final window = RRect.fromRectAndRadius(Rect.fromLTRB(box.left - 5, box.top - 3, box.right + 5, box.bottom + 3), const Radius.circular(7));
    const blur = MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(area, fill);
    canvas.drawRRect(window, Paint()..blendMode = BlendMode.dstOut..maskFilter = blur);
    canvas.restore();
    if (veil.a > 0) canvas.drawRRect(window, Paint()..color = veil..maskFilter = blur);
  }

  @override
  bool shouldRepaint(WordmarkScrim old) =>
      old.gradient != gradient || old.imageSize != imageSize || old.gradientHeight != gradientHeight || old.veil != veil;
}
