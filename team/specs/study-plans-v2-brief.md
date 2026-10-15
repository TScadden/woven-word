# PRODUCER BRIEF — STUDY PLANS V2: CUSTOM PLANS + REALISTIC SCHEDULES

**From:** Silas, Producer
**To:** Petra (spec) → Maren (build) → Petra (gate) → Boaz duties folded
into Maren's ship steps (below)
**Worktree:** `~/workspace/ww-plans-v2`, branch `plans-v2`, from HEAD
`f7aa773`. ALL work happens in this worktree. Sibling packages hold
uncommitted work in the main tree — never build there (lesson 47).

## Founder directions (Tyson, Oct 15, 2026), verbatim

1. "Also add the option for a user to make their own study plan"
2. "Make the study plans a little more realistic as well"
3. (fold-in addition, same day) "And they can check off what they
   have read and it'll show a percentage complete."

Run 11 shipped three built-ins whose schedules split chapters
evenly by count (base/remainder): Gospels 89 ch / 30 days, Psalms
& Proverbs 181 / 60, Whole Bible 1,189 / 365. Measured on the real
data, the old rule's heaviest days run **187–212 verses** while its
lightest run 16–18 — a quota, not a pace. Direction 2 is that
complaint. Direction 3 restates the shipped mechanism as the core
interaction and pins its display (see §5 — already partly shipped;
v2 pins and tests it rather than rebuilding it).

## Research reconciliation (producer step, lesson 15)

Studied: published reading-plan loads (My Bible Log's reading-time
guide and plan pages; Thomas Nelson's Bible-in-a-year guide;
bible270's verse-sized schedule design).

- A one-year Bible plan asks ~3¼ chapters/day ≈ **86 verses/day**
  (8–12 min/day). That is the load the founder is rejecting.
- A two-year plan asks ~1½ chapters/day ≈ **43 verses/day**
  (4–6 min/day) — the published gentle pace.
- Serious schedulers size days by VERSE count, not chapter count,
  because chapter lengths run 2–176 verses; a daily verse goal is
  what makes days even (My Bible Log's stated reason for offering
  verse goals; bible270 sizes every day by verse load).

**Adopted target (binding): 40 verses/day** for built-in plans —
the two-year published pace, "about one ordinary chapter a day"
(mean chapter in our data = 31,102 / 1,189 ≈ 26 verses, so typical
days land at 1–2 chapters). Computed on the bundled data with the
§1 engine: **Gospels 87 days, Psalms & Proverbs 84 days, Whole
Bible 767 days**. Petra's spec verifies these from the data
and pins them as test values; if her computation disagrees, the
spec stops and returns to Silas — the numbers above are the
producer's own run of the §1 rule over `assets/data.json`.

**Producer ruling (Oct 15, 2026, on Petra's blocking note):**
Petra's independent recomputation confirmed every figure above
except one of mine: I claimed the heaviest non-Psalm-119 day was
80 verses, but that was the Gospels' peak, not the global one.
The Whole Bible schedule's heaviest days after Psalm 119 (176)
are single long chapters standing alone — Numbers 7 (89),
1 Chronicles 6 (81), Luke 1 (80) — and its heaviest
MULTI-chapter day is 71 verses. **Petra's figures stand; the
spec's pinned values (marked †BLOCKING in her §2.3/§11.7) are
ratified as filed and the block is lifted.** The honest headline
is stronger anyway: under the old rule days stacked to 212
verses; under the new engine no day built from more than one
chapter exceeds 71 — only chapters that cannot be split exceed
it, alone.

## 1. The schedule engine (one engine, two modes)

Chapters are atomic and consecutive — the check-off unit is the
chapter, and no chapter is ever split across days (Psalm 119, 176
verses, is one day; that is the honest cost of chapter check-off
and the spec states it rather than hiding it).

- **Mode A — daily amount (target T verses).** Greedy closest-fit:
  walk chapters in order; before adding a chapter to the open
  day, close the day when it is non-empty AND (its verse total
  already ≥ T, OR adding this chapter would leave the total at
  least as far from T as stopping now: `|tot + v − T| >= |tot −
  T|`). Guarantees: concatenation reproduces the chapter list
  exactly; no empty days; every day but a single-oversize-chapter
  day is the locally closest fit to T.
- **Mode B — finish in N days.** Cumulative-threshold partition
  into EXACTLY N non-empty days (`1 ≤ N ≤ chapterCount`): walk
  chapters accumulating verses; close a day when the cumulative
  total reaches the next threshold `j × totalVerses / N`
  (j = days closed + 1), and force-close when the chapters
  remaining equal the days remaining. Concatenation exact; day
  verse totals as even as whole chapters allow.

Both modes are pure functions over (chapter list, verse counts)
in `lib/data/plans.dart`. Schedules are DERIVED, never stored —
the run-11 rule stands and is what makes §3 free.

## 2. Built-ins re-derived

Same ids, names, and book sets (`gospels` [39–42],
`psalms-proverbs` [18–19], `whole-bible` all books). `days` is
no longer a definition input: a built-in's day count IS its
Mode-A schedule length at the adopted target (40). Availability
rule unchanged (every book in the active tradition's canon).
Home card captions and the detail status line keep the run-11
copy forms with the derived numbers; the detail screen also
states the pace (exact copy is Petra's, substance: the adopted
target named as verses per day).

## 3. Migration rule (binding, stated for the report)

**Progress lives on chapters, not days.** The stored payload —
`startedOn` plus the `done` SET of global chapter indices — is
not rewritten, reinterpreted, or intersected any differently by
the schedule change: schedules are derived, so re-deriving them
under the new engine changes only how chapters group into days
and how many days the plan has. Every check mark survives; the
percent (`done ∩ chapters / total`) is IDENTICAL before and
after, because it never depended on the schedule; `currentDay`
recomputes from the same `startedOn` against the NEW day count
under the unchanged clamp rule. A user mid-plan keeps every
check and gains the longer, honest runway. Tests seed run-11
(v1-shape) stored progress, load it under v2, and assert the
done set, startedOn, and percent are exactly preserved.

## 4. Custom plans

**Definition** (stored, per profile, in the plans document):
- `id`: `custom-<n>`, n from a per-profile counter that only
  increases (deleted ids are never reused, so a recreated plan
  can never inherit a deleted plan's checks).
- `name`: user text, trimmed; empty-after-trim cannot save.
- `segments`: ordered coverage, `[{book, from, to}]` — core
  `BibleData` books only (the run-11 plan universe; deuterocanon
  stays out, as shipped), `from`/`to` are 1-based chapters in
  the book, `1 ≤ from ≤ to`; the resolved chapter list derives
  from segments in order, clamped to the book's real chapter
  count at resolution (a segment can never invent chapters).
- `pace`: `{mode: 'verses', versesPerDay}` (Mode A) or
  `{mode: 'days', days}` (Mode B).

**Store shape (v2, same prefs key `ww_plans_v1`):**
`{version: 2, progress: {…the v1 payload, shape unchanged…},
custom: {profileId: [def, …]}, customSeq: {profileId: n}}`.
`parse` accepts the v1 bare-progress shape AND v2, defensively,
entry by entry (lessons 18/22: bad entries drop, parse never
throws, unknown ids preserved); `encode` writes v2 only. The
run-11 assertions that pin the exact v1 encode string are
SUPERSEDED — Petra's spec lists them and Maren translates them
per lesson 40 (the v1 inputs become load/migration cases; the
claims that survive are re-asserted against the v2 shape).

**Surfaces:**
- Home Study Plans row: built-ins (offered), then the active
  profile's offered custom plans in creation order, then ONE
  trailing **Create tile** ("Create your own plan"). The section
  renders whenever the shell wires the create action — even
  with zero offered plans, the door the founder asked for must
  exist. Custom cards are the shipped card construction (cover
  book lines from segment books: ≤ 4 distinct books → all
  names; more → first / `…` / last, the whole-Bible pattern),
  same captions, same percent rule (§5).
- **Editor screen** (create and edit share it; edit seeds from
  the stored def): name field; pace as a segmented choice —
  "Daily amount" (stepper over verses/day) or "Finish in"
  (stepper over days, bounded `1..coverage chapter count` and
  re-clamped when coverage shrinks); coverage as a book list in
  BibleData order showing only books inside the ACTIVE
  tradition's canon, each book a ≥48dp toggle row with, when
  selected, a whole-book / chapter-range choice (range = two
  steppers within the book's chapter count); a live summary
  line carrying the engine's own outputs (chapters, verses,
  resulting days) — computed, never promised. Save is disabled
  only in states that are truly invalid (no name, no coverage)
  and the summary says why — no dead controls, no silent
  refusals. All presentation defaults set explicitly (lesson
  20); all controls ≥ 48dp; text scale 2.0 clean.
- **Detail screen** generalizes to any resolved plan (built-in
  or custom): identical summary/schedule/toggle construction.
  Custom plans additionally carry **Edit plan** (pushes the
  editor; on return the detail reloads — name, coverage, pace
  and the re-derived schedule reflect the edit; checks survive
  by chapter identity — a chapter removed from coverage simply
  stops counting, the run-11 intersection rule; its stored
  check is NOT deleted) and **Delete plan** behind the shipped
  confirm-dialog construction (removes the def AND its
  progress entry; id retired forever). Built-ins keep Start /
  Restart exactly as shipped and gain no edit/delete.
- **Dormancy:** a custom plan is offered iff every segment book
  is in the active tradition's canon (`canonContainsBook`) —
  the built-in rule verbatim. Out-of-canon customs hide from
  Home, cannot be opened, and their defs + progress are
  byte-untouched by tradition switches; they return intact.

## 5. Check-off + percentage (founder fold-in — pin, don't rebuild)

Run 11 already ships per-chapter check toggles (detail), the
progress bar (card cover + detail summary), and a percent in
the card caption (`Day 12 of 30 · 50%` form) and the detail
status (`… · 37%` form) — all from the single `planPercent`
computation. V2 PINS this as the contract for BOTH plan kinds:
- the percent is an explicit number (`<pct>%`) shown alongside
  the bar on the Home card AND on the detail screen;
- both surfaces compute it from the same helper over the same
  intersected count, so they agree BY CONSTRUCTION;
- NEW widget tests assert the percent text updates when a
  chapter is checked AND when it is unchecked — on the detail
  screen, and on the Home card after returning from the detail
  (the shell reload path). If Petra finds any surface where
  the number is missing for a started plan, that is a build
  item, not a copy choice.

## 6. Backups (producer call — recorded here)

Custom plan definitions are user-created content; a backup
that restores notes and highlights but silently drops a user's
own plans breaks the file's promise. **Plans join the backup:**

- The exported document gains a top-level `plans` member
  carrying the plans store's v2 payload (`progress`, `custom`,
  `customSeq`). `UserData.version` stays 3 — the member is
  additive; `UserData.fromJson` ignores unknown keys, so an
  older build reading a newer backup loses nothing it ever
  understood. Export assembles the document from the live
  UserData export PLUS the current plans payload (Profiles
  screen loads the plans store for export/import, the shipped
  own-instance pattern).
- Import: `validateImport` extends. When `plans` is PRESENT it
  is strictly validated in front of the parser (lesson 22):
  object shape; progress entries with valid date keys and
  non-negative int `done` lists; custom defs with `custom-<n>`
  ids, non-empty names, segments with `book ≥ 0` and
  `1 ≤ from ≤ to`, pace mode in {verses, days} with values in
  sane range (verses 1–1000, days ≥ 1). ANY malformation
  rejects the WHOLE import with a NEW named error
  (`BackupImportError.invalidPlans`) and its own dialog
  sentence — nothing is written, either store, byte-tested.
  Silently dropping a user's plans on import is the one
  unacceptable outcome.
- When `plans` is ABSENT (every backup written before this
  package): import proceeds exactly as today and leaves plans
  state untouched — those files never held plans, so nothing
  they promised is lost. When present and valid: plans state
  replaces wholesale on confirm, alongside the UserData
  replacement, and the confirm dialog's counts name what the
  backup holds for plans (custom plan count; plans in
  progress) in the shipped counts style.
- Round-trip test: export → import into a fresh store
  reproduces custom defs and all progress byte-equal; built-in
  progress rides the same `progress` payload (one rule for
  every plan's checks — that consistency IS the call).

## 7. Acceptance (Maren's verify + Petra's gate)

Analyze clean; FULL suite green (baseline discipline, lesson
41); web release green. New suites must cover: engine
properties both modes (concat exact, no empty days, Mode-A
closeness invariant per day, Mode-B exact N), built-in
durations/day-counts derived from the real data (87 / 84 /
767 and heaviest-day values), migration (§3), custom
lifecycle (create → card → start → check → percent; edit
re-derives, checks survive; delete removes def + progress,
seq not reused), dormancy pure + shell, backup (§6 incl.
malformed-member rejection writing nothing, legacy-absent
leaving plans bytes untouched, round-trip byte-equal), and
the §5 percent-update widget tests. Petra gates the editor,
the create tile, the rebalanced cards, and the detail's new
controls: computed contrast from tokens, ≥48dp targets,
geometry asserted from rendered positions at 360dp and text
scale 2.0 (lessons 30/37), no placeholder or dead control,
every dialog's presentation defaults explicit (lesson 20).

## 8. Ship steps (Maren, Boaz's desk)

1. Commits on `plans-v2` naming the change and the founder
   directions they answer.
2. Final CI: `workflow_dispatch` on `plans-v2` (the workflow
   runs on dispatch; the Android job must be green on the
   final tree). Record the run id.
3. Stage the arm64 APK from that run's artifact at
   `~/workspace/woven-word/build-plans-v2/woven_word_plans_v2_arm64_20261015.apk`
   (exact byte size reported; signer digest from the run log
   must match the pinned key, lesson 10/54 discipline).
4. Upload that same file to the `flutter-apk-latest` release
   as an additional asset under its staged filename; verify
   the release asset size equals the staged size. (The CI
   release step recreates the release with
   `woven-word-flutter.apk`; the named asset is added AFTER
   the run completes.)
5. Website: the Pages-deploy package has NOT landed in this
   tree (the web job is still compile-check only) — no
   website action; the report notes it.
6. Landing: if `main` is still `f7aa773`, fast-forward it to
   the branch head and push. If main has moved, rebase onto
   it, re-run the full suite, re-dispatch CI if code changed,
   then push. Conflicts in `shell_screen.dart` beyond the
   mechanical → STOP and report to Silas instead of resolving
   blind (siblings are working there).

## 9. Out of scope

Splitting chapters across days; notifications, reminders,
streaks, sharing; reordering plans by hand; deuterocanon books
in coverage; editing built-ins; Verse of the Day and arc files
(sibling packages — `verse_of_day*.dart`, `arc_*` untouched);
the Library search files.

— Silas, Producer, Oct 15, 2026. This brief is the producer
record; Petra's filed spec (team/specs/study-plans-v2.md)
binds the build (lesson 23/28: a brief that paraphrases the
spec loses to the spec).
