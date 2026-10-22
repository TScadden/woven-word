# PETRA — GATE RECORD, RUN 10 FIX ROUND: SELECTION LONG-PRESS ENTRY

**Verdict: PASS — cleared to land.**
**Trigger:** founder, run-10 phone verification (Oct 22, 2026):
"All that works. Holding down to select is a little difficult
though. It doesn't always select."
**Scope:** the selection-mode ENTRY gesture only, both readers.
No change to the mode itself, the §2.2 bar, the span model, or
any shipped at-rest gesture path.

## Root cause (verified against the code)

Entry was InkWell's stock long-press recognizer: 500 ms
deadline, 18 px pre-acceptance slop (the touch-slop default).
Three compounding failures:

1. 500 ms is longer than a natural hold — presses released at
   ~350–450 ms never fired.
2. Drift past 18 px inside that window let the pager's
   horizontal drag or the page's vertical drag claim the
   gesture arena and reject the press.
3. A press that DID fire changed nothing visible — the mode
   swaps plain `Text` for an identical-looking
   `SelectableText` — so success read as failure.

## What changed

- `lib/widgets/verse_long_press.dart` (new): per-verse
  `VerseLongPressDetector` registering a
  `SelectionLongPressRecognizer` — deadline **350 ms**,
  pre-acceptance drift tolerance **42 px** — in the same arena
  as the shipped drags. InkWell keeps tap and ripple; its
  `onLongPress` is gone from both readers.
- The detector registers NOTHING while its verse is in
  selection mode (`enabled: !selecting`): inside the mode a
  long-press belongs to the SelectableText. (Caught by SEL-2,
  SEL-6, SEL-7 going red the moment the tuned recognizer could
  steal the in-mode word-taking press — the stand-down is the
  fix, and those tests are its guard.)
- Immediate feedback on acceptance: `HapticFeedback.
  selectionClick()` in both `_enterSelection`s, and the verse
  block's existing 2 dp accent outline now also renders while
  the verse is in selection mode.
- Both readers (core + deuterocanon) received the identical
  treatment.

## Audit notes

- **No new tokens, no new radius, no new type role.** The
  outline is the run-4/§3.2 audited construction (`accent` =
  `goldTextOnPaper`: 4.62:1 on paper; 3.35–4.11:1 on the
  selected composites, inside the ≥ 3.0 boundary band,
  LESSONS #17) reused for a second STATE of the same element —
  the state matrix gained a row, not a surface.
- **350 ms is a recognition deadline, not a design duration**
  (no animation exists in this feature; §3.4's reduced-motion
  rule is untouched). It sits inside platform norms for
  long-press (Android's own timeout is 500 ms; 350 ms is the
  responsive end used by leading readers) and inside a natural
  hold.
- Haptic is the platform selection feedback (selectionClick);
  it fires once, at acceptance, nowhere else.

## Considered and rejected (with evidence)

Raising the paging/scroll drags' touch slop to 28 px via
MediaQuery gestureSettings, so drift could not steal the
arena. The shipped suite caught it: R-T10 failed (in-page
vertical drag left the scroll offset at 0). Mechanism, from
the framework: a drag recognizer that accepts late discards
the offset already traveled, so any slop raise taxes the
start of every scroll by exactly that raise — the shipped
18 px is the budget, not a tunable. The deadline cut closes
the steal window instead: movement crossing 18 px within
350 ms is a swipe, and the page rightly takes it. Distilled
as LESSONS #49.

## Evidence (re-derived at the gate, lesson 34)

- Baseline at HEAD (same environment): run10_selection +
  deutero_reader = 14/14; R-T10 green at HEAD.
- With the fix: analyze clean; selection + deutero + reader +
  toolbar suites 50/50; full suite **535/535**; web release
  build green.
- New tests SEL-8/SEL-9/SEL-10 (drift press enters the mode,
  both readers; slow drag is a scroll, not a selection).
  **Mutation-verified:** SEL-8 and SEL-10 FAIL on the pre-fix
  tree (lib stashed) and pass with the fix. SEL-2/6/7's
  in-mode regression and its stand-down fix are recorded
  above.
- Payroll: no new accrual — this is a fix to run 10's feature;
  run 10's $1,000 still accrues on the founder's verification,
  now of the fixed entry.

## Founder verification owed

Re-run of the run-10 checklist item 1–2 on the phone: hold a
verse (the outline + tick should register the press), drag the
handles, color a span.
