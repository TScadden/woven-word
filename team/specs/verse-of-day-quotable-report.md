# Verse of the Day — quotable pool: ship record

**SHIPPED Oct 15, 2026.** Founder ruling (Tyson, Oct 15, 2026):
"It should make sure that the verses aren't just filler verses.
They should be ones that people can quote." Spec:
`team/specs/verse-of-day-quotable.md`. Gate:
`team/specs/verse-of-day-quotable-gate.md` (Petra, PASS).

## What shipped

The Verse of the Day pool no longer ranks by cross-reference
connections. A verse joins its canon's pool only if it clears a
signal floor, passes four encoded complete-sense predicates, and is
not on the 116-entry curatorial exclusion list (shipped as data,
`lib/data/verse_of_day_curation.dart`, auditable source
`tools/votd_curation/`).

- **Core canons (None / LDS / Protestant / Catholic): 410 verses** —
  each cited by ≥ 25 distinct talks in the bundled conference
  corpus, ranked citations → connections → canonical. Only 49 of
  the shipped 365 survive.
- **Jewish canon: 483 verses** — ≥ 55 cross-reference connections
  (the LDS conference signal is not used for the Tanakh), ranked
  connections → canonical.
- **Fallback** (citation counts fail to load): 365 by connections,
  the shipped ranking, still filtered.
- Card, pick math, tap routing, and local-midnight rollover are
  byte-for-byte the run 11 behavior.

## Verification

- Petra gate PASS: method review + sample audit (every 12th verse
  of each built pool plus each pool's 15 lowest-ranked; 47 core /
  54 Jewish) — **zero verses judged filler**; borderlines named in
  the gate (Daniel 2:42 weakest core member, kept; Luke 24:21 and
  Daniel 9:25, both named by Maren, kept with reasoning).
- Maren verify: `flutter analyze` clean; full suite **476/476** on
  the merged tree (459 from this package's tree + 17 reader-arch
  tests that landed concurrently); `flutter build web --release`
  green.
- Commits: app `fd6d2d9`, tests `38086a9`, records `dc9e1f9`,
  gate/lessons records `f9dc939`; merged to main at
  `30f0c985ad120e872e3b594538deda135f6b3977`.
- Final CI: run **38828627437**, success (android, web, ios, pages),
  head SHA = the merge commit.
- APK: `build-verse-quotable/woven_word_verse_quotable_arm64_20261015.apk`,
  **32,019,045 bytes**, arm64 split release; signer SHA-256
  `05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11`
  = the pinned fingerprint; mirrored to the `flutter-apk-latest`
  release at exactly 32,019,045 bytes.

## Notes

- Lessons distilled: 58–60 in `team/memory/LESSONS.md` (KJV
  punctuation cannot proxy complete sense; floors beat rank cuts
  in tie-dense distributions; prove audit coverage against the
  shipped rule's candidate set). Filed as 56–58 on the branch and
  renumbered at integration when two concurrent packages claimed
  56–57.
- One integration failure during the merge was the reader-arch
  package's own known test failure (its main CI failed
  identically); the upstream fix landed minutes later and the
  merged tree went 476/476. Not a regression from this package.
- Payroll: no new accrual. This package revises run 11's Verse of
  the Day before founder verification of run 11; run 11's $3,000
  accrual stands as recorded.
- Awaiting founder verification on device: the new rotation's feel
  (the pool is a different 410 verses; the day's verse changes
  everywhere), and the lower connection counts on citation-pool
  captions (e.g. Matthew 22:38 captions "1 connection" — correct
  data, named in the gate).
