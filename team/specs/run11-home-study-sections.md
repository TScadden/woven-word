# PETRA — DESIGN SPEC, BOARD RUN 11: HOME STUDY SECTIONS (BINDING)

**From:** Petra, Design Auditor & QC
**To:** Maren, Lead Flutter Engineer (verbatim handoff, via Silas)
**Scope:** three new Home sections in the Home scroll area —
(1) Verse of the Day, (2) Study Plans (three canon-generated
plans, a plan detail screen, a plans store outside `UserData`),
(3) Study Tools (My Notes / Highlights / Profiles) plus the NEW
All Highlights screen. The standing `STUDY` / My Notes place-row
is retired into Study Tools. Nothing else.

**Authorities:** TEAM.md; LESSONS.md (esp. #13 role-split tokens,
#16 audit every state/surface, #17 the surface matrix and
non-color cues, #18 both bounds, #19 profiles are a store
concern, #20 presentation defaults set explicitly, #22
validation in front of the parser, #23 specs persist as files,
#30 geometry asserted from rendered positions, #37 control
counts are a layout budget at 360dp); the design law
(tabs-design-audit, Woven Word adaptation: `ww_theme.dart` tokens
only, explicit type scale, 8dp grid, 16dp margins, 48dp targets,
WCAG contrast computed from tokens, closed radius scale,
reduced motion renders final states); the founder request of
Oct 15, 2026 (below); producer decisions for run 11 (§0.2,
binding, encoded verbatim in substance).

**Research:** the founder's three Gospel Library Home
screenshots (`feedback/gl-home-1-20261015.png`,
`gl-home-2-20261015.png`, `gl-home-3-20261015.png`), studied
2026-10-15. Patterns adapted — GL artwork, branding, covers,
and content are NEVER copied:
- Study Plans (screenshot 1): section header + horizontal row
  of cover-style cards, title under each cover, a slim progress
  bar across the cover's bottom edge.
- Study Tools (screenshot 2): section header + a row of
  icon-over-label entries.
- Verse of the Day (screenshot 3): full-width card, small
  section label top-left, verse text large in serif, reference
  under it in a muted role.
The section names "Study Plans", "Study Tools", and "Verse of
the Day" are the founder's own words for these features. Every
cover in this spec is typographic in our tokens (no artwork);
the verse is our own data's most-connected verse; the tools are
our own three functions.

**Method note:** every ratio in §9 I computed from token hexes
by the audit §2 method (alpha composited to opaque first, sRGB
linearized, ratio `(Llight + 0.05) / (Ldark + 0.05)`).
Thresholds: normal text ≥ 4.5:1; large text (≥24sp, or ≥19sp
bold) ≥ 3.0:1; meaningful icons and control boundaries ≥ 3.0:1.
**New tokens: none. New colors: none. New radii: none. New
durations: none. New `WwType` roles: exactly three (§8).**

---

## 0. Founder request and producer decisions

### 0.1 Founder request (Tyson, Oct 15, 2026), verbatim

> "I like the study plan, study tools, and verse of the day
> things on the home screen of the gospel library app. Can we
> have something like it on our home screen?"

### 0.2 Producer decisions (binding; substance verbatim)

1. **ORDER** in the Home scroll area: Continue reading →
   Verse of the Day → Study Plans → Study Tools. The standing
   `STUDY` / My Notes place-row is RETIRED into Study Tools
   (one door to My Notes, still one tap from Home). The
   selection panel is untouched.
2. **VERSE OF THE DAY:** pool = the 365 verses with the highest
   connection count in the app's own data
   (`BibleData.verseConnections(ch, v).length`), ties broken by
   canonical order (chapter asc, verse asc), restricted to
   chapters inside the active tradition's canon
   (`tradition.dart` `CanonView` / `canonContainsBook`). Verse
   for a date = `pool[daysSinceEpoch(local date) %
   pool.length]` — same verse all day, no repeat within
   `pool.length` days; if a canon yields a smaller pool the
   window shrinks to the pool size, never an error. Text = the
   reader's active translation for that book (same resolution
   the reader uses), full verse text, no truncation, no
   summaries. Card shows: `VERSE OF THE DAY` label, verse text
   (serif), reference, and the verse's connection count as a
   caption (`716 connections` style — real data, our identity).
   Whole card is the tap target → opens the reader at that
   chapter/verse via the My Notes path.
   *Supersession note: the pool rule in this decision is replaced in full by `team/specs/verse-of-day-quotable.md` (founder ruling, Oct 15, 2026); the card, the pick, and the tap routing stand.*
3. **STUDY PLANS** — exactly three, generated from canon data,
   ids/names/day counts fixed: `gospels` "The Gospels"
   (Matthew–John, 89 chapters, 30 days), `psalms-proverbs`
   "Psalms & Proverbs" (181 chapters, 60 days), `whole-bible`
   "The Whole Bible" (1,189 chapters, 365 days). Schedule = the
   plan's chapter list (canonical order) split into consecutive
   day chunks (ceil division, earlier days take the remainder —
   the exact distribution rule is pinned in §4.2). A plan is
   OFFERED only when every book in its definition is inside the
   active tradition's canon. State lives OUTSIDE `UserData`
   (backup format untouched): SharedPreferences key
   `ww_plans_v1`, JSON `{profileId: {planId: {startedOn:
   'yyyy-mm-dd', done: [global chapter indices]}}}`, defensive
   load (bad data → empty state). Per profile. Start = explicit
   `Start plan` on the plan detail screen; current day =
   `clamp(localToday − startedOn + 1, 1, days)`. Completion
   mechanism (the one stated mechanism): per-chapter check
   toggle (≥48dp) on the plan detail screen; tapping a
   chapter's label opens it in the reader. Progress = done
   chapters / total chapters, shown as the bar + percent. Plan
   detail also carries `Restart plan` with an explicit confirm
   dialog (lesson 20: surface, radius, field styling, reduced
   motion all set explicitly). Switching tradition never
   mutates plan state — an out-of-canon plan is simply not
   offered (dormancy, run 10 pattern).
4. **STUDY TOOLS:** header `STUDY TOOLS` in the shipped
   section-header role. Exactly three entries, icon over label,
   each ≥48dp: `My Notes` (caption: active-profile +
   active-translation note count, shipped copy style
   `No notes yet` / `1 note` / `N notes`), `Highlights`
   (caption: span count for active profile + active
   translation, same copy pattern), `Profiles` (caption: active
   profile name). Entries push `MyNotesScreen`, the NEW All
   Highlights screen, and `ProfilesScreen` on `homeNavKey`.
5. **ALL HIGHLIGHTS screen:** title `All Highlights`. Every
   span of the active profile in the active translation (store
   v3 `ProfileData.spans[translationKey]`), grouped by book in
   the active tradition's canon order, chapter subheads, spans
   ordered by verse then start offset. Visibility = run 10
   rule: a span shows only when its book is in the active canon
   (deuterocanon spans appear under Catholic, routed to the
   deuterocanon reader on tap, exactly like My Notes). Row:
   tint swatch in the span's highlight color, reference label,
   highlighted text on one line with ellipsis (the span's
   anchor; for full-verse spans, the verse text in the active
   translation). Tap → reader at that verse. Empty state
   mirrors My Notes' empty-state pattern with copy that teaches
   the gesture (`No highlights yet in <translation>` +
   long-press guidance — exact strings pinned in §2.4).

### 0.3 Interpretations pinned by this spec (producer to note)

These are the points where the decisions needed one reading
chosen. Each is flagged again in the run report to Silas.

- **I-1 Selection panel position.** "Untouched" (§0.2.1) is
  read strictly: the panel keeps its current slot — directly
  after Continue reading, before Verse of the Day — with its
  content, construction, and behavior byte-for-byte as shipped.
  The §0.2.1 order governs the four named sections.
- **I-2 Schedule distribution.** §4.2 pins the base/remainder
  distribution. A literal fixed chunk size of `ceil(total /
  days)` leaves trailing days EMPTY for two of the three plans
  (evidence in §4.2), which contradicts the stated day counts;
  base/remainder is the only distribution satisfying "earlier
  days take the remainder", the fixed day counts, and
  no-empty-days simultaneously.
- **I-3 Tools My Notes caption count.** The caption carries the
  count the shipped Home already computes (run 10): notes of
  the active profile in the active translation that are
  VISIBLE under canon dormancy — i.e. exactly what My Notes
  would show. A raw stored count would contradict run-10
  dormancy and the shipped card it replaces.
- **I-4 All Highlights empty branches.** §6.3 pins two
  branches. The producer's `No highlights yet in <translation>`
  title governs the branch where the active translation's set
  is empty; a second branch (set non-empty, every span
  canon-dormant) mirrors My Notes' "none to show here" branch.

---

## 1. Home scroll area — order and structure

`HomeTab._scrollArea` (lib/screens/home_tab.dart) builds, in
order, with exactly these spacings (8dp grid, audit §5; the
shipped 16dp section rhythm is retained):

| # | Child | Preceding gap |
|---|---|---|
| 1 | Continue reading place-row (as shipped) | ListView top padding 16 |
| 2 | Selection panel — ONLY when `selection != null`, as shipped, unmoved (I-1) | 16 |
| 3 | Verse of the Day card — only when `verseOfDay != null` (§3) | 16 |
| 4 | Study Plans section — only when `plans` is non-empty (§4.4) | 16 |
| 5 | Study Tools section (§5) | 16 |
| — | Bottom padding | 24 after last child |

- The retired `_studySection()` and its `STUDY` header are
  deleted. `My Notes` appears on Home exactly once after this
  run: the Study Tools entry. (The top-bar profile avatar still
  opens Profiles, as shipped — it is not a My Notes door and
  §0.2.4 gives Profiles a second entrance, the Tools entry;
  both call the same shell method, §7.)
- All three new sections sit at the shipped 16dp screen margin
  (`WwSpace.screenMargin`), matching the place-row's left edge.
- No new animation anywhere in this run. Section content
  renders its final state directly (reduced-motion rule is
  satisfied trivially); pushes use `WwPageRoute` (§8.3).

---

## 2. Copy register — every new string, exact

No string outside this register may appear on a new surface.
`<…>` marks a runtime substitution. Counts use comma grouping
(the shipped `HomeTab._fmt`: `1,189`, never `1189`).

### 2.1 Verse of the Day card

| Element | String |
|---|---|
| Label | `VERSE OF THE DAY` |
| Verse text | the full verse text (§3.2) — data, not copy |
| Reference | `data.refName(ch, v)`, e.g. `Isaiah 61:10` — data |
| Count caption, count = 1 | `1 connection` |
| Count caption, count ≠ 1 | `<fmt(count)> connections` |
| Text still loading (§3.3) | `Loading today's verse…` |
| Text failed / empty (§3.3) | `Today's verse text could not be loaded.` |

The apostrophes above are the ASCII `'` exactly as written
(shipped copy style: `Loading your notes…`).

### 2.2 Study Plans — Home cards

| Element | String |
|---|---|
| Section header | `STUDY PLANS` |
| Card title | the plan name: `The Gospels` / `Psalms & Proverbs` / `The Whole Bible` (from the definition, §4.1) |
| Cover book lines | the plan's book names from `BibleData` (§4.4) — data |
| Cover meta line | `<total> chapters`, e.g. `89 chapters` |
| Caption, not started | `<days> days · <total> chapters`, e.g. `30 days · 89 chapters` |
| Caption, started, not complete | `Day <currentDay> of <days> · <pct>%` |
| Caption, complete | `Complete · 100%` |

`<pct>` is `planPercent` (§4.3): integer floor,
`(doneCounted * 100) ~/ total`. The separator is ` · `
(space, middle dot U+00B7, space), the shipped style.

### 2.3 Study Plans — plan detail screen

| Element | String |
|---|---|
| Top-bar title | the plan name (from the definition) |
| Loading | `Loading plan…` |
| Status, not started | `<days> days · <total> chapters` |
| Status, started, not complete | `Day <currentDay> of <days> · <done> of <total> chapters · <pct>%` |
| Status, complete | `Complete · <total> of <total> chapters · 100%` |
| Today's-reading label (started, not complete) | `TODAY'S READING` |
| Today's-reading line | the current day's chapter names joined by ` · `, e.g. `Matthew 1 · Matthew 2 · Matthew 3` — data |
| Complete line (replaces today's reading) | `You have read every chapter in this plan.` |
| Start button | `Start plan` |
| Day subhead | `Day <n>` (1-based) |
| Chapter row label | `data.chapterName(globalChapter)`, e.g. `Matthew 1` — data |
| Toggle semantics label, unchecked | `Mark <chapterName> as read` |
| Toggle semantics label, checked | `Mark <chapterName> as not read` |
| Restart button | `Restart plan` |
| Restart dialog title | `Restart <plan name>?` |
| Restart dialog body | `Your check marks for this plan will be cleared, and the plan will return to not started. Your highlights and notes are not affected.` |
| Restart dialog actions | `Cancel` / `Restart` |

### 2.4 Study Tools and All Highlights

| Element | String |
|---|---|
| Section header | `STUDY TOOLS` |
| Tool labels | `My Notes` / `Highlights` / `Profiles` |
| Notes caption, 0 | `No notes yet` |
| Notes caption, 1 | `1 note` |
| Notes caption, n | `<n> notes` |
| Highlights caption, 0 | `No highlights yet` |
| Highlights caption, 1 | `1 highlight` |
| Highlights caption, n | `<n> highlights` |
| Profiles caption | the active profile's display name, verbatim |
| All Highlights top-bar title | `All Highlights` |
| All Highlights loading | `Loading your highlights…` |
| All Highlights header line | `Highlights in <profile name> · <translation label>` |
| Chapter subhead | `Chapter <chapterInBook>` |
| Empty A title (§6.3 branch 1) | `No highlights yet in <translation label>` |
| Empty A body | `While reading, long-press a verse, then choose a color to highlight it. Highlights for <profile name> will gather here.` |
| Empty B title (§6.3 branch 2) | `No highlights to show here` |
| Empty B body | `These highlights are for books outside your current tradition's canon. They are kept and return when you switch back.` |

`<translation label>` is `WwTranslation.label` (`KJV`, `WEB`,
`JPS`, `Hebrew`, `WEBC`) — the same label My Notes' header line
uses. `<n>` in tool captions is the plain integer (no comma
grouping; counts here are the user's own spans/notes and the
shipped notes caption never grouped).

---

## 3. Verse of the Day

### 3.1 Pure functions — `lib/data/verse_of_day.dart` (NEW)

All functions in this file are pure and unit-testable without
widgets, `SharedPreferences`, or the asset bundle.

```dart
class VerseOfDayPick {
  final int chapter;        // global chapter index
  final int verse;          // 1-based verse in the chapter
  final int connectionCount;
  // == and hashCode over all three fields.
}

int daysSinceEpochLocal(DateTime localDate);

List<VerseOfDayPick> buildVerseOfDayPool(
  BibleData data,
  WwTradition tradition, {
  int poolSize = 365,
});

VerseOfDayPick? verseOfDayFromPool(
  List<VerseOfDayPick> pool,
  DateTime localDate,
);

VerseOfDayPick? verseOfDayForDate(
  BibleData data,
  WwTradition tradition,
  DateTime localDate,
);

WwTranslation translationForVerseOfDay({
  required WwTranslation stored,
  required WwTradition tradition,
  required bool otBook,
  required bool Function(WwTranslation) hasTranslation,
});

class VerseOfDayCardData {
  final int chapter;
  final int verse;
  final String reference;
  final int connectionCount;
  final String? text;          // null = still loading (§3.3)
  final WwTranslation translation;
}
```

Semantics, pinned:

- `daysSinceEpochLocal` uses the date's LOCAL components
  resolved through UTC midnights, so DST can never shift the
  count: `DateTime.utc(d.year, d.month, d.day)
  .difference(DateTime.utc(1970, 1, 1)).inDays`. Time-of-day
  is ignored: every moment of one local date yields the same
  value (the "same verse all day" guarantee).
- `buildVerseOfDayPool` enumerates every verse of every
  chapter whose BOOK satisfies `canonContainsBook(tradition,
  data, bookIndex)`. Canon membership is book-level
  (`canonContainsBook` defers to `CanonView`); every chapter
  of a contained book is contained. Deuterocanon books are
  never enumerated: they are not in `BibleData.chapters` and
  carry no connection data.
- A verse's count IS `data.verseConnections(ch, v).length`
  (§0.2.2). Implementation: the builder MAY count distinct
  targets directly from `data.verseConnsByPos[data.versePos
  (ch, v)]` (a `Set` of `targetChapter * 1000 + targetVerse`)
  instead of materializing the sorted deduped list —
  `verseConnections` dedupes by exactly that key, so the two
  counts are identical by construction. The test suite asserts
  the equality on sampled verses (§11.1). It may NOT count raw
  ref rows (undeduped) — that is a different number.
- Sort: count DESC, then global chapter ASC, then verse ASC
  (the producer's canonical-order tie-break). Truncate to
  `poolSize`. When the canon holds fewer than `poolSize`
  verses the pool is every verse (0-count verses included,
  in canonical order at the tail) — the pool is the top
  `min(poolSize, totalVersesInCanon)`, never an error.
- `verseOfDayFromPool`: empty pool → `null`; otherwise
  `pool[daysSinceEpochLocal(date) % pool.length]`. Dart's `%`
  on a positive divisor is non-negative, so pre-epoch dates
  are safe. No repeat within `pool.length` consecutive days
  follows from the modulo over a fixed pool.
- `verseOfDayForDate` = `verseOfDayFromPool(buildVerseOfDay
  Pool(data, tradition), date)`. Callers that rebuild often
  (the shell) cache the pool (§7) and call
  `verseOfDayFromPool` directly.
- `translationForVerseOfDay` reproduces the reader's
  resolution EXACTLY (reader_screen.dart `_availableTranslations`
  + `_effT`): `available = translationsFor(tradition, otBook:
  otBook).where(hasTranslation)`; return `stored` when
  `available` contains it, else `WwTranslation.kjv`. The
  reader itself is NOT refactored in this run; §11.1 pins the
  equivalence cases so the two cannot silently drift.

### 3.2 Text resolution

The card's text is `ScriptureText.verseText(effective, data,
ch, v)` where `effective = translationForVerseOfDay(stored:
shell.translation, tradition: shell.tradition, otBook:
data.chapters[ch].b < 39, hasTranslation: texts.hasTranslation)`.
Full verse text, no truncation, no ellipsis, no summary.
`ScriptureText`'s own per-chapter KJV fallback applies as
shipped. When `effective.isRtl` (Hebrew), the verse text
renders with `TextDirection.rtl`, exactly as the reader does.
*Supersession note: the pool whose text this section resolves is now defined by `team/specs/verse-of-day-quotable.md`; this section's text resolution is unchanged.*

### 3.3 Shell computation and the loading/failure branches

The shell (§7) owns a memoized `Future<ScriptureText>`
(`textsLoader ?? ScriptureText.load`, the seam `WwShell`
already accepts). On resolve it stores the `ScriptureText`
and calls `notifyListeners()`; on error it records failure
and notifies. `_homeRoot` computes the `VerseOfDayCardData`:

- `data == null` → the scroll area is not built at all
  (shipped behavior), so no card state is needed.
- Pick is `null` (degenerate empty canon) → `verseOfDay`
  prop is `null` → no card.
- Texts not yet resolved → `text == null` → the card renders
  label, reference, and count as usual, with the loading
  string (§2.1) in the verse-text slot (`WwType.captionOnDark`).
  The card is already fully tappable in this state.
- Texts failed, OR resolved text is the empty string →
  `text == ''` → the card renders the failure string (§2.1)
  in the verse-text slot (`WwType.captionOnDark`). A real
  in-canon verse with the KJV fallback never resolves to `''`
  in production data, so `''` unambiguously means failure.
- Otherwise `text` is the verse text (§3.2).

The pick is recomputed on every shell build from
`DateTime.now()` (local). An app left open across midnight
shows the new verse at the next shell rebuild/notification;
no timer is added in this run (pinned, known behavior).

### 3.4 Card construction (HomeTab)

- `Padding(horizontal: 16)` → `Material(color: surface,
  borderRadius: row 10)` → `InkWell(borderRadius: row 10,
  onTap: onOpenVerseOfDay(chapter, verse))` → `Container(
  padding: all 16, width: double.infinity)`.
- `ValueKey('votd-card')` on the `Material`.
- Column, `crossAxisAlignment: start`:
  1. `Text('VERSE OF THE DAY', style: appSubtitle)`.
  2. Gap 8.
  3. Verse text: `Text(text, style: verseOfDayBody)` (§8) —
     or the loading/failure string in `captionOnDark` (§3.3).
     No `maxLines`, no overflow — the full verse always shows.
  4. Gap 8.
  5. `Text(reference, style: refLabelOnDark)`.
  6. Gap 4.
  7. `Text(countCaption, style: captionOnDark)`.
- The whole card is the one tap target; its height is
  content-driven and always ≥ 48dp by construction (label +
  one text line + reference + caption + 32dp padding already
  exceeds it). No inner tappable children.
- Semantics: the InkWell's merged node must read the
  reference; give the card `Semantics(container: true, button:
  true, label: 'Verse of the Day, <reference>')` wrapping the
  InkWell with inner semantics excluded — the lesson-25
  pattern, so the label does not merge upward.

---

## 4. Study Plans

### 4.1 Definitions and availability — `lib/data/plans.dart` (NEW)

```dart
class StudyPlanDef {
  final String id;
  final String name;
  final int days;
  final List<int>? bookIndices; // null = every book in the data
}

const List<StudyPlanDef> wwStudyPlans = [
  StudyPlanDef(id: 'gospels', name: 'The Gospels', days: 30,
      bookIndices: [39, 40, 41, 42]),
  StudyPlanDef(id: 'psalms-proverbs', name: 'Psalms & Proverbs',
      days: 60, bookIndices: [18, 19]),
  StudyPlanDef(id: 'whole-bible', name: 'The Whole Bible',
      days: 365, bookIndices: null),
];

List<int> planChapters(BibleData data, StudyPlanDef plan);
bool planAvailable(StudyPlanDef plan, WwTradition tradition,
    BibleData data);
```

- `planChapters`: the plan's books in definition order (for
  `whole-bible`, every book in `BibleData` order), each book's
  chapters expanded to global indices via `book.start`, in
  canonical (BibleData) order. Presentation order (e.g. the
  Tanakh's Ketuvim order) NEVER reorders a plan — §0.2.3 says
  canonical order. Totals against the real canon: Gospels
  28 + 16 + 24 + 21 = **89**; Psalms & Proverbs 150 + 31 =
  **181**; Whole Bible **1,189**. Totals are DERIVED from
  `BibleData`, never hard-coded in widget code.
- `planAvailable`: true iff EVERY book in the definition
  satisfies `canonContainsBook(tradition, data, bookIndex)`.
  For `whole-bible` that is every book in the data.
- Availability matrix (asserted in §11.2):

| Tradition | gospels | psalms-proverbs | whole-bible |
|---|---|---|---|
| none (Bible only) | ✓ | ✓ | ✓ |
| lds | ✓ | ✓ | ✓ |
| protestant | ✓ | ✓ | ✓ |
| catholic | ✓ | ✓ | ✓ |
| jewish | ✗ (NT not in Tanakh) | ✓ (both in Ketuvim) | ✗ (includes NT) |

### 4.2 Schedule — the exact distribution rule

```dart
List<List<int>> planSchedule(BibleData data, StudyPlanDef plan);
```

Let `T = planChapters(...).length`, `D = plan.days`,
`base = T ~/ D`, `rem = T % D`. Day `i` (1-based) receives
`base + 1` chapters when `i <= rem`, else `base` chapters,
taken consecutively from the chapter list in order. Day sizes
differ by at most 1, earlier days are never smaller than
later days, no day is empty (every plan here has `T > D`),
and concatenating the days reproduces `planChapters` exactly.

Exact distributions (asserted verbatim in §11.2):

| Plan | T | D | base | rem | Day sizes |
|---|---|---|---|---|---|
| The Gospels | 89 | 30 | 2 | 29 | days 1–29: 3; day 30: 2 |
| Psalms & Proverbs | 181 | 60 | 3 | 1 | day 1: 4; days 2–60: 3 |
| The Whole Bible | 1,189 | 365 | 3 | 94 | days 1–94: 4; days 95–365: 3 |

**Why not a fixed `ceil` chunk (I-2 evidence):** chunking by
`ceil(T / D)` gives chunk 4 for Psalms & Proverbs — the last
chapter lands on day `ceil(181 / 4) = 46`, leaving days
47–60 with nothing to read; and chunk 4 for the Whole Bible
ends on day 298, leaving 67 empty days. A "60-day plan" with
14 empty days is not buildable as stated; the base/remainder
rule above is the distribution the producer's "earlier days
take the remainder" describes, and it coincides with the
ceil reading on the one plan where that reading works
(Gospels: 29 × 3 + 2).

### 4.3 Progress arithmetic — pure helpers in `plans.dart`

```dart
String planDateKey(DateTime local);          // 'yyyy-mm-dd'
int calendarDaysBetween(DateTime fromLocal, DateTime toLocal);
int planDayFor({required String startedOn,
    required DateTime today, required int days});
int planDoneCount(PlanProgress? progress, List<int> chapters);
int planPercent(int done, int total);
```

- `planDateKey`: zero-padded `yyyy-mm-dd` from the LOCAL
  components (`2026-10-05`, never `2026-10-5`).
- `calendarDaysBetween`: the same UTC-midnight method as
  `daysSinceEpochLocal` applied to both ends — a calendar-day
  difference, immune to DST.
- `planDayFor`: parse `startedOn` (a valid key per §4.5's
  defensive rules; an unparseable value yields 1), then
  `clamp(calendarDaysBetween(start, today) + 1, 1, days)` —
  the producer's formula. A `startedOn` in the future
  (clock skew) yields day 1.
- `planDoneCount`: `progress.done ∩ chapters` — the
  intersection is counted, never the raw set, so a corrupt
  store can never push progress past 100% or count another
  plan's chapters.
- `planPercent(done, total)`: `total == 0 ? 0 : (done * 100)
  ~/ total` (integer floor; the same value on the card, in
  the detail status, and in tests).

### 4.4 Home plan cards

Section construction:

- Header: `Padding(horizontal: 16)` → `Text('STUDY PLANS',
  style: appSubtitle)` — the shipped section-header role,
  same as the retired `STUDY` header and the new `STUDY
  TOOLS` header.
- Gap 16 (the shipped header-to-content rhythm).
- Horizontal row: `SingleChildScrollView(scrollDirection:
  horizontal, padding: horizontal 16)` → `IntrinsicHeight` →
  `Row(crossAxisAlignment: stretch)` of plan cards with 12dp
  gaps between them. The `IntrinsicHeight` construction is
  REQUIRED (not an implementation suggestion): it makes the
  row's height the tallest card's intrinsic height, so card
  text at text scale 2.0 grows the row instead of overflowing
  a fixed height (§10, §11.5).
- Cards render in `wwStudyPlans` definition order, filtered
  to offered plans (the shell passes only offered plans, §7).
  If NO plan is offered the whole section — header included —
  is omitted (§1). (With the shipped canon this happens for
  no tradition; Jewish still offers one plan.)

One card (width **112dp**, fixed):

- `Material(color: transparent)` → `InkWell(borderRadius:
  row 10, onTap: onOpenPlan(def.id))` → `SizedBox(width:
  112)` → Column, `crossAxisAlignment: start`:
  1. **Cover** — `ValueKey('plan-cover-<id>')`, 112 × 144dp,
     `Container` decoration: `color: surfaceHigh`,
     `border: Border.all(borderDark, 1)`, `borderRadius:
     row 10`, clipped so the progress bar (§4.4 last item)
     sits inside the bottom edge. Inside, `Padding(all 12)`
     → Column, `crossAxisAlignment: start`:
     - Gold rule: `Container(width: 24, height: 2, color:
       gold)` — a decorative accent (audited §9 as a graphic).
     - Gap 8.
     - Book lines: one `Text` per line, `style:
       planCoverBook` (§8), each `maxLines: 1`, ellipsis.
       Lines are DERIVED: a plan with ≤ 4 books lists every
       book name in definition order (Gospels: `Matthew`,
       `Mark`, `Luke`, `John`; Psalms & Proverbs: `Psalms`,
       `Proverbs`); the whole-Bible plan lists the first
       book's name, the single line `…`, and the last book's
       name (`Genesis`, `…`, `Revelation`).
     - `Spacer` equivalent (an `Expanded` empty box).
     - Meta line: `Text('<total> chapters', style:
       planCoverMeta)`.
     - The cover is typographic only: no images, no artwork,
       no gradients (audit §4: depth from surface steps,
       never gradients).
  2. Gap 8.
  3. Title: `Text(def.name, style: controlLabel.copyWith(
     fontWeight: w600), maxLines: 2, overflow: ellipsis)` —
     the shipped place-row title construction.
  4. Gap 2.
  5. Caption: `Text(caption, style: captionOnDark,
     maxLines: 2, overflow: ellipsis)` with the §2.2 strings.
  6. **Progress bar** — present ONLY when the plan is started
     (a not-started plan shows no track: an empty track would
     be a meaningless graphic). `ValueKey('plan-progress-
     <id>')` on the bar's outer box. Construction: `Stack`
     over the cover's bottom edge — `Positioned(left: 0,
     right: 0, bottom: 0, height: 4)` inside the cover's
     clipped area: track `Container(color: borderDark)`,
     fill `Container(width: 112 * doneCounted / total,
     color: goldBright)`, the fill's outer corner rounded
     with the cover's bottom corners (the cover clip handles
     this). Height exactly 4dp; no `LinearProgressIndicator`
     (its min height, animation, and semantics are all wrong
     here — this is a static graphic whose value is carried
     redundantly by the percent caption, §9 note).
- The whole card is one tap target (≥ 48dp in both axes by
  construction: 112 wide, cover alone 144 tall). No inner
  tappable children.
- Semantics: `Semantics(container: true, button: true,
  label: '<plan name>, <caption>')` around the InkWell,
  inner semantics excluded (lesson 25).
- A complete plan (`doneCounted == total`) shows the full-
  width fill and the `Complete · 100%` caption. Nothing else
  changes — no badge, no check overlay (one representation
  of state, carried by bar + text together).

### 4.5 PlansStore — `lib/data/plans.dart`

State lives OUTSIDE `UserData`; `user_data.dart` is not
modified and the backup format is untouched (§12).

```dart
const String plansPrefsKey = 'ww_plans_v1';

class PlanProgress {
  final String startedOn;   // 'yyyy-mm-dd'
  final Set<int> done;      // global chapter indices
  // == / hashCode; Map<String, dynamic> toJson();
}

class PlansStore {
  PlansStore._(this._prefs, this.state);
  final Map<String, Map<String, PlanProgress>> state;

  static Future<PlansStore> load(SharedPreferences prefs);
  static Map<String, Map<String, PlanProgress>> parse(String? raw);
  static String encode(Map<String, Map<String, PlanProgress>> state);

  PlanProgress? progressFor(String profileId, String planId);
  void startPlan(String profileId, String planId, DateTime today);
  void toggleChapter(String profileId, String planId, int globalChapter);
  void restartPlan(String profileId, String planId);
  Future<void> save();
}
```

- **Storage:** one SharedPreferences string under
  `plansPrefsKey`, whose JSON is EXACTLY
  `{profileId: {planId: {"startedOn": "yyyy-mm-dd", "done":
  [int, …]}}}`. `encode` writes `done` sorted ascending and
  omits empty parent maps (a profile whose last plan is
  restarted away disappears from the JSON).
- **Defensive load** (`parse`, lesson 18/22 discipline —
  every rule below is a test case in §11.2):
  - `raw == null`, undecodable JSON, or a non-object root →
    empty state.
  - A profile value that is not an object → that profile is
    dropped; other profiles survive.
  - A plan value that is not an object → that plan dropped.
  - `startedOn` not a string matching `^\d{4}-\d{2}-\d{2}$`,
    or not a real calendar date (month 13, Feb 30 — verified
    by parsing and re-formatting to the identical string) →
    that plan dropped.
  - `done` not a list → that plan dropped. Entries that are
    not integers, or are negative → those ENTRIES dropped;
    duplicates collapse (it is a set). Non-negative integers
    beyond the canon are KEPT in state (they may belong to a
    plan not currently offered; counting always intersects,
    §4.3) but can never be produced by the UI.
  - Unknown plan ids and unknown profile ids are PRESERVED
    verbatim through a load/save cycle (forward compatibility;
    display and counting filter by known definitions).
  - `parse` never throws.
- **Mutators** are synchronous and in-memory; persistence is
  `save()` (the UI calls it fire-and-forget with a catch
  after each mutation — the Profiles `_persist` pattern, so
  the visible change never waits on disk):
  - `startPlan`: no-op when an entry already exists (the
    button that calls it is only shown pre-start). Otherwise
    creates `{startedOn: planDateKey(today), done: {}}`.
  - `toggleChapter`: no-op when no entry exists. Adds the
    chapter when absent, removes it when present.
  - `restartPlan`: removes the entry entirely (and prunes
    the now-empty profile map).
- **Ownership:** following the shipped pattern (My Notes,
  Profiles, and the reader each load their own `UserDataStore`),
  the plan detail screen loads its OWN `PlansStore` instance;
  the shell loads a snapshot for the Home cards (§7) and
  reloads it when the detail screen pops. The two never
  coexist as writers: the detail is topmost while open, and
  Home's snapshot is refreshed on pop before it is read again.

### 4.6 Plan detail screen — `lib/screens/plan_detail_screen.dart` (NEW)

Constructor contract:

```dart
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.data,          // BibleData
    required this.plan,          // StudyPlanDef
    required this.profileId,     // active profile at push time
    required this.onOpenChapter, // void Function(int globalChapter)
    this.now,                    // DateTime Function()? — test seam
  });
}
```

`now` defaults to `DateTime.now`; tests inject a fixed clock
(the `textsLoader` seam pattern). The screen loads its
`PlansStore` in `initState` (loading state §2.3 until loaded).

Construction (mirrors My Notes' screen skeleton):

- `Scaffold(backgroundColor: stage)` → `SafeArea` → Column:
  top bar, then `Expanded(ListView)`.
- Top bar: the shipped pattern (`Container(minHeight: 56,
  color: nav, bottom border borderDarkSoft, padding
  horizontal 16)`): Back `IconButton` (tooltip `Back`, 48dp,
  `Icons.arrow_back` in `navInk`), gap 8, `Text(plan.name,
  style: screenTitle)`.
- ListView `padding: all 16`, children in order:
  1. **Summary card** — `Material(color: surface,
     borderRadius: row 10)` → `Container(padding: all 16)` →
     Column (start-aligned):
     - Status line (§2.3 strings) in `bodyOnDark`.
     - When started: gap 8, then the progress bar — full
       card-content width, height 4, track `borderDark`,
       fill `goldBright` at `doneCounted / total`, corners
       fully round (pill, radius 2 = height/2; the audit's
       sanctioned fully-round exception). Same construction
       as the cover bar (§4.4), no `LinearProgressIndicator`.
     - When started and not complete: gap 8,
       `Text('TODAY'S READING', style: appSubtitle)`, gap 4,
       today's-reading line in `bodyOnDark`.
     - When complete: gap 8, the complete line (§2.3) in
       `bodyOnDark`.
     - When not started: gap 16, the Start button —
       `ElevatedButton` in the shipped selection-panel
       construction (`backgroundColor: goldBright`,
       `foregroundColor: onGold`, `minimumSize:
       Size.fromHeight(48)`, shape radius `chip` 12,
       `Text('Start plan', style: goldButtonLabel)`),
       `ValueKey('plan-start')`. Tapping it calls
       `startPlan(profileId, plan.id, now())`, persists, and
       rebuilds — the schedule's toggles appear (§4.6 last
       items) and the status becomes the started form.
  2. Gap 16.
  3. **Schedule** — for each day `1..days`: a day subhead
     `Text('Day <n>', style: controlLabel.copyWith(
     fontWeight: w600))`, gap 8, then that day's chapter
     rows with 8dp gaps between rows (the My Notes row-gap),
     and a 16dp gap before the next day subhead.
     Chapter row — `Material(color: surface, borderRadius:
     row 10)` → `Container(padding: horizontal 12, vertical
     8, constraints: minHeight 48)` → Row:
     - When the plan is started: the **check toggle** —
       `ValueKey('plan-toggle-<globalChapter>')`,
       `Semantics(container: true, button: true, checked:
       done, label: <§2.3 toggle label>)` around an `InkWell`
       whose hit box is EXACTLY 48 × 48dp, centering a 24dp
       visual box: `Container(24 × 24, borderRadius: input
       8)` — unchecked: transparent fill, 2dp border in
       `mutedOnDark` (the audited fix, §9.3 — `borderDark`
       computes 1.47:1 on `surface` and is PROHIBITED here);
       checked: fill `goldBright`, no border, centered
       `Icon(Icons.check, size: 18, color: onGold)`. The
       check GLYPH is the state cue; color is never the only
       signal (lesson 17). Tapping toggles via
       `PlansStore.toggleChapter`, persists, rebuilds.
       Pre-start there is NO toggle (the mechanism does not
       exist before the plan starts — nothing disabled, nothing
       dead).
     - Gap 8 (only when the toggle is present).
     - **Chapter label** — `Expanded` → `InkWell(
       borderRadius: row 10, onTap: onOpenChapter(global))`
       → `Container(constraints: minHeight 48, alignment:
       centerLeft, padding: vertical 8)` → `Text(chapterName,
       style: controlLabel)`. `ValueKey('plan-chapter-
       <globalChapter>')` on the InkWell. The label is a
       live tap target pre-start too (preview reading is
       honest function, not a dead control).
     - `Icon(Icons.chevron_right, size: 20, color:
       mutedOnDark)` at the row's end — the navigation cue
       that distinguishes the label's action from the toggle's.
     Row height: ≥ 64dp when the toggle is present (48 +
     vertical padding), ≥ 48dp pre-start.
     Checking is UNGATED: any chapter may be toggled on any
     day, in any order. The current day (§4.3) is guidance
     displayed in the summary — it never locks, hides, or
     reorders rows.
  4. When started: gap 24, then the **Restart** control —
     `TextButton` (`minimumSize: Size(64, 48)`,
     `ValueKey('plan-restart')`) with `Text('Restart plan',
     style: dangerActionLabel)`, left-aligned. Absent
     pre-start (there is nothing to restart).
- **Restart dialog** (§2.3 strings) via `wwShowDialog` (the
  reduced-motion path, lesson 20), with EVERY presentation
  property explicit: `AlertDialog(backgroundColor:
  surfaceHigh, surfaceTintColor: Colors.transparent, shape:
  RoundedRectangleBorder(borderRadius: sheet 16), title:
  Text(..., style: selectionTitle), content: Text(...,
  style: bodyOnDark), actions: [Cancel (buttonLabel),
  Restart (dangerActionLabel)], each action `TextButton`
  with `minimumSize: Size(64, 48)`)`. No text field exists
  in this dialog, so field styling is satisfied vacuously —
  the dialog carries no `TextField` and inherits no input
  decoration. Confirming calls `restartPlan`, persists,
  pops the dialog, and rebuilds to the not-started state;
  cancelling changes nothing (byte-identical stored JSON).
- While the detail is open the tradition cannot change
  (Profiles lives under Home's top bar, beneath this route),
  so a plan that was offered at push stays valid for the
  screen's lifetime. No tradition parameter is taken.

### 4.7 Dormancy

Switching tradition NEVER mutates plan state (no write path
from `setTradition` touches `ww_plans_v1`). An out-of-canon
plan is simply not offered: its card disappears from Home
and it cannot be opened. Its stored progress is preserved
byte-for-byte through any number of tradition switches and
reappears, intact, when the tradition offers it again — the
run-10 dormancy pattern, asserted in §11.2/§11.6.

---

## 5. Study Tools

Section construction (HomeTab):

- Header: `Padding(horizontal: 16)` → `Text('STUDY TOOLS',
  style: appSubtitle)`; gap 16.
- One card: `Padding(horizontal: 16)` → `Material(color:
  surface, borderRadius: row 10)` → `Padding(vertical: 12)`
  → `Row(crossAxisAlignment: start)` of exactly three
  `Expanded` entries, in this order: My Notes, Highlights,
  Profiles.
- One entry: `InkWell(borderRadius: row 10, onTap: …)` with
  `ValueKey('tool-my-notes' | 'tool-highlights' |
  'tool-profiles')` → `Container(constraints: minHeight 48,
  padding: horizontal 8)` → Column, centered:
  - `Icon(icon, size: 24, color: goldBright)` — icons:
    My Notes `Icons.notes` (the retired row's icon —
    continuity), Highlights `Icons.highlight`, Profiles
    `Icons.person_outline`.
  - Gap 4.
  - Label: `Text(label, style: controlLabel.copyWith(
    fontWeight: w600), textAlign: center, maxLines: 2,
    overflow: ellipsis)`.
  - Gap 2.
  - Caption: `Text(caption, style: captionOnDark,
    textAlign: center, maxLines: 2, overflow: ellipsis)`;
    the Profiles caption additionally `maxLines: 1`
    (a profile name is one line or it is cut — names are
    user data of unbounded length; ellipsis, never wrap).
  - Centered icon-over-label is the tool-tile role (the GL
    pattern and the Tabs tool-tile role); it is the one
    sanctioned centered composition in this run.
  - Each entry's hit area is its full `Expanded` column ×
    the card's full content height — ≥ 48dp in both axes at
    360dp (each column is ≈ 101dp wide; §10, §11.5).
  - Semantics per entry: `Semantics(container: true, button:
    true, label: '<label>, <caption>')` around the InkWell,
    inner excluded (lesson 25).
- Counts (computed by the shell, §7; passed as props):
  - **My Notes caption** ← the EXISTING `notesCount` prop,
    computed exactly as shipped (run 10: active profile,
    active translation, `notePositionInCanon` incl. the
    deuterocanon table, `canonContainsBook`) — see I-3.
  - **Highlights caption** ← NEW `highlightsCount` prop:
    `visibleSpansForIndex(...)` (§6.1) length for the active
    profile's spans in the active translation, under the
    active tradition, with the deuterocanon table — the same
    visibility the All Highlights screen applies, so the
    caption always equals the number of rows the tap reveals.
  - **Profiles caption** ← `userData.profileName(userData.
    activeProfileId)` (already available to HomeTab via the
    `userData` prop; no new prop).

---

## 6. All Highlights

### 6.1 Grouping contract — `lib/data/highlights_index.dart` (NEW)

Pure, widget-free, unit-testable:

```dart
bool spanPositionInCanon(BibleData data, int book,
    int chapter, int verse, {DeuterocanonData? deutero});

List<HighlightSpan> visibleSpansForIndex({
  required BibleData data,
  required DeuterocanonData? deutero,
  required List<HighlightSpan> spans,
  required WwTradition tradition,
});

class HighlightRowData {
  final HighlightSpan span;
  final int book;        // may be >= DeuteroBook.bookIndexBase
  final int chapter;     // chapter in book, 1-based
  final int verse;
  final String refLabel;
  final String displayText;
}
class HighlightChapterGroup {
  final int chapter;
  final List<HighlightRowData> rows;
}
class HighlightBookGroup {
  final int book;
  final String bookName;
  final List<HighlightChapterGroup> chapters;
}

List<HighlightBookGroup> groupHighlights({
  required BibleData data,
  required DeuterocanonData? deutero,
  required List<HighlightSpan> spans,
  required WwTradition tradition,
  required ScriptureText? texts,
  required WwTranslation translation,
});
```

- `spanPositionInCanon` mirrors `notePositionInCanon`
  (my_notes_screen.dart) EXACTLY — both bounds bind (lesson
  18): core books need `0 <= book < books.length`,
  `1 <= chapter <= book.chapters`, `1 <= verse <=
  chapters[global].v`; indices ≥ `DeuteroBook.bookIndexBase`
  defer to `deutero.positionInCanon` and are out when
  `deutero` is null. It is re-implemented here, NOT imported
  from the screen file: a data-layer function never imports
  a screen (the shell's highlights count uses this one).
- `visibleSpansForIndex`: from `spans` (ONE profile's spans
  in ONE translation set — the caller slices
  `ProfileData.spans[translationKey]`, absent set = empty),
  drop every span whose `verseKey` does not parse
  (`parseVerseKey`), whose position fails
  `spanPositionInCanon`, or whose book fails
  `canonContainsBook(tradition, data, book)` — the run-10
  visibility rule (§0.2.5). Storage is never filtered; this
  is a view predicate only. Return order: unspecified —
  ordering is `groupHighlights`' job; the shell's count uses
  only the length.
- `groupHighlights` builds on the same filter, then:
  - **Book order:** the active tradition's canon order —
    `CanonView.forTradition(tradition, data).bookOrder` for
    core books; deuterocanon groups (Catholic only, the only
    tradition under which they are visible) follow ALL core
    groups, in deuterocanon table order (ordinal asc).
    Pinned: the Catholic browse grid interleaves the
    deuterocanon, but `CanonView` carries no deuterocanon
    positions, so table order appended after the core canon
    is the one deterministic order this data supports.
  - **Book name:** `CanonView.nameFor(book)` when present,
    else `data.books[book].name`; deuterocanon: the
    `DeuteroBook.name`.
  - **Chapters** ascending within a book; **rows** within a
    chapter ordered by verse ASC, then `span.start` ASC,
    then `span.end` ASC, then `span.anchor` (full
    determinism — §0.2.5's "verse then start offset", with
    the remaining ties broken explicitly).
  - **refLabel:** core — `data.refName(globalChapter,
    verse)`; deuterocanon — `deutero.refLabel(book, chapter,
    verse)`.
  - **displayText** (§0.2.5): for a full-verse span
    (`span.isFullVerse`) — the verse's text in the active
    translation; for any other span — `span.anchor` when
    non-empty, else the verse's text. Verse text resolves
    core via `texts.verseText(translation, data, global,
    verse)`, deuterocanon via `texts.extraVerseText(slug,
    chapter, verse)`; `texts == null` or an empty resolution
    falls back to `span.anchor` (which may itself be `''` —
    the row then shows its reference alone, never a
    fabricated line).

### 6.2 Screen — `lib/screens/all_highlights_screen.dart` (NEW)

Constructor mirrors `MyNotesScreen` exactly, so the shell's
routing closure is shared (§7):

```dart
class AllHighlightsScreen extends StatefulWidget {
  const AllHighlightsScreen({
    super.key,
    required this.data,               // BibleData
    this.onOpenVerse,                  // void Function(int book,
                                       //   int chapterInBook, int verse)?
    this.deuteroLoader,                // Future<DeuterocanonData?> Function()?
    this.textsLoader,                  // Future<ScriptureText> Function()?
    this.tradition = WwTradition.none, // WwTradition
  });
}
```

- Loads, in `initState`, exactly as My Notes does: the
  `UserDataStore` (active profile resolved by the model),
  the stored translation (`translationPrefsKey` via
  `ReaderScreen.translationKey`, the shipped alias), the
  texts (best-effort: failure leaves `texts == null` and
  rows fall back per §6.1), and the deuterocanon table via
  `deuteroLoader`.
- Skeleton: `Scaffold(stage)` → `SafeArea` → Column: the
  shipped top-bar pattern with Back `IconButton` (48dp) and
  `Text('All Highlights', style: screenTitle)`; body is the
  loading string (§2.4) centered in `captionOnDark` until
  loaded, then the list or an empty state (§6.3).
- List: `ListView(padding: all 16)`:
  - Header line (§2.4) in `captionOnDark`; gap 16.
  - Per book group: book head `Text(bookName, style:
    selectionTitle)` (gap 16 before every group except the
    first), gap 8; per chapter group: subhead
    `Text('Chapter <n>', style: captionOnDark.copyWith(
    fontWeight: w600))`, gap 8; rows with 8dp gaps (the My
    Notes rhythm).
  - Row: `ValueKey('highlight-row-<verseKey>-<start>')` →
    `Material(color: surface, borderRadius: row 10)` →
    `InkWell(borderRadius: row 10, onTap: …)` →
    `Container(constraints: minHeight 48, padding:
    horizontal 12, vertical 8)` → Row (crossAxis start):
    - Swatch: `Container(16 × 16, decoration: BoxDecoration(
      color: <tint>, shape: BoxShape.circle))` where `<tint>`
      maps `span.color` through the reader's shipped tint
      table (`gold → hlGold, green → hlGreen, blue → hlBlue,
      pink → hlPink, purple → hlPurple`). The swatch is the
      span's color identity, redundant with nothing — it IS
      the data — and is audited as a graphic in §9.
    - Gap 12.
    - `Expanded` Column (start): `Text(refLabel, style:
      refLabelOnDark)`; gap 2; `Text(displayText, style:
      bodyOnDark, maxLines: 1, overflow: ellipsis)` — ONE
      line with ellipsis, per §0.2.5; when `displayText` is
      empty the second line is omitted entirely.
    - No edit/delete controls. This screen is an index; all
      mutation lives in the reader, as with My Notes' rows
      minus its editor — the producer's surface is tap →
      reader only.
  - Tap: `onOpenVerse?.call(book, chapter, verse)` — the
    My Notes path (§7): core verses route through the shell's
    §7.4 `openChapter`; deuterocanon verses (book ≥
    `DeuteroBook.bookIndexBase`) route to the deuterocanon
    reader ON THE HOME STACK, exactly as a My Notes
    deuterocanon row does today. After a tap the screen
    reloads its store on the reader's return (the My Notes
    `_reloadUserData` pattern), so spans changed in the
    reader are reflected when the user comes back.
- The screen never writes `UserData`.

### 6.3 Empty states (I-4)

Centered, `Padding(horizontal: 16)`, title in
`selectionTitle` (`textAlign: center`), gap 8, body in
`captionOnDark` (`textAlign: center`) — My Notes' empty
construction verbatim. Branch by the ACTIVE TRANSLATION's
set (after load):

- **Branch 1** — the active set holds no spans at all
  (`visibleSpansForIndex` input list is empty): Empty A
  strings (§2.4). This branch holds even when OTHER
  translations hold spans: the title names the translation
  the user is looking at, and the gesture copy is the
  teaching the producer pinned.
- **Branch 2** — the active set holds spans but every one is
  filtered out (all canon-dormant under the current
  tradition): Empty B strings (§2.4).

---

## 7. Shell and HomeTab contracts

### 7.1 HomeTab — prop changes (lib/screens/home_tab.dart)

Retained unchanged: `dataFuture`, `userData`, `selection`,
`resumeBound`, `resumeSubtitle`, `notesCount`, `onOpenChapter`,
`onClearSelection`, `onResume`, `onOpenProfiles`,
`onOpenMyNotes`, `onRetryLoad`.

NEW props (all required):

| Prop | Type | Meaning |
|---|---|---|
| `verseOfDay` | `VerseOfDayCardData?` | §3.3; null = no card |
| `plans` | `List<PlanCardData>` | offered plans only, definition order; empty = no section |
| `highlightsCount` | `int` | §5 visible span count |
| `onOpenVerseOfDay` | `void Function(int chapter, int verse)` | card tap |
| `onOpenPlan` | `void Function(String planId)` | plan card tap |
| `onOpenHighlights` | `VoidCallback` | Highlights tool tap |

`PlanCardData` lives in `lib/data/plans.dart`:

```dart
class PlanCardData {
  final StudyPlanDef def;
  final int totalChapters;
  final bool started;
  final int doneCount;    // intersected count (§4.3)
  final int currentDay;   // 0 when not started (sentinel)
  final int percent;      // planPercent(doneCount, totalChapters)
}
```

HomeTab computes NOTHING about plans, verses, or counts
beyond formatting the values it is handed (the shipped
division of labor: the shell computes, HomeTab renders —
`resumeSubtitle`/`notesCount` are the precedent).

### 7.2 Shell — new state and methods (lib/screens/shell_screen.dart)

`ShellController` gains:

- `Future<ScriptureText>? _textsFuture; ScriptureText?
  _texts; bool _textsFailed = false;` — kicked in the
  constructor from `textsLoader ?? ScriptureText.load`;
  resolution stores the texts (or sets `_textsFailed`) and
  calls `notifyListeners()`. Never throws into the UI.
- `List<VerseOfDayPick>? _votdPool; WwTradition?
  _votdPoolTradition;` — the pool cache (§3.1): rebuilt
  lazily when `data` or `tradition` differs from the cached
  pair, reused otherwise.
- `PlansStore? _plansStore;` plus `Future<void> _loadPlans()`
  — loads (or reloads) the store snapshot; called after
  `_loadUserData` (the active profile id is needed) and
  after every plan-detail pop (§7.3). Failure leaves an
  empty snapshot (Home renders not-started cards), never a
  crash.
- In `_homeRoot`, computed per build and passed down:
  - `verseOfDay`: §3.3 from `data`, `tradition`, the pool
    cache, `DateTime.now()`, `translation`, and `_texts`.
  - `plans`: for each def in `wwStudyPlans` where
    `planAvailable(def, tradition, data)` — a `PlanCardData`
    from `_plansStore?.progressFor(activeProfileId, def.id)`,
    `planChapters` (computed once per build; 1,189-element
    list construction is trivial), §4.3 helpers, and
    `DateTime.now()`.
  - `highlightsCount`: `visibleSpansForIndex(data: data,
    deutero: deuterocanonData, spans: userData.profiles
    [activeProfileId]?.spans[translation.name] ?? const [],
    tradition: tradition).length`. (When the deuterocanon
    table has not loaded yet the count may transiently
    exclude deuterocanon spans under Catholic; the shell
    already kicks `ensureDeuteroLoaded()` at startup and
    notifies on its arrival, after which the count is
    exact — the same transient the shipped notes count has.)

### 7.3 Shell — routing (all on `homeNavKey`, all `WwPageRoute`)

- **Shared verse routing.** The closure `_openMyNotes`
  passes today as `onOpenVerse` is extracted into ONE
  private method used by My Notes, All Highlights, and
  nothing else changes:
  ```dart
  void _openVerseFromList(int book, int chapterInBook, int verse) {
    if (book >= DeuteroBook.bookIndexBase) {
      final dBook = deuterocanonData?.byBookIndex(book);
      if (dBook != null) {
        _openDeuteroReader(homeNavKey, dBook, chapterInBook, verse);
      }
      return;
    }
    final global = data!.books[book].start + chapterInBook - 1;
    openChapter(global, verse: verse);
  }
  ```
- `onOpenVerseOfDay` → `openChapter(ch, verse: v)` directly
  (the pick is always a core chapter; this IS the My Notes
  path's core branch — the §7.4 one open-chapter procedure).
- `_openMyNotes` — as shipped, but its `onOpenVerse` is now
  `_openVerseFromList`. Still awaits the push, then
  `_loadUserData()`.
- `_openAllHighlights` — mirrors `_openMyNotes`: pushes
  `AllHighlightsScreen(data, tradition, textsLoader,
  deuteroLoader: <the shipped ensure-then-return closure>,
  onOpenVerse: _openVerseFromList)`; awaits the push, then
  `_loadUserData()` (span counts may have changed in the
  reader) and `_loadPlans()` is NOT called (highlights do
  not touch plans).
- `_openPlanDetail(String planId)` — resolves the def from
  `wwStudyPlans` by id (unknown id = no-op), pushes
  `PlanDetailScreen(data, plan: def, profileId:
  userData.activeProfileId, onOpenChapter: (ch) =>
  openChapter(ch))`; awaits the push, then `_loadPlans()`.
  Note `onOpenChapter` here takes a GLOBAL chapter (plan
  rows carry globals) and lands in the Screens-tab reader
  via §7.4, leaving the detail route on the Home stack
  beneath — Back from the reader returns through the shell's
  one back handler to the detail, as shipped for every
  Home-pushed route that opens chapters.
- Tools `Profiles` → the EXISTING `_openProfiles` (unchanged:
  pushes `ProfilesScreen`, reloads user data on return).
  Tools `My Notes` → the EXISTING `_openMyNotes`.

### 7.4 What does not change in the shell

Tab structure, navigators, the back handler, `openChapter`,
tradition/conference/Sefaria/confession handling, screens
persistence, and the resume computation are untouched. The
`ww_user_data` document and every other prefs key are
untouched; the only new prefs key in the app is
`ww_plans_v1`.

---

## 8. Tokens and type

### 8.1 New `WwType` roles — exactly three, added to ww_theme.dart

```dart
/// Verse of the Day text: the reader's serif metrics
/// (readerBody: serif 18, height 1.55) in the dark-surface
/// ink. Contrast in run-11 spec §9.
static const verseOfDayBody = TextStyle(
  fontFamily: serif, fontFamilyFallback: serifFallback,
  fontSize: 18, height: 1.55, color: WwColors.navInk,
);

/// Plan cover book line: serif 13 navInk on surfaceHigh.
static const planCoverBook = TextStyle(
  fontFamily: serif, fontFamilyFallback: serifFallback,
  fontSize: 13, color: WwColors.navInk,
);

/// Plan cover meta line: 12sp w600 goldBright on surfaceHigh.
static const planCoverMeta = TextStyle(
  fontSize: 12, fontWeight: FontWeight.w600,
  color: WwColors.goldBright,
);
```

Every other text on the new surfaces uses a SHIPPED role:
`appSubtitle` (all three section headers + `VERSE OF THE DAY`
+ `TODAY'S READING`), `captionOnDark`, `bodyOnDark`,
`controlLabel` (+ the shipped `copyWith(fontWeight: w600)`
pattern), `refLabelOnDark`, `selectionTitle`, `screenTitle`,
`goldButtonLabel`, `buttonLabel`, `dangerActionLabel`,
`dialogActionLabel` (unused here — the restart dialog's
actions are `buttonLabel`/`dangerActionLabel`, the shipped
dialog pairing from My Notes' delete dialog).

### 8.2 Colors, radii, spacing tokens

No new colors. Surfaces used: `stage` (page), `surface`
(cards, rows), `surfaceHigh` (covers, dialog), `nav` (top
bars). Fills: `goldBright` (progress fill, Start button,
checked toggle), `gold` (cover rule — graphic only, never
text in this run), `borderDark` (progress track, cover
border), `mutedOnDark` (unchecked toggle border — §9.3).
Radii: `row` 10 (cards, covers, rows, tool card), `chip` 12
(Start button), `sheet` 16 (dialog), `input` 8 (toggle box),
pill radius 2 for the 4dp progress bars on flat surfaces
(height/2, the closed scale's fully-round exception). The
cover bar's corners come from the cover's clip. No shadows,
no gradients, no raw hex anywhere.

### 8.3 Motion

No new durations or curves. Pushes are `WwPageRoute` (300ms
slide from right, no fade; reduced motion swaps instantly —
the route already honors `MediaQuery.disableAnimations`).
Dialogs go through `wwShowDialog` (reduced-motion final
state). The toggle, Start, and Restart state changes are
instant rebuilds with no animated widget. There is nothing
to gate: no `Animated*` widget is introduced in this run.

---

## 9. Contrast — computed table (audit §2 method)

All ratios computed by Petra from the token hexes in
`ww_theme.dart`. Verdicts use the element's own class:
text ≥ 4.5, large text ≥ 3.0, meaningful graphic ≥ 3.0.

### 9.1 Text and icon pairs

| Element | Token (class) | Surface | Ratio | Verdict |
|---|---|---|---|---|
| VOTD verse text (`verseOfDayBody`, 18sp serif — normal class) | navInk | surface | 15.29 | ✓ |
| VOTD label (`appSubtitle`) | mutedOnDark | surface | 6.03 | ✓ |
| VOTD reference (`refLabelOnDark`) | goldBright | surface | 9.55 | ✓ |
| VOTD count / loading / failure (`captionOnDark`) | mutedOnDark | surface | 6.03 | ✓ |
| Plan section header (`appSubtitle`) | mutedOnDark | stage | 6.92 | ✓ |
| Plan card title (`controlLabel` w600) | navInk | stage | 17.54 | ✓ |
| Plan card caption (`captionOnDark`) | mutedOnDark | stage | 6.92 | ✓ |
| Cover book lines (`planCoverBook`) | navInk | surfaceHigh | 14.27 | ✓ |
| Cover meta (`planCoverMeta`) | goldBright | surfaceHigh | 8.91 | ✓ |
| Tools header (`appSubtitle`) | mutedOnDark | stage | 6.92 | ✓ |
| Tool icons (24dp, graphic) | goldBright | surface | 9.55 | ✓ ≥3 |
| Tool labels (`controlLabel` w600) | navInk | surface | 15.29 | ✓ |
| Tool captions (`captionOnDark`) | mutedOnDark | surface | 6.03 | ✓ |
| Detail top-bar title (`screenTitle`) | goldBright | nav | 10.23 | ✓ |
| Detail status / today's line (`bodyOnDark`) | navInk | surface | 15.29 | ✓ |
| Detail today's label (`appSubtitle`) | mutedOnDark | surface | 6.03 | ✓ |
| Detail day subhead (`controlLabel` w600) | navInk | stage | 17.54 | ✓ |
| Detail chapter label (`controlLabel`) | navInk | surface | 15.29 | ✓ |
| Detail chevron (graphic) | mutedOnDark | surface | 6.03 | ✓ ≥3 |
| Start button label (`goldButtonLabel`) | onGold | goldBright fill | 9.71 | ✓ |
| Restart button (`dangerActionLabel`) | danger | stage | — see note | ✓ |

Note on Restart: the button sits on the `stage` background
(the ListView), where `danger` #FFB9C0 computes higher than
its 10.54 on `surfaceHigh`; the binding (worst) surface for
`danger` in this run is the dialog (§9.2). Both pass.

### 9.2 Dialog (Restart confirm, on `surfaceHigh`)

| Element | Token | Ratio | Verdict |
|---|---|---|---|
| Title (`selectionTitle`) | goldBright | 8.91 | ✓ |
| Body (`bodyOnDark`) | navInk | 14.27 | ✓ |
| Cancel (`buttonLabel`) | navInk | 14.27 | ✓ |
| Restart (`dangerActionLabel`) | danger | 10.54 | ✓ |

### 9.3 Graphics and control boundaries

| Element | Pair | Ratio | Verdict |
|---|---|---|---|
| Progress fill vs track | goldBright on borderDark | 6.49 | ✓ ≥3 |
| Progress fill vs cover | goldBright on surfaceHigh | 8.91 | ✓ ≥3 |
| Progress fill vs summary card | goldBright on surface | 9.55 | ✓ ≥3 |
| Progress track vs cover/card | borderDark on surfaceHigh 1.37 / on surface 1.47 | — | informational* |
| Cover rule (decorative accent) | gold on surfaceHigh | 5.25 | ✓ ≥3 |
| Cover border (decorative hairline) | borderDark on stage | 1.69 | exempt† |
| Checked toggle glyph | onGold on goldBright | 9.71 | ✓ ≥3 |
| Unchecked toggle border (control boundary) | mutedOnDark on surface | 6.03 | ✓ ≥3 |
| ~~Unchecked toggle border in `borderDark`~~ | borderDark on surface | 1.47 | ✗ PROHIBITED — superseded by the `mutedOnDark` row above |
| Highlight swatches (graphics) on surface | hlGold 13.94 / hlGreen 13.66 / hlBlue 12.67 / hlPink 12.98 / hlPurple 12.54 | — | ✓ ≥3 all five |

\* The track is the bar's unfilled remainder. Its low ratio
against the cover/card is not a failure: the bar's MEANING
(fill length) computes ≥ 6.49 against both the track and the
surface beneath, and the identical value is always carried
as text (percent caption on Home, percent in the detail
status line) — progress never rides on the track's visibility
(lesson 17, non-color redundancy).

† Decorative hairlines that carry no meaning alone are
exempt (audit §2); the cover's edge is additionally defined
by the `surfaceHigh`-on-`stage` step (15.29-class text
surfaces read against it) and its gold rule.

### 9.4 Result

Every text pair on every new surface passes ≥ 4.5:1; every
meaningful graphic passes ≥ 3.0:1. **One token failed as
first assigned and was fixed in this spec:** `borderDark`
as the unchecked toggle's border (1.47:1 on `surface`, below
the 3.0 control-boundary floor) → reassigned to
`mutedOnDark` (6.03:1). No token needs a new hex; no pair
needs a founder flag. The assignments in §§3–6 already
carry the fixed value — there is no second place to update.

---

## 10. Layout geometry

All spacing literals come from the audit §5 allowed set
{2, 3, 4, 6, 8, 10, 12, 14, 16, 20, 24}; this run uses only
{2, 4, 8, 12, 16, 24}. Screen margin 16 everywhere.

| Surface | Geometry |
|---|---|
| VOTD card | margin H16; padding 16; radius 10; gaps 8 / 8 / 4 (§3.4); height content-driven |
| Plans section | header at H16; gap 16; scroll row padding H16; card width 112; card gaps 12; cover 112 × 144, radius 10, padding 12, rule 24 × 2; cover→title gap 8; title→caption gap 2 |
| Tools section | header at H16; gap 16; card margin H16, radius 10, padding V12; 3 equal columns; icon 24; icon→label gap 4; label→caption gap 2; entry padding H8 |
| Plan detail | ListView padding 16; summary padding 16; block gaps 16 / 24; day rows: padding H12 V8, gaps 8, toggle hit box 48 × 48, visual box 24, radius 8 |
| All Highlights | ListView padding 16; group gap 16; subhead→rows gap 8; rows: padding H12 V8, min height 48, gaps 8; swatch 16 × 16, swatch→text gap 12 |

**360dp / text-scale-2.0 rule (lessons 30, 37).** At 360dp
wide and text scale 2.0, no new surface may overflow,
clip a label into illegibility, or shrink a target below
48dp. The constructions guarantee it structurally — no
fixed height anywhere text lives (the plans row uses
`IntrinsicHeight`, §4.4; tool captions wrap to 2 lines;
the VOTD text is unbounded; detail rows grow with their
labels) — and §11.5/§11.6 assert it from RENDERED GEOMETRY,
not widget properties: rendered rects, sizes, and centers,
plus `tester.takeException()` returning null. The one fixed
height in the run is the plan cover (144dp), which contains
only single-line ellipsized serif lines and the 4dp bar —
no wrapping text can grow it.

---

## 11. Acceptance tests

Suites are NEW files unless named otherwise. Every suite
must pass; every pre-existing suite must stay green
(baseline discipline, lesson 41: a failure is owned only
after a same-environment HEAD baseline says so). Widget
suites pump at 360 × 800, device pixel ratio 1.0 (the
`shell_pump.dart` pattern), with `textScale: 2.0` variants
where stated.

### 11.1 `test/verse_of_day_test.dart` (pure)

Verse-of-day determinism, canon restriction, tie-breaking:

1. Pool ordering on the fake canon (`fakeReaderData()`):
   Genesis 1:1 has 3 deduped connections, Genesis 1:2 /
   Psalms 119:1 / John 1:1 have 1 each, everything else 0.
   Assert `pool.length == 365`; `pool[0] == (chapter 0,
   verse 1, count 3)`; the three count-1 verses follow in
   canonical order (chapter asc: Genesis 1:2, then Psalms
   119:1, then John 1:1); `pool[4].connectionCount == 0`.
2. Count equivalence: for a sample of verses (incl. Genesis
   1:1, 1:2, Psalms 119:1), each pool entry's
   `connectionCount` equals `data.verseConnections(ch, v)
   .length` exactly.
3. Tie-breaking is canonical, not insertion order: build a
   small canon via `BibleData.fromJsonString` whose ref
   list presents the later chapter's verse FIRST; two
   verses with equal counts still order chapter-asc,
   verse-asc.
4. Canon restriction: under `WwTradition.jewish`, a small
   canon whose highest-count verse is in the New Testament
   yields a pool containing NO NT verse (every entry's book
   < 39 and in the Tanakh view); under `none` the same
   canon's pool leads with that NT verse. Under `catholic`,
   `none`, `lds`, `protestant` the full canon is eligible.
5. Small-canon pool: a canon with fewer than 365 verses
   yields `pool.length == total verses`, 0-count verses
   included at the tail in canonical order.
6. Date selection: `verseOfDayFromPool(pool, date)` returns
   the same pick for `DateTime(2026, 10, 15, 0, 1)` and
   `DateTime(2026, 10, 15, 23, 59)`; consecutive local dates
   advance the index by exactly 1, including across the US
   spring-forward (2026-03-07 → 2026-03-08 → 2026-03-09);
   index wraps at `pool.length`; empty pool → null;
   `daysSinceEpochLocal(DateTime(1970, 1, 1)) == 0` and
   `daysSinceEpochLocal(DateTime(1970, 1, 2)) == 1`.
7. Translation resolution (`translationForVerseOfDay`):
   stored available → stored; stored JPS + NT book under
   jewish → kjv; stored Hebrew + OT book under jewish with
   Hebrew bundled → hebrew; stored WEBC under catholic →
   webc; stored WEB under none → web; a stored translation
   the bundle lacks (`hasTranslation` false) → kjv.

### 11.2 `test/plans_data_test.dart` (pure + prefs)

Schedule distribution exactness, persistence, availability,
dormancy. Fake canon: `fakeReaderData()` (real book/chapter
counts).

1. Totals: `planChapters` lengths are exactly 89 / 181 /
   1,189; first/last chapter names: Gospels `Matthew 1` /
   `John 21`; Psalms & Proverbs `Psalms 1` / `Proverbs 31`;
   Whole Bible `Genesis 1` / `Revelation 22`.
2. Distribution (§4.2), exact day-size lists: Gospels
   `[3 ×29, 2]`; Psalms & Proverbs `[4, 3 ×59]`; Whole
   Bible `[4 ×94, 3 ×271]`. Concatenation of each schedule
   equals `planChapters` exactly; no day empty; sizes
   non-increasing. Spot chapters: `gospels schedule[0] ==
   [929, 930, 931]` (Matthew 1–3) and `schedule[29] ==
   [1016, 1017]` (John 20–21); `psalms-proverbs
   schedule[0] == [478, 479, 480, 481]` (Psalms 1–4) and
   `schedule[59] == [656, 657, 658]` (Proverbs 29–31);
   `whole-bible schedule[93]` holds 4 chapters ending at
   global 375 and `schedule[364] == [1186, 1187, 1188]`
   (Revelation 20–22).
3. Persistence round-trip: seed a store with two profiles
   × plans (one plan partially done, one complete), `save`,
   assert the raw prefs string decodes to EXACTLY the
   §4.5 JSON shape (key `ww_plans_v1`; inner keys
   `startedOn`/`done`; `done` sorted asc), reload via
   `PlansStore.load`, assert deep equality of state.
4. Defensive load (each input → asserted state, `parse`
   never throws): `null`; `not json`; `[]`; `{"p": 42}`;
   `{"p": {"gospels": 7}}`; `startedOn` values `2026-13-01`,
   `2026-02-30`, `15/10/2026`, `2026-1-5`, `20261015`, a
   number → plan dropped, sibling plan survives; `done`
   not a list → plan dropped; `done: [1, "2", -3, 1, 2.5]`
   → done == {1}; unknown plan id + unknown profile id
   survive a load/save cycle verbatim.
5. Mutators: `startPlan` on a fresh state writes
   `planDateKey(today)` (zero-padded: a 2026-10-05 clock
   yields `2026-10-05`); `startPlan` on an existing entry
   is a byte-identical no-op; `toggleChapter` adds, then
   removes; `toggleChapter` with no entry is a no-op;
   `restartPlan` removes the entry and prunes the empty
   profile map from the encoded JSON.
6. Day arithmetic: `planDayFor` — start date → 1; a
   `startedOn` after today → 1; start + (days − 1) → days;
   start + 400 days on the 30-day plan → 30; an
   unparseable `startedOn` → 1. `planDoneCount` intersects
   (a `done` set containing another plan's chapter and an
   out-of-canon index counts neither). `planPercent(1, 89)
   == 1`, `planPercent(89, 89) == 100`, `planPercent(0, 0)
   == 0`.
7. Availability matrix: the §4.1 table, all 15 cells,
   asserted against the fake canon for all five traditions.
8. Dormancy of state: a store holding Gospels progress,
   saved; tradition switches (availability recomputed
   false under jewish, true under catholic) perform NO
   store write — the raw prefs string is byte-identical
   before and after; reloading shows the progress intact.

### 11.3 `test/plan_detail_test.dart` (widget)

Pump `PlanDetailScreen` directly (fake canon, mock prefs,
injected `now`):

1. Not-started state: status line `30 days · 89 chapters`;
   `plan-start` present; NO toggle keys exist; chapter
   label tap calls `onOpenChapter` with the global index
   (Matthew 1 → 929).
2. Start flow: tap `plan-start` → prefs now hold
   `ww_plans_v1` with `startedOn` == the injected today;
   toggles appear; status reads `Day 1 of 30 · 0 of 89
   chapters · 0%`; today's line lists Matthew 1–3 names.
3. Toggle flow: tap `plan-toggle-929` → stored `done`
   contains 929, status percent updates to `1%`, the
   toggle's semantics `checked` is true and its label is
   `Mark Matthew 1 as not read`; tap again → removed.
   Toggling a LATER day's chapter (ungated) also persists.
4. Current day: with `startedOn` 10 days before the
   injected today, status reads `Day 11 of 30` and the
   today's-reading line shows day 11's chapters. Day 11
   covers schedule positions 30–32 = globals 959–961 =
   `Mark 3 · Mark 4 · Mark 5` (Matthew ends at global 956;
   Mark 1 is 957). The test derives the expected names
   from `planSchedule`, and this sentence is checked
   against it.
5. Restart flow: from a started plan, tap `plan-restart`
   → dialog appears; assert its `AlertDialog` props:
   `backgroundColor == WwColors.surfaceHigh`,
   `surfaceTintColor == Colors.transparent`, shape radius
   == `WwRadius.sheet`; title/body/action strings exact
   (§2.3). Cancel → stored JSON byte-identical, still
   started. Reopen, confirm `Restart` → entry gone from
   prefs, screen back to the not-started state.
6. Complete state: seed `done` = all 89 Gospels chapters →
   status `Complete · 89 of 89 chapters · 100%`, complete
   line present, no today label.
7. Reduced motion: pump with `disableAnimations: true`;
   the restart dialog still appears and functions (the
   `wwShowDialog` path).

### 11.4 `test/highlights_index_test.dart` (pure)

Grouping, visibility, routing data (incl. deuterocanon).
Seed spans directly as `HighlightSpan` values; fake canon +
a two-book fake deuterocanon table.

1. Grouping order (tradition `none`): spans in John,
   Genesis, Psalms (insertion order scrambled) group as
   [Genesis, Psalms, John] — `CanonView` order, not input
   order. Under `jewish`: spans in Ruth and Psalms group
   Psalms BEFORE Ruth (Ketuvim order in the Tanakh view).
2. Row order: within one chapter, spans order by verse,
   then start, then end — a fixture with two spans on one
   verse (starts 10 and 0) and one on a later verse
   asserts the exact sequence.
3. Visibility: an NT span under `jewish` is dropped; the
   same span under `none` shows. A span with chapter 0,
   verse 0, chapter beyond the book, verse beyond the
   chapter, or an unparseable key is dropped
   (`visibleSpansForIndex` and `groupHighlights` agree).
4. Deuterocanon: a span on book `bookIndexBase + 0` shows
   ONLY under `catholic` (dropped under `none`,
   `protestant`, `jewish`, `lds`), groups AFTER all core
   groups, carries the deutero book name and a
   `deutero.refLabel` reference, and is dropped entirely
   when `deutero` is null. Two deutero books group in
   table order.
5. Display text: a partial span shows its anchor; a
   full-verse span shows the verse text from `texts`
   (NOT its anchor — seed them different); a partial span
   with an empty anchor falls back to the verse text;
   with `texts == null` a full-verse span falls back to
   its anchor.
6. Count consistency: `visibleSpansForIndex(...).length`
   equals the total row count of `groupHighlights(...)`
   on the same fixture, for every tradition.

### 11.5 `test/home_study_sections_test.dart` (widget, HomeTab)

Pump `HomeTab` directly with fixed props (fake data
future, hand-built `VerseOfDayCardData` and
`PlanCardData`s, recording callbacks):

1. Order: `getTopLeft` dy ordering — Continue reading <
   `votd-card` < `STUDY PLANS` header < first plan card <
   `STUDY TOOLS` header < tools card. With a selection
   set, the selection panel renders and sits between
   Continue reading and the VOTD card (I-1).
2. Retirement: `find.text('STUDY')` finds nothing;
   `find.text('My Notes')` finds exactly one widget (the
   tool label).
3. VOTD content: a card data with connectionCount 1189
   renders the exact verse text, the reference, and the
   caption `1,189 connections`; count 1 renders
   `1 connection`. Loading data (`text == null`) renders
   `Loading today's verse…`; `text == ''` renders the
   failure string. Tap → callback receives the exact
   (chapter, verse).
4. Plan cards: not-started card shows `30 days · 89
   chapters` and `find.byKey('plan-progress-gospels')`
   finds nothing; started card (doneCount 45 of 89) shows
   `Day 12 of 30 · 50%` (percent from the prop) and the
   progress key exists; complete card shows
   `Complete · 100%`. Tap a card → `onOpenPlan('gospels')`.
   Under a `plans` list holding only psalms-proverbs,
   exactly one card renders.
5. Tools: captions for (notes 0 / highlights 0) read
   `No notes yet` / `No highlights yet`; (1 / 1) read
   `1 note` / `1 highlight`; (7 / 3) read `7 notes` /
   `3 highlights`; Profiles caption is the seeded profile
   name. Taps fire `onOpenMyNotes`, `onOpenHighlights`,
   `onOpenProfiles` respectively.
6. Geometry at 360 × 800, text scale 2.0 (lesson 30 —
   rendered positions, mutation-checkable): pump the full
   Home (long VOTD verse, started plan, longest plan
   name, a 40-character profile name) and assert:
   `tester.takeException()` is null; each section
   header's dx == 16; the VOTD label's dx == 32 (margin +
   card padding); each tool entry's rendered size is
   ≥ 48 × 48 and the three icons' centers divide the
   tools card into thirds (±1dp); `plan-cover-gospels`
   renders exactly 112 × 144; with doneCount 45/89 the
   progress fill's rendered width == 112 × 45/89 ± 0.5
   and its height == 4; the plan title's rect lies within
   its 112-wide column; the VOTD reference's dy is below
   the verse text's dy.

### 11.6 `test/shell_home_study_test.dart` (widget, WwShell)

Pump the full shell via `pumpShell` (fake canon + texts):

1. Routing: tapping the Highlights tool pushes
   `AllHighlightsScreen`; tapping My Notes pushes
   `MyNotesScreen`; tapping Profiles pushes
   `ProfilesScreen`; tapping a plan card pushes
   `PlanDetailScreen` for that plan; tapping the VOTD
   card switches to the Screens tab with the reader open
   and the active screen's anchor equal to
   `verseOfDayForDate(data, tradition, today)`'s verse
   (computed in the test from the same pure function —
   the pick itself is proven in §11.1).
2. Live plan state: start the Gospels plan from Home
   (card → detail → Start → back) → the Home card now
   shows the bar and `Day 1 of 30 · 0%`; check a chapter
   in the detail → back → card percent updates.
3. Tradition dormancy at the shell level: with Gospels
   progress stored, switch tradition to Jewish (via the
   Profiles screen) → Home shows exactly one plan card
   (`Psalms & Proverbs`), the Gospels card is absent, and
   the stored `ww_plans_v1` string is unchanged; switch
   back to Bible only → the Gospels card returns with its
   progress caption intact.
4. Highlights count honesty: seed a span in the KJV set
   and one in the WEB set (stored translation KJV) → the
   Highlights caption reads `1 highlight`; seed a
   deuterocanon span → under Bible only the caption is
   unchanged; it never counts dormant spans.

### 11.7 `test/all_highlights_screen_test.dart` (widget)

Pump `AllHighlightsScreen` directly (mock prefs seeding a
v3 `UserData` document, fake texts, recording
`onOpenVerse`):

1. Rendering: header line `Highlights in My Profile ·
   KJV`; book heads and `Chapter <n>` subheads in grouped
   order; a row shows its reference and its one-line
   display text; the swatch's decoration color equals the
   span's tint token (asserted for two different colors).
2. Row tap, core: `onOpenVerse` receives (book,
   chapterInBook, verse) — the My Notes signature.
3. Row tap, deuterocanon (tradition catholic, deutero
   loader supplied): `onOpenVerse` receives a book
   ≥ `DeuteroBook.bookIndexBase` with the span's chapter
   and verse — the value the shell's `_openVerseFromList`
   routes to the deuterocanon reader (§7.3); the shell
   suite (§11.6 pattern, My Notes' shipped deutero tests)
   covers the final routing.
4. Empty branch 1: no spans anywhere → title
   `No highlights yet in KJV` and the exact gesture body
   with the profile name substituted. With the stored
   translation WEB, the title reads `No highlights yet
   in WEB`.
5. Empty branch 2: spans exist in the active set but all
   on NT books under tradition jewish → title
   `No highlights to show here` and the exact branch-2
   body. The same seed under `none` renders rows (the
   dormancy is visibility, never deletion — the prefs
   document is byte-identical after the screen closes).

### 11.8 Regression gate

- `flutter analyze` clean; `flutter test` green incl.
  every pre-existing suite; `flutter build web --release`
  green (Maren's verify, TEAM.md).
- `test/arc_rendering_test.dart` is not run as part of
  this package's changes and MUST NOT be modified (§12);
  if it fails, that failure belongs to the parallel desk
  and is reported as such, not fixed here.

---

## 12. Out of scope — explicit

- **`lib/widgets/arc_stage.dart` and its tests**
  (`test/arc_rendering_test.dart` and any arc evidence
  tooling): owned by a parallel package. Not read for
  changes, not modified, not re-verified here. The pinned
  mini-map above the scroll area is untouched.
- **Backup format / `UserData`**: `lib/data/user_data.dart`
  is NOT modified. Store stays v3; export/import shapes,
  counts, and validation are byte-for-byte as shipped.
  Plan state lives in its own store precisely so this
  holds (§4.5).
- **Tradition layers**: conference, Sefaria, and confession
  data, screens, and loaders are untouched.
  `lib/data/tradition.dart`, `lib/data/bible_data.dart`,
  `lib/data/scripture_text.dart`, and
  `lib/data/deuterocanon.dart` are READ-ONLY inputs to this
  run (their shipped APIs are used exactly as they stand).
- **Reader screens** (core and deuterocanon): untouched,
  including the reader's private translation resolution —
  §3.1 reproduces its rule in a pure function and §11.1
  pins the equivalence instead of refactoring.
- **My Notes screen**: untouched except that the shell
  passes it the extracted shared routing closure (§7.3) —
  its behavior, copy, and tests are unchanged.
- No new translations, no new plans beyond the three, no
  plan editing, no notifications/reminders, no sharing,
  no streaks. A plan's schedule is derived, never stored.

---

## 13. Files in this run

NEW:
- `lib/data/verse_of_day.dart` (§3.1)
- `lib/data/plans.dart` (§§4.1–4.5)
- `lib/data/highlights_index.dart` (§6.1)
- `lib/screens/plan_detail_screen.dart` (§4.6)
- `lib/screens/all_highlights_screen.dart` (§6.2)
- `test/verse_of_day_test.dart`, `test/plans_data_test.dart`,
  `test/plan_detail_test.dart`,
  `test/highlights_index_test.dart`,
  `test/home_study_sections_test.dart`,
  `test/all_highlights_screen_test.dart`,
  `test/shell_home_study_test.dart`

MODIFIED:
- `lib/theme/ww_theme.dart` — the three roles of §8.1 ONLY
  (plus their computed-contrast comments).
- `lib/screens/home_tab.dart` — new props (§7.1), the
  §1 scroll order, `_studySection` deleted, the three new
  section builders (§§3.4, 4.4, 5).
- `lib/screens/shell_screen.dart` — §7.2 state, §7.3
  routing, `_homeRoot` computations. Nothing else.

— Petra, Design Auditor & QC, board run 11, desk 1.
Filed as the binding spec per lesson 23: a brief that
paraphrases this file loses to this file (§0.3 lists the
interpretations a brief must not silently re-decide).


## Amendment — gate D-1 (2026-10-15, ratified by Silas)

§10's cover geometry stands (112×144 exact), but its premise that
unclamped ambient-scaled text fits the cover's inner height is
withdrawn: at text scale 2.0 the cover's text wraps in a
`MediaQuery` clamp (scale ≤ 1.0) scoped to the cover only, per
LESSONS.md #48. The card's title and caption outside the cover
carry the same words at full scale. See
`run11-home-study-sections-gate.md` D-1.
