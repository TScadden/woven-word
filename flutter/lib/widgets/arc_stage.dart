import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/ambient_stage.dart';
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

  /// [xForPos] for an interpolated (fractional) verse position —
  /// the ambient morph's lerped endpoints (arch-ambient-home
  /// spec §4). Same mapping, double input.
  double xForPosValue(double pos) =>
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

/// The ambient web's brightness cap (arch-ambient package, Oct 15,
/// 2026): every ambient stroke color is luminance-clamped to at
/// most this WCAG relative luminance before it is drawn. History
/// in two lines: the original hue sweep under additive blending
/// blew out to a white dome, and the run-8 fix round replaced it
/// with one gold token under srcOver — bounded, but flat gold.
/// The founder then asked the static arch to look more like the
/// original until a chapter is selected, so the ambient path now
/// draws the distance-hue sweep again, with each sweep color
/// clamped to this cap and additive blending still banned.
///
/// The bound is by construction (lesson 31): the ambient path
/// composites with srcOver over the black stage, and a srcOver
/// composite is a convex combination of the stroke colors, so no
/// ambient pixel's luminance can exceed the brightest single
/// stroke's — and every stroke is clamped to the cap. The cap's
/// starting value is the fix round's measured max: 0.216, the
/// gold-token render's brightest arc-region pixel at the Home
/// parameters (its construction cap was the token's own 0.273;
/// accumulation at the shipped alphas never reached it). The
/// sweep also survives in the selection painter (shipped
/// behavior, single-pass normal blending, no accumulation),
/// which this cap does not govern.
const ambientLuminanceCap = 0.216;

/// Rasterization guard subtracted from [ambientLuminanceCap] to
/// get the clamp target. The construction bound above is exact
/// in float arithmetic, but the stage rasterizes to 8-bit
/// premultiplied pixels: thousands of srcOver draws at one pixel
/// each round the surface to bytes, and the accumulated rounding
/// drifts measured pixels ABOVE the float bound — measured on
/// this package's first capture, clamped to exactly the cap:
/// max 0.221248, +0.0052 over, in 31 of 420,000 arc-region
/// pixels. (The gold render never showed it: its accumulation
/// sat 0.057 below its token cap.) Clamping to cap − guard keeps
/// every measured pixel at or under the cap; the guard is sized
/// above the measured drift.
const _ambientRasterGuard = 0.008;

/// Scales [color] toward black — one proportional factor on all
/// three RGB channels, so hue is preserved and alpha untouched —
/// until its WCAG relative luminance equals the clamp target,
/// [ambientLuminanceCap] − [_ambientRasterGuard]. Colors already
/// at or under the target pass through unchanged.
Color clampToAmbientCap(Color color) {
  const target = ambientLuminanceCap - _ambientRasterGuard;
  if (color.computeLuminance() <= target) return color;
  // Luminance rises monotonically with the RGB scale factor, so
  // bisect for the factor whose luminance lands on the target;
  // keep the under-target side so the result never exceeds it.
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 64; i++) {
    final mid = (lo + hi) / 2;
    final scaled = color.withValues(
      red: color.r * mid,
      green: color.g * mid,
      blue: color.b * mid,
    );
    if (scaled.computeLuminance() > target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return color.withValues(
    red: color.r * lo,
    green: color.g * lo,
    blue: color.b * lo,
  );
}

/// The ambient path's color for one arc: the distance-hue sweep
/// ([_arcColor], the original's rainbow), luminance-clamped to
/// [ambientLuminanceCap].
Color ambientArcColor(double distFrac, double alpha) =>
    clampToAmbientCap(_arcColor(distFrac, alpha));

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
  bool includeArcs = true,
  bool includeLabels = true,
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
    ..strokeWidth = 1.6;
  if (includeArcs) {
    if (faint) {
      // Faint mode is untouched by the fix round: additive, one
      // flat dim color, drawn under the live selection overlay.
      arcPaint.blendMode = BlendMode.plus;
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
      // Ambient web (arch-ambient package): srcOver — additive
      // blending stays banned — with the distance-hue sweep
      // restored as the color source and every stroke color
      // luminance-clamped to ambientLuminanceCap before drawing
      // (see the cap's doc for the bound). Per-arc alpha unchanged
      // in form — min(0.30, 0.028 + log10(n) * 0.055) * density,
      // so at the Home band (0.30) alpha runs 0.0084–0.09 and at
      // full density at most 0.30.
      arcPaint.blendMode = BlendMode.srcOver;
      for (final arc in data.chapterArcs) {
        final a = arc[0], b = arc[1], n = arc[2];
        if (a < lo || a > hi || b < lo || b > hi) continue;
        final pa = data.versePos(a, (data.chapters[a].v / 2).ceil());
        final pb = data.versePos(b, (data.chapters[b].v / 2).ceil());
        final alpha = math.min(0.30, 0.028 + log10(n) * 0.055) * density;
        final distFrac = (pb - pa).abs() / (g.hiV - g.loV);
        arcPaint.color = ambientArcColor(distFrac, alpha);
        _drawArc(canvas, g, pa, pb, arcPaint);
      }
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
  if (includeLabels) {
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
  }

  final picture = recorder.endRecording();
  return picture.toImage(stage.width.ceil(), stage.height.ceil());
}

/// Mini-map selection layer for the home screen: the selected chapter's
/// partner arcs only, drawn with normal blending in a single pass per
/// partner (no additive accumulation — that saturation was the
/// founder's core complaint about the old selected mode), plus the
/// gold selection bar.
class MiniSelectionPainter extends CustomPainter {
  final BibleData data;
  final int lo;
  final int hi;
  final Size stage;
  final int? selected;

  const MiniSelectionPainter({
    required this.data,
    required this.lo,
    required this.hi,
    required this.stage,
    required this.selected,
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
    // One arc per partner, single pass, normal blending.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final partners = data.chapterPartners[sel] ?? const {};
    final pa = data.versePos(sel, (data.chapters[sel].v / 2).ceil());
    partners.forEach((p, n) {
      if (p < lo || p > hi) return;
      final pb = data.versePos(p, (data.chapters[p].v / 2).ceil());
      paint.color = _arcColor(
        (pb - pa).abs() / (g.hiV - g.loV),
        0.30 + math.min(0.45, log10(n) * 0.18),
      );
      _drawArc(canvas, g, pa, pb, paint);
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
  bool shouldRepaint(MiniSelectionPainter old) =>
      old.selected != selected ||
      old.lo != lo ||
      old.hi != hi ||
      old.stage != stage;
}

/// The ambient Home stage's featured-chapter arcs (HOME ARCH
/// GOES AMBIENT, spec §4): the shipped selected-chapter rendering
/// — [MiniSelectionPainter]'s geometry, its `_arcColor` sweep,
/// its alpha formula, its gold bar — carried across a morph
/// between two featured chapters. The color path is the shipped
/// one verbatim; this painter only interpolates the GEOMETRY
/// the precomputed [AmbientArc] lists hand it (spec §7) and
/// cross-fades the arcs a rank pairing cannot carry.
///
/// Pairing is by rank in partner-ascending order: a paired arc's
/// source position, target position, and count lerp from the
/// outgoing chapter's arc to the incoming one's; unpaired
/// outgoing arcs fade in place, unpaired incoming arcs fade in.
/// At t = 0 the render is exactly the outgoing chapter's
/// selected rendering; at t = 1 exactly the incoming one's.
class AmbientArcPainter extends CustomPainter {
  final BibleData data;
  final int lo;
  final int hi;
  final Size stage;
  final int? fromChapter;
  final int? toChapter;

  /// The outgoing chapter's precomputed arcs (empty when the
  /// chapter has no partners or there is no outgoing chapter).
  final List<AmbientArc> fromArcs;

  /// The incoming (featured) chapter's precomputed arcs.
  final List<AmbientArc> toArcs;

  /// Morph progress, 0..1 (already eased by the driver).
  final double t;

  const AmbientArcPainter({
    required this.data,
    required this.lo,
    required this.hi,
    required this.stage,
    required this.fromChapter,
    required this.toChapter,
    required this.fromArcs,
    required this.toArcs,
    required this.t,
  });

  double _lerp(double a, double b) => a + (b - a) * t;

  void _drawArcD(Canvas canvas, ArcGeometry g, double pa, double pb,
      Paint paint) {
    final x1 = g.xForPosValue(pa), x2 = g.xForPosValue(pb);
    if ((x2 - x1).abs() < 0.8) return;
    final hgt = math.min(g.maxArcH, (x2 - x1).abs() * 0.52);
    final path = Path()
      ..moveTo(x1, g.axisY)
      ..quadraticBezierTo((x1 + x2) / 2, g.axisY - hgt * 2, x2, g.axisY);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final to = toChapter;
    if (to == null || to < lo || to > hi) return;
    final g = ArcGeometry(
      stage,
      data.chapterStart[lo],
      data.chapterStart[hi] + data.chapters[hi].v,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    // The shipped selection alpha (MiniSelectionPainter): the
    // base for one partner arc of count n, before the morph's
    // fade factor for unpaired arcs.
    double alphaFor(double n, double factor) =>
        (0.30 + math.min(0.45, log10(n) * 0.18)) * factor;
    void drawArc(double pa, double pb, double n, double factor) {
      if (factor <= 0) return;
      paint.color = _arcColor(
        (pb - pa).abs() / (g.hiV - g.loV),
        alphaFor(n, factor).clamp(0.0, 1.0),
      );
      _drawArcD(canvas, g, pa, pb, paint);
    }

    final paired = math.min(fromArcs.length, toArcs.length);
    for (var i = 0; i < paired; i++) {
      final a = fromArcs[i], b = toArcs[i];
      // A paired arc whose partner sits outside the stage range
      // in either state is not drawn in that state (the shipped
      // painter's range rule); the morph fades it at the side
      // where it exists instead of sliding it across the range.
      final aIn = a.partner >= lo && a.partner <= hi;
      final bIn = b.partner >= lo && b.partner <= hi;
      if (aIn && bIn) {
        drawArc(
          _lerp(a.fromPos.toDouble(), b.fromPos.toDouble()),
          _lerp(a.toPos.toDouble(), b.toPos.toDouble()),
          _lerp(a.count.toDouble(), b.count.toDouble()),
          1,
        );
      } else if (aIn) {
        drawArc(a.fromPos.toDouble(), a.toPos.toDouble(),
            a.count.toDouble(), 1 - t);
      } else if (bIn) {
        drawArc(b.fromPos.toDouble(), b.toPos.toDouble(),
            b.count.toDouble(), t);
      }
    }
    for (var i = paired; i < fromArcs.length; i++) {
      final a = fromArcs[i];
      if (a.partner < lo || a.partner > hi) continue;
      drawArc(a.fromPos.toDouble(), a.toPos.toDouble(),
          a.count.toDouble(), 1 - t);
    }
    for (var i = paired; i < toArcs.length; i++) {
      final b = toArcs[i];
      if (b.partner < lo || b.partner > hi) continue;
      drawArc(b.fromPos.toDouble(), b.toPos.toDouble(),
          b.count.toDouble(), t);
    }
    // Gold selection bars, cross-faded like the arcs: the
    // outgoing chapter's at (1 − t), the featured one's at t —
    // at the endpoints exactly the shipped single gold bar.
    void goldBar(int ch, double factor) {
      if (factor <= 0 || ch < lo || ch > hi) return;
      final c = data.chapters[ch];
      final x0 = g.xForPos(data.chapterStart[ch]);
      final x1 = g.xForPos(data.chapterStart[ch] + c.v);
      final h = 14 + math.sqrt(c.v) * 4.4;
      canvas.drawRect(
        Rect.fromLTWH(x0, g.axisY, math.max(2.0, x1 - x0 - 0.6), h),
        Paint()..color = WwColors.goldBright.withValues(alpha: factor),
      );
    }

    final from = fromChapter;
    if (from != null && from != to) goldBar(from, 1 - t);
    goldBar(to, from == null || from == to ? 1 : t);
  }

  @override
  bool shouldRepaint(AmbientArcPainter old) =>
      old.t != t ||
      old.fromChapter != fromChapter ||
      old.toChapter != toChapter ||
      old.lo != lo ||
      old.hi != hi ||
      old.stage != stage;
}
