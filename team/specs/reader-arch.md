# SPEC — READER CONNECTION ARCH, collapsible & remembered (binding)

**Producer:** Silas. **Builder:** Maren. **Gate:** Petra, against
THIS spec. **Base:** 2532f4a (worktree `~/workspace/ww-reader-arch`,
branch `reader-arch` off origin/main).
**Authority:** founder request (Tyson, Oct 15, 2026, from the
reader with the connections sheet open), verbatim: "I think it
would be cool if we added the connection arch image to the top
right here that users can minimize or expand. We should remember
what they last did (minimize or expand) so it's like a saved
profile setting kinda."
**Lessons applied:** #13 (tokens by role), #16 (every element in
every state it renders in), #19 (profiles are a store concern;
new document fields default on load), #20 (presentation defaults
set explicitly), #22 (validation is a shape gate in front of the
parser), #25 (a tooltip IS the semantics label), #30 (geometry
asserted from rendered positions), #31/#42 (the painter color
path is NOT touched — the luminance bound is inherited, not
re-derived), #37/#43 (a new always-visible control is a layout
budget: the toggle is priced into the panel, never the top bar),
#40 (test translations re-seed scenarios), #41 (baseline proof
for red tests), #44 (stored values resolve through a getter over
the model, never an assignment race), #51 (worktree under
~/workspace), #54 (arm64 deliverable, `_arm64_` marker, measured
sizes).
**Design law:** Tabs design-audit as adapted — `ww_theme.dart`
tokens only, 8dp grid, 16dp margins, ≥48dp targets, closed
radius scale {8,10,12,16,18,20,pill}, reduced motion renders
final states. **New tokens: none. New colors: none. New radii:
none. New durations: none** (the collapse uses the theme's
existing `WwMotion.expand`, 220ms).

---

## 0. Interpretations pinned by this spec (flagged in the report)

- **I-1 Placement.** "The top right here" = the top of the
  reading area, directly under the reader top bar, above the
  pager. The arch panel sits there inset by the 16dp screen
  margin; its minimize control overlays the panel's own top
  right. When minimized, the panel leaves the layout entirely
  and a 48dp expand chip floats at the top right of the pager
  viewport — the affordance stays where the founder pointed,
  and the reading flow reclaims every pixel of the panel.
- **I-2 The arch rendering is Home's, verbatim.** Stage canvas
  `Size(1200, 500)`; background from `renderArcImage` with
  `includeArcs: false, includeLabels: false` (chapter bars only)
  at the width's density band, cached per band exactly as Home
  caches it; foreground `MiniSelectionPainter(selected:
  currentChapter)` over the whole-canon range
  (0 .. totalChapters−1). No painter is modified; no new
  painter is written.
- **I-3 The stage is a plate in both themes.** The panel's
  surface is `WwColors.stage` (pure black) in Dark AND Paper —
  the arch is an inset image, and its black stage is the app
  identity (Home's stage is the same plate). Drawing the sweep
  directly on paper was considered and is rejected in the gate
  with computed numbers (the sweep's hues at their shipped
  alphas sit far under the 3.0 graphic band on cream; fixing
  that would mean recoloring the web away from Home's). Only
  the plate's frame and the minimized chip take palette roles.
- **I-4 First-run default: EXPANDED.** Recorded studio call:
  the founder asked for this feature to exist; a default-hidden
  feature is one nobody discovers, and dismissal is a single
  tap that is then remembered forever. (YouVersion and Logos
  both default auxiliary reading visuals ON with a persistent
  dismiss — the category pattern.)
- **I-5 Deuterocanon: NO arch element, NO toggle.** Those
  chapters carry no cross-reference data at all
  (`deuterocanon.dart`: "The woven web carries no
  cross-reference data for these chapters"), and the deutero
  reader's first page already says so plainly. An arch there
  would be a fabricated web or an empty frame; the honest
  behavior is absence. The per-profile setting simply has no
  surface in that reader.
- **I-6 Document version stays 3.** The setting is a new
  OPTIONAL member of the profile bucket, defaulted on load
  (the lesson-19 pattern that carried v1/v2 forward). Old
  builds ignore the key; new builds default it in old
  backups. No migration, no version bump.
- **I-7 The setting is NOT the reader theme's prefs key.**
  The founder framed this one as per-profile ("a saved
  profile setting"), so it lives in the `ww_user_data`
  document inside the profile bucket — not in a global
  SharedPreferences key like `ww_reader_theme`.

## 1. Store (UserData / ProfileData)

- `ProfileData` gains `bool readerArchExpanded`, default
  `true`. JSON member name: `readerArchExpanded`, written by
  `toJson` on every profile bucket, read by `fromJson` only
  when the member is a bool (any other shape → default true;
  defensive parse never throws, as everywhere in this file).
- `UserData.readerArchExpandedFor(profileId)`: the profile's
  value; a missing profile resolves to `true` (the default —
  read paths never create buckets).
- `UserData.setReaderArchExpanded(profileId, value)`: writes
  through `_bucketForWrite` (a write materializes the bucket,
  the `setNote` pattern).
- The reader resolves the value through a getter over its
  loaded model on every build (lesson 44) — no mirrored field,
  no load race. Toggling mutates the model inside `setState`
  and persists through the reader's existing
  `_persistUserData()`.

## 2. Backup (run 6 rules)

- Export carries the member automatically (it is part of
  `ProfileData.toJson`).
- `validateImport` gains ONE shape rule, beside the existing
  bucket checks: a profile bucket whose `readerArchExpanded`
  member is present and not a bool is rejected as
  `notBackup`. Absent is valid (pre-package backups import
  and default to expanded).
- Round-trip test: two profiles holding opposite values
  export → validate → import with both values intact.

## 3. Reader UI (chapter-page reader only)

- **Expanded panel** (key `reader-arch-panel`): below the top
  bar, `Padding(16, 8, 16, 0)`, clipped to `WwRadius.sheet`,
  stage-black. Inside, the Home construction (I-2) sized by
  LayoutBuilder width at the stage's 1200:500 aspect. A
  `Semantics(container: true, label: 'Chapter connections for
  {chapterName}')` wraps the stage. The paint carries key
  `reader-arch-paint` (test seam).
- **Minimize control** (key `reader-arch-minimize`): an
  `IconButton`, 48dp constraints, overlaid at the panel's top
  right (`Positioned(top: 0, right: 0)`), icon
  `Icons.keyboard_arrow_up`, color `WwColors.goldBright` (on
  the stage plate), tooltip `Hide chapter connections`.
- **Minimized chip** (key `reader-arch-expand`): floats in
  the pager Stack at `Positioned(top: 8, right: 8)`; a
  Material card in `palette.cardBg`, `WwRadius.chip`, border
  `palette.hairline`; `IconButton` 48dp, icon
  `Icons.keyboard_arrow_down`, color `palette.accent`,
  tooltip `Show chapter connections`.
- **Collapse motion:** the panel slot is an `AnimatedSize`
  (`WwMotion.expand`, `WwMotion.curve`); under
  `MediaQuery.disableAnimations` the AnimatedSize leaves the
  tree entirely and the slot swaps outright — reduced motion
  renders the final state. (As built: a zero-duration
  AnimatedSize throws "mutated in its own performLayout" in
  this SDK; the instant swap is the design law's construction
  in any case.) The chip appears only in the minimized state
  (no fade).
- **Chapter following:** the painter's `selected` is the
  reader's `_currentChapter`; a page turn repaints the new
  chapter's web (`MiniSelectionPainter.shouldRepaint` already
  keys on it). A chapter with no recorded partners renders its
  gold bar on the bars field — the truthful empty web.
- **Gestures:** the panel is in the Column ABOVE the pager —
  outside the PageView's gesture path by construction; the
  chip intercepts taps on itself only. Page turns from the
  reading area, in-page scroll, verse tap/long-press and
  selection mode are regression-tested with the panel
  expanded.
- **States with no panel:** the loading and error scaffolds
  render exactly as shipped (the panel belongs to the loaded
  reading state).

## 4. Tests (all new assertions named in the report)

Store: default true with no document; set/get round trip;
two-profile isolation at model level; document round trip
preserves opposite values; a legacy document without the
member loads expanded; a non-bool member in a stored
document loads as the default (defensive).
Backup: round trip carries both profiles' values; a
non-bool member is rejected `notBackup`; a pre-package v3
backup (member absent) validates.
Widget (reader_arch_test.dart, through `pumpReader`):
(1) panel renders expanded by default, painter selected ==
start chapter; (2) minimize tap removes the panel and shows
the chip, and the stored document now holds false —
re-pumped fresh with that document, the reader opens
minimized (persistence across relaunch); (3) a seeded store
whose ACTIVE profile holds false while another profile holds
true opens minimized (per-profile isolation at the reader
seam); (4) turning a page updates the painter's selected
chapter; (5) a horizontal fling on the reading area turns
the page with the panel expanded; (6) at text scale 2.0:
no overflow exception, panel present, both controls ≥48dp
from rendered size; (7) reduced motion: toggle applies the
final state with no animation in flight.
Deutero: pumped DeuteroReaderScreen contains no
`reader-arch-panel`, no minimize control, no expand chip.

## 5. Ship

Maren verify (analyze clean, full suite green — red tests get
a lesson-41 HEAD baseline before anyone owns them), Petra
gate (§3 surfaces in both themes and both states, contrasts
computed from tokens/scripts, geometry from rendered
positions), CI green on main, arm64 APK staged per lesson 54
at `~/workspace/woven-word/build-reader-arch/
woven_word_reader_arch_arm64_20261015.apk`, mirrored to the
`flutter-apk-latest` release at matching size, signer digest
read from the CI log. Payroll: one shipped feature, $1,000
accrued, pays on founder verification.
