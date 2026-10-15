# Board run 10 — Petra gate: text-selection highlighting

Spec: `run10-selection-highlights.md` (binding; two build-time
amendments recorded in §2.1/§2.2 and ratified here). Gate read
against the final tree, 2026-10-15. Numbers re-derived from the
artifacts on disk (LESSONS #34).

## Verdict: PASS

### 1. Span tint contrast (computed from tokens, spec §3.3)

- Ink on the five tints: 11.92–13.25 — all far above 4.5. PASS.
- Ink on the selected composite (hlGold @ 0.45 over tint/paper):
  12.41–13.25. PASS.
- Selection overlay `hlGold @ 0.50` over tint: worst ink ratio
  12.48; handles/cursor `goldTextOnPaper` 4.62:1 on paper.
  PASS.
- Verse number on tinted segments: the shipped ink rule stands
  (goldTextOnPaper on tints computes 3.22–3.58, below 4.5 —
  the rule exists for exactly this reason). PASS.

### 2. Targets and layout budget

- Selection bar: five 48dp swatches + Clear 48dp + Copy 48dp +
  16dp card padding = 352dp ≤ 360dp (LESSONS #37). PASS.
- Verse toolbar targets unchanged (48dp swatches, shipped).
  PASS.

### 3. Interaction (as built, spec §2 as amended)

- Selection is a MODE entered by long-press (amendment): an
  always-on `SelectableText` claims horizontal swipes starting
  on text on Android (eager-victory drag recognizer) — proven
  by the shipped pager tests R-T8/R-T9/TOOL-3 failing under
  that construction and passing under the mode construction.
  Outside the mode every shipped gesture is the shipped code
  path. Inside the mode, platform selection behavior rules.
  PASS.
- Selection bar writes: hide-bar-first, span written with the
  exact selected offsets + anchor substring, mode exits, tint
  is the feedback. Clear enabled only on overlap; a collapsed
  selection shows no bar. Copy via the editable state. PASS.
- The verse toolbar stays verse-scoped and now writes
  full-verse spans (None clears all of the verse's spans in
  the translation); its color row is NOT displaced by the
  selection bar — the two surfaces are mode-exclusive (the
  toolbar closes when selection mode opens). This is the
  producer's stated call on brief item 4. PASS.
- Back ladder: no new rung; mode exits are taps, writes, and
  page turns. `system_back_test` + BACK groups green. PASS.
- Reduced motion: the feature introduces no animation; the
  mode swap and bar are final-state renders. PASS.

### 4. Data model, migration, dormancy

- Store v3 shapes per spec §1; non-overlap invariant enforced
  by subtraction arithmetic, unit-tested (split, recolor,
  merge, clamp). PASS.
- Per-translation isolation tested at store level and in the
  reader (SEL-5). Migration: v1+v2 fixtures with the stored
  preference at WEB land in the WEB set only; store-load
  migration writes v3 on next save. Backup validator keeps the
  run 6 rejection classes; a legacy backup imports into the
  translation active at import (tested). PASS.
- Dormancy is view-only: DORM-1/2/3 pass, including
  byte-identical storage across tradition views. PASS.
- Copy: My Notes header, dormant empty state, and the Profiles
  backup blurb are the spec §4 strings verbatim (checked
  against the source). PASS.

### 5. Maren's verification (re-derived)

- `flutter analyze`: No issues found.
- `flutter test`: 269 passed / 1 failed of 270. The one failure
  (`conference_shell_test: default off`) fails identically on
  the untouched run-9 HEAD tree in this environment (a
  ShellController dispose race in `ensureDeuteroLoaded`,
  241/242 there) — pre-existing, environment-local; CI on the
  final tree is the arbiter.
- `flutter build web --release`: green.
- New coverage: 28 tests (span arithmetic, per-translation
  isolation, migration fixtures, SEL-1…7, DORM-1…3) — every
  shipped test translated to the new model, none deleted.

### Device-only check owed (founder verification)

- Long-press a verse, drag the handles, color the exact words;
  confirm the feel of entering/exiting selection mode, and that
  swipes starting on text still turn pages everywhere outside
  the mode (the F-2-sensitive surface).
