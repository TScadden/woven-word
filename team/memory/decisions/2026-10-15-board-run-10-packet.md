# Board run 10 — packet: text-selection highlighting (2026-10-15)

Producer: Silas. Desks: Petra (spec + gate), Maren (build + verify),
Boaz (CI + APK). Founder request (Tyson, Oct 15, 2026), verbatim:
"Can you make it so instead of highlighting the whole text we can
hold down and select exact text we want then highlight it"

## Rulings that govern this run (filed, binding)

- `decisions/2026-10-15-highlights-notes-per-translation.md`:
  highlights AND notes are stored PER TRANSLATION. Switching swaps
  the visible set; switching back restores it exactly. No anchoring,
  no cross-translation mapping. Pre-run-10 data (no translation
  recorded) is assigned to the translation active at upgrade; no
  duplication.
- Founder clarification, canon dormancy (Oct 15, 2026): tradition /
  canon is NEVER a data scope and never deletes or migrates data.
  A highlight or note is visible iff (a) the current translation
  matches the set it was saved in AND (b) its book is in the
  current tradition's canon. Otherwise DORMANT — stored untouched,
  invisible, restored exactly when both hold again.

## Research named (per TEAM.md research mandate)

- YouVersion: long-press a verse for actions; its highlights are
  version-specific in practice — the founder's per-translation
  ruling matches the category's dominant shipped behavior.
- Logos: selection handles + a highlight palette on the selection;
  its cross-version note anchoring (lemma/surface mapping) is the
  complex route the founder's ruling explicitly replaces.
- Gospel Library: press-and-hold selection with a marking bar.
- Platform: Flutter `SelectableText` gives the standard selection
  (long-press word, draggable handles) and a `contextMenuBuilder`
  seam for a custom action bar — the run's mechanism, adapted to
  design law (paper bar, audited swatches, ≥48dp targets).

## Producer's architecture calls (recorded here, spec'd by Petra)

1. Store v3. A highlight is a SPAN: {verseKey, start, end,
   anchorText, color} inside a per-translation list. Spans within
   one (verse, translation) never overlap: applying a color or a
   clear SUBTRACTS the range from existing spans first (trim/split),
   then inserts — coverage is deterministic and rendering is a
   disjoint segment walk. Notes become per-translation maps.
2. The tap-a-verse toolbar stays verse-scoped: its color row writes
   a FULL-VERSE span (start 0, end = text length, anchor = the whole
   verse text) in the current translation. The selection action bar
   is selection-scoped. Two surfaces, two honest scopes.
3. Whole-verse presentation: a verse whose span coverage includes
   a full-verse span keeps the shipped block-tint presentation;
   partial spans render inside the text only.
4. Dormancy is a VIEW rule implemented at the two list surfaces
   (My Notes + the Home My Notes card): storage, backup totals,
   export and import never filter by translation, tradition, or
   canon. The reader needs no dormancy code: a book outside the
   tradition's canon is unreachable, and its translations list is
   the tradition's own.
5. Migration is structural in `UserData.fromJson` (it takes the
   legacy translation key), so the store load and the backup
   validator share one path — a v1/v2 backup imports into the
   translation active at import under the same assignment rule.

## Scope

IN: store v3 + migration + validator; reader text selection
(chapter-page reader + deuterocanon reader); selection action bar;
toolbar/deutero full-verse spans; My Notes per-translation +
dormancy; Home card count under the same visibility rule; Profiles
backup copy + import assignment; tests per the brief (selection
without page turns, span persistence across relaunch, migration of
a v-current store, span rendering in both states, per-translation
isolation, the three dormancy cases).
OUT: multi-verse selections (a span carries one verse key — the
founder's model); cross-translation anchoring (dissolved by the
ruling); Spurgeon/Fathers/Douay-Rheims (queued in run 9); any
palette or type change (computed audit shows none is needed).

Payroll: $1,000 feature, accrues on founder verification.
