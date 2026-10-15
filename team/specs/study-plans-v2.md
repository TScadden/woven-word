# PETRA — DESIGN SPEC, STUDY PLANS V2: CUSTOM PLANS + REALISTIC SCHEDULES (BINDING)

**From:** Petra, Design Auditor & QC
**To:** Maren, Lead Flutter Engineer (verbatim handoff, via Silas)
**Scope:** the run-11 Study Plans system revised — (1) a
verse-sized schedule engine with two modes replaces the
base/remainder chapter-count rule; (2) the three built-ins
become target-derived (no stored day count); (3) users can
create, edit, and delete their own plans (a new editor screen);
(4) the plans store document becomes v2 under the same prefs
key; (5) plans join the backup under a strict validator;
(6) the founder's check-off percentage is pinned as a tested
contract on both surfaces for both plan kinds. Nothing else.

**Authorities:** TEAM.md (main tree `team/TEAM.md` — this
worktree carries no copy; read it there); LESSONS.md (esp.
#13 role-split tokens, #16 audit every state, #17 surface
matrix + non-color cues, #18 both bounds, #19 profiles are a
store concern / model resolves, #20 presentation defaults set
explicitly, #22 validation in front of the parser, #23/#28
this filed spec binds over any brief paraphrase, #30 geometry
asserted from rendered positions, #37 control counts are a
layout budget at 360dp, #40 model changes re-seed test
scenarios, #41 HEAD-baseline discipline, #46 verify an
arithmetic rule against every instance, #48 fixed-geometry
decorative surfaces clamp their own text scale); the producer
brief `team/specs/study-plans-v2-brief.md` (its producer
decisions are binding; this spec pins everything it leaves
open and supersedes it where §0.4 says so); the run-11 spec
`team/specs/run11-home-study-sections.md` (the shipped system
this spec revises — §0.3 lists exactly which of its parts
stand, change, or fall).

**Method note:** every schedule number in §2 and §11 was
computed by me from the bundled data
(`flutter/assets/data.json`, chapter verse counts =
`chapters[].v`) by an independent scratch implementation of
the §1 rules, kept outside the repo. Every contrast ratio in
§9 I computed from the token hexes in `ww_theme.dart` by the
audit §2 method (sRGB linearized, ratio `(Llight + 0.05) /
(Ldark + 0.05)`); the calculator was first validated against
run-11's published table (15.29 / 6.03 / 6.92 / 9.55 / 8.91 —
it reproduces all of them exactly). **New tokens: none.
New colors: none. New radii: none. New durations: none.
New `WwType` roles: none (§9.4 proves the shipped roles
carry every new string).**

---

## ⚠ BLOCKING NOTE — ONE PRODUCER FIGURE DISAGREES WITH THE DATA (read first)

The brief (Research reconciliation + §7) and my dispatch both
state the Mode-A engine's **heaviest non-Psalm-119 day =
80 verses**. My independent recomputation over
`assets/data.json` disagrees:

- Whole Bible, Mode A at T = 40, day **96** is **Numbers 7
  alone = 89 verses** (global chapter 123; the chapter itself
  is 89 verses).
- Day **258** is **1 Chronicles 6 alone = 81 verses** (global
  343).
- Day **617** is **Luke 1 alone = 80 verses** (global 973).

So the heaviest non-Psalm-119 day across the built-ins is
**89**, not 80. The figure 80 is correct only as (a) the
Gospels plan's heaviest day, and (b) the Luke 1 day inside the
Whole Bible schedule. No re-reading I can construct yields 80
as the global figure: excluding single-chapter days as well,
the Whole Bible's heaviest multi-chapter day is 71 verses
(Ezekiel 15 + Ezekiel 16, 8 + 63), not 80.

**Every other producer figure verifies EXACTLY** (§2.5):
Gospels **87 days** ✓, Psalms & Proverbs **84 days** ✓,
Whole Bible **767 days** ✓, heaviest day **176 = Psalm 119
alone** ✓ (Whole Bible day 393; Psalms & Proverbs day 49),
old base/remainder peaks **187 / 191 / 212** → the stated
187–212 range ✓.

**Ruling required from Silas before Maren builds §2/§11.7's
heaviest-day assertions.** This spec pins the test values
with MY computed figure (89), marked `†BLOCKING` wherever
they appear, because a spec that pins a number the data
refutes would fail its own gate (lessons 9, 46). If Silas
rules the brief's 80 was a per-Gospels figure mis-stated as
global, the `†BLOCKING` values stand as written and the
block lifts with no other change. Nothing else in this spec
depends on the disputed figure: day counts, first/last days,
the engine, the store, the editor, and backups are all
unaffected.

---

## 0. Founder directions, producer decisions, supersession

### 0.1 Founder directions (Tyson, Oct 15, 2026), verbatim

1. "Also add the option for a user to make their own study plan"
2. "Make the study plans a little more realistic as well"
3. (fold-in, same day) "And they can check off what they
   have read and it'll show a percentage complete."

### 0.2 Producer decisions carried in the brief (binding)

- **Adopted target: 40 verses/day** for built-in plans (the
  published two-year pace, ~4–6 min/day; mean chapter in our
  data = 31,102 / 1,189 ≈ 26 verses, so typical days land at
  1–2 chapters). §2.5 verifies the brief's research arithmetic
  (one-year ≈ 86 verses/day is the load being rejected).
- One engine, two modes (§1 of the brief = §1 here).
  Chapters are atomic and consecutive; no chapter is ever
  split across days. Psalm 119 (176 verses) is one day; the
  spec states that cost rather than hiding it (§2.3).
- Schedules are DERIVED, never stored (the run-11 rule).
- Migration: progress lives on chapters, not days (§3 here).
- Custom-plan model, store v2 shape, editor surface, detail
  Edit/Delete, dormancy rule (§§4–7 here).
- Backups: plans join the backup; `UserData.version` stays
  3; absent member = legacy behavior; malformed member =
  whole import rejected with a new named error (§8 here).
- Percent (§5 of the brief = §6.3 here): PIN the shipped
  mechanism as the contract for BOTH plan kinds, with new
  widget tests in both directions (check AND uncheck) on
  both surfaces.

### 0.3 Supersession — what this spec does to run 11

Run 11's spec stands in full EXCEPT the following, which
this spec supersedes by section:

| Run-11 part | Disposition in v2 |
|---|---|
| §0.2.3 fixed day counts (30 / 60 / 365) | **Superseded.** Day counts are derived (§2). Ids, names, book sets unchanged. |
| §4.1 `StudyPlanDef.days` field | **Removed.** Defs become target-derived (§2.1). |
| §4.2 base/remainder schedule rule + its distribution table | **Superseded** by the §1 engine (Mode A for built-ins). |
| §4.5 plans-store JSON shape (bare progress map) | **Superseded** by the v2 document (§4). Same prefs key `ww_plans_v1`. The §4.5 defensive-parse RULES survive verbatim and govern the v2 `progress` member (§4.3). |
| §2.2 / §2.3 copy forms for cards and detail | **Forms retained**; the numbers in them are now derived. Detail gains one pace line (§6.2). Card/detail percent forms are pinned as the §6.3 contract. |
| §4.4 cover book-line rule (≤4 books → all names; whole-Bible → first / `…` / last) | **Generalized** to one rule over distinct coverage books (§5.2); the built-in outputs are identical under it. |
| §1 / §4.4 section-render rule ("section only when `plans` non-empty") | **Superseded** for Study Plans only: the section now renders whenever the shell wires the create action, even with zero offered plans (§5.4). Verse of the Day and Study Tools rules unchanged. |
| §7.1 HomeTab prop list | **Extended:** one new required prop `onCreatePlan`; `plans` now carries resolved plans of both kinds (§5.5). |
| §7.2 / §7.3 shell plan computation and `_openPlanDetail` | **Generalized** to resolved plans; one new routing method `_openPlanEditor` (§5.5). |
| §12 "Backup format / `UserData` not modified" | **Superseded in part:** `user_data.dart` IS modified in v2 — validator + error enum + result only (§8). The `UserData` model, its document shape, and `version` (3) are NOT modified. Export assembly changes in `profiles_screen.dart` (§8.4). |
| §11.2 schedule/store assertions; parts of §11.3/§11.5/§11.6 | Superseded assertions are quoted and translated in §4.6 (store shape) and §11.8 (engine-driven numbers). |

Everything else in run 11 — Verse of the Day (§3), Study
Tools (§5 there), All Highlights (§6 there), tokens (§8
there), the cover construction, the detail screen's shipped
construction except as §6 here amends it — is untouched by
this package.

### 0.4 Where this spec narrows or extends the brief (Petra's calls, flagged for Silas)

1. **Heaviest-other figure.** See the BLOCKING NOTE: the
   spec pins 89, not the brief's 80.
2. **Custom availability gains a non-emptiness clause**
   (narrowing the brief's "iff every segment book is in
   canon"): a custom whose segments all clamp away (e.g.
   `from` beyond the book's real chapters — creatable only
   via a crafted backup, never via the editor) resolves to
   ZERO chapters and is not offered (§5.3). A zero-chapter
   plan has no schedule, no percent denominator, and nothing
   to check off; offering it would ship a dead surface.
3. **Editor verses stepper range is 5–200, step 5** — a
   strict subset of the backup validator's sane range
   (1–1000, §8.2). 200 verses/day already exceeds every
   published pace the brief studied (86/day is the one-year
   load); the validator stays wide because a backup gate
   must not reject files the product could ever have
   written, while the stepper is a human control. An
   imported def outside 5–200 normalizes on edit-save
   (§6.1 seeding rule) — stated, tested, never silent in
   this spec.
4. **Validation order:** when a backup's `plans` member is
   malformed AND the document also parses to nothing,
   `invalidPlans` is reported (the specific member error
   outranks the generic emptiness error). Pinned in §8.2.
5. **Pace line extended uniformly** (extension, not
   narrowing): the brief requires the pace stated on
   built-in details; §6.2 states it on EVERY resolved plan's
   detail in one copy form, because a custom's pace is the
   user's own choice and hiding it on the one screen that
   executes it would be incoherent.
6. **Profiles Backup section copy is NOT changed** (§8.5):
   the shipped copy never promised the file holds ONLY
   profiles' highlights and notes, and changing it would
   supersede a shipped verbatim-copy test for no founder
   benefit. The confirm dialog DOES gain plans counts
   (§8.3), which is where the file's contents are named at
   the moment of consequence.

---

## 1. The schedule engine — `lib/data/plans.dart` (pure)

All engine functions are pure, widget-free, and operate on
`(BibleData data, List<int> chapters)` where `chapters` is a
list of global chapter indices in coverage order. A chapter's
verse count is always `data.chapters[ch].v`. No function in
this section reads prefs, clocks, or definitions.

```dart
/// Mode A — daily amount.
List<List<int>> scheduleByVerses(
  BibleData data,
  List<int> chapters,
  int targetVerses,
);

/// Mode B — finish in N days.
List<List<int>> scheduleByDays(
  BibleData data,
  List<int> chapters,
  int dayCount,
);
```

### 1.1 Mode A — closest-fit greedy (exact semantics)

Pseudocode (this IS the algorithm; any implementation that
deviates on any input is wrong):

```
T = max(1, targetVerses)
days = []; open = []; tot = 0
for ch in chapters:
  v = verses(ch)
  if open is non-empty AND (tot >= T OR |tot + v - T| >= |tot - T|):
    days.push(open); open = []; tot = 0
  open.push(ch); tot += v
if open is non-empty: days.push(open)
return days
```

- The close test runs BEFORE adding each chapter, against
  the OPEN day only. The comparison is `>=` (a tie closes:
  adding a chapter that leaves the total exactly as far
  from T as stopping now does not improve the fit, so the
  day closes — this is the brief's rule verbatim).
- Guarantees (all asserted in §11.1): concatenation of the
  days reproduces `chapters` exactly, in order; no day is
  empty; every closed day satisfied the close condition
  against the chapter that opened the next day (the
  locally-closest-fit invariant, §11.1 test 4).
- Edge cases, pinned:
  - `chapters` empty → `[]` (zero days).
  - A single chapter whose verses exceed T forms a day
    alone at its full verse count (the open day is empty
    when it is added, so no close can fire first; the NEXT
    chapter, if any, closes it because `tot >= T`). Psalm
    119 at T = 40 is the canonical instance: a 176-verse day.
  - `targetVerses` larger than the whole coverage's verse
    total → exactly ONE day holding every chapter (adding a
    chapter always strictly reduces `|tot - T|` while
    `tot + v <= total < T`, so no close ever fires).
  - `targetVerses <= 0` cannot be produced by the UI or a
    valid def (§4.3 drops such defs); the function still
    clamps to 1 rather than throwing (defensive floor, in
    the pseudocode above).
  - Coverage of one chapter → `[[ch]]` at any T.

### 1.2 Mode B — cumulative thresholds, exactly N days (exact semantics)

Pseudocode:

```
C = chapters.length
if C == 0: return []
N = clamp(dayCount, 1, C)            // N_effective
totalVerses = sum of verses(ch) over chapters
days = []; open = []; cum = 0; closed = 0
for i, ch in chapters:
  open.push(ch); cum += verses(ch)
  remainingChapters = C - (i + 1)
  if closed < N - 1 AND (
       cum * N >= (closed + 1) * totalVerses     // threshold j = closed + 1
       OR remainingChapters == N - closed - 1    // force-close
     ):
    days.push(open); open = []; closed += 1
if open is non-empty: days.push(open)
return days
```

- Threshold comparison is INTEGER cross-multiplication
  (`cum * N >= j * totalVerses`), never floating point —
  `j × totalVerses / N` as a double is not a spec.
- The force-close term reserves exactly one chapter for
  each day still to come, so the partition can never strand
  a later day empty; the loop guard (`closed < N - 1`)
  reserves the final day for the flush. Together they
  guarantee EXACTLY N non-empty days whenever
  `1 <= N <= C` (property-verified by me over 500 random
  verse vectors × every N before filing; §11.1 asserts it
  in-suite).
- Edge cases, pinned:
  - `N = 1` → one day holding every chapter (the guard
    `closed < 0` never fires; the flush is the only day).
  - `N = C` (chapter count) → every chapter alone in its
    own day (force-close fires at every step: after each
    chapter, `remainingChapters == N - closed - 1`).
  - `dayCount > C` → clamps to C (the editor can never
    produce this, §6.4 re-clamp; a stored/imported def can —
    §5.1 resolution applies the same clamp, so a stored
    `days` above the chapter count is valid data with a
    clamped effect, never an error).
  - `dayCount < 1` cannot be produced by the UI; a stored
    def with `days < 1` is dropped at parse (§4.3), so the
    engine's own clamp to 1 is a defensive floor only.
  - Coverage of one chapter → `[[ch]]` at any N.
- Worked examples (asserted verbatim in §11.1; verse vectors
  are per-chapter verse counts in order):
  - `[10,10,10,10,10]`, N = 2 → days `[[0,1,2],[3,4]]`,
    verse totals `[30, 20]`.
  - `[31,26,32]`, N = 2 → `[[0,1],[2]]`, totals `[57, 32]`.
  - `[50,10,10,50]`, N = 3 → `[[0],[1,2],[3]]`, totals
    `[50, 20, 50]` (threshold close, then force-close
    discipline).
  - `[1,1,100,1]`, N = 3 → `[[0,1],[2],[3]]`, totals
    `[2, 100, 1]` (force-close before the giant chapter:
    without it the first day would swallow it and strand
    day 3).
  - `[10,20,30]`, N = 3 → `[[0],[1],[2]]`.

### 1.3 What the engine replaces

`planSchedule(data, plan)` (run-11 §4.2, base/remainder) is
DELETED. Its callers move to the resolved-plan schedule
(§5.1). `planChapters` survives only as the built-in
coverage expander (§2.1); customs expand via §5.1.

---

## 2. Built-ins re-derived

### 2.1 Definitions — target-derived, no stored day count

```dart
/// The adopted built-in pace (brief: binding): every
/// built-in's schedule is Mode A at this target.
const int wwBuiltinVersesPerDay = 40;

class StudyPlanDef {
  const StudyPlanDef({
    required this.id,
    required this.name,
    this.bookIndices, // null = every book in the data
  });
  final String id;
  final String name;
  final List<int>? bookIndices;
}

const List<StudyPlanDef> wwStudyPlans = [
  StudyPlanDef(id: 'gospels', name: 'The Gospels',
      bookIndices: [39, 40, 41, 42]),
  StudyPlanDef(id: 'psalms-proverbs', name: 'Psalms & Proverbs',
      bookIndices: [18, 19]),
  StudyPlanDef(id: 'whole-bible', name: 'The Whole Bible',
      bookIndices: null),
];
```

Ids, names, and book sets are byte-identical to run 11. The
`days` field is GONE: a built-in's day count IS
`scheduleByVerses(data, planChapters(data, def), 40).length`,
obtained through the resolved plan (§5.1). Any code that
needs a built-in's days, chapters, or schedule consumes the
`ResolvedPlan`, never the def alone.

### 2.2 Availability matrix — re-verified, unchanged

The rule is run 11's verbatim: a built-in is offered iff
EVERY book in its definition satisfies
`canonContainsBook(tradition, data, bookIndex)` (for
`whole-bible`, every book in the data). The book sets did
not change, so the matrix cannot change; I re-verified all
15 cells against the shipped `tradition.dart`:

| Tradition | gospels | psalms-proverbs | whole-bible |
|---|---|---|---|
| none (Bible only) | ✓ | ✓ | ✓ |
| lds | ✓ | ✓ | ✓ |
| protestant | ✓ | ✓ | ✓ |
| catholic | ✓ | ✓ | ✓ |
| jewish | ✗ (NT not in Tanakh) | ✓ (both in Ketuvim) | ✗ (includes NT) |

### 2.3 Derived values from the real data (computed, pinned)

Mode A at T = 40 over `assets/data.json`:

| Plan | Chapters | Verses | **Days** | Day 1 | Last day | Heaviest day | Lightest day |
|---|---|---|---|---|---|---|---|
| The Gospels | 89 | 3,779 | **87** | day 1: Matthew 1 · Matthew 2 (globals 929–930), 48v | day 87: John 21 (1017), 25v | day 43: Luke 1 alone (973), **80v** | day 26: Matthew 28 alone (956), 20v |
| Psalms & Proverbs | 181 | 3,376 | **84** | day 1: Psalms 1–4 (478–481), 34v | day 84: Proverbs 31 (658), 31v | day 49: Psalms 119 alone (596), **176v** | day 5: Psalms 17 alone (494), 15v |
| The Whole Bible | 1,189 | 31,102 | **767** | day 1: Genesis 1 (0), 31v | day 767: Revelation 22 (1188), 21v | day 393: Psalms 119 alone (596), **176v** | day 297: Ezra 1 alone (403), 11v |

Whole-Bible heavy days, for the record (see BLOCKING NOTE):
day 96 = Numbers 7 alone (123), **89v** `†BLOCKING`;
day 258 = 1 Chronicles 6 alone (343), **81v**; day 617 =
Luke 1 alone (973), **80v**. The heaviest non-Psalm-119 day
is therefore **89v** `†BLOCKING`, and the heaviest day of
any kind is 176v (Psalm 119 alone, in two plans).

Honest-cost statement (carried into the detail pace line's
"About", §6.2): chapter atomicity means a day's actual load
varies — built-in day totals run 11–176 verses on the Whole
Bible — and the 176-verse Psalm 119 day is the price of
chapter check-off. The spec does not hide this: the schedule
itself shows exactly one chapter on that day.

Further spot values (asserted in §11.7): Gospels day 2 =
Matthew 3 · Matthew 4 (931–932), 42v; day 3 = Matthew 5
(933), 48v; day 86 = John 20 (1016), 31v. Psalms & Proverbs
day 2 = Psalms 5–7 (482–484), 39v; day 83 = Proverbs 30
(657), 33v. Whole Bible day 2 = Genesis 2 · Genesis 3
(1–2), 49v; day 766 = Revelation 20 · Revelation 21
(1186–1187), 42v.

### 2.4 Derived values on the fake canon (test fixtures)

The shipped suites run on `fakeReaderData()` (10 verses per
chapter, Psalms 119 = 176). Mode A at T = 40 there yields —
computed by the same independent implementation:

| Plan (fake) | Days | Shape |
|---|---|---|
| The Gospels | **23** | days 1–22: 4 chapters (40v); day 23: John 21 alone (10v). Day 1 = globals 929–932 (Matthew 1–4); day 11 = globals 969–972 (Mark 13–16). |
| Psalms & Proverbs | **47** | day 30 = Psalms 117 · Psalms 118 (594–595, 20v); day 31 = Psalms 119 alone (596, 176v); day 47 = Proverbs 30 · Proverbs 31 (657–658, 20v). |
| The Whole Bible | **298** | day 1 = globals 0–3 (40v); day 150 = Psalms 119 alone (596); day 298 = globals 1185–1188 (40v). |

Every run-11 test expectation that quoted 30 / 60 / 365
days, base/remainder spot globals, or a fake-canon status
string is translated in §11.8 — none is silently dropped.

### 2.5 Verification of the brief's remaining numbers

- Mean chapter: 31,102 / 1,189 = 26.16 → the brief's "≈ 26
  verses" ✓. One-year pace: 31,102 / 365 = 85.2 verses/day →
  "≈ 86" ✓. Two-year: 31,102 / 730 = 42.6 → "≈ 43" ✓.
- Old rule (base/remainder, run-11 §4.2) verse loads on the
  real data, recomputed: Gospels peak **187v** (lightest
  56v), Psalms & Proverbs peak **191v** (lightest 16v),
  Whole Bible peak **212v** (lightest 18v) — the brief's
  "heaviest days run 187–212" ✓.
- Mode-A typical day: median built-in day is 1–2 chapters
  (Gospels: 87 days over 89 chapters; Whole Bible: 767 days
  over 1,189 chapters) — the brief's "typical days land at
  1–2 chapters" ✓.

### 2.6 Copy that changes for built-ins

Only the NUMBERS inside the run-11 forms change; the forms
themselves are §5.4/§6.2's register. On the real data:
not-started card captions become `87 days · 89 chapters`,
`84 days · 181 chapters`, `767 days · 1,189 chapters`;
not-started detail statuses likewise; started captions and
statuses carry the derived day counts. No other built-in
string changes. The detail screen gains the pace line
(§6.2) — the one new built-in string.

---

## 3. Migration — progress lives on chapters, not days

Binding restatement of the brief's §3, pinned as testable
claims (§11.3):

1. The stored payload — `startedOn` plus the `done` SET of
   global chapter indices, per profile per plan — is not
   rewritten, reinterpreted, or intersected any differently
   by the schedule change. Schedules are derived, so
   re-deriving under the new engine changes only how
   chapters group into days and how many days a plan has.
2. Every check mark survives. The percent
   (`planDoneCount` = |done ∩ chapters|, `planPercent` =
   floor(done × 100 / total)) is IDENTICAL before and after,
   because neither input depends on the schedule.
3. `currentDay` recomputes from the same `startedOn` against
   the NEW derived day count under the unchanged clamp rule
   (`planDayFor`: `clamp(calendarDaysBetween(start, today) +
   1, 1, days)`; unparseable → 1; future start → 1).
   `planDayFor`, `planDateKey`, `calendarDaysBetween`,
   `planDoneCount`, and `planPercent` survive from run 11
   with their exact shipped semantics — only the `days`
   argument's source changes (resolved plan, not def).
4. Storage-shape migration is separate and equally lossless
   (§4): a v1 bare-progress payload loads as a v2 document
   whose `progress` is exactly the v1 state; the first
   `save()` under v2 rewrites the string in v2 shape. No
   other migration exists, and none is destructive.

---

## 4. The v2 plans-store document — `lib/data/plans.dart`

### 4.1 Exact JSON shape

Same SharedPreferences key: `plansPrefsKey = 'ww_plans_v1'`
(the key names the STORE, not the document version; it does
not change). `encode` writes v2 ONLY, exactly:

```json
{
  "version": 2,
  "progress": {
    "<profileId>": {
      "<planId>": {"startedOn": "yyyy-mm-dd", "done": [int, …]}
    }
  },
  "custom": {
    "<profileId>": [ <custom def>, … ]
  },
  "customSeq": { "<profileId>": int }
}
```

- Top-level key ORDER in `encode` output: `version`,
  `progress`, `custom`, `customSeq` (Dart map insertion
  order through `jsonEncode`, as shipped).
- `progress` encoding is run-11's `encode` verbatim: `done`
  sorted ascending; a profile whose progress map is empty
  is OMITTED from `progress`.
- `custom`: a profile whose def list is empty is OMITTED.
  Def list order is creation order (the stored order; the
  editor never reorders another profile's list, §6.5).
- `customSeq`: an entry, once allocated, is NEVER omitted —
  even when the profile's def list is empty and its
  progress is gone. Dropping it would let a later create
  reuse a retired id and inherit nothing-but-the-id's
  history in any other copy of the data. A profile with
  seq 0 that never allocated does not appear.
- So the empty v2 document encodes as exactly
  `{"version":2,"progress":{},"custom":{},"customSeq":{}}`.

Custom def JSON shape (inside `custom`), key order as
written by `toJson`:

```json
{
  "id": "custom-<n>",
  "name": "<trimmed user text>",
  "segments": [ {"book": int, "from": int, "to": int}, … ],
  "pace": {"mode": "verses", "versesPerDay": int}
       or {"mode": "days", "days": int}
}
```

Segment key order: `book`, `from`, `to`. Pace key order:
`mode`, then its value key. Unknown keys anywhere in a def
are ignored on parse and NOT preserved on encode (defs are
a closed model, unlike progress's forward-compatible ids —
the run-11 preservation rule applies to progress plan ids
and profile ids, and §4.3 keeps it there).

### 4.2 Model types

```dart
enum PlanPaceMode { verses, days }

class PlanPace {
  const PlanPace.verses(this.versesPerDay) : mode = PlanPaceMode.verses, days = null;
  const PlanPace.days(this.days) : mode = PlanPaceMode.days, versesPerDay = null;
  final PlanPaceMode mode;
  final int? versesPerDay; // non-null iff mode == verses
  final int? days;         // non-null iff mode == days
  // toJson / == / hashCode
}

class PlanSegment {
  const PlanSegment({required this.book, required this.from, required this.to});
  final int book;  // BibleData book index, >= 0
  final int from;  // 1-based chapter in book, >= 1
  final int to;    // 1-based, >= from
  // toJson / == / hashCode
}

class CustomPlanDef {
  const CustomPlanDef({
    required this.id, required this.name,
    required this.segments, required this.pace,
  });
  final String id;   // 'custom-<n>', n >= 1
  final String name; // trimmed, non-empty
  final List<PlanSegment> segments;
  final PlanPace pace;
  // toJson / == / hashCode (deep over segments)
}

/// The full v2 document: the store's one state object.
class PlansDocument {
  PlansDocument({
    Map<String, Map<String, PlanProgress>>? progress,
    Map<String, List<CustomPlanDef>>? custom,
    Map<String, int>? customSeq,
  });
  final Map<String, Map<String, PlanProgress>> progress;
  final Map<String, List<CustomPlanDef>> custom;
  final Map<String, int> customSeq;
  bool get isEmpty => progress.isEmpty && custom.isEmpty;
  // == / hashCode: deep (progress values are PlanProgress,
  // whose shipped == already deep-compares the done set;
  // custom def lists compare element-wise in order;
  // customSeq compares as a map).
}
```

`PlanProgress` is the shipped class, unchanged (fields,
`toJson`, `==`, `hashCode`).

### 4.3 Parse rules — v1 and v2 inputs, entry by entry

```dart
class PlansStore {
  PlansStore._(this._prefs, this.document);
  final PlansDocument document;

  static Future<PlansStore> load(SharedPreferences prefs);
  static PlansDocument parseDocument(String? raw);
  static String encodeDocument(PlansDocument doc);

  /// Shipped convenience, RETAINED with its exact run-11
  /// signature and semantics: the progress map of
  /// parseDocument(raw). (Keeping it is what lets most
  /// run-11 defensive-parse assertions survive verbatim,
  /// §4.6.)
  static Map<String, Map<String, PlanProgress>> parse(String? raw);

  PlanProgress? progressFor(String profileId, String planId);
  void startPlan(String profileId, String planId, DateTime today);
  void toggleChapter(String profileId, String planId, int globalChapter);
  void restartPlan(String profileId, String planId);

  List<CustomPlanDef> customsFor(String profileId); // stored order; [] when none
  CustomPlanDef? customFor(String profileId, String planId);
  CustomPlanDef createCustom(String profileId, {
    required String name,
    required List<PlanSegment> segments,
    required PlanPace pace,
  });
  void updateCustom(String profileId, CustomPlanDef def);
  void deleteCustom(String profileId, String planId);
  Future<void> save(); // writes encodeDocument(document)
}
```

`parse` (run 11) is re-implemented as
`parseDocument(raw).progress` — one parser, two views; the
two can never disagree.

**Discrimination rule (the only one):** decode the root.
If the root is a JSON object AND `root['version']` is the
integer `2`, parse it as a v2 document (below). OTHERWISE
— no `version`, a non-integer `version`, any other integer,
or a non-object root — parse the root under the v1 rules
(bare progress map). A v1 profile literally named
`"version"` would hold a progress map, not the integer 2,
so the rule cannot misfire on data the app could write.

**v1 rules** = run-11 §4.5 verbatim, applied to the root:
`null` / undecodable / non-object root → empty document
(progress empty, custom empty, seq empty). Non-object
profile value → profile dropped. Non-object plan value →
plan dropped. `startedOn` not a string matching
`^\d{4}-\d{2}-\d{2}$` or not a real calendar date
(re-format equality) → plan dropped. `done` not a list →
plan dropped; non-integer or negative ENTRIES dropped,
duplicates collapse (a set). Unknown plan/profile ids
preserved. Parse never throws.

**v2 rules**, member by member (each is a §11.2 test case):

- Root not an object → empty document.
- `progress`: absent or not an object → empty progress
  (NOT a document failure — the members are independent).
  When an object, parsed by the v1 rules above, applied to
  the member instead of the root.
- `custom`: absent or not an object → no customs. Per
  profile: value not a LIST → that profile's customs
  dropped, others survive. Per def entry, drop the ENTRY
  (never the whole list) when any of these holds:
  - entry is not an object;
  - `id` is not a string matching `^custom-\d+$` with
    numeric part ≥ 1;
  - `id` duplicates an earlier kept def IN THE SAME
    PROFILE's list (first wins; later duplicates drop —
    two defs sharing an id would share one progress entry
    ambiguously);
  - `name` is not a string, or is empty after trimming
    (a kept name is stored TRIMMED — the editor's save
    rule, applied at the boundary so no consumer re-trims);
  - `segments` is not a list or is an empty list;
  - any segment is not an object, or its `book` is not an
    integer or is < 0, or `from`/`to` are not integers, or
    `1 <= from <= to` fails. (No upper bounds at parse:
    chapter-count clamping is resolution's job, §5.1 —
    parse has no `BibleData` and invents no canon facts.
    A segment whose `book` has a fractional JSON number
    (e.g. `18.0`) is not an integer in Dart's `jsonDecode`
    type sense for this rule — `is int` decides, exactly as
    run-11's `done` rule decides.)
  - `pace` is not an object; `mode` is not `'verses'` or
    `'days'`; for `verses`, `versesPerDay` is not an
    integer or is outside 1–1000; for `days`, `days` is
    not an integer or is < 1. (No upper bound on `days` at
    parse — §1.2/§5.1 clamp at resolution.)
- `customSeq`: absent or not an object → empty. Per entry:
  value not an integer or < 0 → entry dropped.
- **Seq self-heal (lesson 19's resolve-in-the-model rule):**
  after parsing, each profile's EFFECTIVE seq is
  `max(storedSeq ?? 0, highest n among that profile's kept
  custom ids, 0)`. `document.customSeq` exposes the healed
  value, and the next encode writes it. A corrupt low seq
  can therefore never cause id reuse, and the heal is
  visible in state, not hidden in the allocator.

**Id allocation** (`createCustom`): `n = (effective seq for
the profile) + 1`; id = `custom-<n>`; the def is appended
to the profile's list; `customSeq[profileId] = n`.
`createCustom` stores the name TRIMMED and assumes its
inputs are editor-valid (§6 save enablement guarantees
non-empty name and non-empty segments); it does not
re-validate (validation lives at the editor boundary and
the backup gate — the store is not a third gate).

**Mutators for customs:**
- `updateCustom`: replaces the def with the same id IN
  PLACE (list position unchanged — an edit never reorders
  Home). Unknown id → no-op. Progress is NOT touched:
  checks survive by chapter identity (§5.1 intersection).
- `deleteCustom`: removes the def AND its `progress` entry
  for (profile, planId), pruning an emptied progress
  profile map (the run-11 `restartPlan` pruning rule).
  `customSeq` is NOT decremented — the id is retired
  forever. Unknown id → no-op.
- `restartPlan` on a custom behaves exactly as on a
  built-in (removes the progress entry, keeps the def) —
  Restart and Delete are different operations and the
  detail offers both to customs (§6.2).
- Shipped mutators (`startPlan`, `toggleChapter`,
  `restartPlan`) keep their exact run-11 semantics over
  `document.progress`.

**`encode` (shipped static, taking the state map) is
REMOVED**, replaced by `encodeDocument(PlansDocument)`.
There is no v1 writer left in the app (§4.6 A4).

### 4.4 Ownership (unchanged pattern, extended)

The shell loads a snapshot for Home; the detail screen and
the editor screen each load their OWN `PlansStore` instance
(the shipped own-instance pattern: My Notes, Profiles, the
reader). Writers never coexist: whichever of detail/editor
is topmost is the only writer, the screen beneath reloads
its store when the route above it pops (§6.2/§6.5), and the
shell reloads its snapshot after every plan-detail or
plan-editor pop (§5.5).

### 4.5 Resolution entry points (defined in §5.1)

`resolveBuiltinPlan(data, def)` and
`resolveCustomPlan(data, def)` live in `plans.dart` beside
the store and consume §1's engine. The backup member (§8)
reuses `PlansDocument.toJson`-equivalent encoding: pin
`Map<String, dynamic> PlansDocument.toJson()` whose output
is exactly the §4.1 shape (and `encodeDocument(doc)` IS
`jsonEncode(doc.toJson())`), plus
`static PlansDocument PlansDocument.fromJson(Object? decoded)`
performing the §4.3 v2 member rules on an already-decoded
value (with `parseDocument(raw)` = decode-then-`fromJson`
for strings, and the v1 discrimination applied only at the
string entry point — a backup member is NEVER a v1 payload,
§8.2 P2/P3). One document model, three doors (prefs string,
backup member, tests), one parse.

### 4.6 Superseded run-11 assertions — plans_data_test.dart (store shape)

Quoted verbatim from the shipped `flutter/test/
plans_data_test.dart`. Each is superseded BY THE SHAPE
CHANGE (§4.1); its claim, where it survives, is re-asserted
against the v2 shape as stated (lesson 40 translations —
§11.2 carries the full replacement tests):

- **A1** — `expect(decoded.keys, containsAll(['default', 'p2']));`
  (round-trip test). The root no longer holds profiles
  directly. **Replacement:** `expect(decoded.keys,
  ['version', 'progress', 'custom', 'customSeq']);` (exact
  order) and `expect((decoded['progress'] as Map).keys,
  containsAll(['default', 'p2']))`.
- **A2** — `final gospels = (decoded['default'] as Map)['gospels'] as Map;`
  **Replacement:** `final gospels = ((decoded['progress']
  as Map)['default'] as Map)['gospels'] as Map;` — the two
  following assertions survive verbatim against it:
  `expect(gospels['startedOn'], '2026-10-05');` and
  `expect(gospels['done'], [929, 931]); // sorted ascending`.
- **A3** — `expect(reloaded.state, store.state);`
  The `state` field is replaced by `document`.
  **Replacement:** `expect(reloaded.document, store.document);`
  (deep `PlansDocument` equality, §4.2). The next assertion,
  `expect(reloaded.progressFor('default', 'gospels'),
  PlanProgress(startedOn: '2026-10-05', done: {929, 931}));`,
  survives verbatim — its API did not change.
- **A4** — `expect(jsonDecode(PlansStore.encode(parsed)), jsonDecode(unknown));`
  (defensive-parse test; `unknown` is a v1 bare-progress
  string, `parsed` its parse). `encode` is removed and a v1
  input now encodes as a v2 document. **Replacement:**
  `expect(jsonDecode(PlansStore.encodeDocument(
  PlansStore.parseDocument(unknown))),
  {'version': 2, 'progress': jsonDecode(unknown),
  'custom': <String, dynamic>{}, 'customSeq':
  <String, dynamic>{}});` — the claim that survives (unknown
  ids preserved verbatim) is asserted on the `progress`
  member, which is where the v1 payload now lives.
- **A5** — `expect(store.state, isEmpty);` (mutators test,
  after `restartPlan` empties the store).
  **Replacement:** `expect(store.document.progress, isEmpty);`
- **A6** — `expect(jsonDecode(prefs.getString(plansPrefsKey)!), <String, dynamic>{});`
  (mutators test: the emptied store's raw JSON). An emptied
  v2 store encodes the empty v2 document, not `{}`.
  **Replacement:** `expect(jsonDecode(prefs.getString(
  plansPrefsKey)!), {'version': 2, 'progress':
  <String, dynamic>{}, 'custom': <String, dynamic>{},
  'customSeq': <String, dynamic>{}});`

NOT superseded by the shape change (they survive because
`parse(String?)` and `progressFor` kept their signatures):
every defensive-parse assertion that indexes the parse
result as a progress map, including
`expect(parsed['p']!.containsKey('gospels'), isFalse, reason: bad);`,
`expect(mixedDone['p']!['gospels']!.done, {1});`, the
`PlansStore.parse(null / 'not json' / '[]' / '{"p": 42}')`
emptiness assertions, and all `planDayFor` / `planDoneCount`
/ `planPercent` assertions. The schedule-distribution
assertions in the same file ARE superseded, but by the
ENGINE change, not the shape change — they are quoted and
translated in §11.8, not here.

---

## 5. Resolved plans, Home cards, and the create tile

### 5.1 The resolved-definition model (one runtime type)

```dart
class ResolvedPlan {
  const ResolvedPlan({
    required this.id,
    required this.name,
    required this.isCustom,
    required this.pace,
    required this.chapters,
    required this.schedule,
    required this.coverBooks,
  });
  final String id;
  final String name;
  final bool isCustom;
  final PlanPace pace;               // built-ins: PlanPace.verses(40)
  final List<int> chapters;          // global indices, coverage order
  final List<List<int>> schedule;    // derived, never stored
  final List<int> coverBooks;        // distinct books, coverage order
  int get days => schedule.length;
  int get totalChapters => chapters.length;
  int get totalVerses;               // sum of chapters[].v — a field
                                     // computed at resolution, or a
                                     // getter over chapters + data is
                                     // NOT possible post-resolution;
                                     // store it as a constructor field.
}
```

(Implementation note pinned to remove doubt: `totalVerses`
is a stored constructor field computed by the resolve
functions, which are the only constructors callers use.)

Resolution rules:

- `resolveBuiltinPlan(data, def)`:
  `chapters = planChapters(data, def)` (run-11 expansion,
  canonical order); `pace = PlanPace.verses(wwBuiltinVersesPerDay)`;
  `schedule = scheduleByVerses(data, chapters, 40)`;
  `coverBooks` = the def's books in definition order (for
  `whole-bible`, every book in `BibleData` order);
  `isCustom = false`.
- `customChapters(data, segments)` — the custom coverage
  expander (pure, exported for tests): for each segment IN
  STORED ORDER: if `segment.book >= data.books.length`,
  the segment contributes nothing; else let
  `count = data.books[book].chapters`,
  `from = segment.from`, `to = min(segment.to, count)`;
  if `from > count`, the segment contributes nothing; else
  it contributes globals `book.start + from - 1` …
  `book.start + to - 1`. The concatenated result is then
  DEDUPLICATED keeping first occurrence (segments from a
  crafted backup may overlap; a chapter is one check-off
  unit and may appear in a schedule exactly once — its
  first position wins). Editor-produced segments never
  overlap (§6.4), so dedupe is a no-op for app-written data.
- `resolveCustomPlan(data, def)`:
  `chapters = customChapters(data, def.segments)`;
  `schedule` = `scheduleByVerses(data, chapters,
  def.pace.versesPerDay!)` for verses pace, or
  `scheduleByDays(data, chapters, def.pace.days!)` for days
  pace (the §1.2 clamp applies inside); `coverBooks` =
  distinct segment books in segment order (INCLUDING a book
  whose segment clamped to nothing — the user chose that
  book; §5.3's non-emptiness rule governs offering, and a
  def with SOME live chapters still shows all its chosen
  books on the cover); `isCustom = true`.

The detail screen, the Home cards, the shell's card
computation, and the editor's summary all consume
`ResolvedPlan` — there is no second plan-shaped type in v2.
`planAvailable` (run 11) survives for built-ins over defs;
custom availability is §5.3.

### 5.2 Cover book-line rule (one rule, both kinds)

From `coverBooks` (book NAMES via `data.books[b].name`):

- `coverBooks.length <= 4` → one line per book name, in
  order. (Gospels: `Matthew`, `Mark`, `Luke`, `John`;
  Psalms & Proverbs: `Psalms`, `Proverbs` — identical to
  run 11.)
- `coverBooks.length > 4` → exactly three lines: first
  book's name, the single line `…`, last book's name.
  (Whole Bible: `Genesis`, `…`, `Revelation` — identical to
  run 11's special case, now the general rule's output.)

The cover construction itself (112 × 144, `surfaceHigh`,
`borderDark` border, gold rule, meta line `<total>
chapters`, text-scale clamp ≤ 1.0 inside the cover per
lesson 48 / run-11 gate D-1, progress bar over the bottom
edge when started) is run-11 §4.4 VERBATIM, driven by the
resolved plan's values. The meta line for a custom carries
its resolved total (`<fmt(totalChapters)> chapters`).

### 5.3 Availability / dormancy predicate for customs (pure)

```dart
bool customAvailable(
  CustomPlanDef def,
  WwTradition tradition,
  BibleData data,
);
```

True iff (a) EVERY segment book satisfies
`canonContainsBook(tradition, data, book)` — the brief's
rule, verbatim, over SEGMENT books (a book ≥
`DeuteroBook.bookIndexBase` or ≥ the data's book count
fails `canonContainsBook`'s core path and is out — customs
are core-books only — brief §4), AND (b) `customChapters(data,
def.segments)` is non-empty (§0.4.2's narrowing). §7 states
the dormancy consequences.

### 5.4 Home Study Plans section — construction changes

Run-11 §4.4's section construction stands with these
changes ONLY:

1. **Render condition.** The section (header + row) renders
   UNCONDITIONALLY in the scroll area at its run-11 slot —
   header `STUDY PLANS` (`appSubtitle`, H16), gap 16, the
   horizontal `SingleChildScrollView` + `IntrinsicHeight`
   row — whenever HomeTab is built with its create callback
   (§5.5 makes the callback a required prop, and the shell
   always wires it). Zero offered plans → the row holds
   exactly one child: the create tile. This replaces run-11
   §1's "only when `plans` is non-empty" for this section.
2. **Row children, in order:** offered built-ins in
   `wwStudyPlans` definition order; then the active
   profile's offered customs in creation (stored list)
   order; then ONE create tile. Children are separated by
   the shipped 12dp gaps. Built-in and custom cards are the
   same widget construction (§5.2); customs are
   indistinguishable in construction from built-ins — same
   cover, title, caption forms, progress bar, semantics
   (`Semantics(container: true, button: true, label:
   '<plan name>, <caption>')`, inner excluded, key
   `plan-cover-<id>` on the cover — for a custom, its
   `custom-<n>` id).
3. **Captions** (exact forms; `<days>` and `<total>` are
   the RESOLVED plan's, `<pct>` is §6.3's `planPercent`):
   - not started: `<days> days · <total> chapters`
   - started, not complete: `Day <currentDay> of <days> · <pct>%`
   - complete: `Complete · 100%`
   These are run-11 §2.2's forms unchanged. Comma grouping
   via the shipped `_fmt` (`1,189`).

**The create tile** (new; exact construction):

- Same slot geometry as a plan card: `Material(color:
  transparent)` → `InkWell(borderRadius: row 10, onTap:
  onCreatePlan)` → `SizedBox(width: 112)` → Column
  (start-aligned):
  1. Cover — `ValueKey('plan-cover-create')`, 112 × 144,
     `Container` decoration `color: surfaceHigh`,
     `border: Border.all(borderDark, 1)`,
     `borderRadius: row 10`. Inside, `Padding(all 12)` →
     Column (start): gold rule `Container(width: 24,
     height: 2, color: gold)` (the plan covers' accent,
     verbatim); then `Expanded` → `Center` →
     `Icon(Icons.add, size: 32, color: goldBright)`. NO
     meta line, NO progress bar, NO text inside the cover
     (the tile's words live outside it at full text scale —
     lesson 48's rule: the cover is decorative here and its
     one glyph is an icon, audited §9).
  2. Gap 8.
  3. Title: `Text('Create your own plan', style:
     controlLabel.copyWith(fontWeight: w600), maxLines: 2,
     overflow: ellipsis)`.
  4. Gap 2.
  5. Caption: `Text('Choose books and a pace', style:
     captionOnDark, maxLines: 2, overflow: ellipsis)`.
- Semantics: `Semantics(container: true, button: true,
  label: 'Create your own plan, Choose books and a pace')`
  around the InkWell, inner semantics excluded (lesson 25)
  — the card pattern with the tile's title and caption.
- The tile is ALWAYS the row's last child and exists
  exactly once. It is a live control in every state (no
  profile or canon condition gates it: the editor it opens
  scopes its book list to the active canon, §6.3).

### 5.5 HomeTab and shell prop contracts

**HomeTab** (lib/screens/home_tab.dart): all run-11 props
retained; `plans` is now `List<PlanCardData>` over resolved
plans (below); ONE new required prop:

| Prop | Type | Meaning |
|---|---|---|
| `onCreatePlan` | `VoidCallback` | create-tile tap |

`PlanCardData` (lib/data/plans.dart) is re-shaped around
the resolved plan — the `def` field is REPLACED:

```dart
class PlanCardData {
  const PlanCardData({
    required this.plan,        // ResolvedPlan
    required this.started,
    required this.doneCount,   // intersected (§3)
    required this.currentDay,  // 0 when not started
    required this.percent,     // planPercent(doneCount, plan.totalChapters)
  });
}
```

`totalChapters` and `days` are read from `plan` by the
card; there is no second copy to drift. HomeTab computes
nothing about plans beyond formatting (run-11 §7.1's
division of labor stands).

**Shell** (lib/screens/shell_screen.dart):

- `_homeRoot` computes `planCards` as: for each def in
  `wwStudyPlans` where `planAvailable(...)` →
  `_planCardData(resolveBuiltinPlan(d, def), today)`; then
  for each def in `_plansStore.customsFor(activeProfileId)`
  where `customAvailable(def, tradition, d)` →
  `_planCardData(resolveCustomPlan(d, def), today)`.
  `_planCardData` re-shapes to take the `ResolvedPlan`
  (chapters, days, and totals from it; progress via
  `progressFor(activeProfileId, plan.id)`; `planDayFor`
  with `days: plan.days`).
- `_openPlanDetail(String planId)` generalizes: resolve the
  id against the shell snapshot — a built-in def (must also
  be currently offered; an id that is not offered is a
  no-op, as an unknown id is today) or a custom def of the
  ACTIVE profile (must satisfy `customAvailable`; a dormant
  custom cannot be opened, §7) — unknown or unoffered →
  no-op. Pushes `PlanDetailScreen` (§6.2's new constructor,
  including `tradition: tradition`); awaits the push, then
  `_loadPlans()` (shipped behavior).
- NEW `_openPlanEditor()`: pushes the editor in CREATE mode
  (§6.1's constructor: `data`, `tradition`,
  `profileId: userData.activeProfileId`,
  `initialDef: null`) on `homeNavKey` via `WwPageRoute`;
  awaits the push, then `_loadPlans()`. Wired as HomeTab's
  `onCreatePlan`.
- Nothing else in the shell changes. `setTradition` gains
  no plans write path (§7).

---

## 6. The editor screen and the detail screen

### 6.1 Plan editor — `lib/screens/plan_editor_screen.dart` (NEW)

Constructor contract:

```dart
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    super.key,
    required this.data,        // BibleData
    required this.tradition,    // active tradition at push time
    required this.profileId,    // active profile at push time
    required this.initialDef,   // CustomPlanDef? — null = create
  });
}
```

- The editor loads its OWN `PlansStore` in `initState`
  (the §4.4 pattern). Until loaded it renders the loading
  state: centered `Text('Loading plan…', style:
  captionOnDark)` — the detail screen's loading string,
  reused (it is the same wait).
- Top-bar title: `New plan` (create) / `Edit plan` (edit).
- The editor OWNS its `TextEditingController` in its State
  and disposes it in `dispose()` (lesson 33: never from a
  route future). Text fields in a full screen follow the
  same lifetime rule as dialog fields.
- While the editor is open the tradition cannot change
  (Profiles sits beneath this route), so the book list's
  canon is fixed at push time — no tradition watcher.

**Edit seeding** (from `initialDef`; create uses the
defaults):

| Field | Create default | Edit seed |
|---|---|---|
| Name | empty | `initialDef.name` (already trimmed) |
| Pace mode | `Daily amount` (verses) | `initialDef.pace.mode` |
| Verses/day | 40 | `initialDef.pace.versesPerDay`, clamped into the §6.4 stepper range 5–200 — an imported value outside the range displays (and on save, persists) clamped (§0.4.3) |
| Finish-in days | 30 | `initialDef.pace.days`, clamped into `1..seeded coverage chapter count` (§6.4) |
| Coverage | nothing selected | one row per segment book (§6.4 seeding rules) |

If a seeded verses value is not a multiple of 5 (possible
only via import — the validator admits any int 1–1000),
the stepper DISPLAYS the true value and stepping moves by
5 from it, clamped into range (e.g. 37 → + → 42, − → 32);
saving without stepping preserves 37 exactly. Clamping
(§0.4.3) applies only OUTSIDE 5–200. This is pinned so
Maren does not invent a rounding rule.

### 6.2 Detail screen changes — `lib/screens/plan_detail_screen.dart`

Constructor (replaces run-11 §4.6's):

```dart
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.data,          // BibleData
    required this.plan,          // ResolvedPlan
    required this.profileId,     // active profile at push time
    required this.tradition,     // active tradition at push time —
                                 // used only to seed the editor
    required this.onOpenChapter, // void Function(int globalChapter)
    this.now,                    // DateTime Function()? — test seam
  });
}
```

`StudyPlanDef plan` is replaced by `ResolvedPlan plan`;
every use of `plan.days` reads `plan.days` (the resolved
getter — same name, derived source), chapters/schedule
come from the resolved plan (no `planChapters` /
`planSchedule` calls remain in the screen).

Construction is run-11 §4.6 verbatim EXCEPT:

1. **Pace line (NEW).** In the summary card, directly
   under the status line, gap 4: `Text(paceLine, style:
   captionOnDark)` in EVERY state (not started, started,
   complete). Exact forms, from the resolved plan's pace:
   - Verses pace with target T: `About <T> verses a day`;
     T = 1: `About 1 verse a day`.
   - Days pace with N = `plan.days` and total verses V:
     `About <X> verses a day` where `X = (V / N).round()`
     (Dart `round()`: halves away from zero — V and N are
     positive, so halves round up); X = 1: `About 1 verse
     a day`. X is COMPUTED from the resolved plan at build
     time, never stored.
   For built-ins this yields `About 40 verses a day` — the
   brief's required pace statement (§0.2), in the uniform
   form (§0.4.5).
2. **Status line numbers** are the resolved plan's
   (`<days> days · <total> chapters` etc. — §6.3's forms).
3. **Bottom controls.** After the schedule, gap 24, the
   controls appear in this order, each a left-aligned
   `TextButton` (`minimumSize: Size(64, 48)`), with gap 8
   between successive controls:
   - `Restart plan` — only when started, exactly as shipped
     (`ValueKey('plan-restart')`, `dangerActionLabel`, the
     shipped dialog §6.2.1 below). Offered for BOTH kinds.
   - `Edit plan` — customs only, any start state:
     `ValueKey('plan-edit')`, `Text('Edit plan', style:
     buttonLabel)`. Pushes the editor (§6.1) seeded from the
     CURRENT stored def (re-read from the detail's own store
     at tap time — never from a stale snapshot); awaits the
     push; on return the detail RELOADS its store and
     re-resolves: `_plan = resolveCustomPlan(data, def)` —
     name, coverage, pace, schedule, and counts reflect the
     edit; progress survives by chapter identity (§3: the
     done set is untouched; counting intersects). If the
     def no longer exists on reload (unreachable through
     this UI — the editor cannot delete — but pinned
     defensively), the detail pops itself.
   - `Delete plan` — customs only, any start state:
     `ValueKey('plan-delete')`, `Text('Delete plan',
     style: dangerActionLabel)`. Behind the delete confirm
     dialog (§6.2.1). On confirm: `deleteCustom` (§4.3 —
     def AND progress entry removed, seq untouched),
     persist, then pop the detail (the plan no longer
     exists; there is nothing to return to). The shell's
     post-pop `_loadPlans()` refreshes Home.
   Built-ins show ONLY Restart (when started) — no Edit, no
   Delete, in any state (asserted in §11.4).

#### 6.2.1 Dialogs (presentation defaults explicit — lesson 20)

Both dialogs go through `wwShowDialog` with EVERY
presentation property explicit, mirroring the shipped
Restart dialog's construction token-for-token:
`AlertDialog(backgroundColor: surfaceHigh,
surfaceTintColor: Colors.transparent, shape:
RoundedRectangleBorder(borderRadius: sheet 16))`, title in
`selectionTitle`, body in `bodyOnDark`, actions
`TextButton(minimumSize: Size(64, 48))`.

- **Restart** (unchanged from run 11, strings verbatim):
  title `Restart <plan name>?`; body `Your check marks for
  this plan will be cleared, and the plan will return to
  not started. Your highlights and notes are not affected.`;
  actions `Cancel` (`buttonLabel`) / `Restart`
  (`dangerActionLabel`). Confirm → `restartPlan`, persist,
  rebuild to not-started. Cancel → nothing (byte-identical
  stored JSON — §11.4 asserts it for both kinds).
- **Delete** (new, mirroring Restart): title
  `Delete <plan name>?`; body `This plan and its check
  marks will be deleted. Your highlights and notes are not
  affected.`; actions `Cancel` (`buttonLabel`) / `Delete`
  (`dangerActionLabel`). Neither dialog contains a text
  field, so field styling is satisfied vacuously — as the
  run-11 spec noted for Restart, the dialogs carry no
  `TextField` and inherit no input decoration.

### 6.3 The percent contract (founder direction 3 — pinned)

One computation, every surface: `done = planDoneCount(
progress, resolved.chapters)` (the intersection, §3);
`pct = planPercent(done, resolved.totalChapters)` (integer
floor; total 0 → 0 — unreachable for offered plans, §5.3).
The surfaces and their exact forms:

| Surface | State | Exact text carrying `<pct>%` |
|---|---|---|
| Home card caption | started, not complete | `Day <currentDay> of <days> · <pct>%` |
| Home card caption | complete | `Complete · 100%` |
| Detail status | started, not complete | `Day <currentDay> of <days> · <done> of <total> chapters · <pct>%` |
| Detail status | complete | `Complete · <total> of <total> chapters · 100%` |

- Not-started plans carry NO percent on either surface
  (run-11's forms; there is no progress to state).
- Both surfaces are fed by the same helpers over the same
  store payload, so they agree BY CONSTRUCTION — the card
  via the shell's snapshot, the detail via its own store;
  the shell reloads its snapshot on detail pop, closing the
  loop (§11.6 tests the agreement end-to-end).
- Semantics carry the percent: the card's semantics label
  IS `'<plan name>, <caption>'` (run-11 §4.4 — the caption
  includes the percent when started); the detail's status
  is a plain `Text` in the semantics tree. No additional
  semantics work exists or is permitted here.
- The progress BAR (cover + detail summary) is the shipped
  construction, driven by the same done/total pair.

### 6.4 The editor — full construction

Skeleton mirrors the detail screen: `Scaffold(backgroundColor:
stage)` → `SafeArea` → Column: top bar, then
`Expanded(ListView(padding: all 16))`.

**Top bar** — the shipped pattern (`Container(minHeight: 56,
color: nav, bottom border borderDarkSoft, padding
horizontal 16)`): Back `IconButton` (tooltip `Back`, 48dp,
`Icons.arrow_back` in `navInk`), gap 8, `Text('New plan' |
'Edit plan', style: screenTitle)`. Back with unsaved changes
simply leaves — no unsaved-changes dialog exists in the app
and none is invented here; nothing is written until Save.

**ListView children, in order** (gaps are §10 literals):

1. Section label `Text('PLAN NAME', style: appSubtitle)`.
2. Gap 8.
3. **Name field** — `TextField` (controller §6.1), ONE line,
   with EVERY decoration property explicit (lesson 20 —
   the theme's input theme is NOT inherited silently; the
   values below ARE the shipped input construction, restated
   because this surface must not drift with the theme):
   - `style: controlLabel`; `textCapitalization:
     TextCapitalization.sentences`; `autofocus: false`.
   - `decoration: InputDecoration(labelText: 'Plan name',
     labelStyle: TextStyle(fontSize: 13, color:
     mutedOnDark), filled: true, fillColor: surfaceHigh,
     contentPadding: EdgeInsets.symmetric(horizontal: 12,
     vertical: 12), border / enabledBorder:
     OutlineInputBorder(borderRadius: input 8, borderSide:
     borderDark), focusedBorder: OutlineInputBorder(
     borderRadius: input 8, borderSide: goldBright))`.
     The field sits directly on `stage` (not inside a
     `surfaceHigh` container), so the `surfaceHigh` fill is
     the one-step-up inset — the lesson-20 trap (theme fill
     inside a same-level dialog) does not apply, and the
     fill is pinned explicitly regardless.
   - Semantics (one pinned choice): the field carries
     `labelText: 'Plan name'` and NO `hintText` and NO
     wrapping `Semantics` node. The decoration label is the
     field's accessible name (it renders as the field's
     floating label); the §6.4 item 1 section label
     (`PLAN NAME`) is presentation for sighted scanning.
     Label wins over hint — Maren does not choose.
4. Gap 16.
5. Section label `Text('PACE', style: appSubtitle)`.
6. Gap 8.
7. **Pace card** — `Material(color: surface, borderRadius:
   row 10)` → `Container(padding: all 16)` → Column (start):
   - **Segmented control** (exactly two segments — inside
     lesson 37's ≤3 budget at 360dp): `Container(
     decoration: BoxDecoration(color: surfaceHigh,
     border: Border.all(borderDark, 1), borderRadius:
     chip 12), padding: all 4)` → `Row` of two `Expanded`
     segments. One segment: `Material(color: selected ?
     goldBright : Colors.transparent, borderRadius:
     chip 12)` → `InkWell(borderRadius: chip 12, onTap:
     select)` → `Container(constraints: minHeight 48,
     alignment: center, padding: horizontal 8)` →
     `Text(label, style: selected ? goldButtonLabel :
     buttonLabel, maxLines: 2, overflow: ellipsis)`.
     Labels: `Daily amount` /
     `Finish in`. Semantics per segment:
     `Semantics(container: true, button: true, selected:
     <bool>, label: 'Daily amount' | 'Finish in')` around
     the InkWell with inner semantics excluded (lesson 25 —
     the tradition-row pattern).
   - Gap 16.
   - **The ACTIVE mode's stepper row only.** The inactive
     mode's stepper is NOT rendered (a hidden-but-present
     control is a dead control; mode switching swaps the
     row). Stepper row construction (used for verses, days,
     and both range bounds — one construction, four
     instances): `Row`: `Expanded(Text(label, style:
     controlLabel))`, then the stepper: `IconButton`
     (decrease), `SizedBox(width: 48, child: Text('<value>',
     style: controlLabel.copyWith(fontWeight: w600),
     textAlign: center))`, `IconButton` (increase).
     `IconButton`s: `constraints: BoxConstraints(minWidth:
     48, minHeight: 48)`, icon size 24, color `navInk`;
     at the bound the button is DISABLED (`onPressed:
     null`, icon color `mutedOnDark` — a bound state, not a
     dead control: the value beside it shows why).
     Tooltips ARE the semantics labels (lesson 25), exact:
     - verses: decrease `Decrease verses per day`,
       increase `Increase verses per day`; row label
       `Verses per day`.
     - days: decrease `Decrease days`, increase
       `Increase days`; row label `Days`.
   - Stepper ranges/steps (PINNED):
     - Verses per day: min **5**, max **200**, step **5**,
       default **40**. (Stepping from a non-multiple seed
       preserves the offset, §6.1.)
     - Days: min **1**, max **coverage chapter count**
       (dynamic, §6.4 re-clamp rule), step **1**, default
       **30** (clamped at seed/render to the current max).
8. Gap 16.
9. Section label `Text('COVERAGE', style: appSubtitle)`.
10. Gap 8.
11. **Book rows** — one per book in `BibleData` order whose
    book satisfies `canonContainsBook(tradition, data,
    book)` (core books only; deuterocanon books are not in
    `BibleData` and cannot appear — brief §4). Rows separated
    by gap 8. One row: `Material(color: surface,
    borderRadius: row 10)` → `Container(padding:
    horizontal 12, vertical 8, constraints: minHeight 48)`
    → Column (start):
    - Header row (`Row`): the **check toggle** — the detail
      screen's toggle construction verbatim:
      `Semantics(container: true, button: true, checked:
      selected, label: 'Include <book name>')` around an
      `InkWell` whose hit box is EXACTLY 48 × 48, centering
      the 24dp visual box (`Container(24 × 24, borderRadius:
      input 8)` — unselected: transparent fill, 2dp border
      `mutedOnDark`; selected: fill `goldBright`, no border,
      centered `Icon(Icons.check, size: 18, color:
      onGold)`); gap 8; `Expanded(Text(bookName, style:
      controlLabel))`; `Text('<chapters> chapters', style:
      captionOnDark)` (`<chapters>` = the book's real chapter
      count, plain integer, no grouping — a book holds at
      most 150). Tapping the toggle OR the book name toggles
      inclusion, as two targets with ONE action (the detail
      chapter row's toggle+label pattern, run-11 §4.6,
      reused exactly): the toggle's Semantics/InkWell is
      the 48×48 box (`ValueKey('plan-editor-toggle-
      <bookIndex>')`); the book name is a second InkWell
      with the same toggle action (`ValueKey(
      'plan-editor-book-<bookIndex>')`), its hit area
      ≥48dp high spanning the name's row width; the chapter
      count caption is not tappable.
    - When the book is selected: gap 8, then the
      **whole/range choice** — the §6.4 item 7 segmented
      construction at the same sizes, labels `Whole book` /
      `Chapter range`, semantics labels `Whole book` /
      `Chapter range` with `selected` flags (container,
      button, inner excluded). Then, ONLY when
      `Chapter range` is chosen: gap 8, two stepper rows
      (§6.4 item 7 construction): row label `First chapter`
      (tooltips `Decrease first chapter for <book name>` /
      `Increase first chapter for <book name>`), row label
      `Last chapter` (tooltips likewise with `last`).
      Range stepper ranges: First: `1..to`; Last:
      `from..bookChapterCount`; step 1. Stepping First
      above Last is impossible (First's max IS Last's
      current value) and vice versa — the two bounds clamp
      each other, the §6.4 pace re-clamp rule in miniature.
    - Seeding a book's whole/range choice: a stored segment
      with `from == 1 && to == bookChapterCount` seeds
      `Whole book`; anything else seeds `Chapter range`
      with the stored bounds (clamped: `to` to the book's
      count; a segment whose `from` exceeds the count
      cannot seed — it contributes nothing at resolution
      and the book seeds UNSELECTED; its segment is a
      carried segment, §6.5).
12. Gap 16.
13. **Summary card** — `Material(color: surface,
    borderRadius: row 10)` → `Container(padding: all 16)` →
    Column (start):
    - Counts line (ALWAYS rendered, computed live from the
      draft through the §5.1 resolution functions — the
      editor builds a draft `CustomPlanDef` (id: the seed's
      id, or `custom-0` as a never-persisted placeholder id
      for create — resolution never reads the id) and
      resolves it on every build): exact form
      `<fmt(chapters)> chapters · <fmt(verses)> verses ·
      <fmt(days)> days`, in `bodyOnDark`, where `days` is
      `resolved.schedule.length` — the ENGINE's output in
      both modes (Mode A: the greedy length; Mode B: the
      effective N after clamping), never the raw stepper
      value. Examples (fake canon): a Psalms 1–10 draft at
      Daily amount 40 → `10 chapters · 100 verses · 3 days`;
      the same draft at Finish in 4 → `10 chapters · 100
      verses · 4 days`; empty draft → `0 chapters · 0
      verses · 0 days`.
    - Reason lines (only in invalid states, each gap 4
      below the previous line, `captionOnDark`): name
      invalid → `Give your plan a name to save it.`;
      coverage invalid → `Choose at least one chapter to
      save your plan.` Both invalid → both lines, name
      first. No other reason text exists.
14. Gap 16.
15. **Save button** — `ElevatedButton`
    (`ValueKey('plan-editor-save')`), the shipped
    selection-panel construction: `backgroundColor:
    goldBright`, `foregroundColor: onGold`,
    `minimumSize: Size.fromHeight(48)`, shape radius
    `chip` 12, `Text('Save plan' | 'Save changes', style:
    goldButtonLabel)`. Disabled state is EXPLICIT:
    `onPressed: null` when invalid (§6.5), with
    `disabledBackgroundColor: surfaceHigh` and the label
    style switching to `dialogActionLabelDisabled` (the
    shipped disabled-action role — mutedOnDark, audited
    §9). Button text: create → `Save plan`; edit →
    `Save changes`.

**Pace re-clamp rule (binding).** The days stepper's max is
the CURRENT draft coverage chapter count. Whenever a
coverage change (book toggle, range change) makes the
chapter count drop below the chosen days value, the days
value clamps DOWN to the new count IN THE SAME state
update (the summary's resulting-days figure never shows a
stale promise). Growing coverage never raises the days
value. When coverage becomes empty, days clamps to 1 (its
floor) and the summary shows `0 days` (the engine over an
empty coverage) — the stepper's displayed 1 is the stored
draft value awaiting coverage, not a schedule claim; the
counts line is the schedule claim and it says 0. The
verses value is never re-clamped by coverage (Mode A has
no coverage-dependent bound).

**Coverage seeding rules (binding).** From `initialDef`'s
segments, in stored order:
- Group segments by book. A book with exactly ONE segment
  whose `from <= bookChapterCount` seeds a selected row
  with that segment (whole/range per the from/to rule).
- A book with MULTIPLE segments seeds ONE selected row
  whose range is the BOUNDING range `min(from) ..
  max(to)` (clamped per §5.1) — the editor's model is one
  segment per book, so disjoint stored ranges for one book
  collapse to their bounding range ON SAVE (§6.5). Such
  defs arise only from crafted backups; the collapse is
  deterministic, resolution-deduped in the interim, and
  named here so it is never discovered in the field.
- Segments whose book is not in the editor's canon book
  list (out-of-canon under the CURRENT tradition) or whose
  `from` exceeds the book's chapter count are CARRIED
  segments (§6.5): unshown, unedited, preserved on save.
  (Through the shipped UI an edit can only be opened for an
  offered plan, whose segments are all in-canon and live —
  carried segments are a defensive path for store states
  the UI cannot currently produce, pinned so the behavior
  is defined, not improvised.)

### 6.5 Editor save behavior

- **Enablement.** Save is enabled IFF the name is non-empty
  after trimming AND the draft coverage resolves to at
  least one chapter. No other state disables it — pace is
  always valid by construction (stepper bounds), and there
  are no other fields. (Brief: "Save is disabled only in
  states that are truly invalid (no name, no coverage) and
  the summary says why" — §6.4.13's reason lines are the
  "says why".)
- **On Save (create):** `store.createCustom(profileId,
  name: trimmed, segments: <editor segments>, pace:
  <draft pace>)`; persist (fire-and-forget with catch, the
  shipped pattern); pop. Editor segments are emitted in
  **BibleData order** (the book list's order), one per
  selected book: whole → `{book, 1, bookChapterCount}`;
  range → `{book, from, to}`.
- **On Save (edit):** segments = editor segments (BibleData
  order) FOLLOWED BY the carried segments in their original
  relative order; `store.updateCustom(profileId,
  CustomPlanDef(id: initialDef.id, name: trimmed, segments:
  …, pace: …))`; persist; pop. The id, the list position,
  the profile's seq, and ALL progress (for this and every
  plan) are untouched by the save itself.
- **No-save exits write nothing:** Back, barrier-equivalent
  gestures, and system back from the editor leave the prefs
  string byte-identical (§11.5 asserts it in create AND
  edit modes).
- The detail's post-edit reload is §6.2 (item 3, Edit
  plan); the shell's post-create reload is §5.5.

---

## 7. Dormancy — customs under tradition switches

Pure statements (asserted in §11.2/§11.6):

1. A custom plan is OFFERED iff `customAvailable(def,
   tradition, data)` (§5.3). Out-of-canon customs hide from
   Home and cannot be opened (the shell's
   `_openPlanDetail` no-ops for them, §5.5).
2. Tradition switches perform NO plans write. No code path
   from `setTradition` (or the Profiles tradition rows)
   touches `ww_plans_v1`: the prefs string holding a
   custom's def + progress is BYTE-IDENTICAL before and
   after any number of switches, and the def and its checks
   return intact when the tradition offers the plan again.
   (Same guarantee run 11 pinned for built-in progress;
   v2 extends it to defs, which live in the same string.)
3. The editor is never offered for a dormant custom (it is
   reachable only from an offered plan's detail, or in
   create mode from Home), so a switch can never strand an
   open edit of a now-dormant plan: while the editor or
   detail is open, the tradition cannot change (Profiles
   sits beneath those routes).

Shell statement: `_loadPlans()` only READS the store; the
shell's snapshot after a switch simply resolves fewer
offered customs. Nothing in the switch path calls `save()`
on any plans instance.

---

## 8. Backups — plans join the file

### 8.1 The `plans` member (exact JSON)

The exported document gains a top-level `plans` member
whose value is the plans store's v2 document OBJECT (the
§4.1 shape as a JSON value, not a string):

```json
"plans": {
  "version": 2,
  "progress": { …§4.1… },
  "custom": { …§4.1… },
  "customSeq": { …§4.1… }
}
```

`UserData.version` STAYS 3, and the member is additive.
Why (pinned rationale, brief §6): `UserData.fromJson` reads
only its named members and ignores unknown keys, so an
older build reading a newer backup imports everything it
ever understood and simply does not restore plans; a newer
build reading an older backup finds no `plans` member and
leaves plans state untouched (§8.3). The UserData document
version describes the UserData shape, which did not change;
the plans payload carries its OWN version (2) inside the
member, versioned independently — exactly as the store
document is.

### 8.2 Import validation — the strict gate (lesson 22)

`UserDataStore.validateImport` extends. The result type
gains one field; the error enum gains one case:

```dart
enum BackupImportError {
  notJson, notBackup, newerVersion, emptyDocument,
  invalidPlans, // NEW
}

class BackupImportResult {
  final UserData? data;
  final BackupImportError? error;
  /// The validated `plans` member, decoded — non-null ONLY
  /// when the source carried a `plans` member AND it passed
  /// §8.2's checklist. Null when the member was ABSENT
  /// (legacy file) — absence and emptiness are different
  /// states and Profiles branches on exactly this.
  final Map<String, dynamic>? plans;
}
```

Validation order (pinned, §0.4.4): (1) `notJson`,
(2) `notBackup` (root/profiles/version-type checks, as
shipped), (3) `newerVersion` (UserData version, as
shipped), (4) **plans checklist** (only when a `plans`
member is PRESENT; any failure → `invalidPlans`),
(5) `emptyDocument` (as shipped — computed over the
UserData model ONLY: plans content does NOT rescue an
otherwise-empty document; a file with empty `profiles` and
rich plans is still `emptyDocument`, in this order: a
malformed plans member in such a file reports
`invalidPlans` first, per the pinned order).

**The plans checklist — every malformation is named; ANY
one rejects the WHOLE import** (nothing is written, either
store — §11.8 byte-tests it):

- P1. `plans` is not a JSON object.
- P2. `plans['version']` is not the integer 2 (absent,
  non-integer, or any other value — a plans payload is
  never a v1 bare map, §4.5; a future plans version is
  this build's `invalidPlans`, not `newerVersion`, whose
  meaning stays bound to `UserData.version`).
- P3. Any of `progress`, `custom`, `customSeq` is absent
  or not an object. (Exports always write all three,
  possibly empty.)
- P4. Progress malformations: a progress profile value is
  not an object; a plan value is not an object;
  `startedOn` is not a string, does not match
  `^\d{4}-\d{2}-\d{2}$`, or is not a real calendar date
  (re-format equality — the store's own strict date rule);
  `done` is not a list; any `done` entry is not an integer
  or is negative; `done` contains a duplicate entry.
  (STRICTER than the store's defensive parse, deliberately:
  the gate rejects what the parser would have silently
  trimmed — lesson 22.)
- P5. Custom malformations: a custom profile value is not
  a list; a def is not an object; `id` is not a string
  matching `^custom-\d+$` with numeric part ≥ 1; two defs
  in one profile share an id; `name` is not a string or is
  empty after trimming; `segments` is not a list or is
  empty; a segment is not an object, or `book` is not an
  integer ≥ 0, or `from`/`to` are not integers, or
  `1 <= from <= to` fails; `pace` is not an object, or
  `mode` is not `'verses'`/`'days'`, or (`verses`)
  `versesPerDay` is not an integer in 1–1000, or (`days`)
  `days` is not an integer ≥ 1.
- P6. customSeq malformations: a value is not an integer
  or is < 0. (A seq BELOW the highest id suffix in the same
  file is NOT a malformation — the store's §4.3 self-heal
  resolves it at parse; the gate checks shapes, the model
  resolves state, lesson 19.)

Unknown keys inside the plans member (top level, defs,
segments, pace) are IGNORED (forward compatibility within
v2 — the same stance `UserData.fromJson` takes toward the
document). Validation is pure and never writes; it lives
in `user_data.dart` as shape-only code over the decoded
JSON (it does NOT import `plans.dart` — the gate knows the
member's SHAPE; `PlansDocument.fromJson` is the parser
behind it, and the two are tested against each other in
§11.8: every checklist-valid member parses to a document
whose `toJson()` reproduces the member).

**Counts for the confirm dialog** come from the validated
member by ONE helper, used by the dialog and the tests
(lesson 22's one-method rule), pinned in `plans.dart`:

```dart
({int customPlans, int plansInProgress}) plansBackupCounts(
  Map<String, dynamic> plansMember,
);
```

`customPlans` = total def count across all profiles in
`custom`; `plansInProgress` = total progress ENTRIES
across all profiles in `progress` (an entry = a started
plan, built-in or custom or unknown id — the file's
progress payload is one rule for every plan, §8.4).

### 8.3 Absent vs present; the error dialog; the confirm dialog

- **Absent member** (every pre-v2 backup): import proceeds
  EXACTLY as shipped — same validation outcomes, same
  confirm dialog text (§8.3 below, unchanged form), and on
  confirm ONLY the UserData replacement happens. Plans
  state is untouched: the `ww_plans_v1` prefs string is
  byte-identical across the import (§11.8 asserts it).
  Those files never held plans, so nothing they promised
  is lost.
- **Present and valid:** on confirm, UserData is replaced
  (`replaceData`, awaited, as shipped) AND the plans state
  is replaced wholesale: Profiles loads a `PlansStore`,
  sets its document to `PlansDocument.fromJson(result.plans)`,
  and awaits `save()` — both replacements complete before
  the success snackbar (the shipped true-receipt rule).
  Replacement is wholesale: profiles' defs/progress/seq in
  the file replace the device's entirely (no merging — the
  shipped import semantics).
- **New error sentence.** `_showImportError` gains the
  `invalidPlans` arm:
  `This backup's study plans are not in a form Woven Word can import.`
  — rendered in the shipped construction
  (`Nothing was changed. <sentence>`). The other four
  sentences are byte-identical to shipped.
- **Confirm dialog counts.** The shipped body form is
  retained; when (and only when) the file carries a valid
  plans member, ONE sentence is inserted before the final
  sentence. Exact forms:
  - Absent: `Importing this backup will replace all
    current data. The <curProfiles>, <curHighlights>, and
    <curNotes> now on this device will be removed, and
    <fileProfiles>, <fileHighlights>, and <fileNotes> from
    the file will take their place. This cannot be
    undone.` (shipped, verbatim).
  - Present: `…will take their place. The file also holds
    <fileCustomPlans> and <filePlansInProgress>. This
    cannot be undone.` where `<fileCustomPlans>` =
    `_counted(n, 'custom plan', 'custom plans')` and
    `<filePlansInProgress>` = `_counted(n, 'plan in
    progress', 'plans in progress')` — e.g. `The file also
    holds 1 custom plan and 3 plans in progress.` /
    `The file also holds 0 custom plans and 1 plan in
    progress.` The device-side plans counts are NOT added
    (brief: the dialog names what the BACKUP holds for
    plans; the replacement of current plans is already
    stated by "replace all current data" and effected
    wholesale).

### 8.4 Export assembly — `profiles_screen.dart`

- `_load` also loads a `PlansStore` snapshot (own-instance
  pattern; failure leaves a null plans store and export
  then writes an EMPTY v2 document as the member — a
  backup never omits the member in v2, and export never
  crashes on a plans-load failure; import on this screen
  still replaces plans through a FRESHLY loaded store at
  confirm time, §8.3).
- `_exportBackup`: the document is assembled as
  `Map<String, dynamic>.from(_data.toJson())` with
  `['plans'] = plansDocument.toJson()` (the snapshot's
  document; empty document when the load failed), encoded
  with `const JsonEncoder.withIndent('  ')` — the shipped
  pretty format. Assembly lives HERE, not in
  `UserData.exportJson` (which is unchanged and still
  returns the plans-less document; §11.8 asserts
  `UserData` behavior is untouched). The share/subject/file
  name are as shipped.
- Import: `_importBackup` passes `result.plans` through
  the confirm flow (§8.3). The legacy-translation handling
  for UserData is unchanged and does not interact with
  plans (plan defs carry no translation).

### 8.5 What does not change in backups

`UserData` (model, `toJson`, `fromJson`, counts),
`UserData.version` (3), the storage key, the four shipped
error sentences, picker cancellation silence, the success
snackbar (`Data replaced from backup.`), and the Backup
section's heading/description/rows copy (§0.4.6) are all
byte-identical to shipped.

---

## 9. Contrast — computed table (audit §2 method)

All ratios computed by me from the token hexes in
`ww_theme.dart`. Thresholds: normal text ≥ 4.5:1; large
text ≥ 3.0:1; meaningful icons and control boundaries
≥ 3.0:1. Only NEW or CHANGED elements are tabled here;
unchanged run-11 surfaces keep their run-11 §9 audit
(detail rows, toggles, covers, dialogs' shared pairs).

### 9.1 Editor screen

| Element | Token (class) | Surface | Ratio | Verdict |
|---|---|---|---|---|
| Top-bar title (`screenTitle`) | goldBright | nav | 10.23 | ✓ |
| Back icon (graphic) | navInk | nav | 16.40 | ✓ ≥3 |
| Section labels (`appSubtitle`: PLAN NAME / PACE / COVERAGE) | mutedOnDark | stage | 6.92 | ✓ |
| Name field text (`controlLabel`) | navInk | surfaceHigh (field fill) | 14.27 | ✓ |
| Name field floating label (`labelText`, 13sp `mutedOnDark` per §6.4 item 3) | mutedOnDark | surfaceHigh | 5.63 | ✓ |
| Summary reason lines (`captionOnDark`) | mutedOnDark | surface | 6.03 | ✓ |
| Segmented, selected label (`goldButtonLabel`) | onGold | goldBright fill | 9.71 | ✓ |
| Segmented, unselected label (`buttonLabel`) | navInk | surfaceHigh (control bg) | 14.27 | ✓ |
| Segmented selected fill vs control bg (state step) | goldBright | surfaceHigh | 8.91 | ✓ ≥3 (state ALSO carried by `selected` semantics + label weight — never color alone, lesson 17) |
| Stepper row label / value (`controlLabel` / +w600) | navInk | surface | 15.29 | ✓ |
| Stepper icons, enabled (graphic) | navInk | surface | 15.29 | ✓ ≥3 |
| Stepper icons, at bound (disabled) | mutedOnDark | surface | 6.03 | ✓ ≥3 |
| Book row name (`controlLabel`) | navInk | surface | 15.29 | ✓ |
| Book row chapter count (`captionOnDark`) | mutedOnDark | surface | 6.03 | ✓ |
| Row toggle, checked glyph | onGold | goldBright fill | 9.71 | ✓ ≥3 |
| Row toggle, unchecked border (control boundary) | mutedOnDark | surface | 6.03 | ✓ ≥3 |
| Whole/range choice labels | as segmented rows above (on `surface` card: unselected fill surfaceHigh 14.27; selected 9.71) | surface | — | ✓ |
| Summary counts (`bodyOnDark`) | navInk | surface | 15.29 | ✓ |
| Save button label, enabled (`goldButtonLabel`) | onGold | goldBright fill | 9.71 | ✓ |
| Save button label, disabled (`dialogActionLabelDisabled`) | mutedOnDark | surfaceHigh (disabled bg) | 5.63 | ✓ |

### 9.2 Create tile

| Element | Token | Surface | Ratio | Verdict |
|---|---|---|---|---|
| Add icon (32dp, graphic) | goldBright | surfaceHigh (cover) | 8.91 | ✓ ≥3 |
| Cover gold rule (decorative accent) | gold | surfaceHigh | 5.25 | ✓ ≥3 |
| Title (`controlLabel` w600) | navInk | stage | 17.54 | ✓ |
| Caption (`captionOnDark`) | mutedOnDark | stage | 6.92 | ✓ |
| Cover border (decorative hairline) | borderDark | stage | 1.69 | exempt† (run-11 §9.3's ruling: hairlines carrying no meaning alone; the cover's edge is also defined by the surfaceHigh-on-stage step) |

### 9.3 Detail additions and backup dialog

| Element | Token | Surface | Ratio | Verdict |
|---|---|---|---|---|
| Pace line (`captionOnDark`) | mutedOnDark | surface (summary card) | 6.03 | ✓ |
| Edit button (`buttonLabel`) | navInk | stage | 17.54 | ✓ |
| Delete / Restart buttons (`dangerActionLabel`) | danger | stage | 12.95 | ✓ |
| Delete dialog title (`selectionTitle`) | goldBright | surfaceHigh | 8.91 | ✓ |
| Delete dialog body (`bodyOnDark`) | navInk | surfaceHigh | 14.27 | ✓ |
| Delete dialog Cancel (`buttonLabel`) | navInk | surfaceHigh | 14.27 | ✓ |
| Delete dialog Delete (`dangerActionLabel`) | danger | surfaceHigh | 10.54 | ✓ |
| Confirm dialog plans sentence (part of `bodyOnDark` body) | navInk | surfaceHigh | 14.27 | ✓ |
| Import error dialog, new sentence (part of `bodyOnDark` body) | navInk | surfaceHigh | 14.27 | ✓ |

†/informational, as run-11 §9.3: the segmented control's
`borderDark` outline on `surface` (1.47) and the name
field's `borderDark` borders (on `surfaceHigh` fill, 1.37)
are the SHIPPED input/control construction (the theme's
input borders are `borderDark` throughout the app); the
controls' presence is carried by their fills (surfaceHigh
on surface/stage steps), their labels (≥5.63 everywhere),
and the focused border (`goldBright`: 8.91 on surfaceHigh /
9.55 on surface) — no meaning rides on the resting border
alone. Progress-bar track/fill pairs are run-11's audit,
unchanged.

### 9.4 No new `WwType` roles — proof

Every new string maps to a shipped role: editor section
labels → `appSubtitle` (the shipped section-header role);
field text → `controlLabel` (the shipped profile-dialog
field style); segmented/stepper/save labels →
`buttonLabel` / `goldButtonLabel` (the shipped action
roles); disabled save label → `dialogActionLabelDisabled`
(the shipped disabled-action role, built for exactly this);
book rows → `controlLabel` + `captionOnDark` (the shipped
row pairing); summary → `bodyOnDark` + `captionOnDark`
(the detail summary's own roles); pace line →
`captionOnDark`; create tile → `controlLabel` +w600 +
`captionOnDark` (the plan card's own roles); dialog text →
`selectionTitle` / `bodyOnDark` / `buttonLabel` /
`dangerActionLabel` (the shipped dialog set). No text in
§§5–8 needs a size, weight, or color outside these roles,
so no role is added. **New tokens: none. New colors: none.
New radii: none** (editor uses `row` 10, `chip` 12,
`input` 8, `sheet` 16 — the closed scale).

### 9.5 Motion

No new durations or curves. The editor and detail push via
`WwPageRoute` (300ms slide, no fade; reduced motion swaps
instantly); dialogs via `wwShowDialog`; toggles, steppers,
segmented switches, and Start/Restart/Edit/Delete state
changes are instant rebuilds. No `Animated*` widget is
introduced. The summary line updates are text changes in a
rebuilt card, never animated.

---

## 10. Layout geometry

All spacing literals come from the audit §5 allowed set
{2, 3, 4, 6, 8, 10, 12, 14, 16, 20, 24}; this package uses
only {2, 4, 8, 12, 16, 24}. Screen margin 16 everywhere.
Radii: `row` 10 / `chip` 12 / `input` 8 / `sheet` 16 only.

| Surface | Geometry |
|---|---|
| Plans row (changed) | header H16; gap 16; scroll row padding H16; card/tile width 112; children gaps 12; cover 112 × 144 radius 10 |
| Create tile | cover padding 12; rule 24 × 2; icon 32 centered; cover→title gap 8; title→caption gap 2 |
| Editor | ListView padding 16; section gaps 16 between sections, 8 label→content; pace card padding 16; segmented padding 4, segment minHeight 48, padding H8; stepper value box width 48; book rows padding H12 V8, gaps 8, toggle hit 48 × 48, visual 24 radius 8; summary padding 16; save `Size.fromHeight(48)` |
| Detail (changed parts) | status→pace line gap 4; bottom controls: gap 24 before the first control, gap 8 between controls, each `minSize(64, 48)` |
| Dialogs | shipped AlertDialog construction; actions `minSize(64, 48)` |

**360dp / text-scale-2.0 rules (lessons 30, 37, 48).**
- The segmented control holds exactly 2 options (≤3 budget,
  lesson 37): at 360dp each segment is ~148dp wide inside
  the pace card. Segment labels carry `maxLines: 2,
  overflow: ellipsis`: at scale 2.0 the labels are
  expected on one line inside a 48dp-min-height segment
  that GROWS vertically with the text (no fixed height);
  the 2-line allowance is headroom so a longer scale wraps
  rather than clips. §11.5 item 10 asserts no exception
  and ≥48dp rendered segment heights at scale 2.0.
- Book rows, stepper rows, and the summary card have no
  fixed heights; rows grow with wrapped text. The name
  field is one line and scrolls horizontally (TextField
  default) — text scale cannot overflow it.
- Every target ≥ 48dp in both axes: book toggle 48 × 48;
  book name InkWell ≥ 48 high (row minHeight) and full
  remaining width; stepper buttons 48 × 48; segments
  ≥ 48 high × ~148 wide; save 48 high × full width; create
  tile 112 wide × ≥ 144 + title/caption tall.
- §11.5/§11.6 assert geometry from RENDERED POSITIONS at
  360 × 800 and text scale 2.0 (rects, sizes, centers,
  `tester.takeException()` null) — never from widget
  properties alone.

---

## 11. Acceptance tests

Suites are NEW files unless named otherwise. Every suite
must pass; every pre-existing suite must stay green except
where §11.9 translates it (baseline discipline, lesson 41:
a failure is owned only after a same-environment HEAD
baseline says so). Widget suites pump at 360 × 800, DPR 1.0
(the shipped harness patterns), with text-scale 2.0
variants where stated.

### 11.1 `test/plans_engine_test.dart` (NEW, pure)

Engine properties and worked examples (§1). Tiny canons
built via `BibleData.fromJsonString` (a helper in the suite
maps a verse vector to a one-book canon; global index =
position).

1. Mode A worked examples: `[10,10,10,10,10]` at T = 40 →
   `[[0,1,2,3],[4]]`; `[10,10]` at T = 40 (T > total
   verses) → `[[0,1]]` (one day); `[176]` at T = 40 →
   `[[0]]`; `[50,10,10]` at T = 40 → `[[0],[1,2]]` (the
   50-verse chapter closes before the next is added —
   `tot >= T`); `[30,30]` at T = 40 → `[[0],[1]]` (the tie
   closes: `|30+30-40| = 20 >= |30-40| = 10`).
2. Mode A properties (assert over the fake canon's three
   built-in chapter lists AND 200 seeded random verse
   vectors with T in {1, 5, 40, 200}): concatenation ==
   input exactly; no empty day; the closeness invariant —
   for every day except the last, with day total `t` and
   next chapter verse `v`: `t >= T || (t + v - T).abs() >=
   (t - T).abs()`; day count is non-increasing as T grows
   (spot: T = 1 on fake Gospels → 89 days, one chapter per
   day).
3. Mode B worked examples (§1.2's five, verbatim): the
   day partitions and verse totals as listed there.
4. Mode B properties (same vectors, every N in
   `1..chapterCount` for the small vectors; sampled N for
   the fake lists): `schedule.length == N` exactly; no
   empty day; concatenation == input. Edge pins: N = 1 →
   one day with all chapters; N = chapterCount → every
   chapter alone; N > chapterCount clamps (length ==
   chapterCount); empty chapter list → `[]` in both modes.
5. Resolution: `customChapters` clamps and dedupes — a
   def with segments `[{book:18, from:149, to:999}]` on the
   fake canon resolves to globals `[626, 627]` (Psalms
   149–150); `[{book:18, from:200, to:210}]` resolves to
   `[]`; overlapping segments `[{18,1,3},{18,3,5}]` resolve
   to globals `[478,479,480,481,482]` (chapter 480 once,
   first position); a segment with `book` ≥ book count
   contributes nothing. `resolveCustomPlan` dispatches
   pace: the Psalms 1–10 fake def (segments
   `[{book:18, from:1, to:10}]`) at verses 40 → schedule
   sizes `[4,4,2]`, totals `[40,40,20]`, days 3; at days 4
   → sizes `[3,2,3,2]`, totals `[30,20,30,20]`, days 4;
   at days 99 → days 10 (clamped to chapter count), every
   chapter alone.

### 11.2 `test/plans_data_test.dart` (SHIPPED, translated)

The shipped suite survives with §4.6's replacements and
§11.9's engine translations, PLUS these new groups:

1. **v2 round-trip:** build a document with two profiles —
   progress (partial + complete), two customs on one
   profile (one per pace mode), seq values — `save`, assert
   the raw string decodes to EXACTLY the §4.1 shape (top
   keys in order; def key order `id/name/segments/pace`;
   segment key order `book/from/to`); reload; assert
   `reloaded.document == store.document`.
2. **v1 load (migration shape):** seed the exact v1 strings
   the shipped suite used (including the unknown-ids string
   of §4.6 A4); assert the loaded document's progress equals
   the v1 parse; `custom`/`customSeq` empty; after `save`,
   the raw string is the v2 document whose `progress`
   member deep-equals the v1 payload.
3. **v2 defensive parse** (each input → asserted document,
   never throws): v2 root with `progress: 42` (progress
   empty, customs survive); `custom` profile value not a
   list; def entries dropped individually for: non-object
   def, `id: 'x-1'`, `id: 'custom-0'`, duplicate id (first
   kept), blank/whitespace name (a kept name with
   surrounding whitespace is stored trimmed), empty
   segments, segment `book: -1`, segment `from: 0`,
   segment `from > to`, pace mode `'weeks'`, `versesPerDay:
   0 / 1001 / '40'`, `days: 0`; each bad def's SIBLING def
   survives. `customSeq` non-int/negative entries dropped.
4. **Seq discipline:** create two customs on a profile →
   ids `custom-1`, `custom-2`; delete `custom-1`; create
   again → `custom-3` (never reused); a stored document
   with seq 0 but a live `custom-7` def heals: next create
   → `custom-8`, and the healed seq is what `encode` writes.
5. **Custom mutators:** `updateCustom` replaces in place
   (list order unchanged) and leaves progress bytes
   semantically identical; unknown id no-op.
   `deleteCustom` removes def + progress entry, prunes the
   emptied progress profile, leaves seq and other profiles
   untouched; unknown id no-op. `restartPlan` on a custom
   removes progress, keeps the def.
6. **Custom availability (pure dormancy):** a Matthew-range
   custom (`book 39`) is available under none/protestant/
   catholic/lds, NOT under jewish; a Psalms-range custom is
   available under ALL five (incl. jewish); a custom whose
   segments clamp to zero chapters is NOT available under
   any tradition (§5.3(b)); availability recomputation
   performs no store write (prefs string byte-identical).

### 11.3 Migration tests (in `plans_data_test.dart`, NEW group)

1. Seed a v1-shape prefs string with a started Gospels
   plan (a known done set + `startedOn`), load under v2:
   `progressFor` returns the identical `startedOn` and done
   SET; `planDoneCount`/`planPercent` over the resolved
   v2 Gospels plan equal the values computed over the
   run-11 plan (same chapters — assert percent equality
   explicitly against `planPercent(done ∩ chapters, 89)`);
   `planDayFor` against the NEW day count (fake: 23)
   clamps a `startedOn` 30 days back to day 23, where the
   old count would have said 30 — the runway grew, the
   checks did not move.
2. After any v2 save, the raw string's `progress` member
   deep-equals the v1 payload (no check lost in the shape
   migration itself).

### 11.4 `test/plan_detail_test.dart` (SHIPPED, translated) + new cases

Translations per §11.9 (day counts 30 → 23 on the fake
canon, today's-reading contents, status strings). New:

1. **Pace line:** not-started Gospels (fake) shows
   `About 40 verses a day` under the status; a started
   custom at days pace (fake Psalms 1–10, days 4) shows
   `About 25 verses a day` (100 verses / 4 days); a verses
   custom at 5 shows `About 5 verses a day`; T = 1 custom
   shows `About 1 verse a day`.
2. **Custom detail parity:** a custom renders the identical
   summary/schedule/toggle construction (start flow,
   toggle flow incl. semantics labels, complete state)
   with its own derived counts.
3. **Edit/Delete presence matrix:** built-in detail shows
   NO `plan-edit` / `plan-delete` in not-started, started,
   or complete states; custom detail shows both in all
   three states; `plan-restart` only when started (both
   kinds).
4. **Delete flow:** dialog props asserted like the shipped
   Restart ones (`backgroundColor == surfaceHigh`,
   `surfaceTintColor == Colors.transparent`, shape radius
   == `WwRadius.sheet`, title/body/action strings exact);
   Cancel → prefs byte-identical, still on the detail;
   confirm → store holds neither def nor progress, seq
   unchanged, the detail has POPPED (the pushing route's
   completion observed / `PlanDetailScreen` finds nothing).
5. **Edit round-trip at the detail level:** from a custom
   detail, tap `plan-edit` → `PlanEditorScreen` seeded
   (name field shows the def's name); change the name,
   save → detail shows the new name in the top bar; narrow
   the coverage so a checked chapter leaves the plan →
   percent/status recompute over the NEW coverage while
   the stored done set still CONTAINS the removed chapter
   (the intersection rule — the check is not deleted);
   widen it back → the check counts again.

### 11.5 `test/plan_editor_test.dart` (NEW, widget)

Pump `PlanEditorScreen` directly (fake canon, mock prefs):

1. **Create defaults:** title `New plan`; name empty; Daily
   amount selected (segment semantics `selected: true`);
   verses stepper shows 40; summary `0 chapters · 0 verses
   · 0 days` + BOTH reason lines; Save disabled
   (`onPressed == null` on `plan-editor-save`).
2. **Live summary:** the rendered counts line always equals
   the formatted engine output for the draft the suite
   built — the suite derives its expectation from
   `resolveCustomPlan` over that draft (§11.1 pins the
   engine itself; this suite pins that the editor SHOWS
   the engine's numbers, never its own arithmetic). One
   literal spot-fix: a Psalms 1–10 range draft at Daily
   amount 40 renders exactly `10 chapters · 100 verses ·
   3 days`; switch it to Finish in and set days 4 →
   `10 chapters · 100 verses · 4 days`.
3. **Enablement:** type a name with coverage present → Save
   enables; clear the name → disables + name reason line;
   remove all coverage → disables + coverage reason line.
4. **Steppers:** verses + taps step by 5 (40 → 45); at 200
   the increase button is disabled; at 5 the decrease is;
   days stepper max == coverage chapter count (select one
   4-chapter book → days cannot exceed 4); RE-CLAMP: set
   days 30 with the Gospels books selected (89 chapters),
   then deselect down to a 4-chapter book → days value is
   4 in the same pump, summary days == 4.
5. **Range steppers:** select Matthew, choose Chapter
   range → First 1 / Last 28; step First up to 28 max
   (== Last); step Last down to First min; save →
   stored segment `{book: 39, from: <f>, to: <l>}` exact.
6. **Create save:** name with surrounding whitespace is
   stored trimmed; prefs decode to the §4.1 v2 shape with
   the def at `custom['default'][0]`, id `custom-1`, seq
   `{'default': 1}`; the editor pops.
7. **Edit seeding + save:** seed a stored def (range
   segment, days pace); editor shows name, Finish in
   selected with the seeded days, the book selected with
   Chapter range and seeded bounds; change nothing, save →
   stored def deep-equals the seed (id, order, pace);
   the multi-segment-book seed (§6.4 bounding rule) saves
   as the single bounding segment; a carried out-of-canon
   segment seed (book 39 segment while tradition is jewish
   — construct directly: editor pumped with tradition
   jewish and a seed whose Matthew segment is unshown)
   survives a save of an unrelated edit, appended after
   the editor segments.
8. **No-save exits:** Back from a dirty create AND a dirty
   edit → prefs string byte-identical to before the pump.
9. **Canon scoping:** under jewish, no NT book row exists
   (`plan-editor-book-39` finds nothing) and Psalms' row
   does; under none, all 66 rows are reachable in the list.
10. **Geometry (360 × 800, text scale 2.0):** pump a dirty
    editor with several books selected incl. one range;
    `takeException()` null; every stepper button and
    segment renders ≥ 48 high (rendered sizes); the Save
    button's height ≥ 48; the summary counts line's rect
    lies within the summary card's rect; segment labels
    render on one line (their rects' height < 2 lines at
    scale 2.0 is NOT asserted — instead assert each
    segment's rendered height ≥ 48 and no exception, per
    §10's headroom rule).

### 11.6 `test/home_study_sections_test.dart` + `test/shell_home_study_test.dart` (SHIPPED, translated) + percent contract

HomeTab suite translations per §11.9, plus:

1. **Create tile:** with `plans: []` the `STUDY PLANS`
   header renders and the row holds ONLY the create tile
   (`plan-cover-create` present; no `plan-cover-*` plan
   keys); the tile sits AFTER the last card when plans
   exist (rendered dx ordering); tap → `onCreatePlan`
   fires exactly once; tile semantics label is
   `Create your own plan, Choose books and a pace`.
2. **Custom cards:** a `PlanCardData` over a resolved
   custom renders the custom's name, its derived caption
   (`<days> days · <total> chapters` not started), its
   cover book lines (multi-book custom ≤ 4 → all names;
   5+ books → first / `…` / last), and, started, its
   progress bar + percent caption — construction identical
   to a built-in's (assert the same keys/geometry).
3. **Order:** built-ins (in def order) precede customs (in
   creation order) precede the create tile — asserted from
   rendered dx positions of the three covers + tile.

Shell suite translations per §11.9, plus the §6.3 percent
contract end-to-end:

4. **Percent updates — detail, both directions:** start
   Gospels from Home; in the detail, check Matthew 1 →
   status shows `1%`; UNCHECK it → status shows `0%`
   (assert the exact status strings, fake canon:
   `Day 1 of 23 · 1 of 89 chapters · 1%` →
   `Day 1 of 23 · 0 of 89 chapters · 0%`).
5. **Percent updates — Home card after pop, both
   directions:** after checking in the detail and popping,
   the card caption reads `Day 1 of 23 · 1%`; re-enter,
   uncheck, pop → the card reads `Day 1 of 23 · 0%` and
   still shows the progress bar (started, 0 done); the
   card and detail percentages are the same numbers at
   every step (assert by reading both surfaces in
   sequence).
6. **Custom lifecycle at the shell level:** create via the
   tile (editor) → Home shows the custom card after the
   built-ins; open it, start, check a chapter, pop → card
   shows `Day 1 of <days> · <pct>%` with the custom's
   derived days; edit its name from the detail → card
   shows the new name; delete it from the detail → card
   gone, built-ins and the create tile remain; recreate a
   plan with the same name → its id is NOT the deleted
   id (assert via prefs: the new def's id differs) and it
   starts unchecked (no inherited progress).
7. **Custom dormancy at the shell level:** with a Matthew
   custom + progress stored, switch tradition to Jewish
   via Profiles → the custom card is absent, built-in
   Psalms & Proverbs card remains, the `ww_plans_v1`
   string is byte-identical; attempt to open the dormant
   custom is impossible (no card) — and switch back → the
   card returns with its caption/percent intact.
8. **Section with zero offered plans:** seed tradition
   jewish + no customs… jewish still offers Psalms &
   Proverbs, so zero-offered is asserted at the HomeTab
   level (§11.6.1) and, at the shell level, the create
   tile's presence is asserted in EVERY tradition.

### 11.7 `test/plans_real_data_test.dart` (NEW, pure, real data)

Loads the bundled `assets/data.json` (`BibleData.load()`
under `TestWidgetsFlutterBinding`) — the only suite that
pins production numbers:

1. Totals: Gospels 89 chapters / 3,779 verses; Psalms &
   Proverbs 181 / 3,376; Whole Bible 1,189 / 31,102.
2. Derived days: **87 / 84 / 767**.
3. Spot days (§2.3 verbatim): Gospels day 1 == `[929, 930]`,
   day 87 == `[1017]`, day 43 == `[973]` at 80 verses;
   Psalms & Proverbs day 1 == `[478, 479, 480, 481]`,
   day 49 == `[596]`, day 84 == `[658]`; Whole Bible
   day 1 == `[0]`, day 96 == `[123]` at 89 verses
   `†BLOCKING`, day 393 == `[596]`, day 767 == `[1188]`.
4. Heaviest/lightest per plan (§2.3's table), incl.
   heaviest non-Psalm-119 day == **89** `†BLOCKING`.
5. Availability matrix: the §2.2 table, all 15 cells,
   against the REAL data.
6. Old-rule contrast (documentation value): base/remainder
   peaks computed in-suite == 187 / 191 / 212 — the
   "before" numbers the founder's direction 2 rejected.

### 11.8 `test/backup_test.dart` (SHIPPED, extended)

Shipped tests stand (the absent-member path is the legacy
path — §8.3). New groups:

1. **Validator — plans member (pure):** a well-formed
   exported document WITH a plans member validates, and
   `result.plans` deep-equals the member; EACH checklist
   malformation (P1–P6, one case each minimum: non-object
   member; version 1 / `'2'` / absent; each of the three
   sub-members absent; bad `startedOn` (month 13);
   `done` with a string entry / a negative / a duplicate;
   def id `custom-0` / `plan-1`; duplicate def ids; blank
   name; empty segments; segment `from > to`; pace
   `versesPerDay: 1001`; pace mode `'weeks'`; seq `-1`)
   → `error == BackupImportError.invalidPlans`,
   `result.data == null`. A member with seq below its
   highest id suffix VALIDATES (§8.2 P6 note). Precedence:
   malformed plans + empty profiles → `invalidPlans`
   (not `emptyDocument`); valid rich plans + empty
   profiles → `emptyDocument`.
2. **Gate/parser agreement:** for a corpus of valid
   members (empty document; customs of both paces;
   unknown progress ids), `PlansDocument.fromJson(member)
   .toJson()` deep-equals the member.
3. **Malformed member writes NOTHING (widget + store):**
   seed prefs with a UserData string AND a plans string;
   run the import flow with a file whose plans member is
   malformed → error dialog shows the new sentence
   (`Nothing was changed. This backup's study plans are
   not in a form Woven Word can import.`); dismiss; BOTH
   prefs strings are BYTE-IDENTICAL to before. Repeat at
   the pure level for every P-malformation: validation is
   pure (no prefs interaction at all — assert by the same
   byte-identity after calling `validateImport`).
4. **Legacy absent-member import leaves plans untouched:**
   import the shipped `_fileJson` (no plans) with plans
   state seeded → after Replace, UserData == the file's
   model AND the plans prefs string is byte-identical.
5. **Present-member import replaces plans wholesale:**
   file with customs + progress for profile `solo` →
   after Replace, the plans prefs string ==
   `PlansStore.encodeDocument` of the file's document
   (device's prior defs/progress GONE — a pre-existing
   device-only custom id does not appear); the shell-level
   consequence is §11.6's domain (not re-tested here).
6. **Confirm dialog counts:** a file with a plans member
   (2 customs across profiles, 3 progress entries) shows
   the §8.3 present-form body with `The file also holds
   2 custom plans and 3 plans in progress.`; singular
   forms (`1 custom plan`, `1 plan in progress`) in a
   second fixture; Cancel changes nothing (both prefs
   strings byte-identical). The shipped absent-member
   confirm assertion stands verbatim.
7. **Round-trip byte-equal:** build UserData + a
   PlansStore (customs both paces, progress on a built-in
   AND a custom, seq advanced past a deletion), export via
   the Profiles flow (share seam) → the shared document
   parses with `plans` deep-equal to the store document's
   `toJson()`; import it into FRESH prefs (both keys
   empty) via the flow → the new `ww_user_data` string
   decodes deep-equal to the source model's `toJson()`
   AND the new `ww_plans_v1` string is BYTE-EQUAL to the
   source store's saved string. (Byte-equality is claimed
   for the plans PREFS strings — both are
   `encodeDocument` output — not for the pretty-printed
   file, §8.4.)
8. **Export with no plans state** still includes a `plans`
   member (the empty v2 document) — a v2 export never
   omits it; and `UserData.exportJson()` itself still
   returns the plans-less document (the model is
   untouched, §8.5).

### 11.9 Translations of shipped suites (lesson 40) + regression gate

Engine-driven translations (the scenario survives; the
numbers were the superseded model — re-seed, don't
re-assert the old claim):

- `plans_data_test.dart` distribution group: `sizes()` now
  reads RESOLVED schedules. Superseded verbatim:
  `expect(sizes('gospels'), [...List.filled(29, 3), 2]);`
  → fake-canon chapter-count sizes `[4 ×22, 1]`;
  `expect(sizes('psalms-proverbs'), [4, ...List.filled(59, 3)]);`
  → `[4 ×29, 2, 1, 4 ×15, 2]` (days 1–29 ×4, day 30 ×2,
  day 31 ×1 — Psalm 119 — then 15 days ×4 and a final ×2;
  the suite asserts this exact list); `expect(sizes(
  'whole-bible'), [...List.filled(94, 4), ...List.filled(271, 3)]);`
  → a property-plus-spots assertion rather than a
  298-element literal (a hand-typed list that long would
  be transcription, not verification), from the arithmetic
  pinned in §2.4: `expect(schedule.length, 298)`;
  `expect(schedule[149], [596])` (day 150 is Psalm 119
  alone); `expect([for (final d in schedule) d.length]
  .where((n) => n != 4).toList(), [1]);` (every other day
  holds exactly 4 chapters).
  Spot chapters, superseded verbatim:
  `expect(gospels[0], [929, 930, 931]);` → `[929, 930, 931, 932]`;
  `expect(gospels[29], [1016, 1017]);` → the Gospels
  schedule now has 23 days: `expect(gospels[22], [1017]);`;
  `expect(psalms[0], [478, 479, 480, 481]);` survives
  (day 1 is 4 chapters under both rules on the fake
  canon); `expect(psalms[59], [656, 657, 658]);` →
  `expect(psalms[46], [657, 658]);`;
  `expect(whole[93].length, 4); expect(whole[93].last, 375);`
  → `expect(whole[0], [0, 1, 2, 3]);`;
  `expect(whole[364], [1186, 1187, 1188]);` →
  `expect(whole[297], [1185, 1186, 1187, 1188]);`.
  The concatenation / no-empty / non-increasing test:
  concatenation and no-empty SURVIVE; "sizes
  non-increasing" is SUPERSEDED as a claim (it was the
  base/remainder rule's shape, not the product's) and is
  replaced by §11.1's closeness invariant (the engine
  suite owns it; this group asserts concat + no-empty +
  exact lengths 23 / 47 / 298).
- `plan_detail_test.dart`: `find.text('30 days · 89
  chapters')` → `'23 days · 89 chapters'` (two sites);
  `'Day 1 of 30 · 0 of 89 chapters · 0%'` →
  `'Day 1 of 23 · …'`; `'Day 1 of 30 · 1 of 89 chapters ·
  1%'` → 23; the current-day test: 'Day 11 of 30' →
  `'Day 11 of 23 · 0 of 89 chapters · 0%'`, and its
  expected today line `Mark 3 · Mark 4 · Mark 5` →
  `Mark 13 · Mark 14 · Mark 15 · Mark 16` (fake day 11 =
  globals 969–972, §2.4); the seeded `startedJson` prefs
  strings are V1 shape and REMAIN valid seeds (§4.3 —
  they double as migration fixtures; the suite notes it);
  the Restart test's closing `find.text('30 days · 89
  chapters')` → 23. The complete-state strings are
  count-only and survive.
- `home_study_sections_test.dart`: its hand-built
  `PlanCardData` helper re-seeds around
  `resolveBuiltinPlan(data, def(id))` (the card helper's
  `total` parameter is superseded — totals come from the
  resolved plan; started/done/day/percent remain
  parameters); `find.text('30 days · 89 chapters')` →
  `'23 days · 89 chapters'`; `find.text('Day 12 of 30 ·
  50%')` → `'Day 12 of 23 · 50%'`; geometry test's progress
  fill width assertion (`112 * 45/89`) survives (it keys
  off done/total, not days).
- `shell_home_study_test.dart`: `find.text('30 days · 89
  chapters')` → `'23 days · 89 chapters'`;
  `find.text('Day 1 of 30 · 0%')` → `'Day 1 of 23 · 0%'`;
  `find.text('Day 1 of 30 · 1%')` → `'Day 1 of 23 · 1%'`
  (three sites incl. the dormancy test, whose seeded
  `plansJson` is v1 shape and remains a valid seed,
  §11.3).
- `backup_test.dart`: all shipped assertions stand
  (§11.8's premise); the suite GAINS §11.8's groups.

**Regression gate:** `flutter analyze` clean; `flutter
test` green incl. every pre-existing suite as translated
above; `flutter build web --release` green (Maren's
verify). Baseline discipline (lesson 41): the conference
dispose race known at HEAD is reported with its baseline,
never hidden inside a "suite green" claim.

---

## 12. Files in this package

NEW:
- `lib/screens/plan_editor_screen.dart` (§6.1, §6.4)
- `test/plans_engine_test.dart`, `test/plan_editor_test.dart`,
  `test/plans_real_data_test.dart`

MODIFIED:
- `lib/data/plans.dart` — §1 engine; §2.1 defs (days
  removed, `wwBuiltinVersesPerDay`); §4 store v2
  (`PlansDocument`, `CustomPlanDef`, `PlanSegment`,
  `PlanPace`, custom mutators, `encodeDocument`;
  `encode` removed; `parse` retained); §5.1 resolution +
  `customAvailable`; §5.5 `PlanCardData` re-shape;
  §8.2 `plansBackupCounts`. `planSchedule` deleted;
  run-11's pure helpers (`planDateKey`,
  `calendarDaysBetween`, `planDayFor`, `planDoneCount`,
  `planPercent`, `planChapters`, `planAvailable`,
  `PlanProgress`) retained with shipped semantics.
- `lib/screens/plan_detail_screen.dart` — §6.2 (resolved
  plan, pace line, Edit/Delete for customs).
- `lib/screens/home_tab.dart` — §5.4/§5.5 (create tile,
  unconditional section, `onCreatePlan`, resolved cards).
- `lib/screens/shell_screen.dart` — §5.5 (resolved card
  computation, generalized `_openPlanDetail`,
  `_openPlanEditor`).
- `lib/data/user_data.dart` — §8 ONLY: `BackupImportError
  .invalidPlans`, `BackupImportResult.plans`,
  `validateImport`'s plans checklist. The `UserData` model
  and document are untouched.
- `lib/screens/profiles_screen.dart` — §8.3/§8.4 (plans
  load for export/import, document assembly, confirm
  counts sentence, error sentence arm).
- `test/plans_data_test.dart`, `test/plan_detail_test.dart`,
  `test/home_study_sections_test.dart`,
  `test/shell_home_study_test.dart`, `test/backup_test.dart`
  — §11.2–§11.9 translations and new groups.

UNTOUCHED (explicit): `lib/theme/ww_theme.dart` (no token,
role, or type changes — §9.4); Verse of the Day, Study
Tools, All Highlights surfaces and their suites except as
§11.9 lists; `verse_of_day*.dart`, `arc_*` (sibling
packages); the Library search files; tradition layers.
Deuterocanon books stay out of plan coverage (§5.3,
§6.4.11: the editor's book list is `BibleData` books only).

— Petra, Design Auditor & QC, Study Plans V2 desk.
Filed as the binding spec per lesson 23/28: a brief that
paraphrases this file loses to this file. The BLOCKING
NOTE at the top is part of this spec: §2.3/§11.7's
`†BLOCKING` values are my computed figures, pending
Silas's ruling on the brief's heaviest-other-day claim.
