import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BrandIntroOverlay extends StatefulWidget {
  final Widget child;

  const BrandIntroOverlay({required this.child, super.key});

  @override
  State<BrandIntroOverlay> createState() => _BrandIntroOverlayState();
}

class _BrandIntroOverlayState extends State<BrandIntroOverlay> {
  static const _assetPath = 'assets/branding/animation/pixelfile_intro.mp4';
  static const _maximumDisplayTime = Duration(seconds: 15);

  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !{TargetPlatform.android, TargetPlatform.macOS}.contains(defaultTargetPlatform)) {
      _finished = true;
      return;
    }

    final controller = VideoPlayerController.asset(_assetPath);
    _controller = controller;
    controller.addListener(_handleVideoState);
    _fallbackTimer = Timer(_maximumDisplayTime, _finish);
    unawaited(_initializeAndPlay());
  }

  Future<void> _initializeAndPlay() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    try {
      await controller.initialize().timeout(const Duration(seconds: 5));
      if (!mounted || _finished) {
        return;
      }

      setState(() {
        _ready = true;
      });
      await controller.play();
    } catch (error) {
      debugPrint('Brand intro could not be played: $error');
      _finish();
    }
  }

  void _handleVideoState() {
    final value = _controller?.value;
    if (value == null) {
      return;
    }
    if (value.hasError) {
      _finish();
      return;
    }

    if (value.isInitialized && value.duration > Duration.zero && value.position >= value.duration) {
      _finish();
    }
  }

  void _finish() {
    if (!mounted || _finished) {
      return;
    }

    _finished = true;
    _fallbackTimer?.cancel();
    setState(() {});
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_handleVideoState);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_finished)
          ColoredBox(
            color: Colors.black,
            child: _ready
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const SizedBox.expand(),
          ),
      ],
    );
  }
}
