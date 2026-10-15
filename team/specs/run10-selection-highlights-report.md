# Board run 10 — report: text-selection highlighting

Founder request (Tyson, 2026-10-15): "Can you make it so instead
of highlighting the whole text we can hold down and select exact
text we want then highlight it"

Spec: `run10-selection-highlights.md` · Gate:
`run10-selection-highlights-gate.md` (Petra — PASS) · Founder
rulings: `team/memory/decisions/2026-10-15-highlights-notes-per-translation.md`
(per-translation sets; canon dormancy).

## What shipped

**Exact-span highlighting.** Long-press on a verse enters
selection mode for that verse; inside the mode a drag or second
long-press takes the exact words with platform handles, and the
app's own selection bar (five 48dp swatches, Clear, Copy —
352dp at phone width) colors exactly the selected character
span. Clear on the bar removes only the selected range (it
splits a span, keeping both tails). Works identically in the
chapter-page reader and the deuterocanon reader (under `webc`).

**Why a mode (the run's engineering call).** The first
construction made verse text an always-on `SelectableText`;
the shipped pager tests proved it broken — on Android the
text-selection drag recognizer wins the gesture arena eagerly
and claims horizontal swipes starting on text, so pages would
not turn from a text start. Selection is therefore a mode:
at rest the verse is the shipped plain rich text and every
shipped gesture (tap, paging, scroll, the back ladder) runs
the shipped code path. Petra gate §3 owns the evidence.

**The verse toolbar stays verse-scoped** (the producer's call
on the brief's open choice): its color row now writes a
full-verse span; tapping the active color or None clears the
verse's spans in the current translation. The toolbar and the
selection bar are mode-exclusive — opening one closes the
other.

## Data model + migration

Store v3. Per profile, per translation set (`kjv`, `web`,
`jps`, `hebrew`, `webc`): spans `{v, s, e, a, c}` (verse key,
start, end with −1 = to verse end, anchor substring, color)
and notes per verse key. Spans per verse are kept disjoint by
subtraction arithmetic; multiple spans per verse are normal.

Migration (structural, in the document parser): a pre-v3
document's whole-verse highlights become full-verse spans and
its notes move, wholesale, into the set of the translation
active at upgrade (the reader's stored preference); nothing is
duplicated into other sets. A legacy backup imports under the
same rule with the translation active at import. The run 6
strict validator keeps its four rejection classes; a v3
backup round-trips byte-exact.

## The translation rule (for the founder)

**Your highlights and notes now belong to the translation you
made them in: switch translations and you see that
translation's set, switch back and yours are exactly where
you left them.**

And its canon companion, also the founder's ruling: tradition
is never a data scope — a highlight or note whose book is
outside the current tradition's canon is dormant (stored
untouched, invisible) and returns exactly when the tradition
presents its book again and its translation is active.

## Verification (Maren)

- `flutter analyze`: No issues found.
- `flutter test`: 269/270 locally. The one failure
  (`conference_shell_test: default off`, a ShellController
  dispose race) fails identically on the untouched run-9 HEAD
  tree in this environment (241/242) — pre-existing; CI is
  green on the final tree (below).
- `flutter build web --release`: green.
- 28 new tests: span arithmetic, per-translation isolation,
  v1/v2 migration fixtures (stored preference at WEB), v3 +
  legacy backup handling, SEL-1…SEL-7 (mode entry, no page
  turn on selection drag, page turn from text at rest, exact
  span write, resting tint render, toolbar full-verse span,
  translation swap, range Clear, deutero span), DORM-1…DORM-3.
  Every shipped test was translated to the new model; none
  deleted.

## Ship record

- Commits: `82db5cd` (app), `efc1955` (tests); records and
  this report follow on the same tree.
- CI: run **38699930342 — SUCCESS** (ios, web, android jobs
  all green on the final tree; the local-only conference
  failure above does not occur in CI).
- APK: `woven-word-flutter.apk` from run 38699930342's
  `woven-word-flutter-apk` artifact, 32,010,573 bytes, staged
  at `build-run10/`. Signer certificate SHA-256 parsed from
  the APK signing block:
  `05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11`
  — identical to the pinned fingerprint recorded in the repo.

## Lessons distilled

#39 (selection is a mode in paged readers), #40 (re-seed
superseded scenarios, never just re-assert), #41 (a red test
is a regression only after a same-environment HEAD baseline).

## Payroll

$1,000 feature — accrued, pays on founder verification.
Device check owed: the long-press → drag-handles → color feel,
and swipes starting on text outside selection mode (F-2's
surface).
