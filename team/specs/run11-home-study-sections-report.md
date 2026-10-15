# Board Run 11 — HOME STUDY SECTIONS: SHIP RECORD

**From Silas (Producer) to Rusty.** The founder's order — "I like the
study plan, study tools, and verse of the day things on the home
screen of the gospel library app. Can we have something like it on
our home screen?" — is built, gated, CI-green, and staged for phone
delivery. Spec: `team/specs/run11-home-study-sections.md`; gate:
`team/specs/run11-home-study-sections-gate.md` (Petra: **PASS**);
packet: `team/memory/decisions/2026-10-15-board-run-11-packet.md`.

## The three sections, as built

Home's scroll order is now: Continue reading → (chapter selection
panel, slot unchanged) → **Verse of the Day** → **Study Plans** →
**Study Tools**. The old STUDY/My Notes row is retired into Study
Tools — My Notes still sits exactly one tap from Home.

**Verse of the Day.** A Home card with the full text of one verse in
the active translation, its reference, and its connection count.
The verse is chosen by a deterministic on-device rule: the pool is
the 365 verses with the most cross-reference connections in the
app's own data (ties broken by canonical order), restricted to the
active tradition's canon; the day picks `pool[local days since
epoch % 365]` — the same verse all day, changing at day rollover,
no repeat within 365 days. Tapping the card opens that chapter in
the reader at the verse.

**Study Plans.** Three built-in plans as cover-style cards with a
progress bar across the cover's bottom edge: **The Gospels**
(Matthew–John, 89 chapters, 30 days), **Psalms & Proverbs** (181
chapters, 60 days), **The Whole Bible** (1,189 chapters, 365 days).
Schedules are generated from canon data by a base/remainder
distribution (day sizes differ by at most one chapter; no empty
days). The completion mechanism, stated plainly: on the plan detail
screen each chapter carries a check toggle — tapping the check
marks that chapter read, tapping the chapter's label opens it in
the reader; progress is checked chapters over total chapters, and
"Day N" counts from the day the user taps Start plan. State is
per profile, on-device (`ww_plans_v1`, outside the backup format).
A plan is offered only when all its books are inside the active
tradition's canon, and switching tradition never loses progress —
an out-of-canon plan is simply not offered until the tradition
presents its books again.

**Study Tools.** Three icon-over-label entries on one card —
**My Notes** (caption: your visible note count), **Highlights**
(caption: your highlight count in the active translation),
**Profiles** (caption: the active profile's name) — each deep-links
to a real screen. Highlights opens the new **All Highlights** view:
every span highlight of the active profile in the active
translation, grouped by book and chapter in canon order, with the
highlighted text on each row; tapping a row opens the reader at
that verse. Deuterocanon highlights appear under Catholic and route
to the deuterocanon reader, under the same visibility rule as
notes.

Everything runs with the conference layer off and under every
tradition; the sections follow the active canon and translation.

## Gate and verification

- Petra's first computed audit caught one token before build
  (`borderDark` as a check border: 1.47:1 on surface — reassigned
  to `mutedOnDark`, 6.03:1) and one spec-side error she owned at
  the gate (D-1: the fixed 112×144 plan cover cannot fit
  ambient-scaled text at scale 2.0; the shipped build clamps text
  scale inside the cover only, with the same words at full scale
  outside it). Gate verdict: **PASS**, every number re-derived
  from the shipped tree (schedule spot-globals, pool floor of 77
  connections, 15/15 tradition availability cells, contrast to 2
  decimals, dormancy byte-identical at pure and shell level).
- Maren: `flutter analyze` clean; `flutter test` green; web
  release green. CI **run 38797275227 — completed success** at
  head `941a150` (342 tests passed, 0 failed). The one red seen
  locally (conference dispose race) fails identically on the
  untouched HEAD tree in this environment and is green in CI —
  pre-existing, baseline attached (lesson 41).

## Commits and APK

- Implementation: `79992d8` (17 flutter files, +4,388 — the run-11
  payload landed inside the arch-ambient package's records commit
  in the shared working tree; declared in the packet, lesson 47),
  fix commit `941a150` (shipped-test re-landmarks on the new Home,
  lesson 40).
- APK: `build-run11/woven_word_run11_home_20261015.apk`,
  32,076,265 bytes, from the green run's artifact; signer SHA-256
  `05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11`
  in that run's log — the pinned key.

## Open items stated plainly

- **Sequencing:** the Library search-fix commits (004b236 +
  7c3ab32) are still not on main. Run 11 was not last to land; the
  reader-theme package landed after it (c5579be..9f5836b) without
  performing the cherry-picks, so the fully-combined-tree CI
  confirmation remains outstanding — flagged to Rusty to close
  with that package.
- **Payroll:** $1,000 × 3 features (Verse of the Day, Study Plans,
  Study Tools + All Highlights) accrued in the ledger; they pay on
  Tyson's phone verification.
- Lessons 46–48 distilled (arithmetic rules verified per instance;
  commit file lists in a shared tree; fixed-geometry text budgets).
