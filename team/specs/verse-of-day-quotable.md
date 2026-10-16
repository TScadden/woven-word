# Verse of the Day — the quotable pool

**Status: BINDING.** This spec replaces the pool rule of the run 11
spec (`run11-home-study-sections.md` §0.2.2 and §3.2) in full. Every
other part of run 11 §3 (the card, the pick, the tap routing, the
rollover) stands exactly as shipped. Maren implements; Petra gates.

Founder ruling (Tyson, Oct 15, 2026), verbatim: "It should make sure
that the verses aren't just filler verses. They should be ones that
people can quote." Decision record:
`team/memory/decisions/2026-10-15-verse-of-day-quotable.md`. The
verse still flips at local midnight by the device's local date
(founder confirmed the same day); that behavior does not change.

## 0. Summary

The shipped pool is the 365 most-connected verses in the active
canon. Connection prominence measures how woven a verse is into the
cross-reference web, not whether anyone quotes it, and the founder
met the difference on the card: hub verses with no life outside the
web (Daniel 9:24, 133 connections, cited by zero conference talks;
Zechariah 13:7, 145 connections, zero citations; Titus 3:3, 135
connections, zero citations). The pool is redefined by an empirical
quotability standard built only from data the app lawfully holds,
in three layers: a **signal floor** (the verse is demonstrably
reached for), four **encoded predicates** (the mechanical shapes of
non-quotable text), and a **curatorial exclusion list** (116 verses
read in context and judged, shipped as data with reasons). Pool
sizes are outcomes of the rule, not targets: **410** verses in the
core canons, **483** in the Jewish canon. Only 49 of the shipped 365
survive into the new core pool.

## 1. What does not change

- The card: §3.4 of run 11 verbatim — heading, reference, connection
  count, full verse text in the active translation, chevron, the
  section's presence rule (tradition-only, never plan-gated).
- The pick: `pool[daysSinceEpochLocal(date) % pool.length]`, with
  `daysSinceEpochLocal` exactly as shipped (local calendar date
  resolved through UTC midnights; DST-immune; one verse per local
  day). Pool length is now 410 / 483 / 365 by mode (§2.4), so the
  rotation period is the pool's size; no verse repeats inside a
  period.
- Tap routing: opens the pick's chapter in the reader at the verse
  (`ReaderArgs` with bookIndex/chapterIndex/verse), unchanged.
- One pool per (data, tradition); the pool follows the active
  tradition's canon; deuterocanon is never pooled (it has no
  cross-reference data — run 11 §0.2.2's fact, unchanged).
- `VerseOfDayPick` keeps its shape (globalChapter, verse,
  connectionCount).

## 2. The pool method

### 2.1 Signals (only what the app lawfully holds)

- **(a) Conference citation frequency.** The number of distinct
  talks in the bundled run 8 corpus (`assets/conference.json`,
  4,964 talks, 1951–2026) that cite the verse — the same deduped,
  canon-clamped edges `ConferenceData.parse` already computes.
  Verses speakers quote constantly are empirically the quotable
  ones: 11,854 verses are cited at least once; the most-cited verse
  in the Bible by this measure is Matthew 22:39 (259 talks).
- **(b) Cross-reference connections.** The verse's deduped distinct
  connection count, exactly as `BibleData.verseConnections` counts
  today (max 212, Isaiah 9:6).

### 2.2 Floors and ranking, per canon

- **Core canons (None / LDS / Protestant / Catholic — one 66-book
  canon, one pool).** Eligibility: signal (a) **≥ 25 distinct
  talks**. Ranking: citations descending, connections descending,
  canonical order (chapter, then verse). The pool is every eligible
  verse that passes §2.3 and §2.4 — **410 verses**. No truncation at
  365 and no padding: the floor is the standard. (Why a floor, not
  a top-365 cut: the citation distribution is tie-dense at the cut —
  a top-365 slice lands at 27 citations and excludes "Jesus wept."
  (John 11:35, 25 talks) in favor of verses no one quotes outside
  their passage. A stated floor is the honest line; the founder's
  complaint is filler, and a floor admits nothing the signal has
  not vouched for.)
- **Jewish canon (Tanakh, core books 0–38).** The conference corpus
  is a Latter-day Saint corpus; its signal is **not** used here, and
  no substitute signal is fabricated. Eligibility: signal (b)
  **≥ 55 connections** — the strongest prominence signal the app
  holds for the Tanakh. Ranking: connections descending, canonical
  order. The pool is every eligible verse passing §2.3 and §2.4 —
  **483 verses**, spanning 32 of the 39 Tanakh books.
- **The honest asymmetry, stated for the record.** The core pool is
  a *quotedness* pool; the Jewish pool is a *prominence* pool held
  to the same complete-sense filter. They are not the same
  instrument. One consequence, measured: Isaiah 53:5 ("with his
  stripes we are healed," 43 talks) is in the core pool and is
  **not** in the Jewish pool — its connection count is 37, below
  the floor, while its chapter-neighbors 53:3, 53:6, 53:10–12 clear
  it. The floors also cut real verses at their edges by
  construction (the core's citation-24 band; Genesis 3:19 at 54
  connections). A floor is a line, and the line is stated rather
  than tuned per verse.

### 2.3 The encoded predicates (complete sense, mechanical layer)

Four predicates over the verse's bundled KJV text. A verse failing
any predicate is out. The normative implementation is
`tools/votd_curation/generate.py` (`predicates()`); the Dart port
must match it exactly, and §5 pins both with the same exemplars.

- **P1 — genealogy verb.** The text contains the word "begat".
- **P2 — itinerary log.** The text matches
  `(removed|departed|journeyed) from <name>,? and (encamped|pitched)`
  (Numbers 33's journey log and its kin).
- **P3 — census / name list.** The text contains "the children of"
  together with ≥ 2 spelled-out number words, or begins "these are
  the names of" / "and these are the names of".
- **P4 — name density.** In a verse of ≥ 6 words, ≥ 45% of the
  non-initial words are capitalized (proper-name lists).

Measured character (this is why the set is exactly these four):
each predicate individually scores **zero hits among the verses
cited ≥ 10 times and ≥ 20 times** — no verse speakers demonstrably
quote is caught by any of them — while together they catch the
mechanical classes across the whole corpus. Two candidate signals
were tested and **rejected on measurement**, and must not be
revived: terminal punctuation (only 83.4% of verses cited ≥ 20
times end in `.?!`; Matthew 28:19, John 11:25 and Matthew 7:7 all
end in a colon — KJV punctuation cannot proxy complete sense), and
looser name/number thresholds (they catch Matthew 16:16, Luke 10:30,
Luke 15:4 — verses the citation record proves quotable).

At the shipped floors the predicates bind **nothing**: all 94 core
removals and all 22 Jewish removals below the candidate line are
curatorial (§2.4). The predicates are the standard's standing
guard — they bind in the fallback pool (§2.5), they bind the day
the bundled data changes, and they are what the membership tests
assert. That is their job; a filter that never binds on today's
data is a specification, not a dead letter.

### 2.4 The curatorial exclusion list (complete sense, judgment layer)

Signals and predicates cannot see the largest class of filler the
founder met: verses that are prominent, well-formed, and still not
quotable standing alone — the question whose answer is the famous
verse, the clause whose main clause lives one verse up, the parable
beat whose whole content is plot. Every candidate verse was read in
ranked context against this bar: *printed alone on the card, the
verse must deliver a complete thought people quote — a teaching, a
promise, a command, a testimony, a self-contained saying.* Three
failure shapes were excluded:

- **SETUP** — a bare question or request whose substance is the
  answer in a neighboring verse (Matthew 22:36 out; its answer
  22:37 is the pool's #2).
- **FRAGMENT** — a clause whose main clause or subject is in
  another verse (Ephesians 4:12 out; 4:11's main clause keeps 4:11
  in).
- **PLOT / RECORD** — content exhausted by its narrative or
  record-keeping function: parable premise and stage business
  (27 verses of Matthew 25's two parables), transitions, plot
  reports, chronicle entries, ritual procedure, adversary plot
  speeches. Narration that itself carries the passage's celebrated
  content stays (Luke 15:20, the father's embrace; Daniel 2:35, the
  stone become a mountain).

The result is **116 exclusions**, shipped as data:
`lib/data/verse_of_day_curation.dart` (already generated; keys are
`(globalChapter, verse)`; every entry carries its reference and
reason). The auditable source is `tools/votd_curation/curation.py`;
the Dart file is generated from it and is never edited by hand.
Borderline keeps are documented in the audit source's companion
record (this package's working notes): e.g. "One Lord, one faith,
one baptism" (Ephesians 4:5) stays as a list member that usage has
made standalone; John 21:6 stays on the strength of its command.
Petra's gate (§6) may move individual verses between keep and
exclude; the mechanism for that is amending the audit source and
regenerating, never a code special-case.

Measured outcome: core candidates at the floor 504 → **410** after
§2.3 + §2.4 (94 removed, all curatorial). Jewish candidates 505 →
**483** (22 removed, all curatorial). The core pool is 76 OT / 334
NT — the citation record is New-Testament heavy because that is
what speakers quote; stated, not corrected.

### 2.5 Degradation (citation signal unavailable)

If the citation counts fail to load (asset or parse failure), the
core pool falls back to signal (b) alone: connections descending,
canonical order, top 365 — the shipped run 11 ranking — still
filtered by §2.3 and §2.4. The Jewish pool is unaffected (it never
uses the signal). The fallback is a failure path, not a mode: it is
not surfaced in the UI, and the pool rebuilds to the citation pool
as soon as counts arrive. One honest consequence: hub verses the
exclusion list does not name (Daniel 9:24 is a complete, if dense,
prophetic proposition — it is deliberately not excluded) return in
the fallback only.

## 3. Implementation shape

### 3.1 The builder (lib/data/verse_of_day.dart)

`buildVerseOfDayPool` stays a pure synchronous function in the data
layer. Its inputs grow; its nature does not:

```dart
List<VerseOfDayPick> buildVerseOfDayPool(
  BibleData data,
  WwTradition tradition, {
  int Function(int globalChapter, int verse)? citationCount,
  String Function(int globalChapter, int verse)? kjvText,
})
```

- Canon membership stays `canonContainsBook`, intersected with the
  core book range (indices < 1000 carry connection data;
  deuterocanon never pools, §1).
- Jewish tradition → the §2.2 connections rule; `citationCount` is
  ignored.
- Other traditions → if `citationCount` is provided, the §2.2
  citation rule; otherwise the §2.5 fallback.
- §2.3 predicates run when `kjvText` is provided (the shell only
  builds the pool once texts are loaded — §3.3 — so in practice it
  always is). §2.4 exclusions always run.
- The §2.3 predicates are exposed as a pure top-level function on
  the KJV text (`versePassesQuotabilityPredicates(String)`) so the
  tests pin them directly.
- Floors are named constants in the file:
  `votdCitationFloor = 25`, `votdConnectionFloor = 55`,
  `votdFallbackPoolSize = 365`.

### 3.2 Citation counts (lib/data/conference_data.dart + shell)

`ConferenceData` gains one pure static:

```dart
static Map<(int, int), int> citationCountsFromSource(
  String source, {required int chapterCount})
```

It counts **distinct talk ids** per (chapter, verse) over the same
edges, dropping edges with chapter outside `[0, chapterCount)` or
verse < 1 (the `parse` discipline; verse upper bounds need not be
clamped — counts for verses that do not exist are inert, since the
builder only ever asks about real verses). The shell loads the
counts from the bundled asset through `compute`, **independently
of the conference layer's toggle and its lazy UI load** — the pool
is a Home surface, not a layer surface. A failed load resolves to
the §2.5 fallback, never to an error state on Home.

### 3.3 Shell wiring (lib/screens/shell_screen.dart)

- The pool builds when its inputs exist: `ScriptureText` loaded
  (for §2.3 and the card's text) **and** citation counts resolved
  (loaded or failed). Until then, Home renders **without** the
  Verse of the Day section — the section appears when the pool
  exists, as Study Plans appear when offered. This retires the
  run 11 §3.3 "Loading today's verse…" branch: it becomes
  unreachable and is removed. (Rationale: a pick computed from
  partial inputs could visibly change when the rest arrive; the
  shipped build never faces that because its only input is the
  already-loaded BibleData. Both new inputs land within the first
  moments from bundled assets.)
- The pool cache key grows from (data, tradition) to (data,
  tradition, inputs): the cached pool rebuilds when the citation
  counts or the texts arrive, and on tradition change, exactly as
  the shipped cache rebuilds on tradition change. The pick is
  recomputed every build from `DateTime.now()`, unchanged.

### 3.4 Run 11 spec amendment

Add a one-line supersession note to `run11-home-study-sections.md`
at §0.2.2 and §3.2 pointing at this spec. Nothing else in that file
changes.

## 4. Copy

No new user-facing copy. The card's strings are run 11's, verbatim.
No surface in the app describes the pool method; the method lives
in this spec and the curation source. (Stated as a decision: the
founder asked for quotable verses, not for an explanation on the
card.)

## 5. Tests (all pinned; extend flutter/test/verse_of_day_test.dart)

1. **Predicate exemplars** (direct, on `versePassesQuotabilityPredicates`
   with the bundled texts): OUT — Matthew 1:2 (P1), Ezra 2:3 (P3),
   Numbers 33:10 (P2), Genesis 10:2 (P4 — a pure name list: "The
   sons of Japheth; Gomer, and Magog, and Madai, and Javan, and
   Tubal, and Meshech, and Tiras."). IN — John 11:35 ("Jesus
   wept."), Matthew 28:19
   (ends in a colon), Matthew 16:16 (a confession full of names),
   Luke 15:4 (number words in a saying), Genesis 1:1.
2. **Real-data membership** (bundled assets): core pool size 410;
   every member cited ≥ 25; every member passes §2.3; no member in
   the exclusion map. Jewish pool size 483; every member ≥ 55
   connections, books 0–38 only; same filter assertions.
3. **Exemplar membership**: John 11:35 IN the core pool; Isaiah
   53:5 IN the core pool and OUT of the Jewish pool; Daniel 9:24
   OUT of the core pool, IN the Jewish pool; Matthew 22:37 is the
   core pool's #2 by rank. OUT by exclusion — Matthew 25:37,
   Ephesians 4:12, Luke 15:26 (core); Leviticus 1:3, Psalms 2:2
   (Jewish). OUT by predicate in a unit fixture (test 1 covers it).
4. **Per-canon scoping**: None / LDS / Protestant / Catholic pools
   are identical lists; the Jewish pool differs and contains no
   book ≥ 39; a Catholic-tradition pool contains no deuterocanon
   book (index ≥ 1000).
5. **No truncation, no padding** (synthetic fixture): a canon whose
   survivors exceed 365 yields all of them; a canon with fewer
   yields exactly the survivors.
6. **Fallback**: with `citationCount` omitted, the core pool is 365
   by connections, canonical tie-break, exclusions still applied:
   Zechariah 8:20 (77 connections — inside the fallback's range,
   excluded as a FRAGMENT) is absent, and no fallback member is in
   the exclusion map.
7. **Rotation unchanged**: the shipped determinism / same-day /
   next-day / leap-day / DST tests stay as they are and stay green;
   add: the pick over a 410-length pool has period 410.
8. **citationCountsFromSource**: distinct-talk counting and
   out-of-range edge dropping on a small JSON fixture.

## 6. Gates and ship

- Maren verify: `flutter analyze` clean; full suite green;
  `flutter build web --release` green.
- **Petra gate (required before ship):** review of this method
  against the founder's words, plus a sample audit of the BUILT
  pools: a stratified sample (every 12th verse of each pool, plus
  each pool's 15 lowest-ranked) read against the §2.4 bar, reported
  in the package report with any verse judged filler that the
  filter let through named individually. The gate files at
  `team/reviews/verse-of-day-quotable-petra-gate-20261015.md`.
- CI green on the final tree; arm64 APK per lesson 54 staged at
  `build-verse-quotable/woven_word_verse_quotable_arm64_20261015.apk`
  and mirrored to the `flutter-apk-latest` release at matching size.

## 7. Non-goals

- No change to the card, the pick math, the rollover, tap routing,
  or any other Home section.
- No per-verse hand-tuning outside the curation mechanism (§2.4).
- No new signal sources (no scraping, no external datasets); the
  Jewish pool's prominence basis is stated, not disguised.
- No change to the conference layer, its toggle, or its surfaces —
  the pool consumes the corpus's counts, nothing more.
- No copy about the method anywhere in the app (§4).
