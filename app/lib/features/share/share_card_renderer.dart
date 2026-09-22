import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/core.dart';
import 'share_card.dart';

/// Renders [ShareCard] to PNG bytes at pixel ratio 1 (1080×1350) by inserting
/// it off-screen into the root [Overlay] for one frame and reading the
/// [RenderRepaintBoundary] back. Needs a context below the app's MaterialApp
/// (theme, locale, overlay).
class ShareCardRenderer {
  const ShareCardRenderer._();

  /// [awaitFrame] is injectable for widget tests, where frames are pumped by hand.
  static Future<Uint8List> render(BuildContext context, DayDetail detail, {Future<void> Function()? awaitFrame}) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -ShareCard.width - 64,
        top: 0,
        child: RepaintBoundary(key: key, child: ShareCard(detail: detail)),
      ),
    );
    overlay.insert(entry);
    try {
      final wait = awaitFrame ?? () => WidgetsBinding.instance.endOfFrame;
      await wait();
      var boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || boundary.debugNeedsPaint) {
        await wait();
        boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      }
      if (boundary == null) throw StateError('share card was not laid out');
      return capture(boundary);
    } finally {
      entry.remove();
    }
  }

  /// PNG bytes of an already painted boundary.
  static Future<Uint8List> capture(RenderRepaintBoundary boundary, {double pixelRatio = 1}) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('png encoding failed');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}
