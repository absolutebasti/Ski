import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Modal bottom sheet in the app style. Full-height sheets (map) pass expand: true.
class AppSheet {
  const AppSheet._();

  static Future<T?> show<T>(BuildContext context, {required WidgetBuilder builder, bool expand = false, bool dismissible = true}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      builder: (ctx) => expand
          ? SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.92, child: builder(ctx))
          : Padding(padding: const EdgeInsets.fromLTRB(Tokens.pad, 0, Tokens.pad, Tokens.pad), child: builder(ctx)),
    );
  }
}
