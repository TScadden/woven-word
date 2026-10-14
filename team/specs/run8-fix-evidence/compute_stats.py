"""Pixel stats for the run-8 fix-round ambient mini-map captures.

Usage: python3 compute_stats.py <capture.png> [...]

The render is RGBA over a transparent canvas; the app displays it
on the black stage (WwColors.stage), so each pixel is composited
over black first: displayed = rgb * alpha. Luminance is WCAG
relative luminance (linearized sRGB), the studio's computed-gate
measure. The arc region is the stage area above the axis:
ArcGeometry.axisY = stageHeight - bottomReserve = 500 - 150 = 350,
so rows 0..349 — the region where only arcs draw (chapter bars and
labels live at and below the axis). Reports arc-region mean, p99,
and max luminance, plus the fraction of arc-region pixels above
0.9 luminance.
"""
import json
import sys

from PIL import Image


def stats(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    axis_y = h - 150  # ArcGeometry.bottomReserve at stage height 500
    px = im.load()
    lums = []
    for y in range(axis_y):
        for x in range(w):
            r, g, b, a = px[x, y]
            af = a / 255.0
            chans = []
            for c in (r, g, b):
                v = (c / 255.0) * af  # composited over black
                chans.append(
                    v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                )
            lums.append(
                0.2126 * chans[0] + 0.7152 * chans[1] + 0.0722 * chans[2]
            )
    lums.sort()
    n = len(lums)
    return {
        "file": path,
        "size": f"{w}x{h}",
        "arcRegionRows": f"0..{axis_y - 1}",
        "arcRegionPixels": n,
        "meanLuminance": round(sum(lums) / n, 6),
        "p99Luminance": round(lums[min(n - 1, int(0.99 * n))], 6),
        "maxLuminance": round(lums[-1], 6),
        "fracAbove0.9": round(sum(1 for v in lums if v > 0.9) / n, 6),
    }


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(json.dumps(stats(p), indent=2))
