# SPEC — HOME ARCH GOES AMBIENT (binding for this package)

**Producer:** Silas. **Builder:** Maren, Lead Flutter Engineer.
**Gate:** Petra, against THIS spec.
**Base:** 95997ee (detached worktree).
**Authority:** founder ruling
`team/memory/decisions/2026-10-15-home-arch-ambient-ruling.md`
(Oct 15, 2026), verbatim anchors: the arch rotates "through
different parts of the Bible… every couple seconds it will
randomly select a new place in the Bible and show small text
underneath that says where it is and how many connections there
are"; chapter taps "Open the reader directly, connections live
in the reader."
**Lessons applied:** #13 (tokens by role), #16 (every state),
#21 (ambient text measurement), #25 (semantics container),
#30 (geometry from rendered positions), #31/#42 (brightness bound
by construction — the painter color path is NOT touched),
#40 (test translation, never silent drop), #41 (baseline proof
for red tests), #46 (compute the instances before pinning a
rule), #48 (decorative geometry is a text budget), #51 noted —
this package's worktree is `/tmp/ww-ambient` BY THE PRODUCER'S
EXPLICIT INSTRUCTION for this package, overriding the lesson's
default; all verification logs are written inside the worktree
before each claim is made.
**Design law:** Tabs design-audit as adapted for Woven Word —
`ww_theme.dart` tokens only, explicit type scale, 8dp grid,
16dp margins, ≥48dp targets, closed radius scale, reduced motion
renders final states. **New tokens: none. New colors: none.
New radii: none. One new duration: the 600ms morph (§4), which
the founder's "more a visual thing" ruling and this package's
brief explicitly require; it is recorded here so the gate can
check it as a named exception, not drift.**

---

## 0. Interpretations pinned by this spec (flagged in the report)

- **I-1 "Home book list".** At 95997ee the Home scroll area has
  NO chapter list: its children are Continue reading, the
  selection panel, Verse of the Day, Study Plans, Study Tools
  (`home_tab.dart` `_scrollArea`). The chapter taps that fed
  the panel model were the panel's own partner chips and its
  Read button, plus selection state written by other surfaces.
  The ruling is therefore executed as: the panel and its taps
  are deleted; every chapter entry point that remains or is
  added on Home (the ambient stage, §5) calls the shell's one
  `openChapter` procedure directly; the Library chapter grids
  already open the reader directly and are unchanged.
- **I-2 Catholic deuterocanon in the picker pool.** The
  deuterocanon books are canon under Catholic
  (`canonContainsBook` returns true for indices ≥
  `DeuteroBook.bookIndexBase`), but they carry NO connection
  data and NO arcs — `deuterocanon.dart`'s own doc: "The woven
  web carries no cross-reference data for these chapters."
  A featured deuterocanon chapter would render an empty web
  and a fabricated-looking "0 connections" caption. The pool
  therefore iterates CORE chapters only; under Catholic the
  pool is exactly the full-core pool (§2, measured). This is
  the one place the brief's "pool follows active tradition
  incl. Catholic deuterocanon eligibility" cannot be built
  literally, and the evidence is the dataset's own doc.
- **I-3 Rotation mechanism.** The brief says "timer". The
  implementation uses a `Ticker` (Flutter's frame timer), not
  `Timer.periodic`: a ticker is muted by `TickerMode` (route
  coverage pauses it structurally), dies with its State, and
  leaves no pending-timer leak in the fake-async test suite.
  Observable behavior is the brief's: a feature every interval,
  pausable, resumable. "The timer only swaps featured chapter
  + drives the morph" (§7) is satisfied verbatim in function.

## 1. Final Home order (exact)

Pinned above the scroll area (unchanged slots):

1. Top bar (as shipped).
2. **Ambient stage + caption** — in the slot the pinned
   mini-map occupied. The panel's old scroll slot is NOT
   reused; nothing takes it.

Scroll area (`_scrollArea`), in order, shipped 16dp rhythm:

1. Continue reading (as shipped, byte-for-byte).
2. Verse of the Day (run 11, unchanged).
3. Study Plans (run 11, unchanged).
4. Study Tools (run 11, unchanged).
5. Bottom padding 24 (as shipped).

## 2. Picker pool — floor derivation (computed, lesson 46)

- Canon chapters for a tradition = core chapters whose BOOK
  is presented by the tradition's `CanonView` (core-book
  reading of `canonContainsBook`; Jewish = the 39 Tanakh
  books, every other tradition incl. Catholic = all 66 core
  books; deuterocanon per I-2).
- Median = the median of `chapterConnCount` over the canon
  chapters (sorted; odd count → middle value; even count →
  mean of the two middle values).
- **Floor = 25% of the median. Eligibility: a canon chapter
  whose TOTAL connection count (`chapterConnCount`, out + in,
  as shipped) is ≥ floor.**
- Measured on the shipped asset (`assets/data.json`, 1,189
  chapters, verified by script over the parsed counts):

| Canon | Chapters | Median | Floor (25%) | Pool size |
|---|---|---|---|---|
| Full core (none / LDS / Protestant / Catholic) | 1,189 | 495 | 123.75 | **1,165** |
| Jewish (Tanakh) | 929 | 429 | 107.25 | **915** |

  (Genesis 1 = 716 connections — the founder's example number
  is the real count.) Pool membership is computed once per
  (data, tradition) from the loaded dataset; never on a tick.

## 3. Picker rule

`AmbientPicker.next(pool, current)` (lib/data/ambient_stage.dart):

- Uniform random over the eligible pool, EXCLUDING the
  currently featured chapter: draw `r ∈ [0, pool.length − 2]`
  and map it onto the pool with the current chapter's slot
  skipped — every non-current member has probability
  `1 / (pool.length − 1)`. No immediate repeat, ever.
- Pool of 1 → that chapter (repeat is unavoidable and honest);
  pool of 0 → no feature, stage renders its background only.
- Random source: `dart:math` `Random`, injectable through the
  HomeTab `ambientRandom` test seam (shell passes none).

## 4. The ambient stage

- **Interval: exactly 3 seconds** between features (the
  founder's "every couple seconds", pinned to one number).
- **Rendering:** the featured chapter's arcs drawn with the
  SHIPPED selected-chapter rendering — `MiniSelectionPainter`'s
  geometry and color formula (one arc per partner chapter,
  single pass, `_arcColor` distance sweep, alpha
  `0.30 + min(0.45, log10(n) × 0.18)`, stroke 1.6, gold
  selection bar) — extended, not modified: the new
  `AmbientArcPainter` in `arc_stage.dart` consumes PRECOMPUTED
  arc geometry (§7) and an interpolation parameter. The
  existing painters, `ambientLuminanceCap`, and
  `_ambientRasterGuard` are untouched; no painter color path
  changes.
- **Background:** the shipped selection-state background —
  `renderArcImage` with `includeArcs: false` (chapter bars,
  no ambient web, labels off as shipped for the mini-map),
  cached by (lo, hi, band) exactly as shipped. Range (lo, hi)
  = first/last canon chapter of the active tradition (§2).
- **Morph (~600ms):** on a feature change the painter
  interpolates for exactly **600ms** under `Curves.easeInOut`
  (studio easing for a two-way transition):
  - Partner arcs of the outgoing (A) and incoming (B)
    chapters are paired BY RANK in partner-ascending order.
    A paired arc's source position, target position, and
    count (hence its sweep color/alpha) are lerped A→B.
  - Unpaired A arcs fade out in place (alpha × (1 − t));
    unpaired B arcs fade in (alpha × t).
  - The gold bar draws for A at (1 − t) and for B at t.
  - At t = 1 the render is exactly B's shipped selected
    rendering; at t = 0 exactly A's.
- **Caption:** directly under the stage, inside the same tap
  target: `<Chapter name> · <count> connections` in
  `WwType.captionOnDark` (the small-text role, token on the
  stage surface), count = the featured chapter's TOTAL
  `chapterConnCount`, comma-grouped by the shipped `_fmt`;
  singular `1 connection`. Exact examples: `Genesis 1 · 716
  connections`, `Exodus 1 · 0 connections`.
- **Tap-through:** the whole stage + caption is ONE tap
  target (full width; stage height as shipped ≈150dp at
  360dp wide, caption band ≥48dp) wrapped in
  `Semantics(container: true, button: true, label:
  'Open <Chapter name>')` with inner semantics excluded
  (lesson 25). Tap → `onOpenChapter(featured)` — the shell's
  existing reader routing, unchanged.
- **Reduced motion** (`MediaQuery.disableAnimations`): ONE
  still chapter — no rotation ticker is started, the morph
  controller never runs, the stage renders the initial
  feature at t = 1. Switching reduced motion on mid-session
  stops rotation at the current feature.

## 5. Pause matrix (all conditions; resume = a fresh interval)

Rotation runs ONLY when ALL of these hold; any one false
pauses it, and clearing it resumes with a fresh 3s interval
(no partial credit, no catch-up burst, no setState on pause
transitions — pause state is plain fields driving ticker
start/stop only):

| Condition | Mechanism |
|---|---|
| Home tab not selected | Shell passes `ambientActive = (tab == 'home')` (Home lives in an IndexedStack; hidden ≠ disposed). |
| App not foregrounded | `WidgetsBindingObserver`: only `AppLifecycleState.resumed` runs. |
| A route is pushed above Home | `RouteAware` on Home's own route (the observer is registered on the shell's HOME navigator only — a `RouteObserver` attaches to exactly one `Navigator`, framework-asserted): `didPushNext` pauses, `didPopNext` resumes. `TickerMode` muting is the structural backstop. |
| User scrolls Home | `ScrollStartNotification`/`ScrollEndNotification` from ANY descendant scrollable (main list, plan row) pause/resume. |
| User touches/interacts | Pointer down anywhere in the Home body pauses until pointer up/cancel. |
| Reduced motion | §4: never starts. |

## 6. Panel removal and state retirement

- `_selectionPanel` and `_partnerChip` are DELETED from
  HomeTab, with the `selection` and `onClearSelection` props.
  No panel widgets or semantics exist in the Home tree.
- **`ww_home_selected` is retired:** the shell stops writing
  it (`recordSelection` keeps only its in-memory value, which
  the reader host contract and the screens fallback still
  use), and `_loadPrefs` REMOVES the stale key and never
  restores from it. The screens document (`ww_screens_v1`)
  remains the restore source for reading places, as shipped.
- **`ww_home_scope` is byte-for-byte as shipped:** still
  removed in `_loadPrefs`, never read.
- **Continue reading is byte-for-byte as shipped** (its
  subtitle comes from the active screen, not from the retired
  key — verified: STORE-3's restored place is a screens-doc
  place).

## 7. Performance

- Per-chapter arc geometry is precomputed ONCE per loaded
  dataset (`buildAmbientArcGeometry`: for each chapter, its
  partner arcs as (partner, source mid-verse position, target
  mid-verse position, count), partner-ascending — the exact
  inputs `MiniSelectionPainter` derives per paint).
- The pool is computed once per (data, tradition) (§2).
- A rotation tick does exactly: one picker draw (O(1) index
  math over the cached pool), one setState swapping
  featured/previous, and starting the morph controller.
  No dataset scans, no partner lookups, no image re-renders
  on ticks (the background image is the cached bars image).

## 8. Connections live in the reader

Design call (the brief's first option): the verse connections
sheet gains a CHAPTER section, in both sheet forms (layered
and unlayered — the unlayered form's verse list becomes the
same single-scroll construction as the layered form so both
sections live in one scroll region; every shipped string and
row of the verse section is preserved verbatim):

- Position: directly under the sheet header, BEFORE the
  `Connections` verse section.
- Heading: `<Chapter name> connects to` in the palette's
  `refLabelStyle` (e.g. `Genesis 1 connects to`).
- Rows: the chapter's partners from the shipped
  `BibleData.partnersSorted` (count desc, chapter asc —
  ranked as shipped). Each row ≥48dp: chapter name
  (`smallBodyStyle` w600) over `<count> connection(s)`
  (`captionStyle`, comma grouping NOT applied — partner
  counts are the shipped panel chip's plain integers),
  keyed `chapter-partner-<globalChapter>`.
- Tap: pops the sheet, then `host.openChapter(partner)` —
  chapter-level (no verse anchor): same-book partners page
  within the reader, cross-book partners route through the
  shipped open-chapter book swap. No new routing.
- Empty: `No chapter connections are recorded for this
  chapter.` in `captionStyle` — the section exists for every
  chapter, so no chapter is a dead end, and the verse section
  below is untouched.

## 9. Scope guard

- `MiniSelectionPainter`, `renderArcImage`, and every other
  arc surface keep shipped behavior; the ONLY change in
  `arc_stage.dart` is additive (a double-position helper on
  `ArcGeometry` and the new `AmbientArcPainter`).
- No search-fix or reader-theme code is touched beyond the
  connections-sheet section (§8) in `reader_screen.dart`.
- Tradition, screens, plans, VOTD, and tools behavior are
  unchanged except §5's `ambientActive` prop and §6.

## 10. Test translation register (lesson 40)

| Shipped test | Fate |
|---|---|
| `home_study_sections_test.dart` — "order with selection: panel sits between resume and votd (I-1)" | TRANSLATED: the panel behavior it landmarked (a Home chapter surface that opens reading) is re-landmarked in `arch_ambient_home_test.dart` (stage order + stage tap opens the featured chapter; panel absent). The run-11 order test is replaced by the §1 order (stage pinned at top; resume < votd < plans < tools). |
| `home_study_sections_test.dart` — `pumpHome` helper (`selection`, `onClearSelection` params) | UPDATED to the new HomeTab contract (adds `tradition`, defaults `ambientActive: false` so the run-11 suite never starts a rotation ticker). No assertion changes. |
| `shell_test.dart` STORE-3 ("selection restored") | KEPT as-is: its Home assertion (`Psalms 119` visible on Home) is satisfied by Continue reading's subtitle from the restored screens doc — the §6 claim. The retirement itself is landmarked NEW in `arch_ambient_home_test.dart` (seeded `ww_home_selected` is removed on load and never rewritten). |
| All other shipped suites | Unchanged; the panel had no other landmarks (grepped: `Connected chapters`, `Clear selection`, `Read …` appear in no other test). |

## 11. New tests (test/arch_ambient_home_test.dart)

Picker/pool (pure): median + floor arithmetic on synthetic
counts incl. sub-floor exclusion and canon-subset restriction;
no-immediate-repeat over 500 seeded draws; pool over the fake
canon (Jewish = OT-only; Catholic = full core pool per I-2;
floor excludes zero-count chapters when the median is > 0);
geometry precompute shape. Widget: caption exact format;
rotation advances on the 3s ticker; EVERY §5 pause condition
(tab invisible, lifecycle paused, route covered, pointer/scroll
interaction) plus reduced-motion stillness; stage tap opens
the featured chapter via callback and, at shell level, lands
in the reader; list/grid chapter tap still opens the reader
directly (shell drill path, landmarked behavior); panel absent
(no panel texts/semantics in the Home tree); final §1 order
from rendered positions; in-reader chapter partners present,
ranked by dy, ≥48dp, and a tap routes to that chapter; a
partnerless chapter's sheet still renders its chapter section
(no dead end).
