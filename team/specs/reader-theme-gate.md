# Reader Theme — Petra gate (design audit, both themes)

Package: Reader theme choice (founder ruling, Oct 15, 2026:
"Add a reader theme choice: paper or dark" — "Default should be
dark though."). Spec: `team/specs/reader-theme.md`.
Method: the audit's — contrast computed from tokens (WCAG
relative luminance over the exact palette values and the exact
composites the code builds), never from screenshots. The gate is
executable: `flutter/test/reader_theme_contrast_test.dart`
asserts every row below, for both palettes.

## Verdict: PASS — both themes

### Paper (the shipped design, unchanged — regression side of the gate)

| Pair | Ratio | Band |
|---|---|---|
| ink on paper (body) | 17.12 | 4.5 ✓ |
| mutedOnPaper captions | 4.57 | 4.5 ✓ |
| goldTextOnPaper (small gold text, resting verse number) | 4.62 | 4.5 ✓ |
| ink on the 5 tints | 11.92–13.25 | 4.5 ✓ |
| goldTextOnPaper on tints (dot, note icon) | 3.22–3.58 | 3.0 ✓ |
| ink on selected composite (plain / tinted) | 15.23 / 12.41–13.25 | 4.5 ✓ |
| outline vs selected fill / page | 4.11 / 4.62 | 3.0 ✓ |
| ink under selection overlay, worst stack (over blue tint) | 12.48 | 4.5 ✓ |
| handles on the worst overlay stack | 3.37 | 3.0 ✓ |
| dot (gold) on paper | 3.20 | 3.0 ✓ |
| onGold on goldBright (toggle + button labels) | 9.71 | 4.5 ✓ |

The palette's paper values are asserted token-for-token against
the shipped `WwColors` values in the gate test: the paper reader
renders identically to the shipped reader.

### Dark (the new token set)

Page `surface` #14141C · chrome `nav` #0B0B10 · cards
`surfaceHigh` · ink `navInk` #F2EAD8 · small gold `goldBright` ·
deep tints: gold #6E560F, green #3E5A24, blue #2F4A6E, pink
#6E3548, purple #4E3A66.

| Pair | Ratio | Band |
|---|---|---|
| navInk on surface / nav / surfaceHigh | 15.29 / 16.40 / 14.27 | 4.5 ✓ |
| mutedOnDark on surface / nav / surfaceHigh | 6.03 / 6.47 / 5.63 | 4.5 ✓ |
| goldBright on surface / nav (small gold text, resting number) | 9.55 / 10.23 | 4.5 ✓ |
| navInk on the 5 dark tints (body + number on tint) | 5.84–8.27 | 4.5 ✓ |
| goldBright on dark tints (dot, note icon) | 3.65–5.16 | 3.0 ✓ |
| navInk on selected fill (plain wash / tinted) | 10.73 / 5.84–8.27 | 4.5 ✓ |
| outline goldBright vs page / own fill / worst adjacent tint | 9.55 / 6.70 / 3.65 | 3.0 ✓ |
| navInk under selection overlay, worst stack (over gold tint) | 4.94 | 4.5 ✓ |
| handles goldBright on that stack / on page | 3.08 / 9.55 | 3.0 ✓ |
| field text navInk on field fill (surface) | 15.29 | 4.5 ✓ |
| field hint mutedOnDark on field fill | 6.03 | 4.5 ✓ |
| chip label goldBright on nav; unselected toggle mutedOnDark on nav | 10.23 / 6.47 | 4.5 ✓ |
| onGold on goldBright (toggle + button labels) | 9.71 | 4.5 ✓ |

Two constructions were decided by the numbers, not by eye:
the verse number takes the ink role on dark tints because
goldBright on the gold tint computes 3.65 (fails the text band)
— the same reason paper switches its number to ink on tints —
and the dark selection overlay is gold at 0.20, the strength at
which both the text under it (4.94) and the handles against it
(3.08) hold their bands in the worst stack.

## Targets, overflow, motion

- The quick switch is a 48dp `IconButton` in both readers' top
  bars, present in every reader state (including loading/error).
- Layout budget (lesson 37), measured in a probe matrix (2 and 3
  translation options × text scales 1.0/1.3/1.6/2.0 at 360dp):
  the added 48dp control overflowed the bar by 8.5px with three
  options at scale 1.0 and by 12px with two at scale 2.0. The
  resolution uses the bar's own patterns: segment padding
  12→6dp, and the segmented toggle takes its existing chip form
  at the measured thresholds (3 options from scale 1.3, any
  options from 1.6). The full matrix renders with no overflow
  after the fix; widget tests assert both themes at scale 2.0.
- Switching is an instant state change — no animation exists to
  reduce; reduced-motion pumps render the final themed states
  (asserted).
- Semantics: the Profiles rows are one node each, label exactly
  the theme's name, selected carried by the check + the selected
  flag (lesson 25); the quick switch's tooltip states the
  current theme and the action.

## Data safety

A theme switch writes one preference key and nothing else: the
setter (`ShellController.setReaderTheme`, and the readers' own
fallback write) touches no user-data code, so spans, notes,
profiles, tradition, and translation are byte-identical across
a switch by construction.
