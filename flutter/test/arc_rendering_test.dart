// Arc-rendering contract tests for the arch-ambient package
// (Oct 15, 2026): the ambient (non-faint, unselected) path of
// renderArcImage draws the distance-hue sweep again, with every
// stroke color luminance-clamped to ambientLuminanceCap and
// srcOver compositing (see arc_stage.dart). Before this package
// no test referenced the ambient path — the fix round's contract
// (one gold token) was verified by evidence captures only — so
// these are the first assertions on the ambient color source,
// pinning the NEW contract the founder directed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/widgets/arc_stage.dart';

void main() {
  group('ambient luminance clamp', () {
    test('cap is the fix round measured max', () {
      // Starting value per the arch-ambient packet: the gold-token
      // render's measured arc-region max at the Home parameters.
      expect(ambientLuminanceCap, 0.216);
    });

    test('every sweep color lands at or under the cap', () {
      // The sweep runs distFrac 0→1 (hue 275→0, s 0.85, l 0.58);
      // sample it densely, at full alpha and at the Home band's
      // alpha range — the clamp bounds the color itself.
      for (var i = 0; i <= 1000; i++) {
        final distFrac = i / 1000;
        for (final alpha in [1.0, 0.09, 0.0084]) {
          final c = ambientArcColor(distFrac, alpha);
          expect(
            c.computeLuminance(),
            lessThanOrEqualTo(ambientLuminanceCap),
            reason: 'distFrac $distFrac at alpha $alpha',
          );
        }
      }
    });

    test('over-cap colors are scaled to the clamp target, inside '
        'the raster guard under the cap', () {
      // A bright green (the sweep's own mid-dome family) starts
      // well over the cap. The clamp lands it on the target —
      // cap minus the rasterization guard documented in
      // arc_stage.dart (8-bit rounding drift measured +0.0052
      // when clamping to exactly the cap) — never above the cap.
      final bright = HSLColor.fromAHSL(1.0, 120, 0.85, 0.58).toColor();
      expect(bright.computeLuminance(), greaterThan(ambientLuminanceCap));
      final clamped = clampToAmbientCap(bright);
      expect(
        clamped.computeLuminance(),
        lessThanOrEqualTo(ambientLuminanceCap),
      );
      expect(
        clamped.computeLuminance(),
        greaterThan(ambientLuminanceCap - 0.01),
        reason: 'lands on the target (cap - guard), not far under it',
      );
    });

    test('a color between the target and the cap is still clamped', () {
      // The guard binds the whole field: a stroke just under the
      // cap would accumulate with the same rounding drift, so
      // the clamp target — not the cap — is the pass-through line.
      const gray = Color(0xFF7F7F7F); // luminance ~0.212
      final lum = gray.computeLuminance();
      expect(lum, lessThanOrEqualTo(ambientLuminanceCap));
      expect(lum, greaterThan(ambientLuminanceCap - 0.008));
      expect(
        clampToAmbientCap(gray).computeLuminance(),
        lessThan(lum),
      );
    });

    test('scaling is proportional (hue preserved) and keeps alpha', () {
      const original = Color.fromRGBO(200, 240, 120, 0.37);
      expect(
        original.computeLuminance(),
        greaterThan(ambientLuminanceCap),
      );
      final clamped = clampToAmbientCap(original);
      // One factor on all channels: channel ratios are unchanged.
      expect(clamped.r / clamped.g, closeTo(original.r / original.g, 1e-6));
      expect(clamped.b / clamped.g, closeTo(original.b / original.g, 1e-6));
      expect(clamped.a, original.a);
    });

    test('colors already under the clamp target pass through '
        'unchanged', () {
      const underTarget = [
        Color(0xFF000000), // black
        Color(0xFF101018), // near-black blue
        Color(0xFF404040), // mid gray, luminance ~0.05
        Color(0xFF3B2A6D), // deep purple, the sweep's low band family
      ];
      for (final c in underTarget) {
        expect(
          c.computeLuminance(),
          lessThanOrEqualTo(ambientLuminanceCap - 0.008),
        );
        expect(clampToAmbientCap(c), same(c));
      }
    });

    test('under-cap sweep colors pass through the ambient path '
        'unchanged in hue', () {
      // Short arcs sit at the purple/blue end of the sweep, whose
      // raw colors are already under the cap; their clamped form
      // must keep the sweep hue (275 at distFrac 0).
      final c = ambientArcColor(0.0, 1.0);
      final hsl = HSLColor.fromColor(c);
      expect(hsl.hue, closeTo(275, 1.0));
      expect(hsl.saturation, closeTo(0.85, 0.01));
    });
  });
}
