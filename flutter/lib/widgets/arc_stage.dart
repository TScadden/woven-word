import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../theme/ww_theme.dart';

/// Geometry of the arc stage. The stage is a fixed logical canvas
/// (poster geometry, landscape-first like the original Harrison /
/// Römhild visualization) that the user pans and zooms like a map.
/// All mapping mirrors the web v1 draw code, with two corrections from
/// Tyson's Oct 13, 2026 device feedback:
///  * arc height caps by stage WIDTH, never by screen height;
///  * arc alpha scales with on-screen density, so a compressed view
///    stays wispy instead of saturating to a white dome.
class ArcGeometry {
  final Size stage;
  final int loV; // first global verse position in scope
  final int hiV; // one past the last global verse position in scope
  const ArcGeometry(this.stage, this.loV, this.hiV);

  static const padX = 24.0;
  static const bottomReserve = 150.0;

  double get axisY => stage.height - bottomReserve;
  double get maxArcH => math.min(axisY - 80, stage.width * 0.85);

  double xForPos(int pos) =>
      padX + (pos - loV) / (hiV - loV) * (stage.width - padX * 2);

  int posForX(double x) {
    final frac = (x - padX) / (stage.width - padX * 2);
    return loV + (frac.clamp(0.0, 1.0) * (hiV - loV)).round();
  }

  /// On-screen width of the whole scope at a given transform scale —
  /// the input to density scaling.
  double effectiveWidth(double scale) => stage.width * scale;
}

/// Density bands: arc alpha is quantized so the pre-rendered arc image
/// only regenerates when the zoom settles into a new band, never per
/// gesture frame (the in-flight gesture just scales the image, the way
/// map apps behave).
const arcDensityBands = [0.22, 0.30, 0.40, 0.55, 0.70, 0.85, 1.0];

double densityFor(double effectiveWidth) =>
    (effectiveWidth / 1500).clamp(0.22, 1.0).toDouble();

double bandFor(double density) {
  for (final b in arcDensityBands) {
    if (density <= b + 0.001) return b;
  }
  return 1.0;
}

Color _arcColor(double distFrac, double alpha) {
  final t = math.pow(distFrac, 0.42).toDouble();
  final hue = 275 - t * 275; // near = purple/blue, far = gold/red
  return HSLColor.fromAHSL(alpha, hue, 0.85, 0.58).toColor();
}

void _drawArc(Canvas canvas, ArcGeometry g, int pa, int pb, Paint paint) {
  final x1 = g.xForPos(pa), x2 = g.xForPos(pb);
  if ((x2 - x1).abs() < 0.8) return;
  final hgt = math.min(g.maxArcH, (x2 - x1).abs() * 0.52);
  final path = Path()
    ..moveTo(x1, g.axisY)
    ..quadraticBezierTo((x1 + x2) / 2, g.axisY - hgt * 2, x2, g.axisY);
  canvas.drawPath(path, paint);
}

/// Renders the static layer (arcs + chapter bars + book labels) into an
/// image at stage resolution. [faint] renders the arcs dimmed, the mode
/// used while a chapter is selected (its partner arcs draw live in the
/// overlay so they stay bright).
Future<ui.Image> renderArcImage({
  required BibleData data,
  required int lo,
  required int hi,
  required Size stage,
  required double density,
  required bool faint,
}) async {
  final g = ArcGeometry(
    stage,
    data.chapterStart[lo],
    data.chapterStart[hi] + data.chapters[hi].v,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..blendMode = BlendMode.plus;
  if (faint) {
    arcPaint.color = const Color.fromRGBO(70, 66, 60, 0.05);
    for (final arc in data.chapterArcs) {
      final a = arc[0], b = arc[1];
      if (a < lo || a > hi || b < lo || b > hi) continue;
      _drawArc(
        canvas,
        g,
        data.versePos(a, (data.chapters[a].v / 2).ceil()),
        data.versePos(b, (data.chapters[b].v / 2).ceil()),
        arcPaint,
      );
    }
  } else {
    for (final arc in data.chapterArcs) {
      final a = arc[0], b = arc[1], n = arc[2];
      if (a < lo || a > hi || b < lo || b > hi) continue;
      final pa = data.versePos(a, (data.chapters[a].v / 2).ceil());
      final pb = data.versePos(b, (data.chapters[b].v / 2).ceil());
      final alpha = math.min(0.30, 0.028 + log10(n) * 0.055) * density;
      arcPaint.color = _arcColor(
        (pb - pa).abs() / (g.hiV - g.loV),
        alpha,
      );
      _drawArc(canvas, g, pa, pb, arcPaint);
    }
  }

  // Chapter bars (base colors; the selected bar is covered by the
  // overlay's gold bar).
  final barPaint = Paint()..style = PaintingStyle.fill;
  for (var ch = lo; ch <= hi; ch++) {
    final c = data.chapters[ch];
    final x0 = g.xForPos(data.chapterStart[ch]);
    final x1 = g.xForPos(data.chapterStart[ch] + c.v);
    final h = 14 + math.sqrt(c.v) * 4.4;
    barPaint.color = c.b % 2 == 1 ? WwColors.barB : WwColors.barA;
    canvas.drawRect(
      Rect.fromLTWH(x0, g.axisY, math.max(2.0, x1 - x0 - 0.6), h),
      barPaint,
    );
  }

  // Book labels, centered under each book that is wide enough on stage.
  for (final book in data.books) {
    final first = book.start, last = book.start + book.chapters - 1;
    if (last < lo || first > hi) continue;
    final w =
        (data.chapterStart[math.min(data.totalChapters - 1, last + 1)] -
            data.chapterStart[first]) /
        (g.hiV - g.loV) *
        stage.width;
    if (w < 130) continue;
    final tp = TextPainter(
      text: TextSpan(
        text: book.abbr,
        style: const TextStyle(
          fontSize: 34,
          color: WwColors.bookLabel,
          fontFamilyFallback: WwType.serifFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final midCh = book.start + (book.chapters - 1) / 2;
    final midPos =
        data.chapterStart[midCh.floor()] +
        (data.chapters[midCh.floor()].v * (midCh - midCh.floor() + 0.5))
            .round();
    tp.paint(
      canvas,
      Offset(g.xForPos(midPos) - tp.width / 2, g.axisY + 88),
    );
  }

  final picture = recorder.endRecording();
  return picture.toImage(stage.width.ceil(), stage.height.ceil());
}

/// Live overlay: the selected chapter's gold bar and its partner arcs.
/// Cheap to repaint on every frame — at most a few hundred paths.
class ArcOverlayPainter extends CustomPainter {
  final BibleData data;
  final int lo;
  final int hi;
  final Size stage;
  final int? selected;
  final double density;

  const ArcOverlayPainter({
    required this.data,
    required this.lo,
    required this.hi,
    required this.stage,
    required this.selected,
    required this.density,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sel = selected;
    if (sel == null || sel < lo || sel > hi) return;
    final g = ArcGeometry(
      stage,
      data.chapterStart[lo],
      data.chapterStart[hi] + data.chapters[hi].v,
    );
    // Partner arcs, repeated by weight like the web version.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..blendMode = BlendMode.plus;
    final partners = data.chapterPartners[sel] ?? const {};
    final pa = data.versePos(sel, (data.chapters[sel].v / 2).ceil());
    final alphaScale = math.max(density, 0.45);
    partners.forEach((p, n) {
      if (p < lo || p > hi) return;
      final pb = data.versePos(p, (data.chapters[p].v / 2).ceil());
      paint.color = _arcColor(
        (pb - pa).abs() / (g.hiV - g.loV),
        0.5 * alphaScale,
      );
      final passes = math.min(3, 1 + (log10(n) ~/ 1));
      for (var i = 0; i < passes; i++) {
        _drawArc(canvas, g, pa, pb, paint);
      }
    });
    // Gold selection bar over the base bar.
    final c = data.chapters[sel];
    final x0 = g.xForPos(data.chapterStart[sel]);
    final x1 = g.xForPos(data.chapterStart[sel] + c.v);
    final h = 14 + math.sqrt(c.v) * 4.4;
    canvas.drawRect(
      Rect.fromLTWH(x0, g.axisY, math.max(2.0, x1 - x0 - 0.6), h),
      Paint()..color = WwColors.goldBright,
    );
  }

  @override
  bool shouldRepaint(ArcOverlayPainter old) =>
      old.selected != selected ||
      old.lo != lo ||
      old.hi != hi ||
      old.density != density ||
      old.stage != stage;
}
