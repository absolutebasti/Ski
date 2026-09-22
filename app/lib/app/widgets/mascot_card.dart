import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 16:9 looping, muted mascot clip with a caption line — the ShapeMe coach card.
/// Falls back to the still while the video initialises or when it fails.
class MascotCard extends StatefulWidget {
  const MascotCard({
    super.key,
    required this.caption,
    this.video = 'assets/mascot/toni-card.mp4',
    this.poster = 'assets/mascot/toni-still.jpg',
    this.aspectRatio = 16 / 9,
  });

  final String caption;
  final String video;
  final String poster;
  final double aspectRatio;

  @override
  State<MascotCard> createState() => _MascotCardState();
}

class _MascotCardState extends State<MascotCard> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final ctrl = VideoPlayerController.asset(widget.video);
    _ctrl = ctrl;
    ctrl.setVolume(0);
    ctrl.setLooping(true);
    ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      ctrl.play();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = _ctrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(widget.poster, fit: BoxFit.cover),
            if (_ready && ctrl != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(width: ctrl.value.size.width, height: ctrl.value.size.height, child: VideoPlayer(ctrl)),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xD90A0B0E)],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 16, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Tokens.fast,
                        child: Text(
                          widget.caption,
                          key: ValueKey(widget.caption),
                          style: AppText.bodyText(Tokens.textPrimary, size: 16, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
