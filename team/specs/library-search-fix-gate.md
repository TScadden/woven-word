# Library live search — Petra gate (search fix package)

Auditor: Petra (design QC). Surfaces gated: the Library root
results region (group headers, result rows), the dynamic
search-field hint. Spec: library-search-fix-spec.md (§6).

## Contrast — computed from tokens (WCAG relative luminance)

| Pairing | Tokens | Ratio | Floor | Verdict |
| --- | --- | --- | --- | --- |
| Row title on row surface | navInk #F2EAD8 on surface #14141C | 15.29:1 | 4.5:1 | PASS |
| Row subtitle on row surface | mutedOnDark #9A947F on surface | 6.03:1 | 4.5:1 | PASS |
| Group header on stage | mutedOnDark #9A947F on #000000 | 6.92:1 | 4.5:1 | PASS |
| Row chevron on row surface | mutedOnDark on surface | 6.03:1 | 3.0:1 (icon) | PASS |
| Field hint on field fill | mutedOnDark on surfaceHigh #1B1B24 | 5.63:1 | 4.5:1 | PASS |

The title pairing reproduces the theme's own annotated
navInk-on-surface value (15.29:1); the hint pairing is the
shipped InputDecorationTheme pairing, unchanged.

## Targets and construction

- Every result row is the shipped browse-row construction
  (Material surface + WwRadius.row + InkWell; Container
  minHeight = WwSpace.minTarget = 48dp; the whole row is the
  tap target). ≥48dp by construction, identical to the
  conference browse rows already on phones.
- Group headers use the shipped section eyebrow
  (WwType.appSubtitle, the sectioned grids' header style).

## Text scale 2.0

Pumped in test ("results render without overflow at text
scale 2.0", library_search_ui_test.dart): BOOKS and
CHAPTERS states both render, no overflow exception.

## Motion

No new animation. Results swap in the field's own frame;
destination pushes ride WwPageRoute (300ms slide-from-right)
and reduced motion renders final states, as shipped.

## Semantics and label honesty

- One container semantics node per row carrying the §4 label
  ("Open book: …", "Open chapter: …", "Open talk: …, by …"),
  inner content excluded — the shipped row pattern
  (lesson 25). Labels asserted in tests via
  find.bySemanticsLabel.
- The field hint names only groups that can appear in the
  current layer state (§2.5); the TALKS group is structurally
  absent with the layer off; the no-match line is the shipped
  string, verbatim.
- Deuterocanon rows and subtitles carry the "Deuterocanon"
  marker; nothing in the results region implies content the
  app does not hold.

## Verdict

**PASS.** No findings. Verification evidence: Maren's run
(analyze clean; the 28 new tests green; full suite in the
package report, with the two baseline conference-race
failures identified per lesson 41).
