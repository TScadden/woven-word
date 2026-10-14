import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/ww_theme.dart';
import 'home_screen.dart';

/// Opening sequence (founder spec, Oct 13, 2026):
/// 1. "Woven Word" types out letter by letter on the black stage.
/// 2. The name dissolves into dust (particles sampled from the glyphs).
/// 3. The home screen slides up into place.
enum _Phase { typing, hold, dust, slide, done }

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  static const _word = 'Woven Word';
  static const _perChar = Duration(milliseconds: 85);
  static const _holdFor = Duration(milliseconds: 380);

  _Phase _phase = _Phase.typing;
  int _typed = 0;
  Timer? _typeTimer;
  Timer? _holdTimer;

  late final AnimationController _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 530),
  )..repeat(reverse: true);
  late final AnimationController _dust = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  Size? _stageSize;
  List<_DustParticle>? _particles;

  @override
  void initState() {
    super.initState();
    _dust.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _phase = _Phase.slide);
        _slide.forward().whenComplete(() {
          if (mounted) setState(() => _phase = _Phase.done);
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (WwMotion.reduced(context)) {
        setState(() => _phase = _Phase.done);
        return;
      }
      _typeTimer = Timer.periodic(_perChar, (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _typed++);
        if (_typed >= _word.length) {
          t.cancel();
          setState(() => _phase = _Phase.hold);
          _holdTimer = Timer(_holdFor, _beginDust);
        }
      });
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _holdTimer?.cancel();
    _caret.dispose();
    _dust.dispose();
    _slide.dispose();
    super.dispose();
  }

  Future<void> _beginDust() async {
    if (!mounted) return;
    _particles ??= await _sampleParticles();
    if (!mounted) return;
    setState(() => _phase = _Phase.dust);
    _dust.forward();
  }

  /// Rasterize the wordmark and sample its pixels into dust particles,
  /// so the dust is literally the letters coming apart.
  Future<List<_DustParticle>> _sampleParticles() async {
    final size = _stageSize ?? const Size(360, 640);
    final painter = TextPainter(
      text: const TextSpan(text: _word, style: WwType.wordmark),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final origin = Offset(
      (size.width - painter.width) / 2,
      (size.height - painter.height) / 2,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), origin);
    final image = await recorder
        .endRecording()
        .toImage(size.width.ceil(), size.height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) return const [];
    final rng = Random(7);
    final out = <_DustParticle>[];
    const step = 3;
    final w = size.width.ceil();
    final left = origin.dx.floor(), top = origin.dy.floor();
    final right = (origin.dx + painter.width).ceil();
    final bottom = (origin.dy + painter.height).ceil();
    for (var y = top; y < bottom; y += step) {
      for (var x = left; x < right; x += step) {
        final alpha = bytes.getUint8((y * w + x) * 4 + 3);
        if (alpha < 90) continue;
        final roll = rng.nextDouble();
        out.add(
          _DustParticle(
            origin: Offset(x.toDouble(), y.toDouble()),
            angle: -pi / 2 + (rng.nextDouble() - 0.5) * 1.9,
            speed: 26 + rng.nextDouble() * 95,
            delay: rng.nextDouble() * 0.35,
            size: 1.4 + rng.nextDouble() * 1.9,
            color: roll < 0.45
                ? WwColors.goldBright
                : roll < 0.8
                ? WwColors.navInk
                : WwColors.gold,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.done) return const HomeScreen();
    return LayoutBuilder(
      builder: (context, constraints) {
        _stageSize = constraints.biggest;
        final showHome = _phase == _Phase.slide;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: WwColors.stage),
            if (showHome)
              AnimatedBuilder(
                animation: _slide,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(_slide.value);
                  return Transform.translate(
                    offset: Offset(0, constraints.maxHeight * (1 - t)),
                    child: child,
                  );
                },
                child: const _RisingHome(),
              ),
            if (!showHome) _stageContent(),
          ],
        );
      },
    );
  }

  Widget _stageContent() {
    final inDust = _phase == _Phase.dust;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AnimatedBuilder(
            animation: _dust,
            builder: (context, _) {
              final fade = inDust ? (1 - _dust.value * 6).clamp(0.0, 1.0) : 1.0;
              return Opacity(
                opacity: fade,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _word.substring(0, _typed),
                      style: WwType.wordmark,
                    ),
                    const SizedBox(width: 6),
                    FadeTransition(
                      opacity: _caret,
                      child: Container(
                        width: 3,
                        height: 46,
                        color: WwColors.goldBright,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (inDust && _particles != null)
          AnimatedBuilder(
            animation: _dust,
            builder: (context, _) => CustomPaint(
              painter: _DustPainter(_particles!, _dust.value),
              size: Size.infinite,
            ),
          ),
      ],
    );
  }
}

/// The home screen rising into place, with a hairline at its top edge so
/// the slide reads against the black stage.
class _RisingHome extends StatelessWidget {
  const _RisingHome();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          height: 1,
          child: ColoredBox(color: Color(0x33E8B33C)),
        ),
        Expanded(child: HomeScreen()),
      ],
    );
  }
}

class _DustParticle {
  const _DustParticle({
    required this.origin,
    required this.angle,
    required this.speed,
    required this.delay,
    required this.size,
    required this.color,
  });

  final Offset origin;
  final double angle;
  final double speed;
  final double delay;
  final double size;
  final Color color;
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.particles, this.progress);

  final List<_DustParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final lt = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0 || lt >= 1) continue;
      final ease = 1 - (1 - lt) * (1 - lt);
      final dx = cos(p.angle) * p.speed * ease;
      final dy = sin(p.angle) * p.speed * ease - 20 * ease;
      paint.color = p.color.withValues(alpha: 1 - lt);
      canvas.drawCircle(
        p.origin + Offset(dx, dy),
        p.size * (1 - 0.55 * lt),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.progress != progress;
}
