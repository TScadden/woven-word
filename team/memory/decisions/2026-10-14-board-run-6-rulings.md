# Decision: Board run 6 rulings under the founder's delegation (2026-10-14)

The founder reviewed the overnight board's morning brief and delegated
every open ruling to Rusty (Tyson, Oct 14, 2026: "Do whatever you think
is best"). Rusty's rulings, which board run 6 executes and records:

1. **Offset-model home scrolling — APPROVED.** The lesson-14
   limitation closes properly: home's list gets an exact offset model
   (deterministic layout math, ground-truthed in tests), so jump
   search and relaunch restore scroll to the target book's section
   even on cold jumps to sections never built.
   *Correction (Petra flag F-2, board run 6):* an earlier draft of
   this item also named partner taps as a scroll path. That was
   wrong — ruling 4 below governs: partner chips open the reader
   and never scrolled. The offset model serves search and restore
   only.
2. **User-data export + import — APPROVED.** Export is a share-sheet
   JSON of the full `ww_user_data` document from the Profiles screen.
   Import picks a JSON file, validates it against the store's
   defensive-load rules, and replaces the current document wholesale
   behind an explicit confirm that names what will be replaced and
   states it cannot be undone. A malformed file changes nothing.
3. **My Notes snippets follow the active translation — CONFIRMED
   correct, standing, no build action.** Notes themselves stay
   translation-independent by design (run 4/5 model); the verse text
   shown beside them follows the reader's active translation.
4. **Partner chips open the reader — CONFIRMED, standing, no build
   action.** This is the founder's own Oct 13, 2026 direction,
   executed in board run 3; the morning brief's flag is answered:
   chips open the partner chapter to read, they do not re-select it.
5. **iOS launch screen stays plain black — CONFIRMED, standing, no
   build action.** Flagged in board run 1 (the template LaunchImage
   is a transparent placeholder); the black stage is the accepted
   launch presentation on iOS.

Payroll settles with this record: the founder's delegation accepts
the overnight stack, so the closed board's shipped features pay out
per the ledger (see `team/payroll/LEDGER.md`, settled 2026-10-14).
The retired WP1 sequence pays nothing (established in the intro
decision, `2026-10-14-intro-decision.md`).
