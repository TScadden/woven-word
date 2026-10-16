# SHIP RECORD — READER CONNECTION ARCH

**Spec:** `team/specs/reader-arch.md` · **Gate:**
`team/specs/reader-arch-gate.md` — Petra PASS, no fix items.
**Founder authority:** Tyson, Oct 15, 2026 — "added the
connection arch image to the top right here that users can
minimize or expand. We should remember what they last did
(minimize or expand) so it's like a saved profile setting
kinda."

## As shipped

- The chapter-page reader carries the current chapter's
  connection arch at the top of the reading area: Home's
  stage construction verbatim (1200×500 canvas, chapter-bars
  background rendered per density band and cached,
  `MiniSelectionPainter` foreground over the whole-canon
  range), on the black stage plate in both reader themes,
  inset by the 16dp margin, `WwRadius.sheet` corners. A page
  turn repaints the new chapter's web; the panel is static
  otherwise.
- Minimize (48dp, top right of the panel, goldBright on the
  plate, 10.94:1) collapses the slot on `WwMotion.expand`;
  minimized, the panel leaves the layout and a 48dp expand
  chip (palette card roles; 4.62 Paper / 8.91 Dark) floats
  at the pager viewport's top right. Reduced motion swaps
  the slot outright (gate §6).
- Persistence: `ProfileData.readerArchExpanded` in the
  `ww_user_data` document (key `readerArchExpanded`),
  resolved through the active profile on every build;
  default expanded (spec I-4). Document version stays 3 —
  the member is optional and defaulted on load (I-6).
  Backup: export carries it; `validateImport` rejects a
  non-bool member as `notBackup`; pre-package backups
  import and default (spec §2).
- Deuterocanon reader: no arch element, no toggle (I-5) —
  those chapters carry no cross-reference data; absence is
  the honest treatment, asserted by ARCH-12.

## Verification

- Local (Maren): analyze clean; new tests 17/17
  (ARCH-1..12); full suite 463/463 post-clean on the final
  tree; web release build green.
- Fix round: first CI (38825697281) failed ONE test —
  `user_data_test` "document shape matches the spec," the
  shipped exact-shape assertion, which the package's new
  document member legitimately superseded. Translated
  under lesson 40 (the assertion still pins the complete
  shape, now including the member); committed 325cf4a
  (rebased over the Pages records commit 151da22).
  Disclosed anomaly: one earlier local full-suite run
  reported 463/463 against the pre-translation test — not
  reproducible afterward in file scope, standalone scope,
  CI, or the post-clean run, all of which agreed; the
  post-clean full run on the final tree is the record.
- Final CI: **run 38827165114 — SUCCESS**, all four jobs
  (android, web, ios, pages), head 325cf4a. Commits:
  app 3a10a38, tests 1c85038, records a48ee4d, fix 325cf4a.
- APK: `woven_word_reader_arch_arm64_20261015.apk`,
  **31,953,509 bytes**, staged at
  `~/workspace/woven-word/build-reader-arch/`; zip
  inspection: `lib/` carries arm64-v8a only (lesson 54);
  signer SHA-256 from the CI print step:
  `05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11`
  (the pinned fingerprint). Mirrored to the
  `flutter-apk-latest` release; asset size verified
  31,953,509, matching the staged file.

## Payroll

$1,000 accrued in `team/payroll/LEDGER.md` — pays on
founder verification. Founder phone checks: open a chapter
(the arch sits under the top bar), minimize it, leave and
reopen the app (still minimized), expand it from the chip,
switch profiles (each profile remembers its own state),
turn a page (the web follows the chapter), and flip the
reader theme (the plate stays black in Paper too).
