# Arch-ambient package — GATE (Petra, Design Auditor & QC)

Date: 2026-10-15. Package gated: `team/specs/arch-ambient-packet.md`;
code commit `859c473` on local main (not pushed — the ship step
follows this gate, per the packet). Evidence gated:
`team/specs/arch-ambient-evidence/` (README + capture + stats).

**CORRECTION (same day, filed as the gate's second commit):**
the first version of this method note stated that no Flutter
SDK exists on this VM and that regeneration and a local suite
run were not executable. That was my error — I asserted the
result of a filesystem search before it had returned. The SDK
is installed (`~/tools/flutter`, Flutter 3.47.7; simply not on
PATH). On discovering this I ran everything the original note
claimed was impossible, in a clean worktree at the gated
commit `859c473`, and corrected this file. The verdict did
not change; its basis is now stronger than first filed.

**Method (lessons 9, 27, 31):** (a) I **regenerated the
capture myself** from the repo tool
(`flutter/tool/arc_minimap_evidence_test.dart`, exact Home
parameters, band 0.30 asserted by the tool) — the output is
**byte-identical** to Maren's filed capture: 560,264 bytes,
SHA-256
`87c5384e5b64fb31911a614c069e6b4d621ea3a769867d1f2cdc1dab62fab5bf`
for both. Her evidence is genuine and the render is
deterministic. (b) Every statistic was computed by me three
ways on that render: the filed `compute_stats.py`, a second,
independently written vectorized implementation, and the
same script on my regeneration — all agree to six decimals.
(c) Suite, analyze, and web release were run by me at the
gated tree (§5; logs filed beside the evidence:
`petra-suite.log`, `petra-analyze.log`, `petra-web.log`).
CI on the pushed tree remains the ship step's own check, as
the packet assigns it.

**VERDICT: PASS. No fix items.** Cap and guard ratified as
filed: **`ambientLuminanceCap = 0.216`, `_ambientRasterGuard =
0.008`, clamp target 0.208.** Two recorded observations in §6 —
neither is a fix item or a blocker.

---

## 1. RE-MEASUREMENT — the envelope holds, off-spec share is zero

My numbers, computed on the committed capture and on my own
byte-identical regeneration of it (1200×500, arc region rows
0–349, 420,000 pixels, composited over black — the fix-round
evidence method), at the exact Home parameters. The evidence tool renders `lo 0, hi
totalChapters − 1` (= 1188), band 0.30 asserted, labels off,
`faint: false`; production Home matches in code
(`home_tab.dart`: `_miniStage = Size(1200, 500)`,
`includeLabels: false`).

| capture | mean | p99 | max | frac > 0.9 | off-spec: arc px > cap 0.216 |
| --- | --- | --- | --- | --- | --- |
| original blowout (plus + sweep) | 0.592718 | 1.000000 | 1.000000 | 0.595550 | 262,540 px — 0.625095 |
| fix-round gold token (srcOver) | 0.103149 | 0.196040 | 0.215765 | 0.000000 | 0 px — 0.000000 |
| **arch-ambient clamped rainbow (srcOver)** | **0.079974** | **0.173455** | **0.213268** | **0.000000** | **0 px — 0.000000** |

Against the packet envelope: mean 0.079974 ≤ 0.13 (38%
under), p99 0.173455 ≤ 0.22 (21% under), max 0.213268 ≤ cap
0.216 (headroom 0.002732), fraction above 0.9 = 0. **All four
lines pass.** Maren's filed stats are exact — my two
implementations reproduce them digit for digit, as they
reproduce the gold and blowout references from the fix round.

**Off-spec classes checked beyond the cap line:**
- *Above the clamp target (0.208), below the cap:* exactly
  **31 pixels** (0.000074 of the arc region), max 0.213268 —
  i.e. the shipped render's hottest pixels sit +0.005268 above
  the float target. That is the raster drift of §2, absorbed
  by the guard, not a cap violation.
- *Blown / near-white class:* **0 pixels** above 0.5
  luminance anywhere in the arc region (the blowout capture
  has 260,649).
- *Hues outside the sweep family:* **none found.** Of sampled
  saturated drawn pixels, hues distribute across the sweep's
  own families — green 32.5%, yellow 43.8% (the expected
  srcOver intermediate of green + orange strokes), orange/red
  17.1%, cyan/teal 5.2%, purple/blue 1.4%. Blue is genuinely
  present where geometry puts it: the low row band's mean blue
  channel is 0.218 against the gold render's 0.000. No
  off-palette color appears.

## 2. THE TWO NUMBERS — both RATIFIED as filed

**Cap 0.216 — RATIFIED.** It is anchored, not tuned: 0.216 is
the fix round's measured max (0.215765) — the brightest
ambient pixel of the build the founder already lived with;
his Oct 15 direction asked for the rainbow back, not for more
brightness, and his standing complaint was "too bright." No
evidence supports a higher cap, and raising it would re-open
the defect this discipline exists to close. The bound is by
construction (lesson 31): srcOver over black is a convex
combination of stroke colors, so no pixel can exceed the
brightest stroke, and every stroke is clamped. I verified the
clamp's necessity and behavior from the sweep math itself:
the raw `_arcColor` sweep (s 0.85, l 0.58) spans luminance
0.169 (purple endpoint, distFrac 0 — passes through
unclamped) to **0.798** (hue ≈ 61°), with even the red
endpoint at 0.2155; my replica of the proportional-scale
bisection lands clamped hues on the target exactly
(e.g. hue 60° at scale 0.544 → L 0.208000), hue preserved,
alpha untouched — the Dart construction does what its doc
block claims, and the unit tests pin it (§5).

**Raster guard 0.008 — RATIFIED.** Judged on the stated
evidence, which the shipped capture independently
corroborates: clamping to exactly the cap measured max
0.221248, drift **+0.005248**, in 31 of 420,000 pixels. The
shipped capture, clamped to cap − guard, reproduces the same
signature — the same 31-pixel hottest population now sits
+0.005268 above the *target* and **0 pixels** above the cap.
Two captures, one mechanism, one magnitude: the drift is
real, stable, and the guard covers it 1.52× over (guard
0.008 vs drift ≈ 0.0053), leaving 0.002732 of headroom under
the cap in the shipped render. A smaller guard (e.g. 0.006)
would leave ~0.0007 of margin against an observed drift that
can only vary with content — too thin for a bound whose whole
point is that it does not depend on tuning luck. The guard's
cost is negligible: clamped strokes land at 0.208 instead of
0.216, a 3.7% luminance difference on the affected hues,
invisible next to the blowout it prevents. **No change to
either number; nothing must change in code.**

## 3. DIFF SCOPE — only the ambient path changed (verified from `git show 859c473`)

Six files: `arc_stage.dart`, the new test, the evidence tool,
and the three evidence files. Within `arc_stage.dart`, the
full parent→commit diff contains exactly: the rewritten doc
block (gold-only history → sweep + clamp + srcOver bound, in
the file's voice, as the packet required), the new constants
`ambientLuminanceCap` / `_ambientRasterGuard` and the
`clampToAmbientCap` / `ambientArcColor` functions replacing
`ambientArcToken` (zero references to the old token remain
anywhere in lib/test/tool), and **two operative lines** in
the ambient branch — the `distFrac` computation and the
`arcPaint.color` assignment.

- **`MiniSelectionPainter`: byte-identical** (section-compared
  parent vs commit; zero mentions in the diff). The faint
  branch, `_arcColor`, `_drawArc`, chapter bars, and book
  labels are likewise absent from the diff — untouched. All
  selection overlays keep shipped behavior, as the packet
  binds.
- **`BlendMode.plus` does not appear in the ambient path.**
  In the gated file it occurs exactly once in code — the
  faint branch (line 180) — plus in doc history. The ambient
  branch sets `BlendMode.srcOver` (line 202). The commit diff
  contains no added `plus` line.
- **Per-arc alpha formula unchanged in form:** the line
  `math.min(0.30, 0.028 + log10(n) * 0.055) * density` is
  byte-identical in both revisions (0.0084–0.09 at the Home
  band 0.30). The evidence tool's only change is an
  `EVIDENCE_DIR` parameter whose default preserves the old
  output path.

## 4. VISUAL READ — my judgment from the captures, not the report

Side by side with the founder's reference
(`feedback/original-arc-reference-20261015.png`), the gold
capture, and the blowout capture:

The clamped-rainbow capture **reads as the original's woven
rainbow** — a dense, saturated dome on black in which
individual arcs stay discernible, which neither predecessor
manages (gold is a flat mustard slab; the blowout is a
clipped white/yellow dome). The band structure follows the
geometry the packet names: a teal/blue low band with purple
flecks along the axis (short arcs — thinner and less
magenta than the reference's low band, because short arcs
are sparse and the purple endpoint is the sweep's dimmest
color at L 0.169), a green/teal mid-dome (green-dominant:
63.0% of drawn pixels), and orange/red carried along the
longest arcs into the crown, interleaved with green — the
same layered mix the reference itself shows, not a solid
orange cap. Row-band means confirm the read: crown
R > G ≫ B, mid R ≈ G ≫ B, low band the only region with
substantial blue. **No blown regions** — no white anywhere,
and §1's zero pixels above 0.5 luminance is the measured
form of that read. The dome is somewhat darker overall than
the gold build (mean 0.080 vs 0.103), most visibly in the
sparse crown (mean 0.026): that is the cap doing its job
under the founder's "too bright" ruling, not a defect. The
founder's direction — "a little more like the original until
we are actually selected on one" — is met, inside the
envelope. His phone verification remains the final word
(lesson 8).

## 5. TESTS & HYGIENE

- New `flutter/test/arc_rendering_test.dart`: **7 tests**,
  counted by me, pinning the new contract the packet names —
  cap value, dense sweep sampling ≤ cap at three alphas,
  over-cap colors landing on the clamp target inside the
  guard, the between-target-and-cap case, proportional
  (hue-preserving) scaling with alpha kept, under-target
  pass-through unchanged, and short-arc hue survival. No
  prior test referenced the ambient path (the fix round's
  contract was evidence-verified only), so **no assertion was
  dropped** — the report's naming of this is accurate.
- Suite **run by me** at the gated tree (clean worktree at
  `859c473`, Flutter 3.47.7): **277/277 — "All tests passed!"**
  (`petra-suite.log`). Declaration count independently
  re-derived: 277 = run 10's 270 + the 7 new. `flutter
  analyze`: **"No issues found!"** (`petra-analyze.log`).
  Web release build: **✓ Built build/web** (`petra-web.log`).
  Maren's three claims are all confirmed by my own runs.
- Hygiene: the `ambientArcToken` doc block was rewritten as
  required; the new comments state the construction bound,
  the cap's provenance, and the guard's measured basis in
  the file's existing voice.

## 6. RECORDED OBSERVATIONS (not fix items)

1. The envelope is ratified **at the Home parameters**, as
   the packet specifies. The full arc stage shares this code
   path at higher density bands; the float bound (cap) holds
   at any density by construction, but raster drift at
   density 1.0 was not separately measured. If the founder
   views the full stage and brightness is questioned there,
   one capture at band 1.0 settles it with the same tool.
2. (Corrected — see the method note.) Regeneration was run
   by me and is byte-identical to the filed capture; suite,
   analyze, and web are verified by my own runs at the gated
   tree. The only check left to the ship step is CI on the
   pushed tree, as the packet assigns it.

## Gate summary

PASS, no fix items. Ratified exactly as filed:
**cap 0.216, guard 0.008, clamp target 0.208.** My measured
stats: mean 0.079974, p99 0.173455, max 0.213268, frac > 0.9
= 0.000000, off-spec (> cap) = 0 of 420,000 pixels — two
independent implementations, exact agreement with the filed
evidence. Diff scope confirmed: ambient path only, selection
and faint paths byte-untouched, no `BlendMode.plus` in the
ambient path, alpha formula unchanged. The package may ship:
Maren pushes, CI green on the final tree, Boaz stages the
APK per the packet.

— **Petra**, Design Auditor & QC, Woven Word Studio
