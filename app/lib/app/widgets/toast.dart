import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/surfaces.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Floating glass capsule above the tab bar, 3 s. Replaces SnackBar.
void showToast(BuildContext context, String text, {IconData? icon, Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) => _Toast(text: text, icon: icon, duration: duration, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.text, this.icon, required this.duration, required this.onDone});
  final String text;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDone;
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Tokens.medium);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _t = Timer(widget.duration, () async {
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 56 + 20;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
            child: Center(
              child: GlassLayer(
                radius: 0,
                opacity: 0.9,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Tokens.rPill), border: Border.all(color: c.glassStroke, width: c.hairlineWidth), boxShadow: Tokens.floatingShadow),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: c.textPrimary), const SizedBox(width: 10)],
                      Flexible(child: Text(widget.text, style: AppText.bodyText(c.textPrimary, size: 15, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
