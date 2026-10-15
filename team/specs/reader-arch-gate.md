# GATE — READER CONNECTION ARCH (Petra, Design Auditor)

**Spec:** `team/specs/reader-arch.md`. **Base:** 2532f4a.
**Verdict: PASS — no fix items.** Three non-blocking Lows
filed (§4); none held the package.

## 1. Contrast, computed from tokens (script, WCAG formula)

Every NEW adjacency this package creates, and nothing else —
the arch's own pixels are the shipped painters' output,
untouched (spec I-2), so their bounds are inherited from the
arch-ambient gate, not re-derived here.

| Surface | Pair | Ratio | Band | Result |
|---|---|---|---|---|
| Minimize icon (on the stage plate) | `goldBright` #E8B33C on `stage` #000000 | **10.94** | icon ≥ 3.0 | PASS |
| Expand chip icon, Paper | palette accent `goldTextOnPaper` #956D09 on `cardBg` paper #FFFDF8 | **4.62** | icon ≥ 3.0 | PASS |
| Expand chip icon, Dark | palette accent `goldBright` #E8B33C on `cardBg` surfaceHigh #1B1B24 | **8.91** | icon ≥ 3.0 | PASS |
| Chip border, both themes | palette `cardBorder` — the shipped floating-card role (the verse toolbar's own border role) | role reuse | — | PASS |

Both themes × both states were computed (lesson 16): the
minimize icon never leaves the black plate, so its pair is
theme-invariant by construction; the chip is the only control
whose surface changes with the theme, and both of its pairs
clear the band with room.

## 2. The plate decision, with the rejected alternative measured

Spec I-3 keeps the arch on `WwColors.stage` in both themes.
The alternative — the sweep drawn directly on the Paper
page — was computed at the painter's MAXIMUM single-pass
alpha (0.75, the strongest case) for five arc distances,
composited srcOver on paper #FFFDF8:

| distFrac | 0.0 | 0.25 | 0.5 | 0.75 | 1.0 |
|---|---|---|---|---|---|
| contrast vs paper | 3.22 | 1.42 | 1.21 | 1.83 | 2.92 |

Four of five sit under the 3.0 graphic band at maximum
alpha; at typical connection counts the shipped alpha runs
lower and the web washes out further. Recoloring the sweep
for paper would break identity with Home's stage. The plate
is ratified: it is also the founder's own framing — he
called it "the connection arch IMAGE."

## 3. Geometry, from rendered positions (ARCH-10)

- Panel at 360dp: content width 328dp (16dp margins), height
  328 × 500/1200 = 136.7dp; the minimize control's rendered
  size is 48×48dp; the expand chip's rendered size is
  48×48dp; both asserted from `getSize` at text scale 2.0,
  no overflow exception at that scale.
- The toggle lives in the PANEL's budget, never the top
  bar's (lessons 37/43): the reader top bar is byte-untouched.
- Minimized state consumes ZERO layout height in the reading
  column (the slot swaps to a zero-size box; ARCH-6/7 assert
  the panel's absence from the tree, not a hidden panel).
- The chip floats at (top 8, right 8) of the pager viewport
  with an opaque `cardBg`: text under it is covered, never
  garbled (lesson: floating affordances carry their own
  surface — the shipped toolbar's discipline).

## 4. Lows (non-blocking, filed)

- **Low-1.** The chip overlays the first page's top-right
  text corner in the minimized state. Opaque surface, 48dp,
  standard floating-affordance geometry — accepted; if the
  founder's eye objects, the fix is a top inset on the page,
  priced then.
- **Low-2.** `Semantics` label on the paint names the
  chapter ("Chapter connections for Genesis 1") but carries
  no live region: a screen-reader user turning a page hears
  nothing about the web changing. The web is decorative
  information already available as the connections sheet's
  data; accepted.
- **Low-3.** The panel renders its bars background per
  density band, cached; a band change mid-session re-renders
  once (Home's identical cost). No action.

## 5. Deuterocanon ruling

NO arch element and NO toggle in `DeuteroReaderScreen`
(spec I-5). The chapters carry no cross-reference data;
any arch there is fabricated or empty. The shipped reader
already opens with the plain statement that the web does
not cover these books. Absence is the honest treatment and
it is what shipped — ARCH-12 asserts no panel and no
controls exist in that tree.

## 6. Motion

Collapse animates on `WwMotion.expand` (220ms, the theme's
existing expand duration — no new duration). Reduced motion:
the AnimatedSize leaves the tree and the slot swaps
outright; ARCH-11 pins the final state after a single
frame. (The zero-duration AnimatedSize first built threw
"mutated in its own performLayout" in this SDK — caught by
ARCH-11 at build, fixed by the swap, spec amended.)
No fades anywhere in the package.
