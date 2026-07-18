import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PixelFileLogo extends StatefulWidget {
  final bool withText;

  const PixelFileLogo({required this.withText, super.key});

  @override
  State<PixelFileLogo> createState() => _PixelFileLogoState();
}

class _PixelFileLogoState extends State<PixelFileLogo> with TickerProviderStateMixin {
  static const _logoSize = 200.0;
  static const _pixelColor = Color(0xFFFAC88C);

  late final AnimationController _introController;
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _introController.forward().whenComplete(() {
      if (mounted) {
        _breathController.repeat(reverse: true).ignore();
      }
    }).ignore();
  }

  @override
  void dispose() {
    _introController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: _logoSize,
      height: _logoSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_introController, _breathController]),
        child: SvgPicture.asset(
          'assets/branding/product/pixelfile_logo.svg',
          width: _logoSize,
          height: _logoSize,
          fit: BoxFit.contain,
        ),
        builder: (context, logoAsset) {
          final intro = Curves.easeInOutCubic.transform(_introController.value);
          final pixelAppearance = const Interval(0, 0.25, curve: Curves.easeOut).transform(intro);
          final pixelConvergence = const Interval(0.2, 0.72, curve: Curves.easeInOutCubic).transform(intro);
          final logoAppearance = const Interval(0.62, 0.9, curve: Curves.easeOutBack).transform(intro);
          final pixelFade = 1 - const Interval(0.68, 1, curve: Curves.easeIn).transform(intro);
          final breathingScale = _introController.isCompleted ? (_breathController.value - 0.5) * 0.025 : 0.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              for (final pixel in _pixels)
                Align(
                  alignment: Alignment.lerp(pixel.start, pixel.end, pixelConvergence)!,
                  child: Opacity(
                    opacity: pixelAppearance * pixelFade,
                    child: Transform.scale(
                      scale: 0.65 + pixelAppearance * 0.35,
                      child: Container(
                        width: pixel.size,
                        height: pixel.size,
                        decoration: BoxDecoration(
                          color: _pixelColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: const [BoxShadow(color: Color(0x55FAC88C), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: logoAppearance.clamp(0, 1),
                child: Transform.scale(
                  scale: 0.88 + logoAppearance * 0.12 + breathingScale,
                  child: logoAsset,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.withText) {
      return Column(
        children: [
          logo,
          const Text(
            '像素快传',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return logo;
  }
}

class _Pixel {
  final Alignment start;
  final Alignment end;
  final double size;

  const _Pixel(this.start, this.end, this.size);
}

const _pixels = [
  _Pixel(Alignment(-0.88, -0.62), Alignment(-0.22, -0.28), 12),
  _Pixel(Alignment(-0.58, -0.88), Alignment(0, -0.28), 9),
  _Pixel(Alignment(0.16, -0.84), Alignment(0.22, -0.28), 11),
  _Pixel(Alignment(0.78, -0.54), Alignment(-0.22, 0), 8),
  _Pixel(Alignment(0.94, -0.08), Alignment(0, 0), 13),
  _Pixel(Alignment(0.76, 0.62), Alignment(0.22, 0), 10),
  _Pixel(Alignment(0.22, 0.9), Alignment(-0.22, 0.28), 8),
  _Pixel(Alignment(-0.36, 0.82), Alignment(0, 0.28), 12),
  _Pixel(Alignment(-0.9, 0.42), Alignment(0.22, 0.28), 9),
  _Pixel(Alignment(-0.78, -0.08), Alignment(-0.22, 0), 11),
];
