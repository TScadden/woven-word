# GATE — HOME ARCH GOES AMBIENT (Petra, Design Auditor & QC)

**Verdict: PASS**
**Build gated:** `a82f9aa` (app `2f46892`) on base `95997ee`, worktree
`/tmp/ww-ambient`. **Spec:** `team/specs/arch-ambient-home.md` (incl. §8
amendment + §10 translation register). **Authority:** founder ruling
`team/memory/decisions/2026-10-15-home-arch-ambient-ruling.md` — the panel
takeover in `feedback/founder-home-selection-panel-20261015.png` is
replaced by a rotating ambient arch with a small caption; list taps open
the reader directly.
**Method:** every number below is computed by the gate from tokens, the
shipped asset, `git diff`, and my own test runs — nothing eyeballed, no
claim taken from the build report without re-derivation where the gate
depends on it. No app code was modified by the gate.

---

## 1. Stage + caption

### Contrast (computed from `ww_theme.dart` tokens, WCAG formula)

Caption style is `WwType.captionOnDark` = `mutedOnDark` `#9A947F`. Its
actual background: the caption band is a border-only container inside
`Material(color: WwColors.stage)` — the effective surface is the stage
itself, `#000000`, at every stage size (the band sits below the artwork,
never over it).

| Pair | L (fg) | L (bg) | Ratio | Class / threshold | Result |
|---|---|---|---|---|---|
| `mutedOnDark` on `stage` (caption) | 0.2958 | 0.0000 | **6.92:1** | normal 12sp / 4.5 | PASS (+2.42) |

Calculator cross-validation: the same computation reproduces the
shipped annotations in `ww_theme.dart` exactly — `mutedOnDark` = 6.47:1
on `nav`, 5.63:1 on `surfaceHigh`; §4's paper pairs likewise reproduce
(4.62, 4.6). The calculator is true, so 6.92 is true.

### Type, target, layout

- **Type size:** caption 12sp = the `captionOnDark` role on the closed
  WwType scale; above the 10sp floor; weight regular as the role
  specifies. PASS.
- **Tap target:** stage + caption are ONE target — one
  `Semantics(container: true, button: true, label: 'Open <Chapter
  name>')` node (fake-canon assertion: `Open Genesis 1`) with inner
  semantics excluded (lesson 25 pattern, same construction as the
  shipped VOTD card). Geometry at 360dp wide: artwork 150.0dp
  (360 × 500/1200) + caption band 48.0dp (probe-measured at scale 1.0)
  = a 360 × ≥198dp target. ≥48dp in both dimensions, everywhere in the
  target. PASS.
- **Grid / margins:** caption text inset is `WwSpace.screenMargin`
  (16dp) on both sides; the artwork is full-bleed in its pinned slot
  exactly as the shipped mini-map occupied it; scroll area keeps its
  shipped 16dp top padding and 16dp section rhythm. All spacing
  literals in the allowed set. PASS.
- **Text scale 2.0 (gate probe, temporary test, run and removed):**
  no exception, no overflow. The caption wraps and its band grows —
  103.0dp under test-font metrics (an upper bound: the test font is
  ~1em per glyph; the longest real caption class, e.g. a
  `2 Thessalonians` chapter with a 4-digit count, wraps to at most
  2 lines in real serif) — while the artwork stays exactly 150.0dp
  (total node 254.0dp = 150 + band + border lines) and the `Expanded`
  scroll area absorbs the growth. The caption never crowds out the
  stage. PASS.
- **Morph / motion law:** 600ms under `Curves.easeInOut`
  (`ambientMorphDuration`), driven by an `AnimationController` whose
  eased value feeds the painter. Judged as what it is — an in-place
  transition of a pinned visual, not a navigation motion. Pushes are
  untouched: `WwPageRoute` (300ms slide-from-right, no fade) has no
  diff, and the package adds no fade anywhere. The 600ms duration is
  the spec §0 named exception the founder's ruling requires, recorded
  in the spec, not drift. PASS.
- **Reduced motion:** in code, `MediaQuery.disableAnimations` is read
  in `didChangeDependencies` into `_reducedMotion`; `_shouldRotate`
  requires `!_reducedMotion` so the ticker never starts; the painter
  is forced to `t = 1`; switching reduced motion on mid-session stops
  the ticker via `_syncRotation` and snaps an in-flight morph to 1.
  In tests, the new suite's reduced-motion case pumps 12s and the
  caption never moves. One still chapter, as specced. PASS
  (see Low-3 for the one untested switch path).

## 2. Brightness law unchanged

`git diff 95997ee..2f46892 -- flutter/lib/widgets/arc_stage.dart`
contains **zero deleted lines**: the file is purely additive (one
import, the `ArcGeometry.xForPosValue` double helper, and
`AmbientArcPainter` appended). `MiniSelectionPainter`,
`renderArcImage`, `ambientLuminanceCap` (0.216), `_ambientRasterGuard`
(0.008), and `clampToAmbientCap` are byte-identical to base.

The featured rendering IS the shipped selected-chapter rendering:
`AmbientArcPainter` calls the same `_arcColor` sweep, the same alpha
formula `0.30 + min(0.45, log10(n) × 0.18)`, the same 1.6 stroke, the
same `goldBright` selection bar, and consumes the precomputed
geometry of §7 (partner-ascending — draw order only; the arc set,
colors, and alphas are identical). Endpoint proof from the painter's
own arithmetic: at `t = 0` every paired lerp collapses to the
outgoing chapter's values, unpaired incoming arcs draw at factor 0
(skipped), and exactly one gold bar draws at alpha 1; at `t = 1` the
mirror holds. The morph interpolates geometry between two shipped
renderings and invents no color path. The background is the shipped
selection-state image — `renderArcImage(includeArcs: false,
includeLabels: false)`, cached by (lo, hi, band) — the exact call the
shipped mini-map made whenever a chapter was selected. PASS.

## 3. Panel removal

- Grep of `flutter/lib` for the panel's widgets, texts, and semantics
  (`_selectionPanel`, `_partnerChip`, `Connected chapters`,
  `Clear selection`, `onClearSelection`) returns nothing in Home; the
  only `ww_home_selected` hits are the retirement itself (shell
  removes the stale key in `_loadPrefs`, `recordSelection` /
  `clearSelection` no longer write it).
- Home tree order, from code and from the new suite's
  rendered-position assertions: top bar → stage + caption (pinned,
  above the scroll area) → Continue reading → Verse of the Day →
  Study Plans → Study Tools → 24dp bottom padding. Exactly spec §1.
- Every Home chapter entry opens the reader directly: stage/caption
  tap → `onOpenChapter(featured)`; Continue reading and Verse of the
  Day route through the shell's existing open-chapter path; no
  intermediary surface remains. Library grids are untouched by the
  diff and already opened the reader directly. PASS.

## 4. In-reader partners (connections sheet chapter section)

Contrast computed for both palettes against the sheet's actual
background (`_palette.bg`: paper `#FFFDF8` / dark `surface`
`#14141C` — the sheet sets `backgroundColor: _palette.bg`):

| Text (role) | Paper ratio | Dark ratio | Threshold | Result |
|---|---|---|---|---|
| Heading `<Chapter> connects to` (`refLabelStyle`, 13sp w600) | **4.62** (`goldTextOnPaper` on paper) | **9.55** (`goldBright` on surface) | 4.5 | PASS |
| Partner name (`smallBodyStyle` w600, 13sp) | **17.12** (ink) | **15.29** (navInk) | 4.5 | PASS |
| Count line + empty-state line (`captionStyle`, 12sp) | **4.57** (`mutedOnPaper`) | **6.03** (`mutedOnDark`) | 4.5 | PASS |

The paper count line at 4.57:1 is the thinnest margin in the package
(+0.07). It passes, and it is the shipped palette role doing shipped
duty (the same pair carries every verse-section caption in the sheet);
recorded here as the number to watch, not a finding.

- **Rows:** `Container(minHeight: WwSpace.minTarget)` + 8dp vertical
  padding — ≥48dp guaranteed by construction and asserted by size in
  the new suite for all three fake-canon partners. Internal gaps
  (16 before heading, 8 after, 2 inside the row) are in the allowed
  set; sheet padding is the 16dp margin.
- **Ranking:** rows come straight from the shipped
  `BibleData.partnersSorted` (count desc, chapter asc); the suite
  asserts ranked order from rendered `dy`.
- **Routing:** tap pops the sheet, then `host.openChapter(partner)` —
  the shell's one procedure; no new routing. Verified in the suite
  (tap lands on the partner chapter, sheet gone).
- **Empty state:** `No chapter connections are recorded for this
  chapter.` in `captionStyle` renders for every partnerless chapter —
  the section always exists, no dead end; asserted in the suite.
- **Placement — LAST in the scroll region: judged SOUND on design
  merits, explicitly.** (1) The sheet is entered from a verse tap;
  the verse's own Connections are the primary task and belong at the
  top, at their shipped position — chapter partners are the
  exploratory second task the ruling adds. (2) The build evidence is
  architectural, not cosmetic: first placement pushed every shipped
  section ~190dp down the lazy list and 12 shipped landmarks across
  five suites fell out of the build range — the sheet's existing
  order is load-bearing. (3) The cost of last placement is one scroll
  through the content the user came for, the same cost long verse
  lists already impose. (4) The founder's ruling requires partners
  reachable from inside the reader; it does not rank the sections.
  The amendment (§8 as built) is accepted as the correct reading of
  the ruling. PASS.

## 5. Deviations — dispositions

**(a) Catholic deuterocanon excluded from the pool — ACCEPTED.**
The deuterocanon carries no cross-reference data anywhere in the
product: it lives in a separate dataset (`BibleData` has no
deuterocanon chapters at all) and `deuterocanon.dart`'s own doc
states the woven web carries no data for these chapters. A featured
deuterocanon chapter could only render an empty web under a
fabricated-looking `0 connections` caption — precisely the dishonest
surface the studio's rules exist to prevent. The pool iterates core
chapters under every tradition, so Catholic gets the identical
full-core pool (1,165, §5b). Founder-visible effect: rotation never
names a deuterocanon chapter — consistent with every other
connection surface in the app. If the founder wants deuterocanon in
rotation, that is a data-pipeline package, not a defect in this one.

**(b) Floor = 25% of the canon median — ACCEPTED; the stage can
never look sparse under it.** Recomputed by the gate from the
shipped `assets/data.json` (344,799 refs), reproducing the spec's
table exactly: full core median 495 → floor 123.75 → pool **1,165**
(24 chapters excluded, counts 43–123); Jewish median 429 → floor
107.25 → pool **915** (14 excluded); Genesis 1 = 716, the founder's
number. The floor is stated in total refs, but the stage draws
partner arcs, so the gate verified the proxy against actual arc
counts instead of trusting it: eligible chapters draw a **minimum
of 49 arcs** (Ezekiel 41, 191 connections), p25 = 166, **median =
227**, max = 725; even the lowest-count eligible chapter (136
connections) draws 74 arcs; the Jewish pool's minimum is 47 arcs.
The sparsest frame this stage can ever show is ~50 crossing arcs
under the full sweep — a dense web by any reading of the founder's
screenshot complaint (which was saturation, never sparsity). The
floor's real work is excluding only 2.0% of chapters.

**(c) 3s interval + 600ms morph vs "every couple seconds" —
ACCEPTED.** The cycle is 2.4s of still chapter + 0.6s of morph,
repeating every 3.0s sharp (ticker arithmetic verified in code and
by the suite's rotation case). Read as ambient cadence, 3s is
"every couple seconds"; a literal 2s cycle would leave only 1.4s
still and turn a background visual into churn, against the
founder's own framing ("more a visual thing"). If the founder wants
it faster on device, the remedy is one constant
(`ambientInterval` in `lib/data/ambient_stage.dart`). Not a defect.

## 6. Evidence (gate's own runs, this worktree)

- `flutter test test/arch_ambient_home_test.dart` — **24/24 pass**
  (pool/picker arithmetic, caption format + semantics + ≥48dp
  caption geometry, 3s rotation, every §5 pause condition,
  reduced-motion stillness, panel absence, §1 order from rendered
  positions, shell retirement + stage-tap-to-reader, in-reader
  partners ranked/≥48dp/routed, partnerless no-dead-end).
- Spot-check of the lesson-40 translated suites:
  `test/home_study_sections_test.dart` + `test/shell_test.dart` —
  **23/23 pass**. The register's translations hold: STORE-3 now
  asserts the retirement it actually landmarked; the order and
  retirement tests keep their shipped assertions verbatim under the
  taller-viewport / scroll-into-range fixtures.
- `flutter analyze` on the five touched lib files — **no issues**.
- Text-scale 2.0 probe (§1) — pass, probe file removed after the run.
- Maren's full-suite claim (438/438) and web build were spot-checked
  as above, not re-run in full by the gate; the claims the verdict
  depends on (contrast, pool arithmetic, brightness diff, new-suite
  behavior) are all independently re-derived here.

## 7. Lows (non-blocking observations — no fix required to merge)

- **Low-1 (parity):** chapter-partner rows are plain `InkWell`s;
  sibling tappable sheet rows (conference, Sefaria) carry a
  `Semantics(container: true, button: true, label: …)` wrapper.
  Default merged semantics still announce the row's two texts and
  the tap works, so this is polish, not a failure. Optional exact
  change, future package: wrap `chapterPartnerRow`'s `InkWell` in
  `Semantics(container: true, button: true, label: 'Open <name>')`
  with `ExcludeSemantics` around the row content, matching the
  sibling rows.
- **Low-2 (performance observation):** the chapter section builds
  all partner rows eagerly inside the sheet's single-scroll
  `ListView` children list — the same construction the shipped
  layered form already uses for its sections. Worst real chapter
  carries 725 partners (~725 two-line rows at sheet open). No
  failure observed in tests; revisit only if sheet-open jank is
  reported on device.
- **Low-3 (test gap, behavior verified):** reduced-motion
  switch-on mid-session is verified in code (dependency change →
  ticker stop, morph snap, painter `t = 1`) but no widget test pins
  the switch itself; the pinned case is initial reduced motion.
  An optional future test, not an app change.

**No blocking defects found. The package satisfies the founder's
ruling as specced: the panel is gone, the arch is a pure rotating
visual with a legible caption, taps open the reader, and partners
live in the reader — with the brightness law, the shipped rendering,
and every shipped Home section byte-for-byte intact around it.**

— Petra, Design Auditor & QC, Woven Word Studio (gate run Oct 15, 2026)
...[truncated 1655 chars]