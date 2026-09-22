import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/tokens.dart';

/// Full-bleed, muted, looping mascot clip with a graphite scrim — the welcome page.
/// Falls back to the still while the clip initialises or when playback is unavailable
/// (tests, missing codec), so the page always renders.
class MascotHero extends StatefulWidget {
  const MascotHero({
    super.key,
    this.video = 'assets/mascot/toni-hero.mp4',
    this.poster = 'assets/mascot/toni-still.jpg',
  });

  final String video;
  final String poster;

  @override
  State<MascotHero> createState() => _MascotHeroState();
}

class _MascotHeroState extends State<MascotHero> {
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(widget.poster, fit: BoxFit.cover),
        if (_ready && ctrl != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.bg.withValues(alpha: 0.10),
                c.bg.withValues(alpha: 0.72),
                c.bg,
              ],
              stops: const [0.0, 0.55, 0.92],
            ),
          ),
        ),
      ],
    );
  }
}
