# PETRA — QC GATE, BOARD RUN 11: HOME STUDY SECTIONS

**Gate:** run11-home-study-sections (desk 3), audited by Petra,
Design Auditor & QC.
**Spec:** `team/specs/run11-home-study-sections.md` (mine, binding,
incl. producer ratifications I-1..I-4).
**Audit target:** the COMMITTED tree at `main` HEAD `941a150`
("Run 11 fix: re-landmark shipped back/top-bar tests on the new
Home"), materialized into a scratch worktree
(`git worktree add /tmp/run11-gate 941a150`, removed after the
audit). The shared working tree's uncommitted reader-theme
changes (shell_screen.dart, ww_theme.dart, reader_screen.dart,
others) were NOT audited and are not run 11's. Run-11
implementation is in commit `79992d8` (17 files, +4,388 — its
message names the arch-ambient records; its flutter payload is
exactly run 11's 15 files plus LESSONS.md and the arch packet),
fix commit `941a150` on top. CI run 38797275227 green at that
head (342 tests, pinned signer digest) taken as verified by
Silas; this gate is spec fidelity and design, not a CI re-run.

## VERDICT: PASS

With four deviations ratified below (D-1..D-4, all read from
`git diff 5b514f6..941a150`, run-11 paths only — lesson 29) and
one minor test-completeness note (M-1). Nothing killed: no
design, surface, or string is rejected. No app-code changes
were made by this gate.

---

## 1. Copy fidelity (§2) — PASS

Every string in the §2 register was grepped as a literal in the
shipped code at HEAD. All present, verbatim, including:

- VOTD: `VERSE OF THE DAY`, `Loading today's verse…`,
  `Today's verse text could not be loaded.`, `1 connection` /
  `<fmt> connections` (grouped — test asserts `1,189
  connections`).
- Plans Home: `STUDY PLANS`; names `The Gospels` / `Psalms &
  Proverbs` / `The Whole Bible` from the definitions in
  plans.dart; captions `30 days · 89 chapters`, `Day <n> of
  <days> · <pct>%`, `Complete · 100%` (templates read in
  home_tab.dart, not just grepped).
- Plan detail: `Loading plan…`, status templates (`Day
  <currentDay> of <days> · <done> of <total> chapters ·
  <pct>%`; `Complete · <total> of <total> chapters · 100%`),
  `TODAY'S READING`, `You have read every chapter in this
  plan.`, `Start plan`, `Day <n>`, toggle semantics labels
  `Mark <name> as read` / `Mark <name> as not read`,
  `Restart plan`, dialog title `Restart <plan name>?`, the
  full dialog body, `Cancel` / `Restart` — all exact, ASCII
  apostrophes as pinned.
- Tools / All Highlights: `STUDY TOOLS`, `My Notes` /
  `Highlights` / `Profiles`, `No notes yet` / `1 note` /
  `<n> notes`, `No highlights yet` / `1 highlight` /
  `<n> highlights`, `All Highlights`, `Loading your
  highlights…`, `Highlights in <profile> · <label>`,
  `Chapter <n>`, Empty A title/body and Empty B title/body
  (§6.3, I-4) — all exact.
- Retirement verified: `_studySection` is gone, the exact
  string `'STUDY'` occurs nowhere at HEAD, and the widget
  suite asserts `My Notes` appears exactly once on Home.

No drift found. No string outside the register appears on a
new surface.

## 2. Contract fidelity (§§3–8, §13) — PASS

- **Pure functions:** all named functions exist with the
  pinned signatures — `daysSinceEpochLocal`,
  `buildVerseOfDayPool`, `verseOfDayFromPool`,
  `verseOfDayForDate`, `translationForVerseOfDay`,
  `VerseOfDayPick` (==/hashCode over all three fields),
  `VerseOfDayCardData`; `StudyPlanDef`, `wwStudyPlans`
  (ids/names/days/bookIndices exactly as §4.1), `planChapters`,
  `planAvailable`, `planSchedule`, `planDateKey`,
  `calendarDaysBetween`, `planDayFor`, `planDoneCount`,
  `planPercent`, `PlanCardData`; `spanPositionInCanon`,
  `visibleSpansForIndex`, `groupHighlights` +
  `HighlightRowData/ChapterGroup/BookGroup`.
- **PlansStore:** key const `plansPrefsKey = 'ww_plans_v1'`
  (the only new prefs key in the whole diff); JSON shape
  exactly `{profileId: {planId: {startedOn, done}}}`; `encode`
  sorts `done` ascending and omits empty parent maps; `parse`
  implements every §4.5 defensive rule (see check 6);
  mutators match §4.5 (start no-op when present, toggle no-op
  without entry, restart prunes).
- **HomeTab props:** exactly the six new required props of
  §7.1 (`verseOfDay`, `plans`, `highlightsCount`,
  `onOpenVerseOfDay`, `onOpenPlan`, `onOpenHighlights`);
  every retained prop unchanged. I-3 holds: the My Notes
  caption still consumes the shipped visible-count
  `notesCount`; the Highlights caption is the new visible
  count (§5).
- **Selection panel (I-1):** `_selectionPanel` and
  `_partnerChip` are byte-identical to the pre-run tree
  (extracted and diffed), and the panel keeps its slot —
  directly after Continue reading, before Verse of the Day
  (§1 order verified in `_scrollArea` and by the rendered-dy
  ordering test).
- **Type/tokens (§8):** the ww_theme.dart diff is +26 lines
  adding EXACTLY the three roles of §8.1 — `verseOfDayBody`
  (serif 18, height 1.55, navInk), `planCoverBook` (serif 13,
  navInk), `planCoverMeta` (12sp w600 goldBright) — values
  verbatim. NO new colors, NO new radii, NO new durations
  anywhere in the run-11 diff; no raw hex in any new file;
  no `Animated*` widget and no `LinearProgressIndicator`
  introduced (§8.2/§8.3). Radii used are the closed scale
  (row 10, chip 12, sheet 16, input 8, pill 2).
- **File list vs §13:** §13's 15 files (5 new lib, 3 modified
  lib, 7 new tests) are exactly the flutter payload of
  `79992d8`. Deviations from the letter of §13 are D-2 below
  (fix commit) — no §13 file is missing, and no other app
  file was touched by run 11. (§12 holds: arc_stage.dart /
  arc_rendering_test.dart / arc_minimap_evidence_test.dart
  changes in the range belong to the parallel arch-ambient
  commits, not run 11; user_data.dart, tradition.dart,
  bible_data.dart, scripture_text.dart, deuterocanon.dart,
  reader_screen.dart, my_notes_screen.dart are untouched in
  `5b514f6..941a150`.)

## 3. Numbers re-derived, not trusted — PASS

Recomputed independently from the shipped plans.dart logic
(base/remainder, §4.2 / I-2) against the REAL canon asset
(`assets/data.json`: 66 books, 1,189 chapters):

| Plan | T | D | base/rem | Distribution (re-derived) |
|---|---|---|---|---|
| The Gospels | 89 | 30 | 2 / 29 | days 1–29: 3; **day 30: 2** |
| Psalms & Proverbs | 181 | 60 | 3 / 1 | day 1: 4; days 2–**60: 3** |
| The Whole Bible | 1,189 | 365 | 3 / 94 | days 1–94: 4; days 95–**365: 3** |

Every §11.2 spot global reproduces: Gospels day 1 =
[929, 930, 931], day 30 = [1016, 1017]; Psalms & Proverbs
day 1 = [478..481], day 60 = [656, 657, 658]; Whole Bible
day 94 (index 93) holds 4 chapters ending at global 375,
day 365 = [1186, 1187, 1188]. No empty day in any plan;
concatenations equal `planChapters`.

**Verse-of-day pool** re-derived against BibleData's own
model (bidirectional clamped rows from `refs`, deduped by
`targetChapter * 1000 + targetVerse` — the identical key
`verseConnections` dedupes by in bible_data.dart source, and
the shipped builder counts exactly that distinct set):

- Full canon: 31,102 verses → pool size exactly **365**,
  sorted count DESC / chapter ASC / verse ASC; top pick
  Isaiah 9:6 with **212** deduped connections; pool floor
  77 (every pooled verse is genuinely most-connected).
- Jewish canon: 23,145 verses → pool 365, **zero NT verses**
  (top Isaiah 9:6, 212); canon restriction holds on real
  data, not just fixtures.
- Rotation: 2026-10-15 = day 20,741 since epoch → index 301
  → 2 Peter 1:1 (82 connections). Same-verse-all-day, wrap,
  and DST behaviour are asserted in the shipped suite (§11.1
  item 6, read and confirmed).

**Tradition availability matrix** re-derived from the shipped
`planAvailable` + `canonContainsBook` logic — all 15 cells
match §4.1: none/lds/protestant/catholic offer all three
plans; jewish offers psalms-proverbs only (gospels ✗,
whole-bible ✗). The shipped test asserts all 15 cells too.

## 4. Contrast (§9) recomputed from shipped token hexes — PASS

Every pair recomputed by the audit §2 method from the hexes
in the HEAD ww_theme.dart. All match §9 to the second
decimal, including the thinnest pairs named in the brief:

- mutedOnDark captions: **6.03** on surface, **6.92** on stage.
- Progress fill vs track: goldBright/borderDark **6.49**;
  fill vs cover (surfaceHigh) **8.91**; fill vs card
  (surface) **9.55**.
- Highlight swatches on surface: hlGold **13.94**, hlGreen
  **13.66**, hlBlue **12.67**, hlPink **12.98**, hlPurple
  **12.54** — all ≥ 3.0 as graphics.
- Also exact: navInk/surface 15.29, navInk/stage 17.54,
  navInk/surfaceHigh 14.27, goldBright/surface 9.55,
  goldBright/nav 10.23, onGold/goldBright 9.71,
  danger/surfaceHigh 10.54, gold/surfaceHigh 5.25,
  borderDark informational pairs 1.37 / 1.47, cover border
  borderDark/stage 1.69 (exempt hairline, as filed).
- **Check toggle:** the shipped unchecked border is
  `mutedOnDark` (2dp, plan_detail_screen.dart) = **6.03:1** —
  confirmed NOT `borderDark` (1.47:1, the §9.3 PROHIBITED
  assignment). `borderDark` appears in run-11 code only
  where §9 sanctions it: the progress track and the
  decorative cover border.

## 5. Geometry / semantics; run-10 reader untouched — PASS

- §11.5 geometry assertions exist in the shipped
  `home_study_sections_test.dart` and assert RENDERED
  geometry (lesson 30) at 360×800 with a text-scale-2.0
  variant: `takeException()` null; section-header dx == 16;
  VOTD label dx == 32; tool entries ≥ 48×48 with icon
  centers dividing the tools card into thirds (±1dp);
  `plan-cover-gospels` renders exactly 112×144; progress
  fill width == 112 × 45/89 ± 0.5, height == 4; plan title
  rect inside its 112dp column; reference dy below verse
  dy. Section ORDER (incl. the I-1 selection-panel slot) is
  asserted from `getTopLeft` dy, not widget properties.
- Semantics: VOTD card and plan cards carry
  `Semantics(container: true, button: true, label: …)` with
  inner semantics excluded (lesson 25 pattern); tool entries
  likewise; the plan toggle carries `checked: done` with the
  §2.3 labels.
- **Run-10 selection-mode / pager behaviour is untouched:**
  reader_screen.dart, the deuterocanon reader, and
  my_notes_screen.dart show NO changes in
  `5b514f6..941a150`. The only shell change to My Notes is
  the §7.3 extraction of the shared `_openVerseFromList`
  closure — the extracted body is the shipped closure
  verbatim (diffed), and All Highlights' reload-on-tap
  mirrors My Notes' shipped `_reloadUserData` pattern line
  for line.

## 6. Dormancy & persistence evidence (tests read, not names) — PASS

- `plans_data_test.dart` asserts, as real assertions: the
  raw prefs string decodes to exactly the §4.5 JSON shape
  under key `ww_plans_v1` with `done` sorted ascending, and
  state deep-equals after reload; every defensive case of
  §4.5 (null / non-JSON / non-object root; non-object
  profile and plan values; `startedOn` = `2026-13-01`,
  `2026-02-30`, `15/10/2026`, `2026-1-5`, `20261015`, and a
  number — plan dropped, sibling survives; `done` not a
  list — dropped; `done: [1, "2", -3, 1, 2.5]` → `{1}`;
  unknown profile/plan ids survive a load/save cycle
  verbatim); mutator rules incl. byte-identical no-op
  `startPlan`; day arithmetic (future start → 1, clamp,
  unparseable → 1, intersected count, percent floor).
- **Byte-identical dormancy is asserted at two levels:**
  the pure suite saves Gospels progress, recomputes
  availability across traditions, and asserts the raw
  `ww_plans_v1` string is unchanged and the progress intact
  on reload; the shell suite
  (`shell_home_study_test.dart`) switches tradition to
  Jewish via Profiles and back, asserting the Gospels card
  disappears (exactly one plan card remains), the stored
  string equals the seeded JSON byte-for-byte, and the
  card returns with `Day 1 of 30 · 1%` intact. Restart
  Cancel is likewise asserted byte-identical in
  `plan_detail_test.dart`, as is the §6.3 branch-2
  no-deletion property in `all_highlights_screen_test.dart`.
- All Highlights suites assert the §6.1/§6.3 contracts as
  written: canon-order grouping (incl. Ketuvim Psalms-before
  -Ruth under jewish), row order verse/start/end, both-bounds
  visibility (lesson 18 cases `b0c0v1`, `b0c1v0` included),
  deuterocanon catholic-only / after-core / table order /
  null-table drop, display-text fallbacks, count consistency
  across every tradition, and both empty branches with the
  exact §2.4 strings.

## 7. Deviations (from `git diff 5b514f6..941a150`, run-11 paths only)

**D-1 — Plan cover text is clamped to text scale ≤ 1.0
(home_tab.dart, `_planCard`). RATIFIED.**
§4.4's construction has no MediaQuery override; the shipped
cover wraps its ClipRRect in
`MediaQuery(textScaler: clamp(maxScaleFactor: 1.0))`. My
§10 rationale — single-line ellipsized lines cannot grow
the fixed 144dp cover — was wrong against lesson 21: the
cover styles carry no height, so the ambient 1.43 multiplier
applies, and at scale 2.0 four book lines + meta measure
~149dp against the cover's 118dp inner height, which is a
RenderFlex overflow — failing §11.5.6's own assertions
(`takeException()` null AND cover exactly 112×144 at scale
2.0). The clamp is scoped to the cover only; the plan name
and caption directly beneath it render at the user's full
scale and carry the same words. It is the only construction
satisfying §4.4's fixed geometry and §11.5.6 simultaneously.
Spec error is mine (§10); the fix is right. Spec §10 should
be amended at the next spec touch — no code change.

**D-2 — Fix commit `941a150` touches three test files §13
does not name (shell_test.dart, system_back_test.dart,
top_bar_test.dart). RATIFIED.**
Written from the diff: six Home-root landmark assertions
change `find.text('STUDY')` → `find.text('Woven Word')`
(the retired §1 header was those tests' landmark; §11.5.2
itself asserts `STUDY` no longer exists), and top_bar T8d
gains one scroll drag before tapping `My Notes` (the Study
Tools entry now sits below the new sections). No assertion
was weakened — same counts, same intents — and §11.8's
"every pre-existing suite stays green" required exactly
this re-landmarking (lesson 40). The commit message
declares it accurately.

**D-3 — Plan snapshot also reloads after My Notes / All
Highlights pops (shell_screen.dart). RATIFIED, letter-only.**
§7.3 says `_loadPlans()` is not called after
`_openAllHighlights`; the shipped `_loadUserData()` now
awaits `_loadPlans()` internally, so the read-only snapshot
refresh also happens on those pops. No write path, no
observable state difference. No change.

**D-4 — VOTD pool cache keys on tradition only
(shell_screen.dart). NOTED, no observable divergence.**
§7.2 says the cache rebuilds when data OR tradition
differs; the shipped check is `pool == null ||
poolTradition != tradition`. The shell's `BibleData` is a
single immutable load for the app's lifetime (the data
future is fixed at construction), so data identity cannot
change under a live cache. No change; recorded so the next
spec does not inherit the gap silently.

**M-1 (minor, tests) — §11.3.3's toggle `checked` flag.**
The shipped code sets `checked: done`; the suite asserts
the semantics LABEL flip (`Mark Matthew 1 as read` → `…
as not read`) plus persistence and percent, but does not
assert the semantics node's `checked` property itself.
Code conforms; assertion coverage is one property short of
the spec sentence. Optional follow-up for Maren; not a
gate failure.

Non-run-11 files in the diff range (arc_stage.dart,
arc_rendering_test.dart, tool/arc_minimap_evidence_test.dart,
team/specs/arch-ambient-*) belong to the parallel
arch-ambient package (§12 out of scope) and are excluded
from this gate, as are the LESSONS.md lesson-42 entry and
the arch packet doc that ride in `79992d8`.

## Killed

Nothing. No design, string, or surface was rejected at this
gate, and no option is being presented that my own review
flags as bad (lesson 7). The one token my spec already
killed pre-build — `borderDark` as the toggle border —
stayed dead in the shipped code (check 4).

## Sign-off

Run 11 as committed at `941a150` conforms to the binding
spec in copy, contracts, numbers, contrast, geometry, and
persistence, with D-1..D-4 ratified above. Cleared from the
QC desk for Silas's package sign-off. Founder phone
verification remains the standing final step (lesson 8) —
that is Tyson's, not this gate's.

— Petra, Design Auditor & QC, board run 11, desk 3.
