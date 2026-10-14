# Decision: goldBright fill exception ratified, narrowed (2026-10-14)

Board run 3 (reader), Petra gate on commit a5202ac, Flag‑1 and Flag‑2.
Decided by Silas under the studio's palette jurisdiction (TEAM.md:
palette changes must pass the design-audit contrast rules and be
reported with rationale). Founder may override on review.

## Flag‑1 — goldBright as a fill on paper: RATIFIED, narrowed

Run 2's palette law (LESSONS.md #13) documents `goldBright` as
dark-surfaces-only. The reader's KJV/WEB toggle uses a `goldBright`
FILL on paper behind an `onGold` label for the selected segment —
an exception the engineer wrote into a code comment in the same diff.
A comment cannot amend palette law; this record does, narrowly:

- PERMITTED: `goldBright` as a selected-state / primary-action FILL on
  paper, only behind an `onGold` label (the pair computes 9.71:1).
- STILL PROHIBITED: `goldBright` as text, icon, or border on paper
  (1.89:1 against paper). Any other on-paper use needs its own audit
  record before it ships.

Rationale: one gold for primary/selected actions app-wide — the
reader toggle's selected fill now matches Home's Read button
(`goldBright` fill + `onGold` label, 9.71:1). The compliant
alternative (`gold` fill, 5.72:1 text) would give the app two
different primary-action golds. Selected state stays identifiable
without the fill: label color (`onGold` vs `goldTextOnPaper`), weight
(w700 vs w600), and the bordered track. No user is blocked either
way; coherence wins.

## Flag‑2 — toggle segment geometry: RATIFIED

Each toggle option rounds all four corners at `WwRadius.chip`, so the
selected fill reads as a pill inside a bordered track rather than a
continuous segmented bar. Radii are inside the closed scale; the
pill-in-track look is accepted as the reader toggle's character.
Revisit only if the founder dislikes it on the phone.
