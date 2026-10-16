# PETRA — QC GATE, STUDY PLANS V2 (PASS WITH FIXES)

**From:** Petra, Design Auditor & QC
**Tree audited:** worktree `~/workspace/ww-plans-v2`, branch `plans-v2`,
head `42bafe8`. Commits under audit: `b8fd864`, `1afcb63`, `9974151`,
`55c64a9`, `c914082`, `42bafe8`. Baseline: `f7aa773`.
**Verdict: PASS WITH FIXES.** No P0 and no P1 findings. The engine, the
store, the percent contract, dormancy, and the backup validator conform
to the spec and were re-derived independently at this gate. The fixes
below are one code-construction item (F1) and test-fidelity gaps
(F2–F5, F9): assertions the spec pinned that the built suites assert
more weakly or not at all. F6–F8 are departures from the spec's letter
with conforming-or-stronger behavior; they are recorded, and F6/F7 may
be closed by a spec-side note from Silas instead of a code change.

---

## 1. Engine — independently re-derived (spec §1, §2, §11.1, §11.7)

I re-implemented Mode A from the spec's pseudocode in a scratch script
over the bundled `flutter/assets/data.json` (verse counts =
`chapters[].v`) and compared against both the spec's pins and the built
code path (`lib/data/plans.dart` `scheduleByVerses`/`scheduleByDays`,
which match the §1 pseudocode line for line, including the `>=` tie
close, the integer cross-multiplication threshold, and the force-close
term):

- Real-data day counts: **Gospels 87, Psalms & Proverbs 84, Whole Bible
  767** — my derivation, the spec (§2.3), the built
  `plans_real_data_test.dart`, and a re-run of that suite all agree.
- Heaviest days: **176** (Psalm 119 alone, Whole Bible day 393 and
  Psalms & Proverbs day 49); heaviest non-Psalm-119 day **89**
  (Numbers 7 alone, day 96, global 123 — the ratified †BLOCKING
  figure); then **81** (1 Chronicles 6, day 258) and **80** (Luke 1,
  day 617; also the Gospels' peak, day 43). Heaviest multi-chapter day
  **71** — my derivation reproduces it (day 514). Lightest days
  20 / 15 / 11 and every §2.3 spot day I checked (Gospels days 1, 2, 3,
  43, 86, 87; Psalms & Proverbs days 1, 2, 49, 83, 84; Whole Bible days
  1, 2, 96, 258, 393, 617, 766, 767) match exactly.
- Fake canon (10 verses/chapter, Psalm 119 = 176): my derivation gives
  **23 / 47 / 298** days, Gospels day 11 = globals 969–972, Psalms &
  Proverbs day 30 = [594, 595], day 31 = [596], day 47 = [657, 658],
  Whole Bible day 150 = [596] with exactly one non-4-chapter day — all
  as §2.4/§11.9 pin, and the built `plans_data_test.dart` distribution
  translation asserts the exact Psalms size list
  `[4 ×29, 2, 1, 4 ×15, 2]`.
- The built engine suite asserts the §1.1/§1.2 worked examples verbatim,
  the closeness invariant, exactly-N, concatenation, no-empty, and the
  §11.1.5 clamp/dedupe cases. No test asserts a number the code does
  not produce: the plan suites re-run by me (below) are green.

## 2. Numbers on surfaces (spec §2.6, §5.4, §6.2, §6.3)

- Grep over `flutter/lib` plan contexts: no `30`/`60`/`365` day count
  survives in any plan copy, caption, or status. Card captions
  (`home_tab.dart`) and the detail status (`plan_detail_screen.dart`)
  read `plan.days` / `plan.totalChapters` from the `ResolvedPlan` only.
- The pace line renders on every resolved plan's detail in the pinned
  form (`_paceLine`: verses pace `About <T> verses a day` with the
  `About 1 verse a day` singular; days pace `X = (totalVerses /
  plan.days).round()`), placed directly under the status with the
  pinned 4dp gap, in every state. All four pinned forms are asserted in
  `plan_detail_test.dart` (`About 40/25/5 verses a day`,
  `About 1 verse a day`).
- Percent contract (founder fold-in): both surfaces render `<pct>%`
  from the one helper — the shell computes
  `percent: planPercent(done, plan.totalChapters)` into `PlanCardData`
  and the detail computes `planPercent(done, total)` from
  `planDoneCount` over the same intersection; there is no second
  computation anywhere in `lib/`. The built
  `shell_home_study_test.dart` test "percent updates both directions,
  card after pop (§11.6.4/5)" asserts CHECK and UNCHECK on the detail
  (exact strings `Day 1 of 23 · 1 of 89 chapters · 1%` →
  `… · 0 of 89 chapters · 0%`) and on the Home card after popping in
  both directions (`Day 1 of 23 · 1%` → `Day 1 of 23 · 0%`, progress
  bar still present at 0%). Contract satisfied.

## 3. Store + migration (spec §3, §4, §11.2, §11.3)

- v1-seeded prefs load under v2 with done set, `startedOn`, and percent
  preserved exactly: `plans_data_test.dart` migration group asserts the
  identical `PlanProgress`, percent equality over the resolved v2 plan,
  `planDayFor` re-clamping a 30-day-old start to the new fake day count
  23, and that after any v2 save the raw string's `progress` member
  deep-equals the v1 payload (§11.3.1/§11.3.2, both present at full
  strength).
- `encodeDocument` writes v2 only (the empty document encodes exactly
  `{"version":2,"progress":{},"custom":{},"customSeq":{}}`); `parse`
  retains its run-11 signature as `parseDocument(raw).progress`.
- Seq never reuses ids after delete (create 1, 2 → delete 1 → create
  3) and the self-heal is asserted (stored seq 0 with a live `custom-7`
  → healed seq 7 → next create `custom-8`).
- The six superseded assertions (§4.6) were translated, not deleted —
  diffed against `f7aa773` and accounted one by one: **A1** → exact key
  order `['version','progress','custom','customSeq']` plus
  `progress` keys `containsAll(['default','p2'])`; **A2** → the
  two-level `progress/default/gospels` access with `startedOn` and
  sorted `done` [929, 931] verbatim; **A3** →
  `expect(reloaded.document, store.document)`; **A4** → the exact
  replacement map with the unknown-ids payload preserved under
  `progress`; **A5** → `expect(store.document.progress, isEmpty)`;
  **A6** → the exact empty v2 document map. All six present.
- §11.9 engine translations are all present and the old strings
  (`of 30`, `30 days`, `365`, base/remainder size lists) appear nowhere
  in the translated suites.

## 4. Editor (spec §6.1, §6.4, §6.5, §9, §10)

- Every pinned control exists: name field with the full explicit
  `InputDecoration` of §6.4 item 3 (lesson 20 — fill `surfaceHigh`,
  `borderDark` borders, `goldBright` focused border, `labelText`
  'Plan name', no hint); two-segment pace control (`Daily amount` /
  `Finish in`); verses stepper 5–200 step 5 default 40 (non-multiple
  seeds step by 5 from the true value, clamped — the code clamps the
  seed into 5–200 and steps with `.clamp(5, 200)`, preserving the
  offset rule); days stepper 1..coverage-count with the same-update
  re-clamp (`_reclampDays` runs inside every coverage mutation);
  per-book toggle rows with whole/range choice and mutually clamping
  First/Last steppers (First max = Last, Last min = First, Last max =
  book chapter count); live summary built from a draft resolved
  through `resolveCustomPlan` on every build (never its own
  arithmetic); reason lines exactly `Give your plan a name to save
  it.` / `Choose at least one chapter to save your plan.`, name first;
  Save disabled only when name-empty or coverage-empty, with the
  explicit disabled colors and the `dialogActionLabelDisabled` label
  role. No-save exits write nothing (asserted byte-identical in create
  and edit). Carried segments, bounding-range collapse, and canon
  scoping are all implemented and tested.
- Every control is ≥48dp by construction (stepper `IconButton`
  constraints 48×48, segments minHeight 48, toggle hit box exactly
  48×48, book-name InkWell minHeight 48, save `Size.fromHeight(48)`)
  and the geometry test asserts rendered sizes from `tester.getSize`
  at 360×800, text scale 2.0, with `takeException()` null — see F3 for
  the two assertions §11.5.10 pins that this test omits.
- Contrast recomputed by me from `ww_theme.dart` hexes with my
  validated calculator (validated first against run-11's published
  15.29 / 6.03 / 6.92 / 10.23 / 9.71 — it reproduces all five exactly;
  `ww_theme.dart` is untouched by this package's diff). Spot values,
  all matching §9 to the second decimal: field text navInk on
  surfaceHigh **14.27**; field floating label mutedOnDark on
  surfaceHigh **5.63**; reason lines / pace line mutedOnDark on surface
  **6.03**; segmented selected onGold on goldBright **9.71**;
  goldBright on surfaceHigh (add icon, state step, focused border on
  surface **9.55**) **8.91**; stepper navInk on surface **15.29**;
  stepper at-bound mutedOnDark on surface **6.03**; create-tile title
  navInk on stage **17.54**; tile caption mutedOnDark on stage
  **6.92**; tile gold rule gold on surfaceHigh **5.25**; danger on
  stage **12.95**; danger on surfaceHigh (dialog) **10.54**; disabled
  save label mutedOnDark on surfaceHigh **5.63**. Every §9 verdict
  stands; no element in any state falls below its band.

## 5. Backup (spec §8, §11.8)

- The validator (`user_data.dart` `_plansMemberValid`) implements the
  §8.2 checklist P1–P6 in full: non-object member; version not the
  integer 2; any of progress/custom/customSeq absent or non-object;
  strict progress dates (re-format equality), `done` list of
  non-negative ints with duplicates rejected; custom defs with
  `custom-<n>` ids (n ≥ 1), duplicate ids rejected, trimmed-non-empty
  names, non-empty segments with `book ≥ 0` int and `1 ≤ from ≤ to`,
  pace modes with verses 1–1000 / days ≥ 1; seq ints ≥ 0, with a seq
  below the highest id suffix explicitly NOT a malformation (asserted).
  Validation order is the pinned one: the plans checklist runs before
  the `emptyDocument` computation, and both precedence cases are
  asserted (malformed plans + empty profiles → `invalidPlans`; valid
  rich plans + empty profiles → `emptyDocument`) — the §0.4.4 call.
- Byte-untouched on rejection: the widget test seeds BOTH prefs strings
  (`ww_user_data` and `ww_plans_v1`), runs a malformed-plans import,
  asserts the exact dialog text `Nothing was changed. This backup's
  study plans are not in a form Woven Word can import.`, and asserts
  both strings byte-identical after dismissal. See F2 for the
  pure-level repetition gap.
- Legacy absent-member import leaves the plans string byte-identical
  (asserted); present-member import replaces plans wholesale (a
  device-only `custom-9` is gone afterward; the stored string equals
  `encodeDocument` of the file's document); round-trip through the
  Profiles flow reproduces the plans prefs string BYTE-EQUAL and the
  user-data document deep-equal; confirm counts assert both plural and
  singular forms of the §8.3 sentence; gate/parser agreement
  (`fromJson(member).toJson()` deep-equals the member) is asserted for
  the empty document and a populated member.
- Export assembles in `profiles_screen.dart` from
  `Map.from(_data.toJson())` plus the plans document, pretty-encoded as
  shipped; `UserData` model, version (3), and `exportJson()` are
  unchanged in behavior.

## 6. Dormancy (spec §5.3, §7)

- Pure level: `customAvailable` asserts a Matthew custom offered under
  none/protestant/catholic/lds and not jewish, a Psalms custom under
  all five, and a zero-chapter (fully clamped) custom under none —
  §5.3(b) included.
- Shell level: a Matthew custom with progress, seeded as a v2 document,
  disappears on switching to Jewish (Psalms & Proverbs card and the
  create tile remain), the `ww_plans_v1` string is asserted
  BYTE-IDENTICAL across the switch, and switching back restores the
  card with its caption intact (`Day 1 of 2 · 20%`). The shell's
  `_openPlanDetail` no-ops for unoffered customs, and no tradition
  switch path writes plans.

## 7. Regression surface — derived by me, not taken from the claim

- CI run **38832254951**: I verified via `gh` that it completed with
  conclusion `success` at headSha exactly `42bafe8…` (android, ios,
  web jobs all green). The claim was true.
- `flutter analyze` in this worktree, run by me: **No issues found**
  (exit 0).
- Plan suites re-run by me (`plans_data`, `plan_detail`, `backup`,
  `plans_engine`, `plans_real_data`, `plan_editor`,
  `home_study_sections`, `shell_home_study`): **111 tests, all
  passed.**
- Full suite, run by me on this head: **441 tests, 440 passed, 1
  failed** — `conference_shell_test.dart: persisted on: startup loads
  the dataset once`, the conference dispose race named in §11.9.
  Baseline discipline (lesson 41): I ran the same test in isolation on
  an untouched `f7aa773` worktree in this environment and it failed
  there identically; in a full baseline run it passed (386/386) — it
  is flaky at HEAD and not owned by this package. Test-count pair
  (runtime, same environment): **baseline 386 → built 441** (+55;
  static declaration count 377 → 432 across 37 → 40 test files).

---

## Findings

### P2 — fix before ship

- **F1 — §8.3 (code, `flutter/lib/screens/profiles_screen.dart`,
  `_importBackup`).** The wholesale plans replacement is wrapped in
  `try { … } catch (_) {}`: if the plans write fails, the import still
  falls through to the success snackbar, breaking §8.3's pinned rule
  that both replacements complete before the snackbar (the shipped
  true-receipt rule). The construction also departs from §8.3's letter
  (load a `PlansStore`, set its document to
  `PlansDocument.fromJson(result.plans)`, await `save()`): the built
  code writes `prefs.setString(plansPrefsKey, encodeDocument(…))`
  directly and reloads. The success-path result is identical; the
  failure path is not. **Fix:** perform the replacement through a
  freshly loaded `PlansStore` with `await save()`, and do not show the
  success snackbar when the plans replacement throws.
- **F2 — §11.8.3 (tests, `flutter/test/backup_test.dart`).** The
  byte-untouched assertions cover both prefs strings at the widget
  level for ONE malformation only (non-object member). §11.8.3 pins a
  pure-level repetition for EVERY P-malformation asserting the same
  byte-identity after calling `validateImport`; the built pure loop
  asserts only `error == invalidPlans` and `data == null`. **Fix:**
  extend the pure loop to seed both prefs strings and assert
  byte-identity after each `validateImport` call.
- **F3 — §11.5.10 / §10 (tests, `flutter/test/plan_editor_test.dart`,
  geometry test).** The scale-2.0 geometry test asserts stepper-button
  rendered heights and the save height, but §11.5.10 also pins each
  segment's rendered height ≥ 48 and the summary counts line's rect
  lying within the summary card's rect. Neither is asserted.
  **Fix:** add both assertions (rendered positions, per lesson 30).
- **F4 — §11.6.6 (tests, `flutter/test/shell_home_study_test.dart`,
  custom lifecycle).** Two pinned steps are missing: editing the
  custom's name from the detail and asserting the card shows the new
  name; and recreating a plan with the same name after deletion,
  asserting the new id differs from the deleted id and it starts
  unchecked. The post-check card assertion is also weaker than the
  spec's wording: it asserts `find.textContaining('Day 1 of')` instead
  of the exact caption with the custom's derived days and percent.
  (The behaviors themselves are covered elsewhere — edit round-trip in
  §11.4.5, seq discipline in §11.2.4 — this is a shell-level fidelity
  gap, not a behavior gap.) **Fix:** add the edit-name and recreate
  steps and tighten the caption assertion to the exact string.

### P3 — record; fix or close by spec note

- **F5 — §11.2.1 (tests, `flutter/test/plans_data_test.dart`).** The v2
  round-trip places its two customs on two DIFFERENT profiles
  (`default` verses, `p2` days); §11.2.1 pins two customs on ONE
  profile, one per pace mode. It also asserts def and segment key
  order but not pace key order (`mode` then its value key).
- **F6 — §4.2 (code, `flutter/lib/data/plans.dart`,
  `PlansDocument.hashCode`).** Spec: `==` / `hashCode` deep. The built
  `hashCode` is `Object.hash(progress.length, custom.length,
  customSeq.length)` — lengths only. It satisfies Dart's contract
  (deep-equal documents hash equal) but is not the pinned deep
  hashCode.
- **F7 — §6.5 (code, `flutter/lib/screens/plan_editor_screen.dart`,
  `_save`).** Spec: persist fire-and-forget with catch, then pop. The
  built code awaits `store.save()` (in try/catch) before popping —
  stronger than the letter, a departure from it.
- **F8 — §12 (code, `flutter/lib/data/user_data.dart`).** The diff
  carries dart-format reflow churn in regions outside §8's scope
  (getters, `ProfileData.fromJson`, `notesFor`, span helpers, etc.).
  I found no semantic change in those hunks — they are line-reflow
  only — but §12 scopes this file's modification to §8, and the churn
  widens every future diff against this file.
- **F9 — §11.8.6/§11.8.8 (tests, `flutter/test/backup_test.dart`).**
  The confirm-dialog Cancel case asserts the plans prefs key is null
  (its seeded state) rather than byte-identity of BOTH strings; and
  §11.8.8's "export with no plans state still includes the member" is
  asserted at the document level (`PlansDocument().toJson()` shape +
  `exportJson()` excluding plans), not through the Profiles export
  flow with an empty plans store.

### Deviation enumeration (§8 of the gate brief)

Every departure from the spec's letter found in `git diff
f7aa773..42bafe8` is listed above: F1 (import construction +
swallowed failure), F5 (round-trip fixture shape), F6 (hashCode),
F7 (editor save await), F8 (user_data formatting churn), and the
test-assertion gaps F2–F4, F9. Copy register: I diffed every pinned
string — create tile, pace lines, reason lines, stepper/segment
labels and tooltips, dialog titles/bodies/actions, the §8.3 counts
sentence, and the `invalidPlans` error sentence — against the built
`lib/` strings; **all match verbatim, with no other copy departure
found.** File list: the diff touches exactly the §12 file list plus
the two spec/brief records — no out-of-package files, `ww_theme.dart`
untouched, no sibling-package files (`verse_of_day*`, `arc_*`) in the
diff.

## Re-check on the fix round

On Maren's fix commit I will re-check exactly: F1 (failure-path
receipt + construction), F2 (pure byte loop), F3 (segment + summary
rect assertions), F4 (edit-name, recreate, exact caption). I will
re-run the plan suites and `flutter analyze` on the new head. F5–F9
may be fixed in the same round or closed by Silas amending the spec
record; they do not block landing once F1–F4 land.

— Petra, Design Auditor & QC, Study Plans V2 desk.
