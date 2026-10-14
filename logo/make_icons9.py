#!/usr/bin/env python3
"""Woven Word icon v3 (Petra, P1): composition repair inside the v1/v2 mark
family -- flat gold Bible, woven web cut into the cover in black, red ribbon,
black tile. NOT a rebrand.

Founder feedback on v2: "You just made the book wide but didn't fix the
empty space." v2 cover was wide/short (1360x1230 at render scale) with the
web baseline low on the cover, leaving a large empty gold field above it.

Fixes (LESSONS.md #1, #2, #3, #4, #7):
  #2 Empty space is composition, not scale: the web emblem is optically
     centered in the cover field -- band from cover top to web apex
     (570) EQUALS band from web baseline to cover bottom (570).
  #1 Fill the tile: whole composition (cover + page block + ribbon)
     spans 1604/2048 = 78.3% of tile width and 64..1978 vertically
     (composition vertical center 1021 vs tile center 1024).
  Portrait proportions restored: cover 1560 wide x 1720 tall (h/w 1.10);
     v2 was 1360 x 1230 (h/w 0.90, wide/short).
  #3 Arcs cross each other on ONE shared baseline (y=1214) with staggered
     endpoints, scaled from the proven make_icons7 span geometry.
  #4 Flat solid colors only: INK / GOLD / CREAM / RED, no gradients.

Render path: PIL at 2048, master saved at 1024 (established pipeline),
then every platform asset is regenerated from the final master.
"""
import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.expanduser('~/workspace/woven-word')
OUT = os.path.join(ROOT, 'logo')
S = 2048

INK = (13, 13, 17)
GOLD = (226, 168, 44)
CREAM = (243, 236, 217)
RED = (158, 34, 48)

# --- composition geometry (2048 render scale) ---
COVER = [222, 64, 1782, 1784]          # 1560 x 1720, portrait h/w = 1.10
PAGE = [266, 108, 1826, 1828]          # cream peek: 44 right, 44 bottom
RIBBON = [(452, 1700), (564, 1700), (564, 1978), (508, 1916), (452, 1978)]
GROOVE_X = 372
GROOVE_Y = (180, 1668)
WEB_X0 = 557                            # web field centered between groove
WEB_W = 1040                            # and cover right edge
WEB_BASE = 1214
# spans: (left offset, right offset, apex height) -- lesson #3 geometry,
# staggered endpoints, all feet on WEB_BASE, arcs cross each other.
WEB_SPANS = [(0, 759, 466), (244, 970, 580), (95, 542, 323),
             (449, 948, 420), (582, 1040, 285)]

MASTER_NAME = 'woven_word_icon_final_black_v3_20261013.png'
PREVIEW_NAME = 'woven_word_icon_v3_preview_20261013.png'


def bez(p0, p1, p2, n=64):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1])
            for t in (i / n for i in range(n + 1))]


def tile(color):
    img = Image.new('RGB', (S, S), (0, 0, 0))
    m = Image.new('L', (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S - 1, S - 1], radius=460, fill=255)
    img.paste(Image.new('RGB', (S, S), color), (0, 0), m)
    return img


def web(d, cut):
    # one shared baseline bar
    d.rounded_rectangle([WEB_X0 - 40, WEB_BASE, WEB_X0 + WEB_W + 40,
                         WEB_BASE + 38], radius=19, fill=cut)
    for a, b, apex in WEB_SPANS:
        xa, xb = WEB_X0 + a, WEB_X0 + b
        d.line(bez((xa, WEB_BASE), ((xa + xb) / 2, WEB_BASE - 2 * apex),
                   (xb, WEB_BASE)), fill=cut, width=44, joint='curve')


def book():
    img = tile(INK)
    d = ImageDraw.Draw(img)
    # cream page block peeking right + bottom
    d.rounded_rectangle(PAGE, radius=84, fill=CREAM)
    # red ribbon marker hanging below the cover (V notch in the polygon)
    d.polygon(RIBBON, fill=RED)
    # gold cover, portrait proportions
    d.rounded_rectangle(COVER, radius=84, fill=GOLD)
    # spine groove
    d.line([(GROOVE_X, GROOVE_Y[0]), (GROOVE_X, GROOVE_Y[1])], fill=INK, width=28)
    for y in GROOVE_Y:
        d.ellipse([GROOVE_X - 14, y - 14, GROOVE_X + 14, y + 14], fill=INK)
    # the woven web, cut into the cover, optically centered:
    # apex of tallest arc = WEB_BASE - 580 = 634; top band 634-64 = 570,
    # bottom band 1784-1214 = 570.
    web(d, INK)
    return img


def save_resized(master, size, path):
    master.resize((size, size), Image.LANCZOS).save(path)
    print('wrote', os.path.relpath(path, ROOT), f'{size}x{size}')


def platform_assets(master):
    # Android mipmaps
    android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for dens, px in android.items():
        save_resized(master, px, os.path.join(
            ROOT, 'flutter/android/app/src/main/res',
            f'mipmap-{dens}', 'ic_launcher.png'))
    # iOS AppIcon set: every size x scale declared in Contents.json
    iconset = os.path.join(
        ROOT, 'flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset')
    with open(os.path.join(iconset, 'Contents.json')) as f:
        contents = json.load(f)
    for entry in contents['images']:
        pt = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        px = int(round(pt * scale))
        save_resized(master, px, os.path.join(iconset, entry['filename']))
    # Web icons + favicon
    web_dir = os.path.join(ROOT, 'flutter/web')
    for name, px in [('Icon-192.png', 192), ('Icon-512.png', 512),
                     ('Icon-maskable-192.png', 192), ('Icon-maskable-512.png', 512)]:
        save_resized(master, px, os.path.join(web_dir, 'icons', name))
    save_resized(master, 64, os.path.join(web_dir, 'favicon.png'))


if __name__ == '__main__':
    apex_y = WEB_BASE - max(a for _, _, a in WEB_SPANS)
    print(f"cover {COVER[2]-COVER[0]}x{COVER[3]-COVER[1]} "
          f"(h/w {(COVER[3]-COVER[1])/(COVER[2]-COVER[0]):.3f})")
    print(f"composition width {PAGE[2]-COVER[0]}/{S} = "
          f"{(PAGE[2]-COVER[0])/S*100:.1f}% of tile")
    print(f"bands: top {apex_y-COVER[1]}, bottom {COVER[3]-WEB_BASE} "
          f"(apex y={apex_y}, baseline y={WEB_BASE})")

    master = book().resize((1024, 1024), Image.LANCZOS)
    master_path = os.path.join(OUT, MASTER_NAME)
    master.save(master_path)
    print('wrote', MASTER_NAME, master.size)

    # evidence sheet: 192 / 96 / 48 side by side on a dark background
    sheet = Image.new('RGB', (400, 224), (24, 24, 30))
    x = 16
    for px in (192, 96, 48):
        sheet.paste(master.resize((px, px), Image.LANCZOS), (x, 16))
        x += px + 16
    sheet.save(os.path.join(OUT, PREVIEW_NAME))
    print('wrote', PREVIEW_NAME, sheet.size)

    platform_assets(master)
