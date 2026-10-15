# Packet — Board run 11: Home Study Sections (2026-10-15)

Producer: Silas. Desks: Petra (spec + QC gate), Maren (build + verify).

## Founder request (Tyson, Oct 15, 2026), verbatim

"I like the study plan, study tools, and verse of the day things on the
home screen of the gospel library app. Can we have something like it on
our home screen?" — with three Gospel Library Home screenshots
(feedback/gl-home-1/2/3-20261015.png). Patterns adapted, never cloned:
GL artwork, branding, and content are not used; all data is ours and
on-device.

## Producer decisions (binding, filed in the spec §0.2)

1. Home scroll order: Continue reading → Verse of the Day → Study
   Plans → Study Tools. The standing STUDY/My Notes row is retired
   into Study Tools (one door to My Notes, still one tap from Home).
2. Verse of the Day: pool = 365 most-connected verses in the app's own
   cross-reference data (verseConnections count, canonical tie-break),
   restricted to the active tradition's canon; verse = pool[local
   days-since-epoch % pool.length]; text in the active translation;
   card shows reference + connection count; tap opens the reader at
   the verse via the My Notes routing path.
3. Study Plans: exactly three, generated from canon data — The
   Gospels (89 chapters / 30 days), Psalms & Proverbs (181 / 60),
   The Whole Bible (1,189 / 365). A plan is offered only when all its
   books are in the active canon. State lives outside UserData in
   SharedPreferences `ww_plans_v1`, per profile. Start is explicit;
   completion is per-chapter check toggles on the plan detail screen;
   Restart with a confirm dialog. Tradition switches never mutate
   plan state (dormancy).
4. Study Tools: My Notes / Highlights / Profiles icon-over-label
   entries with live counts; Highlights opens the new All Highlights
   screen (every span of the active profile + active translation,
   grouped by book/chapter in canon order, run-10 visibility rule,
   tap routes to the reader).

## Ratifications of spec interpretations (Silas, on the filed spec §0.3)

- I-1: the chapter selection panel keeps its slot directly after
  Continue reading ("untouched" read strictly).
- I-2: schedule distribution is base/remainder (§4.2), NOT fixed
  ceil chunks — the ceil reading empties 14 days of Psalms &
  Proverbs and 67 of the Whole Bible (lesson 46).
- I-3: the Study Tools My Notes caption uses the shipped visible
  count (canon + active-translation filtered).
- I-4: All Highlights has two empty branches (§6.3); the producer's
  `No highlights yet in <translation>` copy governs the
  empty-active-set branch.

## Gate (Petra): PASS — team/specs/run11-home-study-sections-gate.md

All six checks evidenced on the committed tree at 941a150 (copy
fidelity, contract fidelity, re-derived numbers — Gospels day 30 = 2
chapters, Psalms & Proverbs day 60 = 3, Whole Bible day 365 = 3;
verse pool exactly 365, floor 77 connections; 15/15 availability
cells — contrast recomputed to 2 decimals, geometry asserted from
rendered positions at 360dp / text scale 2.0, dormancy byte-identical
at pure and shell level). Deviations ratified, none blocking:
D-1 plan cover clamps text scale ≤1.0 inside the cover (Petra's §10
premise error, owned in the gate; spec amended below — lesson 48);
D-2 fix commit 941a150 re-landmarks three shipped test files
(lesson 40); D-3 letter-only (_loadUserData also refreshes the plan
snapshot after list-screen pops; read-only, no observable change);
D-4 noted (verse-pool cache keys on tradition; the shell's BibleData
is one immutable load, unobservable). M-1 minor: one semantics
`checked`-flag assertion is code-present but not suite-asserted —
optional follow-up, not a ship blocker.

## Ship record

- Implementation landed in commit 79992d8 (17 flutter files, +4,388)
  — swept into the arch-ambient package's records commit in the
  shared working tree (lesson 47; declared here, payload re-derived
  from `git show --stat`); fix commit 941a150 on top.
- CI: 'Build Flutter app' run 38797275227, completed success at head
  941a150 (android/ios/web green; 342 tests passed, 0 failed).
  Signer SHA-256 in that run's log: 05d5a45cf52fd141a54e2ecfd00472a
  568c9c0bdffd0458e44ba52bfe4b5be11 — the pinned digest (lesson 10).
- APK staged: build-run11/woven_word_run11_home_20261015.apk,
  32,076,265 bytes, from that green run's woven-word-flutter
  artifact.
- Local pre-existing failure (lesson 41 baseline, unchanged): the
  conference dispose race fails locally at HEAD and is green in CI;
  it is not a run-11 regression.

## Sequencing state (Rusty's note, executed by Maren)

At Maren's landing check, run 11 was not last: the reader-theme
package's work was still uncommitted and the Library search-fix
commits (004b236 + 7c3ab32, branch search-fix-verify) were NOT on
main (verified by merge-base and subject search), so no cherry-pick
was performed by this package. The reader-theme package has since
landed after run 11 (c5579be, dcecb9c, 9f5836b) — and its landing
did not include the cherry-picks. At this records push the
search-fix commits remain off main and the final-tree CI
confirmation for the fully combined tree is still outstanding;
flagged to Rusty to close with that package. (Its lessons took
43–45; run 11's distilled lessons are 46–48.)

## Payroll

Three features accrued at $1,000 each (Verse of the Day; Study
Plans; Study Tools + All Highlights) — team/payroll/LEDGER.md,
Accrued section. They pay when Tyson verifies on his phone.
