import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled Inter faces so goldens and baseline checks measure real
/// glyphs instead of Ahem boxes. Same recipe as the share goldens — a copy
/// until the lead promotes it into test/support.
Future<void> loadInterFonts() async {
  const fonts = {
    'Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
    'InterDisplay': ['InterDisplay-Bold', 'InterDisplay-ExtraBold', 'InterDisplay-Black'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final name in e.value) {
      final bytes = File('assets/fonts/$name.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
