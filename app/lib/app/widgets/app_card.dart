import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.onLongPress, this.elevated = false});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: elevated ? c.elevated : c.surface,
        borderRadius: BorderRadius.circular(Tokens.radius),
        border: Border.all(color: c.hairline),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: body,
      ),
    );
  }
}
