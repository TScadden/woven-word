# Packet — Reader theme choice (Paper / Dark)

Date: Oct 15, 2026 · Producer: Silas · Gate: Petra · Ship: Maren
Founder ruling (Tyson, Oct 15, 2026): "Add a reader theme choice:
paper or dark" — "Default should be dark though."

## The placement call (recorded, spec §1)

The Profiles section "Reader theme" sits between "Your
tradition" and "Backup" — the app's second persisted reading
choice beside its first, mirroring the tradition rows exactly.
An in-reader quick switch (48dp button in both readers' top
bars, present in every reader state) covers the moment of
reading itself. Profiles owns the setting; the switch is a
shortcut to the same stored choice, and the two never disagree
(shell tests assert both directions).

## What shipped

- `WwReaderTheme {paper, dark}` persisted as `ww_reader_theme`;
  absent or unrecognized resolves to **Dark** — fresh installs
  and every install that has never stored a choice open the
  reader in Dark (gate test: the stored values of the other
  selections are untouched by the theme write).
- `ReaderPalette` (theme/ww_theme.dart): every color and style
  role a reader surface uses. Paper = the shipped tokens, value
  for value (asserted). Dark = a real token set: page `surface`,
  chrome `nav`, cards `surfaceHigh`, ink `navInk`, small gold
  `goldBright`, five deep highlight tints carrying ink text at
  5.84–8.27:1.
- Surfaces themed: chapter reader, deuterocanon reader, reader
  top chrome incl. the translation toggle, verse toolbar,
  selection mode + selection bar, connections sheet, note
  editors (reader, deuterocanon, My Notes). Library and the
  rest of the app chrome stay as shipped — the ruling names the
  reader.
- A theme switch writes one preference key and nothing else.

## Gate

Petra: PASS, both themes — full computed matrix in
`team/specs/reader-theme-gate.md`, executable as
`reader_theme_contrast_test.dart`. Top-bar budget measured
across the control-count × text-scale matrix and paid from the
toggle's own padding/chip form (lesson 43). 44 new tests
(24 behavior + 20 contrast); the two shipped paper-render tests
(run 10 SEL-3/SEL-5, deutero note editor) seed the stored Paper
choice — their assertions stand verbatim.

## Landing note (coordination record)

This package was built against 89a54f3 and re-based twice as
siblings landed: the arch package (9ce82fd) and run 11
(79992d8) went in underneath it. Four shipped tests run 11's
Home relabel broke (shell BACK-3/4, system_back rungs, top_bar
T8d — the retired STUDY landmark) were baseline-proven against
pristine 79992d8 during this package's verification (lesson 41)
and fixed by run 11's owner in 941a150; the final tree carries
that fix, and the full affected set passes together here.

## Ship record

- Commits: c5579be (app), dcecb9c (tests), 9f5836b (records),
  on 941a150.
- CI: run 38799454815 — see the run for the final status; the
  APK staged from its signed artifact, signer SHA-256 verified
  against the pinned keystore digest in the ship report.
- Payroll: $1,000 accrued in `team/payroll/LEDGER.md` — pays on
  founder verification.
