# Arch-ambient evidence — clamped-rainbow ambient mini-map capture

Capture of the ambient whole-Bible mini-map at the exact Home
parameters: stage 1200×500, whole-Bible range (lo 0, hi 1188),
density band 0.30 (the band Home computes at a 390dp display
width: `bandFor(densityFor(390))`), `faint: false`,
`includeArcs: true`, `includeLabels: false`.

- `ambient-minimap-clamped-rainbow.png` — the arch-ambient
  render: distance-hue sweep (`_arcColor`) as the ambient color
  source, every stroke color luminance-clamped to the clamp
  target (`ambientLuminanceCap` 0.216 − raster guard 0.008),
  `BlendMode.srcOver` (additive blending stays banned), per-arc
  alpha unchanged in form.
- `stats.txt` — pixel stats for the capture, computed with the
  fix round's existing method
  (`../run8-fix-evidence/compute_stats.py`: WCAG relative
  luminance, composited over black, arc region = rows 0–349,
  above the axis, 420,000 pixels).

Regenerate (from `flutter/`):

```
flutter test tool/arc_minimap_evidence_test.dart \
  --dart-define=EVIDENCE_LABEL=clamped-rainbow \
  --dart-define=EVIDENCE_DIR=../team/specs/arch-ambient-evidence
python3 ../team/specs/run8-fix-evidence/compute_stats.py \
  ../team/specs/arch-ambient-evidence/ambient-minimap-clamped-rainbow.png
```

The generator asserts the band is 0.30 so a capture cannot
silently drift from the Home parameters.

Results (2026-10-15), against the packet envelope
(mean ≤ 0.13, p99 ≤ 0.22, max ≤ cap 0.216, frac > 0.9 = 0):

| capture | mean | p99 | max | frac > 0.9 |
| --- | --- | --- | --- | --- |
| original blowout (plus + sweep) | 0.592718 | 1.000000 | 1.000000 | 0.595550 |
| fix-round gold token (srcOver) | 0.103149 | 0.196040 | 0.215765 | 0.000000 |
| clamped rainbow (srcOver) | 0.079974 | 0.173455 | 0.213268 | 0.000000 |

All four envelope lines pass. Note on the clamp target: the
first clamped-rainbow capture, clamped to exactly 0.216,
measured max 0.221248 — 31 of 420,000 arc-region pixels over
the cap. The construction bound is exact in float arithmetic;
the excess is 8-bit premultiplied rasterization drift
(thousands of srcOver draws rounding the surface to bytes at
one pixel). The clamp therefore targets cap − 0.008 (the
`_ambientRasterGuard` in `arc_stage.dart`, sized above the
measured +0.0052 drift), and the shipped capture's max sits
under the cap. The per-arc alpha formula was not changed.
