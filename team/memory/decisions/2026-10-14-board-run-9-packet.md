# Board run 9 — Tradition layers (packet / spec record)

Founder order (Tyson, Oct 14, 2026): "Add in the religions we can add."
Vision (his words): "you clicking a toggle for what religion you are a
part of and the app becomes your religion." Research verdicts:
`decisions/2026-10-14-product-questions-backlog.md` + the deep-research
report in `~/workspace/research_notes/woven-word-tradition-layers-legal-routes-20261015-0012/`.

## Scope calls (Silas, recorded before building)

1. **One "Your tradition" selection** in Profiles replaces the run-8
   General Conference toggle. Values: Bible only (none) / Latter-day
   Saint / Jewish / Protestant / Catholic. Persisted as `ww_tradition`;
   migration: absent key + `ww_conference_layer == true` → Latter-day
   Saint. First-run picker deferred (Profiles is the run-8 home; one
   screen at a time).
2. **Canon presentation is a view over the core canon** for none / LDS /
   Protestant / Jewish (Jewish = Tanakh order and JPS book names over
   the 39 OT books; the New Testament is not presented in Jewish mode).
   User verse keys stay in core-canon space — profiles, highlights,
   and notes are never touched by a tradition switch.
3. **Catholic grows the canon**: the seven deuterocanonical books
   (Tobit, Judith, Wisdom, Sirach, Baruch, 1 Maccabees, 2 Maccabees)
   arrive as an extra-canon table with WEB Catholic Edition text. They
   are readable in a paged deuterocanon reader. The woven web has no
   cross-reference data for them (OpenBible/TSK is the 66-book canon)
   and every Catholic surface says so plainly. Highlights/notes in the
   deuterocanon use reserved book indices (≥ 1000) in the existing key
   format, bounds-checked against the union canon.
4. **Catholic text = WEB Catholic Edition family only.** Douay-Rheims
   is deferred as its own package: its Vulgate versification (Psalm
   numbering above all) needs a verse-mapping table; keying DR text to
   core chapters would misalign most Psalms. Evidence for DR (status
   line, book list) is still collected this run.
5. **Catholic corpus (Catechism citations)**: terms check first. If no
   terms-clean route to the Index of Citations facts exists, the
   corpus ships BLOCKED with a written route analysis (the run-8 gate
   pattern) while canon + text ship. Fathers derivation is queued
   phase 2 either way. Spurgeon index likewise queued unless the
   confessions land early and clean.
6. **Jewish layer**: JPS 1917 text (Tanakh scope), Hebrew WLC text
   (Tanakh scope, RTL), Sefaria connections per verse (citing works +
   counts, link-out to Sefaria). Sefaria posture: documented
   developer programme + public export; per-item licences honoured
   (only PD/CC0 bundled); the ToU body could not be read by the
   studio's fetch routes (JS-rendered shell; re-checked Oct 14, 2026)
   — disclosed in the report, with a manual ToU read and written
   confirmation from Sefaria filed as pre-launch checklist items.
   NJPS 1985 never bundled, never a source.
7. **Protestant layer**: Westminster Confession + 1689 London Baptist
   Confession proof-text facts. Machine-readable sources only when
   the repo LICENSE file itself is opened and quoted (MIT/Unlicense/
   CC0/public domain); otherwise facts derived from the public-domain
   texts (OPC PDFs / CCEL plain text) with the derivation documented.
   Link-out per document (OPC / CCEL).

## Method law (unchanged from run 8)

Facts only; public-domain or expressly open texts only; no scraping
any site against its terms; no wholesale copying of anyone's finished
dataset; documented APIs/dumps preferred; ordinary-use pacing;
attribution kept; every route documented in a pipeline README with a
LICENSE-EVIDENCE file quoting the status lines relied on.

## Design law

Petra gates every new surface: contrast computed from ww_theme tokens,
≥48dp targets, closed radius scale, no dead controls, honest coverage
copy. The selection-rainbow ruling stands (ambient gold; selection
rainbow = distance encoding). Hebrew verses render RTL.

## Features for payroll (accrue on founder verification)

Tradition architecture; Jewish layer; Protestant confessions layer;
Catholic canon + text. $1,000 each per the ledger rules.

---

# Integration record (Maren, 2026-10-14)

Built as scoped, with these integration decisions recorded:

1. **CanonView jewish names come from the canon data** (core
   display names), with Tanakh ORDER + sections from the packet.
   A book is never called two things in two places (Library
   "Song of Songs" vs reader "Song of Solomon" was the failure
   mode avoided); the tradition changes order and grouping.
2. **Translation toggle law:** ≤3 options keep the shipped
   segmented toggle with compact labels (KJV/WEB/JPS/WEBC);
   >3 options (Jewish OT) ride a chip + menu with full labels —
   4 segmented buttons overflow the 360dp top bar by one button
   width (found by test, fixed structurally).
3. **WEBC Esther/Daniel:** eng-web-c folds Esther into Esther
   (Greek) and Daniel into Daniel (Greek). WEBC serves the 64
   core books whose versification it shares; Esther/Daniel
   chapters fall back to KJV text under the WEBC toggle (never
   blank, never misaligned), and their Greek editions read in
   full as deuterocanon books. Same never-misalign rule that
   deferred Douay-Rheims.
4. **Sefaria narrowing + cap:** canonical work titles (first
   comma segment), Reference category excluded (word-occurrence
   links), per-verse cap of 25 most-cited works with the full
   total recorded in "capped" and a "See all N links on
   Sefaria" sheet row — full analysis in
   tools/sefaria/README.md's integration addendum. Asset ships
   gzipped (4.85 MB), parsed in the compute isolate.
5. **CCC corpus: BLOCKED** (tools/catholic/CCC-ROUTE.md) —
   USCCB written permission is the named unblocking route for
   whole-Index extraction; Fidelis precedent noted, its file
   not used. Canon + text shipped without it; Profiles copy
   states "Catechism citations are not included yet."
6. **setTradition awaits the kicked layer load** (the run-8
   setConferenceEnabled contract), so callers awaiting a
   selection can read layer state.
7. **My Notes gained a textsLoader seam** (the TalkView
   pattern) when its deutero rows needed deterministic tests.
8. First-run tradition picker: DEFERRED (Profiles placement
   shipped; no evidence a first-run gate beats it, and the
   intro stays the static shipped one).
