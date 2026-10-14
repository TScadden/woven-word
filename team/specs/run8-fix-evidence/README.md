# Run-8 fix-round evidence — ambient mini-map captures

Before/after renders of the ambient whole-Bible mini-map at the
exact Home parameters: stage 1200×500, whole-Bible range
(lo 0, hi 1188), density band 0.30 (the band Home computes at a
390dp display width: `bandFor(densityFor(390))`), `faint: false`,
`includeArcs: true`, `includeLabels: false`.

- `ambient-minimap-before.png` — pre-fix tree (hue sweep +
  BlendMode.plus).
- `ambient-minimap-after.png` — fixed tree (gold token, srcOver).

Regenerate (from `flutter/`):

```
flutter test tool/arc_minimap_evidence_test.dart \
  --dart-define=EVIDENCE_LABEL=before   # or: after
```

The generator asserts the band is 0.30 so a capture cannot
silently drift from the Home parameters. Pixel stats (WCAG
relative luminance, composited over black, arc region = rows
0–349, above the axis):

```
python3 compute_stats.py ambient-minimap-before.png ambient-minimap-after.png
```

Results (2026-10-14): before — mean 0.592718, p99 1.0, max 1.0,
59.555% of arc-region pixels above 0.9 luminance. After — mean
0.103149, p99 0.196040, max 0.215765, 0% above 0.9. The after max
sits below the construction cap (the gold token's luminance,
0.273) because accumulation at these alphas is finite.
