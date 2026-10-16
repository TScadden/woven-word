# Petra gate — Verse of the Day, quotable pool

**Gate: PASS.** Package: VERSE OF THE DAY — QUOTABLE POOL.
Spec: `team/specs/verse-of-day-quotable.md`. Branch
`verse-quotable` at `dc9e1f9` (app `fd6d2d9`, tests `38086a9`,
records `dc9e1f9`), audited Oct 15, 2026. (The spec's §6 named a
`team/reviews/` path for this file; house convention is
`team/specs/*-gate.md`, so it files here.)

Founder's words, the standard for this gate: "It should make sure
that the verses aren't just filler verses. They should be ones that
people can quote."

## Method review

The method is three layers, and each layer earns its place:

1. **Signal floor.** Core canons: cited by ≥ 25 distinct talks in
   the bundled conference corpus (1951–2026, 4,964 talks). Jewish
   canon: ≥ 55 cross-reference connections, the conference signal
   withheld there because the corpus is a Latter-day Saint corpus —
   stated in the spec, not disguised. A floor instead of a top-365
   rank cut is the right call on the measured distribution: the
   citation band is tie-dense at the cut, and a rank cut at 365
   lands at 27 citations and throws out John 11:35 ("Jesus wept.",
   25 talks) to keep dream-interpretation detail. The floor admits
   nothing the signal has not vouched for, which is the founder's
   complaint answered structurally.
2. **Encoded predicates P1–P4** (begat; itinerary log; census /
   name-list; name density ≥ 0.45). Each was validated at zero hits
   among verses cited ≥ 10 and ≥ 20 times before adoption, and the
   two plausible-but-wrong signals (terminal punctuation, looser
   name/number thresholds) were measured and rejected — Matthew
   28:19 and John 11:25 end in colons and are among the most quoted
   verses in the corpus. At today's floors the predicates bind
   nothing; they are the standard's standing guard and the fallback
   pool's worker. Accepted as specified.
3. **Curatorial exclusions (116).** Every candidate at both floors
   was read in ranked context (504 core candidates, 505 Jewish,
   plus the fallback range) against the bar: printed alone, a
   complete thought people quote. Coverage was proven
   set-theoretically against the shipped rule's candidate sets, not
   assumed from the analysis files — an early counting pass had
   used un-deduped citation counts, and the re-derivation confirmed
   every true candidate had been read (the counts differed; the
   candidate universe at the floors did not).

Deviations Maren flagged are all sound: the spec signature drops
`poolSize`; the texts-failure card branch retires with the
section-gating rule; the counts function follows the spec text and
its agreement with the full parse on shipped data is pinned by
test (68,999 edges, totals exact).

## Sample audit of the built pools

Sample: every 12th verse of each built pool plus each pool's 15
lowest-ranked verses — 47 core, 54 Jewish — read against the bar.
The built pools match the audited derivation exactly (Maren's
independent rebuild from the branch's assets: 410 / 483 / 365,
same tails; the data tests pin the same numbers and exemplars).

**Result: zero verses in either sample judged filler.**

Named borderlines, with the calls recorded:

- **Daniel 2:42** (core, rank 372) — the weakest core sample
  member: a dream-interpretation detail ("the kingdom shall be
  partly strong, and partly broken"). Kept: it is a complete,
  pointed proposition, and Daniel 2's interpretation sequence is
  quoted as a sequence. Named here so the record shows the gate
  saw it.
- **Luke 24:21** (core, rank 408; named by Maren) — the Emmaus
  disciples' report voice ("But we trusted that it had been he
  which should have redeemed Israel…"). Kept: the disappointed
  hope is the verse's quoted content; it is a complete statement,
  not a plot report of the Luke 24:19/22/23 kind, which are
  excluded.
- **Daniel 9:25** (Jewish, rank 476; named by Maren) — the
  seventy-weeks chronology. Dense, and a complete proposition that
  prophecy study quotes constantly. Kept.
- **Luke 24:29** (core, rank 240) — reads as plot until the speech
  is noticed: "Abide with us: for it is toward evening" is the
  content. Kept.
- **1 Kings 3:9** (Jewish, rank 360) — a request, but not a SETUP
  exclusion: Solomon's petition for an understanding heart is
  itself the celebrated content, unlike a question whose substance
  is the next verse's answer. Kept.

One presentation note, not a finding: Matthew 22:38 ranks #5 in the
core pool on 171 citations with a single cross-reference
connection, so its card captions "1 connection" — correct data
under the shipped card design; the citation pool's captions will
read lower than the old connection pool's did. That is the method
working as intended, and the founder should hear it from the
report rather than discover it.

## Verdict

The pool the founder asked for: every verse in it is there because
speakers demonstrably reach for it (core) or because it stands at
the center of the Tanakh's cross-reference web (Jewish), and every
one of them passed a complete-sense read. Only 49 of the shipped
365 survive — the size of that change is the measure of the
problem the founder named. **PASS.** Cleared for merge, final CI,
and the arm64 staging step.
