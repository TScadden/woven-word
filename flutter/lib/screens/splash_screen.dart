import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/ww_theme.dart';
import 'home_screen.dart';

/// Opening sequence (founder spec, Oct 13, 2026):
/// 1. "Woven Word" types out letter by letter on the black stage, with a
///    human, per-key rhythm (seeded, so it is identical every launch).
/// 2. After a short hold, the wordmark itself crumbles: an erosion front
///    sweeps left to right across the glyphs and each eroding strip
///    releases its own ash particles in the same instant (Infinity War
///    disintegration — the form comes apart, it never just fades).
/// 3. The home screen slides up into place.
enum _Phase { typing, hold, dust, slide, done }

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  static const _word = 'Woven Word';

  /// Human typing rhythm: one seeded interval per keystroke, drawn once
  /// from Random(42) — 115–205ms per key, the interval before the space
  /// stretched ×1.5 (capped at 280ms). The schedule is fixed, so the
  /// sequence timing is exact: the intervals sum to 1516ms.
  static final List<int> _typeScheduleMs = _buildTypeSchedule();

  static List<int> _buildTypeSchedule() {
    final rng = Random(42);
    final out = <int>[];
    for (var i = 0; i < _word.length; i++) {
      var ms = 115 + rng.nextInt(91); // 115–205ms
      if (_word[i] == ' ') ms = min(280, (ms * 1.5).round());
      out.add(ms);
    }
    return List.unmodifiable(out);
  }

  static const _holdFor = Duration(milliseconds: 320);
  static const _dustFor = Duration(milliseconds: 1850);
  static const _slideFor = Duration(milliseconds: 500);

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
    duration: _dustFor,
  );
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: _slideFor,
  );

  Size? _stageSize;

  /// Scene preparation starts the moment typing completes, so the
  /// rasterization overlaps the hold and dust starts on schedule.
  Future<_DustScene?>? _sceneFuture;

  /// The prepared dust scene (rasterized wordmark + particle table +
  /// the single painter that draws both). Null until dust is prepared,
  /// and stays null on the raster-failure fallback path.
  _DustScene? _scene;
  _DustScenePainter? _scenePainter;

  /// True only when rasterization failed (null pixel bytes / exception):
  /// the one path where a plain opacity fade of the word is acceptable.
  bool _rasterFailed = false;

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
      _typeNext();
    });
  }

  /// Chained-timer typing: each keystroke waits its own seeded interval.
  void _typeNext() {
    if (!mounted || _typed >= _word.length) return;
    _typeTimer = Timer(Duration(milliseconds: _typeScheduleMs[_typed]), () {
      if (!mounted) return;
      setState(() => _typed++);
      if (_typed >= _word.length) {
        setState(() => _phase = _Phase.hold);
        // Prepare the dust scene during the hold so its rasterization
        // overlaps the hold; in the unlikely event it runs past the
        // hold, the dust phase waits for it.
        _sceneFuture = _buildDustScene();
        _holdTimer = Timer(_holdFor, _beginDust);
      } else {
        _typeNext();
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _holdTimer?.cancel();
    _caret.dispose();
    _dust.dispose();
    _slide.dispose();
    _scene?.dispose();
    super.dispose();
  }

  Future<void> _beginDust() async {
    if (!mounted) return;
    _DustScene? scene;
    if (_scene == null && !_rasterFailed) {
      try {
        scene = await (_sceneFuture ?? _buildDustScene());
      } catch (_) {
        scene = null;
      }
      if (!mounted) {
        scene?.dispose();
        return;
      }
      if (scene == null) {
        _rasterFailed = true;
      } else {
        _scene = scene;
        _scenePainter = _DustScenePainter(scene, _dust);
      }
    }
    // The caret is consumed by the dust: it stops here and is never
    // drawn again — its pixels are already in the particle table,
    // released with the final erosion strips.
    _caret.stop();
    setState(() => _phase = _Phase.dust);
    _dust.forward();
  }

  /// Rasterize the wordmark once (at 2× for sampling granularity) into a
  /// [ui.Picture], sample its pixels into the ash particle table, and
  /// compute the erosion strip schedule. Particle release times come
  /// from the SAME per-strip start times the glyph painter uses to erase
  /// each strip, so a strip of glyph and its dust are one event.
  /// Returns null when the raster bytes are unavailable (fallback path).
  Future<_DustScene?> _buildDustScene() async {
    final size = _stageSize ?? const Size(360, 640);
    final painter = TextPainter(
      text: const TextSpan(text: _word, style: WwType.wordmark),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final wordSize = painter.size;
    final origin = Offset(
      (size.width - wordSize.width) / 2,
      (size.height - wordSize.height) / 2,
    );

    // One rasterization, at 2×: recorded scaled, drawn scaled back.
    const rasterScale = 2.0;
    final recorder = ui.PictureRecorder();
    final recCanvas = Canvas(recorder)..scale(rasterScale, rasterScale);
    painter.paint(recCanvas, Offset.zero);
    final picture = recorder.endRecording();
    final rasterW = (wordSize.width * rasterScale).ceil();
    final rasterH = (wordSize.height * rasterScale).ceil();
    final image = await picture.toImage(rasterW, rasterH);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) {
      picture.dispose();
      return null;
    }

    // Erosion front: 48 vertical strips sweeping left → right across
    // the word. Each strip starts at a seeded, jittered time; a strip's
    // erase window spans ~3.5 strips of front travel.
    const stripCount = _DustScene.stripCount;
    const sweepSpan = 0.70; // front crosses the word in 70% of the phase
    const eraseWindow = 3.5 * sweepSpan / stripCount; // ≈ 0.051 of progress
    final stripRng = Random(19);
    final stripStarts = List<double>.generate(stripCount, (i) {
      final nominal = (i / stripCount) * sweepSpan;
      final jitter = (stripRng.nextDouble() * 2 - 1) * 0.007;
      return (nominal + jitter).clamp(0.0, sweepSpan);
    }, growable: false);
    final stripW = wordSize.width / stripCount;
    final stripRects = List<Rect>.generate(
      stripCount,
      (i) => Rect.fromLTWH(
        origin.dx + i * stripW,
        origin.dy,
        stripW,
        wordSize.height,
      ),
      growable: false,
    );

    // The caret's rect at its final typed position (3×48, 6px right of
    // the word, vertically centred on the stage). It is sampled into
    // fine-layer particles below — the caret dissolves with the word.
    final caretRect = Rect.fromLTWH(
      origin.dx + wordSize.width + 6,
      size.height / 2 - 24,
      3,
      48,
    );

    // Sample the glyph pixels. Step 3 in raster space (≈1.5 logical px);
    // if the word lands under the particle floor, resample at step 2.
    var samples = _collectSamples(
      bytes,
      rasterW,
      rasterH,
      rasterScale,
      origin,
      wordSize.width,
      3,
    );
    if (samples.length < 1500) {
      samples = _collectSamples(
        bytes,
        rasterW,
        rasterH,
        rasterScale,
        origin,
        wordSize.width,
        2,
      );
    }

    // Caret census: 2 columns × 32 rows at 1.5px steps = 64 particles.
    const caretCount = 64;
    // Cap the word so word + caret never exceeds 3,000 particles,
    // thinning deterministically (even stride, no randomness) if needed.
    const maxParticles = 3000;
    if (samples.length > maxParticles - caretCount) {
      samples = _thin(samples, maxParticles - caretCount);
    }

    final rng = Random(7);
    final particles = <_DustParticle>[];
    for (final s in samples) {
      particles.add(_makeParticle(rng, s.x, s.y, stripStarts[s.strip]));
    }
    // Fold the caret into the dust as fine-layer ash in the muted gold
    // tint, released with the final strip.
    for (var y = caretRect.top; y < caretRect.bottom; y += 1.5) {
      for (var x = caretRect.left; x < caretRect.right; x += 1.5) {
        particles.add(
          _makeParticle(
            rng,
            x,
            y,
            stripStarts[stripCount - 1],
            forceFine: true,
            colorOverride: _DustScene.goldTint,
          ),
        );
      }
    }

    return _DustScene(
      picture: picture,
      wordRect: Rect.fromLTWH(origin.dx, origin.dy, wordSize.width, wordSize.height),
      stripStarts: stripStarts,
      stripRects: stripRects,
      eraseWindow: eraseWindow,
      particles: particles,
    );
  }

  List<_Sample> _collectSamples(
    ByteData bytes,
    int rasterW,
    int rasterH,
    double rasterScale,
    Offset origin,
    double wordWidth,
    int step,
  ) {
    final out = <_Sample>[];
    for (var ry = 0; ry < rasterH; ry += step) {
      for (var rx = 0; rx < rasterW; rx += step) {
        final alpha = bytes.getUint8((ry * rasterW + rx) * 4 + 3);
        if (alpha < 90) continue;
        final lx = origin.dx + rx / rasterScale;
        final ly = origin.dy + ry / rasterScale;
        var strip = ((lx - origin.dx) / wordWidth * _DustScene.stripCount)
            .floor();
        if (strip < 0) strip = 0;
        if (strip > _DustScene.stripCount - 1) {
          strip = _DustScene.stripCount - 1;
        }
        out.add(_Sample(lx, ly, strip));
      }
    }
    return out;
  }

  /// Deterministic thinning: keep an even stride through the samples.
  List<_Sample> _thin(List<_Sample> samples, int target) {
    final stride = samples.length / target;
    return List.generate(
      target,
      (i) => samples[(i * stride).floor()],
      growable: false,
    );
  }

  /// Build one particle with every per-particle parameter precomputed
  /// (wind direction and perpendicular — the trig setup — plus
  /// turbulence phase/frequency/amplitude and lift), so the painter
  /// needs no trig setup per frame; it still evaluates sin() and pow()
  /// per particle per frame and creates the Color/Offset values the
  /// canvas calls require.
  _DustParticle _makeParticle(
    Random rng,
    double x,
    double y,
    double stripStart, {
    bool forceFine = false,
    Color? colorOverride,
  }) {
    // Two layers: a dense fine ash (~82%) and sparse larger flakes
    // (~18%) that travel slower and read dimmer.
    final flake = !forceFine && rng.nextDouble() < 0.18;
    final angle = -0.42 + (rng.nextDouble() - 0.5) * 0.9; // ±0.45 spread
    final dirX = cos(angle);
    final dirY = sin(angle);
    final roll = rng.nextDouble();
    return _DustParticle(
      x: x,
      y: y,
      dirX: dirX,
      dirY: dirY,
      perpX: -dirY,
      perpY: dirX,
      // Same start as its glyph strip, plus ≤0.05 per-particle jitter.
      delay: min(0.80, stripStart + rng.nextDouble() * 0.05),
      speed: flake ? 20 + rng.nextDouble() * 55 : 34 + rng.nextDouble() * 105,
      lift: 8 + rng.nextDouble() * 10,
      size: flake ? 1.3 + rng.nextDouble() * 0.8 : 0.5 + rng.nextDouble() * 0.5,
      cap: flake ? 0.72 : 0.9,
      phase: rng.nextDouble() * pi * 2,
      freq: 4 + rng.nextDouble() * 5,
      amp: 2 + rng.nextDouble() * 5,
      color:
          colorOverride ??
          (roll < 0.06
              ? _DustScene.goldTint // rare muted-gold tint only
              : _DustScene.ash[rng.nextInt(_DustScene.ash.length)]),
    );
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
    if (_phase == _Phase.dust) {
      if (_rasterFailed) {
        // Fallback ONLY (rasterization unavailable): the original fade.
        return Center(
          child: AnimatedBuilder(
            animation: _dust,
            builder: (context, _) {
              final fade = (1 - _dust.value * 1.35).clamp(0.0, 1.0);
              return Opacity(
                opacity: fade,
                child: const Text(_word, style: WwType.wordmark),
              );
            },
          ),
        );
      }
      final painter = _scenePainter;
      if (painter != null) {
        return CustomPaint(painter: painter, size: Size.infinite);
      }
      return const SizedBox.expand();
    }
    // Typing + hold: the word so far and the blinking caret. The caret
    // exists only in these phases; dust consumes it (see _beginDust).
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_word.substring(0, _typed), style: WwType.wordmark),
          const SizedBox(width: 6),
          FadeTransition(
            opacity: _caret,
            child: Container(width: 3, height: 48, color: WwColors.goldBright),
          ),
        ],
      ),
    );
  }
}

/// The home screen rising into place, with a hairline at its top edge so
/// the slide reads against the black stage.
class _RisingHome extends StatelessWidget {
  const _RisingHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 1,
          // goldBright at 20% — the token form of the original hairline.
          child: ColoredBox(color: WwColors.goldBright.withValues(alpha: 0.2)),
        ),
        const Expanded(child: HomeScreen()),
      ],
    );
  }
}

/// Everything the dust phase needs, prepared once before it starts:
/// the rasterized wordmark, the erosion strip schedule, and the full
/// particle table. Nothing here is computed per frame.
class _DustScene {
  _DustScene({
    required this.picture,
    required this.wordRect,
    required this.stripStarts,
    required this.stripRects,
    required this.eraseWindow,
    required this.particles,
  });

  static const stripCount = 48;

  /// Ash palette (Infinity War disintegration): warm grays and tans.
  /// No bright or saturated colour ever becomes a particle.
  static const ash = [
    Color(0xFFC9BBA3),
    Color(0xFFA79B84),
    Color(0xFF8A8071),
    Color(0xFF6E675C),
  ];

  /// The single muted gold permitted as a rare tint.
  static const goldTint = Color(0xFFD8C49A);

  /// The wordmark, rasterized at 2× (drawn at 0.5 scale by the painter).
  final ui.Picture picture;
  final Rect wordRect;
  final List<double> stripStarts;
  final List<Rect> stripRects;
  final double eraseWindow;
  final List<_DustParticle> particles;

  void dispose() => picture.dispose();
}

class _Sample {
  const _Sample(this.x, this.y, this.strip);
  final double x;
  final double y;
  final int strip;
}

class _DustParticle {
  const _DustParticle({
    required this.x,
    required this.y,
    required this.dirX,
    required this.dirY,
    required this.perpX,
    required this.perpY,
    required this.delay,
    required this.speed,
    required this.lift,
    required this.size,
    required this.cap,
    required this.phase,
    required this.freq,
    required this.amp,
    required this.color,
  });

  final double x;
  final double y;
  final double dirX;
  final double dirY;
  final double perpX;
  final double perpY;
  final double delay;
  final double speed;
  final double lift;
  final double size;
  final double cap;
  final double phase;
  final double freq;
  final double amp;
  final Color color;
}

/// The single painter for the whole dust phase. It draws the rasterized
/// wordmark eroding strip by strip (the glyph layer IS the word — no
/// whole-word opacity fade), then the ash particles released by those
/// same strips. Driven by the dust controller via [repaint]; its paint
/// objects are created once, and every per-particle value was
/// precomputed when the scene was built.
class _DustScenePainter extends CustomPainter {
  _DustScenePainter(this.scene, this.animation) : super(repaint: animation);

  final _DustScene scene;
  final Animation<double> animation;

  final Paint _layerPaint = Paint();
  final Paint _erasePaint = Paint()..blendMode = BlendMode.dstOut;
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  static const _eraseBlack = WwColors.stage;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;

    // 1. The word, crumbling at the erosion front. The picture is drawn
    // into a layer, then each strip is punched out with DstOut as its
    // turn comes: alpha ramps 1→0 over the erase window, front sweeping
    // left → right in lockstep with particle release.
    canvas.saveLayer(scene.wordRect, _layerPaint);
    canvas.save();
    canvas.translate(scene.wordRect.left, scene.wordRect.top);
    canvas.scale(0.5, 0.5); // the picture was recorded at 2×
    canvas.drawPicture(scene.picture);
    canvas.restore();
    for (var i = 0; i < _DustScene.stripCount; i++) {
      final e = ((progress - scene.stripStarts[i]) / scene.eraseWindow)
          .clamp(0.0, 1.0);
      if (e <= 0) continue;
      _erasePaint.color = _eraseBlack.withValues(alpha: e);
      canvas.drawRect(scene.stripRects[i], _erasePaint);
    }
    canvas.restore();

    // 2. The ash. Per particle: local time, smoothstep acceleration
    // (slow lift-off), wind carry along the precomputed direction plus
    // a slight extra lift, perpendicular turbulence that grows with
    // local time, alpha thinning as (1−lt)^1.15, and ~45% shrink.
    for (final p in scene.particles) {
      final lt = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0 || lt >= 1) continue;
      final carried = lt * lt * (3 - 2 * lt);
      final drift = p.speed * carried;
      final turb = sin(p.phase + lt * p.freq) * p.amp * lt;
      final dx = p.dirX * drift + p.perpX * turb;
      final dy = p.dirY * drift - p.lift * carried + p.perpY * turb;
      _particlePaint.color = p.color.withValues(
        alpha: p.cap * pow(1 - lt, 1.15).toDouble(),
      );
      canvas.drawCircle(
        Offset(p.x + dx, p.y + dy),
        p.size * (1 - 0.45 * lt),
        _particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustScenePainter oldDelegate) => false;
}
