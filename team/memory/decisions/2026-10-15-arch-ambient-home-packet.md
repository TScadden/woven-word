# Packet: Home arch goes ambient — ship record (2026-10-15)

Founder ruling: team/memory/decisions/2026-10-15-home-arch-ambient-ruling.md
Spec: team/specs/arch-ambient-home.md · Gate: team/specs/arch-ambient-home-gate.md (Petra PASS, no fix items)

## As shipped
- Home's arch is an ambient visual: every 3s a Ticker features a new
  chapter drawn uniformly at random from the active tradition's canon
  pool (no immediate repeat), arcs morphing over 600ms easeInOut;
  caption under the stage: "<Chapter> · <N> connections", one >=48dp
  semantics target, tap opens the featured chapter in the reader.
- Eligibility floor = 25% of the canon's median per-chapter
  connection count, measured on the shipped asset: core median 495
  -> floor 123.75 -> pool 1,165; Jewish median 429 -> floor 107.25
  -> pool 915. Deuterocanon chapters carry no arc data and are not
  featured (Catholic pool = full-core pool). Sparsest eligible
  chapter still draws 49 arcs (gate-verified).
- Pause matrix: tab invisible, app backgrounded, route above Home,
  any descendant scroll, pointer held, reduced motion (single still
  chapter, ticker never starts).
- The Home selection panel is deleted; every Home chapter entry and
  Library grid tap opens the reader directly. ww_home_selected is
  retired (stale key removed on load, never restored); ww_home_scope
  and Continue reading unchanged.
- Connections live in the reader: the verse connections sheet ends
  with a "<Chapter> connects to" section — shipped partnersSorted
  ranking, >=48dp rows, tap opens the partner chapter; an empty-state
  line keeps every chapter reachable, no dead ends.

## Commits on main
- de98a28 spec · 5effec1 spec correction · 9d09f36 app
- 37d3cfa tests (24 new; 438/438 full suite local) · 6df71dc Petra gate
- 8062d71 records (payroll accrual $1,000; lessons 52-53)

## Ship verification
- CI "Build Flutter app" run 38810752884 — SUCCESS on head 8062d71.
- APK: build-arch-ambient-home/woven_word_arch_ambient_home_20261015.apk
  (32,076,557 bytes, from that run's artifact); signer SHA-256
  05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11
  (pinned keystore, parsed from the signing block); package string
  confirmed in libapp.so.
- Payroll: $1,000 accrued, pays on founder verification.
