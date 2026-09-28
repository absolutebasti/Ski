import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A picture the user chose for the avatar, already square and ≤ [maxAvatarPx]
/// on each side. [contentType] is `image/jpeg` or `image/png` — the only two
/// mime types the `avatars` bucket accepts.
@immutable
class PickedAvatar {
  const PickedAvatar(this.bytes, {this.contentType = 'image/jpeg'});

  final Uint8List bytes;
  final String contentType;

  /// File extension for the storage object, derived from [contentType].
  String get extension => contentType == 'image/png' ? 'png' : 'jpg';

  @override
  String toString() => 'PickedAvatar(${bytes.length} B, $contentType)';
}

/// Longest side of an uploaded avatar.
const int maxAvatarPx = 512;

/// Picks a picture from the photo library and hands it back cropped. The
/// real implementation lives behind `image_picker` (added by the lead); the
/// page only knows this interface, so it renders — and tests run — without
/// the plugin.
abstract class AvatarPicker {
  /// Null when the user cancelled.
  Future<PickedAvatar?> pick();
}

/// Test double: returns [result] (or null = cancelled) and counts the calls.
@visibleForTesting
class FakeAvatarPicker implements AvatarPicker {
  FakeAvatarPicker({this.result});

  PickedAvatar? result;
  int calls = 0;

  @override
  Future<PickedAvatar?> pick() async {
    calls++;
    return result;
  }
}

/// Null until the lead wires the `image_picker` implementation (see the
/// PROFILE-PAGE report); the avatar is then read-only and the tap does nothing.
final Provider<AvatarPicker?> avatarPickerProvider = Provider<AvatarPicker?>((ref) => null);

/// Centre-square crop and downscale to at most [maxPx] on a side, re-encoded
/// as PNG (the only lossless encoder `dart:ui` offers). Used by the real
/// picker after `image_picker` returned a file; pure Flutter, no plugin.
///
/// Throws when the bytes are not a decodable image.
Future<PickedAvatar> squareAvatar(Uint8List source, {int maxPx = maxAvatarPx}) async {
  final codec = await ui.instantiateImageCodec(source);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final side = math.min(image.width, image.height);
    final scale = math.min(1.0, maxPx / side);
    final dst = math.max(1, (side * scale).round());
    final left = (image.width - side) / 2;
    final top = (image.height - side) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(left, top, side.toDouble(), side.toDouble()),
      ui.Rect.fromLTWH(0, 0, dst.toDouble(), dst.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final square = await recorder.endRecording().toImage(dst, dst);
    try {
      final data = await square.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('png encode failed');
      return PickedAvatar(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), contentType: 'image/png');
    } finally {
      square.dispose();
    }
  } finally {
    image.dispose();
    codec.dispose();
  }
}
