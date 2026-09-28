import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:slopetrack/features/account/account.dart';

/// Renders a flat [w]×[h] PNG through dart:ui.
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFE3C88C));
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<(int, int)> _size(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final s = (frame.image.width, frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PickedAvatar maps the mime type to the object extension', () {
    expect(PickedAvatar(Uint8List(0)).extension, 'jpg');
    expect(PickedAvatar(Uint8List(0), contentType: 'image/png').extension, 'png');
    expect(avatarObjectPath('u1'), 'u1/avatar.jpg');
    expect(avatarObjectPath('u1', contentType: 'image/png'), 'u1/avatar.png');
  });

  test('squareAvatar crops landscape and portrait to the centre square', () async {
    final wide = await squareAvatar(await _png(300, 200));
    expect(wide.contentType, 'image/png');
    expect(await _size(wide.bytes), (200, 200));

    final tall = await squareAvatar(await _png(120, 400));
    expect(await _size(tall.bytes), (120, 120));
  });

  test('squareAvatar downscales to maxPx and leaves small images alone', () async {
    final big = await squareAvatar(await _png(1400, 1000), maxPx: 512);
    expect(await _size(big.bytes), (512, 512));

    final small = await squareAvatar(await _png(64, 64), maxPx: 512);
    expect(await _size(small.bytes), (64, 64));
  });

  test('squareAvatar throws on garbage instead of returning junk', () async {
    await expectLater(squareAvatar(Uint8List.fromList([1, 2, 3, 4])), throwsA(anything));
  });

  test('FakeAvatarPicker counts calls and returns its result', () async {
    final picker = FakeAvatarPicker();
    expect(await picker.pick(), isNull);
    picker.result = PickedAvatar(Uint8List.fromList([9]));
    expect((await picker.pick())?.bytes, [9]);
    expect(picker.calls, 2);
  });
}
