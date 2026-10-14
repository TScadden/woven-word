# Board run 8 — FIX ROUND report (Maren, Lead Flutter Engineer)

Date: 2026-10-14. Scope: two founder defects on the run-8 build
(from the founder's home screenshot,
`feedback/founder-home-run8-20261014.png`) plus Fix Item 3, a
founder correction added mid-round (screenshot:
`feedback/gospel-library-conference-archive-20261014.png`).
Silas's retrieval and root-cause work was verified in the code
independently; agreement and one sharpening are noted per defect.

Verification of the final tree: `flutter analyze` — no issues.
Full `flutter test` — **192 tests, all passed** (includes the new
geometry and routing suites). `flutter build web --release` —
green. **CI: "Build Flutter app" run 38655650765 — completed,
success**, on head 508b037. Commits: Defect 1 `69e0d07`,
Defect 2 `bd3e458`, Fix Item 3 `9e0fd7d`, records `508b037`
(this sentence's own amendment is a docs-only follow-up that the
workflow's path filter does not rebuild).

---

## Defect 1 — Bottom tab bar misalignment

**Root cause, as verified in code** (`flutter/lib/screens/
shell_screen.dart`, `_WwShellState._tabBar` / `_tabSlot`): the
slot's `Stack` is full-width — its non-positioned child is sized
under the slot's tight `Expanded` width, which is also why the
indicator (`Positioned(left: 0, right: 0)` + `Center`) already
sat dead-on the column center in the founder's measurements
(normalized indicator center 166 vs column center 167). The
sharpening on Silas's account: the Stack sizes to the full slot,
not to its child; what shrink-wraps is the content `Container`
inside the Stack — no width, so it wraps its `Column` (whose
width is its widest child, the label) — and the Stack's default
alignment (topStart) then pins that narrow container to the
slot's left edge. Content at the left edge, indicator at the
center: the visible split. Agreement with Silas on mechanism and
fix shape.

**Fix:** the content `Container` now spans the full slot
(`width: double.infinity`) and its `Column` centers its children
(`crossAxisAlignment: CrossAxisAlignment.center`, main-axis
centering unchanged). No per-tab padding, no offsets. Preserved
exactly: the three `Expanded` equal columns, the indicator and
its placement, the ≥48dp target (`topBarHeight` minimum height
on the same container), the Screens badge construction,
semantics labels (`'$label, $badgeCount screens open'` /
`label`), the badgeCount semantics string, and re-tap behavior
(`onTabTap` untouched). All insets remain on the 8dp grid.

**Geometry test** (`flutter/test/tab_bar_geometry_test.dart`,
new): pumps the real shell at **390×844** and again at
**text scale 1.3**, and asserts from rendered positions
(`tester.getCenter` on finders), never widget properties:

- slot width = 390 / 3 = **130dp**; expected column centers
  **65 / 195 / 325**;
- (a) icon centers equally spaced: both spacings within
  tolerance of 130dp and of each other;
- (b) each icon center == its column center;
- (c) the indicator's center == the active (Home) column center
  (and == the Home icon's center).

**Stated tolerance: 1.0dp** on every assertion. All pass on the
fixed tree. Mutation check: with the shell fix stashed, both
tests fail on the pre-fix tree — the test measures the defect,
not the fix's implementation.

## Defect 2 — Home mini-map arch blowout

**Root cause, as verified in code** (`flutter/lib/widgets/
arc_stage.dart`, `renderArcImage` non-faint path, as used by
`home_tab.dart` at its pinned 1200×500 stage): ambient arcs drew
with `BlendMode.plus` and the hue-sweep `_arcColor` (HSL hue
275→0, s 0.85, l 0.58) at per-arc alpha
`min(0.30, 0.028 + log10(n)·0.055) × density`. Home's whole-Bible
range at phone width computes band **0.30** (`bandFor(densityFor(
390))` — verified, and the evidence generator now asserts it).
Thousands of arcs overlap near the axis and mid-spans; additive
sums blow past 1.0 and clip to a white/yellow dome with
off-palette green/cyan fringes. Agreement with Silas in full.

**Fix:** the ambient path — shared by Home and any
`renderArcImage` caller — now draws **one on-palette token,
`WwColors.gold` (#B8860B, exposed in code as `ambientArcToken`),
with srcOver compositing**. No hue sweep in the ambient path.
The per-arc alpha formula and the density bands are unchanged
in form, so the band-regeneration behavior is untouched; the
faint mode is untouched (it keeps its flat dim color and its
additive paint under the selection overlay, as before).

Brightness parameters, stated for the gate:

- **Token:** `WwColors.gold` #B8860B only (gold family; no
  goldBright, no sweep colors in the ambient path).
- **Blend mode:** `BlendMode.srcOver` (was `BlendMode.plus`).
- **Per-arc alpha:** `min(0.30, 0.028 + log10(n) × 0.055) ×
  density` — at the Home band (density 0.30): **0.0084–0.09**;
  at full density: at most **0.30**.
- **Luminance cap (brightest possible ambient pixel):** srcOver
  accumulation of one color over black converges to that color
  and can never exceed it, so the cap is the token itself at
  full accumulation — **#B8860B, WCAG relative luminance
  0.273**. Stacked arcs deepen toward token gold; whitening is
  impossible by construction.
- **Selection vs ambient:** `MiniSelectionPainter` is unchanged
  — normal blending, single pass per partner, alpha
  **0.30–0.75** — so a selected chapter's arcs land in one pass
  at up to 0.75 strength against an ambient field whose measured
  p99 is 0.196 (below). **Flag for Petra, per the brief:**
  selection still uses the pre-existing hue-sweep `_arcColor`;
  that is shipped behavior and I did not change it. Judging
  whether the sweep survives in selection is the gate's call.

**Evidence** (`team/specs/run8-fix-evidence/`, regenerable):
`flutter/tool/arc_minimap_evidence_test.dart` renders the
ambient whole-Bible mini-map at the exact Home parameters
(1200×500 stage, lo 0, hi 1188, band 0.30, `faint: false`,
`includeArcs: true`, `includeLabels: false`) and writes a PNG;
the BEFORE capture was taken from the pre-fix tree and the
AFTER from the fixed tree. `compute_stats.py` in the same
folder computes the stats (WCAG relative luminance, composited
over black, arc region = rows 0–349 above the axis,
420,000 pixels):

| capture | mean | p99 | max | frac > 0.9 |
| --- | --- | --- | --- | --- |
| before (plus + hue sweep) | 0.592718 | 1.000000 | 1.000000 | 0.595550 |
| after (srcOver, gold token) | 0.103149 | 0.196040 | 0.215765 | 0.000000 |

The after max (0.216) sits below the construction cap (0.273)
because accumulation at these alphas is finite — the cap is the
asymptote, not a tuning target.

**Home usage unchanged:** 1200×500 pinned stage, whole-Bible
range when nothing is selected, selection-only overlay behavior
untouched.

---

## Fix Item 3 — Talks Gospel Library does not carry open in the Citation Index

Founder correction (via Rusty, Oct 14, 2026), verbatim: "It
looks like the conference talks only go back to 1979 in Gospel
Library. We should still have the talks that go all the way
back in our app, you just can't open them in Gospel Library.
You have to open them in the Citation Index." His screenshot
shows Gospel Library's own archive bottoming out at the
"1971–1979" bucket. Recorded as
`team/memory/decisions/2026-10-14-conference-talk-routing-citation-index.md`;
filed spec `team/specs/run8-conference-layer.md` §4.4.1 amended
in place the same day, with copy C-2 amended and C-25/C-26
added (lessons 23/28: Petra gates against the amended rule).

**Dataset does not shrink.** 4,964 talks back to April 1942,
68,999 edges, 905 of 1,189 chapters — all identical before and
after the rebuild. This is a link-routing change only.

**Pipeline** (`tools/conference/`): the Index talk-page URL is
recorded per talk from the Index's own published structure.
The conference pages link each talk only via `getTalk('<sci
id>')` — there is no href to copy; the URL form is the site's
own resolution of that link, taken from its published frontend
code (`static/homepage/scripts/base.js`, `decodeCenter` maps a
talk id to `/content/talks_ajax/<id>/`), verified live on
2026-10-14: `talks_ajax/1/` serves the 1942 Heber J. Grant
talk's own page and `talks_ajax/1383/` the 1965 David O. McKay
talk's. `harvest_conferences.py` now records `indexUrl` per
talk via `sci_talk_url()`; because the checkpointed harvest
already held every sci id from those same pages, the existing
records were backfilled with `--backfill-index-urls` (**5,874
of 5,874 records**, no re-fetch, no new pages requested).
`build_dataset.py` emits the new asset field **`"x"`** and the
routing counts. Method limits unchanged and honored: facts +
the Index's own link targets only; no churchofjesuschrist.org
scraping; no SCI database extraction; ordinary-use pacing
(the backfill and rebuild made zero network requests).
README's Talk-links section rewritten and a run-log addendum
appended with these counts.

**App routing** (`conference_screens.dart` `_readAction()`,
formerly `_gospelAction()`; the talk view is the only external
read action — checked: the reader sheet's Conference talks rows
navigate internally to the talk view and carry no external
action of their own). Data-driven per talk, **no year cutoff
anywhere in the code**:

1. Per-talk Gospel Library URL (`url != null &&
   !urlIsConference`) → **"Read in Gospel Library"** (Form A,
   unchanged; semantics `Read {title} in Gospel Library, opens
   external app or website`; failure snackbar C-20 `Could not
   open Gospel Library.`). Form A wins when both links exist.
2. Else, Index page recorded (`indexUrl != null`) → **"Read in
   Citation Index"** (new Form C; semantics `Read {title} in
   the Scripture Citation Index, opens external app or
   website`; failure snackbar C-26 `Could not open the Citation
   Index.`). This replaces the Form B conference-level fallback
   for the whole `urlIsConference` set that has an Index page.
3. Else, conference-level Gospel Library URL only → **Form B
   residual** (existing label, mandatory C-18 caption, Form B
   semantics — unchanged code path, now reached only when no
   Index page exists).
4. Neither → the existing no-link caption (C-19) in the
   button's place. No disabled form exists in any branch.

`ConferenceData` parses the new field as
`ConferenceTalk.indexUrl` (optional, null when absent), keeping
the asset's compact schema style. Global copy made truthful:
Profiles explanatory copy (spec C-2) now ends "…open each talk
in Gospel Library **or the Citation Index**." (screen + spec +
test updated together).

**New link counts (shipped dataset, asserted by a dataset
test against the real asset):**

| route | talks |
| --- | --- |
| Per-talk Gospel Library (Form A) | 3,014 |
| Citation Index (Form C) | 1,950 |
| Residual conference-level (Form B) | 0 |
| Neither (no-link caption) | 0 |
| **Total** | **4,964** |

Every talk in the dataset carries an Index URL (4,964 of
4,964), including the dataset's first talk (April 1942,
"Upholding the Hands of Our Leaders", Index page
`talks_ajax/3/`).

**Tests:** dataset parse coverage for `x` (fixture rows +
the shipped-dataset routing test above, including counts and
the 1942 talk); widget coverage for Form A precedence (a talk
carrying both links shows no Citation Index action), Form C
(label, semantics naming the Index, launch target = the talk's
own Index page, no Form B caption), the Form C failure
snackbar, the residual Form B (synthetic talk: conference link,
no Index page), and the neither form. Existing sheet/action
suites pass unchanged in behavior.

---

## Deviations — stated from `git diff` (lesson 29)

Read off the final diff, not from memory:

1. **Files changed:** `flutter/lib/screens/shell_screen.dart`
   (Defect 1 only), `flutter/lib/widgets/arc_stage.dart`
   (Defect 2 only), `flutter/lib/data/conference_data.dart`,
   `flutter/lib/screens/conference_screens.dart`,
   `flutter/lib/screens/profiles_screen.dart` (one copy string),
   `flutter/assets/conference.json` (rebuilt, one line),
   `flutter/test/` (new geometry suite; conference suites +
   fixture updated), `flutter/tool/` (new evidence generator),
   `tools/conference/` (harvester, builder, README),
   `team/specs/` (spec amendment, this report, evidence folder),
   `team/memory/` (decision record, lessons 30–32).
2. **Formatter churn — none.** The local SDK formatter's style
   differs from the repo's committed style; an intermediate
   `dart format` pass was fully reverted and every change
   re-applied by hand in the repo's style, so the diff contains
   only the round's own edits. (The one-line `conference.json`
   diff is the asset's single-line JSON form: the whole file is
   one line, and the line gained the `x` fields.)
3. **Selection painter untouched** — including its hue sweep
   (flagged above for the gate), contrary to any reading of
   "on-palette colors only" that would extend it past the
   ambient path; the brief scopes that rule to ambient and
   names selection's sweep as shipped behavior.
4. **Form B was not deleted.** The brief replaces Form B
   "wherever an Index talk URL exists"; the conference form
   remains as the residual branch for a talk with a
   conference-level link and no Index page (zero such talks in
   the shipped dataset), rather than dropping such a talk to
   the no-link caption while a working link exists.
5. **`indexUrl` is an optional constructor parameter** on
   `ConferenceTalk` (default null) rather than required, so
   existing test constructions stand; the parser always sets
   it from the asset.
6. **The pipeline checkpoint file** `tools/conference/work/
   talks.jsonl` gained `indexUrl` on all 5,874 records via the
   documented backfill; that file is git-ignored working state,
   so the change is visible in the pipeline code and README,
   not in the commit diff.

## Lessons

Appended to `team/memory/LESSONS.md` as lessons 30–32
(geometry asserted from rendered positions; bounded-by-
construction rendering with measured evidence; destination
coverage and data-driven routing).
