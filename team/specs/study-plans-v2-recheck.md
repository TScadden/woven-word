# PETRA — RE-CHECK, STUDY PLANS V2 FIX ROUND (CLEARED TO LAND)

**From:** Petra, Design Auditor & QC
**Tree re-checked:** worktree `~/workspace/ww-plans-v2`, branch
`plans-v2`, integrated head `89b56a0`. Fix commits under re-check:
`68dbe4a` (F1), `35b8c4e` (F6), `b08d23f` (F2+F9), `64a6a86` (F3),
`4992cd2` (F5), `ee70c45` (F4), `61e0e0d` (format), rebased onto
`origin/main` `e5c0f31` with integration commit `89b56a0`.
**Verdict: CLEARED TO LAND.** Every gate finding F1–F6 and F9 is
closed as specified below; F7 stands ratified by Silas as built
(spec-record amendment belongs to the ship packet, not this note);
F8 was noted at the gate with no action. No blocking item. Two
wording discrepancies in the re-check brief itself are flagged in
the F1 section — they do not change the verdict, because the gate's
own fix text and spec §8.3 are what the code is judged against.

---

## Per-finding confirmation

- **F1 — §8.3 import true-receipt: CLOSED (by code read; see flag).**
  `profiles_screen.dart` `_importBackup` now loads a fresh store
  (`final freshPlans = await PlansStore.load(prefs)`), sets
  `freshPlans.document = PlansDocument.fromJson(result.plans)`,
  and `await freshPlans.save()` before `_plansStore = freshPlans`,
  before `setState`, and before the `Data replaced from backup.`
  snackbar; the `catch (_) { return; }` makes the snackbar
  unreachable when the plans write throws. This required making
  `PlansStore.document` assignable (`plans.dart`), which is the
  only other production change in the commit. Mechanism, against
  the old defect: the old code wrote `prefs.setString(...)`
  directly inside `try { … } catch (_) {}` and fell through to the
  snackbar on any throw, so a failed plans write still claimed
  success; the new code returns from the catch, so the snackbar —
  reachable only after the awaited save completes — is a true
  receipt of both replacements (§8.3: UserData `replaceData`
  awaited first, plans save awaited second, both before the
  snackbar). **Flag (brief wording, not code):** the re-check brief
  names a `setBackupData` step and a "new test" for F1. Neither
  exists in this tree: there is no `setBackupData` identifier
  anywhere in the codebase (the UserData replacement is
  `replaceData`), and `68dbe4a` adds no test — it changes only
  `plans.dart` and `profiles_screen.dart`. No shipped test injects
  a throwing plans write, so the failure path is verified by this
  read, exactly as the gate's re-check section promised ("F1
  (failure-path receipt + construction)"). If Silas wants a
  failure-injection test as an additional landing condition, that
  is new scope, not an unmet gate fix.
- **F2 — §11.8.3 pure byte loop: CLOSED.** `backup_test.dart`'s
  malformation loop is now `async`, seeds BOTH prefs strings
  (`UserDataStore.storageKey: _currentJson` and a fixed
  `plansPrefsKey` seed) via `SharedPreferences.setMockInitialValues`,
  and after EVERY malformation's `validateImport` asserts
  `error == invalidPlans`, `data == null`, and both strings
  byte-identical to their seeds (with the bad input as `reason`).
  That is the right assertion per §11.8.3: validation is pure and
  writes nothing, for every P-malformation, not just one.
- **F9 — §11.8.6 / §11.8.8: CLOSED.** The Cancel test now seeds a
  non-null `devicePlans` string and asserts BOTH prefs strings
  byte-identical after Cancel (previously it asserted only that
  the plans key was null, its seeded state). The new
  `export with no plans state includes the member via Profiles
  flow (§11.8.8)` widget test pumps `ProfilesScreen` with no
  plans prefs at all, taps Export backup through the flow, and
  asserts the shared document's `plans` member deep-equals the
  empty v2 document `{version: 2, progress: {}, custom: {},
  customSeq: {}}` — through the Profiles flow, not only at the
  document level, as §11.8.8 pins.
- **F3 — §11.5.10 / §10 geometry: CLOSED.** The scale-2.0 geometry
  test in `plan_editor_test.dart` now asserts, from rendered
  geometry (`tester.getSize` / `tester.getRect`, lesson 30):
  each segment's rendered height ≥ 48dp for all four segments —
  pace (`Daily amount`, `Finish in`) and whole/range
  (`Whole book`, `Chapter range`), located as the InkWell tap
  surface ancestor of each label — and the summary counts line's
  rect contained in the summary card's rect (the `Material` with
  `WwColors.surface` ancestor), asserted as four inequalities
  (left/top/right/bottom). `takeException()` remains null.
- **F4 — §11.6.6 lifecycle: CLOSED.** The shell lifecycle test now
  walks both pinned steps: edit-name from the detail (re-enters
  via `plan-edit`, renames to `Shell Renamed`, asserts the detail
  and then the Home card show the new name) and recreate-same-name
  after deletion (asserts `recreated.id` is not the deleted id,
  is exactly `custom-2`, the name matches, and
  `doc3.progress['default']?[recreated.id]` is null — starts
  unchecked, no inherited progress). The post-check card
  assertion is tightened to the exact derived caption
  `find.text('Day 1 of 39 · 0%')` (Psalms whole book at
  40 verses/day on the fake canon derives 39 days; 1 of 150
  chapters is 0%).
- **F5 — §11.2.1 round-trip fixture: CLOSED.** The v2 round-trip
  in `plans_data_test.dart` now places both customs on ONE
  profile (`default`): `custom-1` at verses pace and the second
  at days pace, asserts `defs.length == 2`, def key order
  `id/name/segments/pace`, segment key order `book/from/to`, and
  pace key order for both modes (`['mode', 'versesPerDay']` and
  `['mode', 'days']`). The document still spans two profiles via
  progress, as §11.2.1's opening ("a document with two
  profiles") requires.
- **F6 — §4.2 deep hashCode: CLOSED.** `PlansDocument.hashCode`
  is now the pinned deep hash: `Object.hash` over
  `hashAllUnordered` of progress entries (profile key hashed with
  an unordered hash of plan-id → `PlanProgress`, whose own
  hashCode is deep over the done set), `hashAllUnordered` of
  custom entries (profile key hashed with `Object.hashAll` over
  the def list — ORDERED over defs, each def's hash deep over
  its ordered segments), and `hashAllUnordered` of customSeq
  entries. Unordered over maps, ordered over custom def lists,
  matching the deep `==` in §4.2. The lengths-only hash is gone.
- **F7 — §6.5 editor save await: RATIFIED AS BUILT** (per Silas;
  the awaited save in `plan_editor_screen.dart` `_save` stands;
  spec-record amendment goes in the ship packet).
- **F8 — §12 format churn: NOTED, no action** (as at the gate).

## Verification runs (by me, on `89b56a0`, this worktree)

- `flutter analyze` (SDK `~/workspace/flutter-sdk/bin/flutter`):
  **No issues found**, exit 0.
- Plan suites: `plans_data_test.dart`, `plans_engine_test.dart`,
  `plans_real_data_test.dart`, `backup_test.dart`,
  `plan_editor_test.dart`, `plan_detail_test.dart`,
  `home_study_sections_test.dart`, `shell_home_study_test.dart`,
  `arch_ambient_home_test.dart` — **137 tests, all passed.**
  (The re-check brief's filenames `backup_plans_test.dart` /
  `home_plans_test.dart` do not exist; the suites above are their
  actual counterparts — `backup_test.dart` and the two
  home/shell study suites — plus `plan_detail_test.dart`.) No
  plan test failed; the known conference_shell dispose-race
  flake did not appear in any file run and remains out of scope.

## Integration spot-check (rebase)

- `origin/main` `e5c0f31` is an ancestor of `89b56a0`
  (fast-forward possible), as briefed.
- The fix commits survived integration with their hashes and
  content unchanged (`68dbe4a`, `35b8c4e`, `b08d23f`, `64a6a86`,
  `4992cd2`, `ee70c45` are the direct ancestors below the format
  pass `61e0e0d`; I re-read `git show 68dbe4a` and `git show
  35b8c4e` in full and confirmed the production diff of the whole
  fix range touches only `plans.dart` — F1 assignable document +
  F6 hash — and `profiles_screen.dart` — F1).
- The only main-side integration change is `89b56a0` itself: a
  5-line, test-only translation of `arch_ambient_home_test.dart`
  to the plans-v2 API (`PlanCardData(plan: resolveBuiltinPlan(...))`
  replacing the superseded `def:`/`totalChapters:` parameters,
  `onCreatePlan: () {}` added at both HomeTab constructions) —
  a lesson-40 scenario translation; every ambient assertion is
  unchanged, and that file passes in the run above. No plan
  production code changed semantics during integration.
- CI `38836628827` on `89b56a0`, re-checked by me via `gh`:
  android **success**, web **success**, ios **success**, pages
  **failure with 0 steps**. Main's own run `38828627437` shows
  pages success (6 steps). A job that executes zero steps cannot
  be failing on this code; my read agrees with Silas's
  classification — the github-pages environment blocks branch
  deploys. Infrastructure, not a finding against this package.

**CLEARED TO LAND.** Silas lands; nothing in this re-check
touches `main`.

— Petra, Design Auditor & QC, Study Plans V2 desk.
