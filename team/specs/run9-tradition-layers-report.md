# Board run 9 — TRADITION LAYERS report (Silas, Producer)

Date: 2026-10-14/15. Founder's order (Tyson, Oct 14, 2026):
"Add in the religions we can add." The run-8 General Conference
toggle generalizes into a **Your tradition** selection in
Profiles: the tradition switches the canon presented, the
connections corpus layered over verses, the translations
offered, and where reading links land. The woven Bible core
stays underneath; Bible only (no tradition) remains a
first-class state. Packet:
`team/memory/decisions/2026-10-14-board-run-9-packet.md`.

Verification of the final tree: `flutter analyze` — no issues.
Full `flutter test` — **242 tests, all passed**. `flutter build
web --release` — green. CI: [CI RUN — filled at ship]. Commits:
[COMMITS — filled at ship]. Signed APK: [APK — filled at ship].

---

## Architecture (shared by all traditions)

- `lib/data/tradition.dart`: `WwTradition` {none, lds, jewish,
  protestant, catholic}, persisted at `ww_tradition`; a pre-run-9
  install with `ww_conference_layer == true` migrates to lds.
  `translationsFor(tradition, {otBook})` scopes the reader's
  translation set per tradition and testament. Tanakh view uses
  core canon display names under Tanakh order and sections
  (Torah / Nevi'im / Ketuvim) — a book is never called two things
  in two places.
- `lib/data/scripture_text.dart`: five translations (KJV, WEB,
  JPS, Hebrew, WEBC), each chapter falling back to KJV when a
  translation's chapter is missing or empty — a held place never
  renders blank. WEBC extras read by slug.
- Tradition state lives on the shell; switching re-scopes Home /
  Library / reader layers and **never touches user data** —
  profiles, highlights, and notes are byte-identical after a
  switch (tested). Setters await the layer loads their callers
  read (LESSONS #38).
- Translation toggle law (LESSONS #37): ≤3 options keep the
  segmented toggle; >3 (Jewish OT) ride a chip + popup menu with
  48dp items — four segmented buttons overflow 360dp by 48px.

## Jewish layer

- **Texts (bundled, public domain).** JPS 1917 from eBible.org's
  USFM zip; the zip's own status file reads "Public Domain" and
  credits the Jewish Publication Society 1917 edition. 66 core
  slots, **23,145 verses**, zero chapter/verse-count mismatches
  against the core canon. Hebrew from tanach.us: the text is
  **UXLC 2.5, derived from WLC 4.20** — never represented as the
  WLC itself, per the site's own precision; its licence page
  states the biblical Hebrew text may be viewed or copied
  without restriction, and the WLC is public domain. 66 slots,
  **23,213 verses**, rendered right-to-left in the reader.
  NJPS 1985 is copyrighted — never bundled, never a source.
- **Citation facts (not bundled text).** Sefaria's public link
  export (13 CSVs, 3,899,752 rows read). The export's LICENSE.md
  licenses texts per-version only; **no Sefaria text is
  bundled** — this layer takes citation facts (which work cites
  which verse, and how often) and links out to sefaria.org.
  Pipeline narrowing, documented in `tools/sefaria/README.md`
  (LESSONS #36): canonical work titles (3,407 works), the
  Reference category excluded (lexicons link by word
  occurrence, not engagement), a per-verse cap of 25 works with
  each capped verse's full total recorded (534,526 triples;
  17,379 capped verses; 23,139 verses carry links). The cap is
  disclosed in-product: capped verses carry a "See all N links
  on Sefaria" row. Shipped asset: `sefaria.json.gz`, 4,848,303
  bytes (faithful output was 174 MB).
- **Known gap, disclosed:** Malachi 4 (global chapter 928) has
  no Sefaria links — Sefaria's Hebrew versification places
  those verses at Malachi 3:19–24 and the pipeline drops
  out-of-range refs rather than clamping. 928 of 929 OT
  chapters carry links; the sheet says so at point of use.
- **Sefaria Terms of Use — open item, stated plainly:** the
  ToU body could not be read through the available route (the
  page serves a JS-rendered shell). Standing posture:
  documented developer programme + public export use, facts
  only. A manual ToU read and written confirmation from
  Sefaria are **pre-launch checklist items**.

## Protestant layer (historic confessions)

- **Route: derivation for both documents** — proof facts
  extracted from the public-domain works themselves. WCF from
  the OPC's official PDF ("Confession of Faith with Scripture
  proofs", 159 pp.); 1689 from CCEL's PDF (Banner of Truth 1958
  underlying edition, public domain; CCEL's boilerplate claims
  no copyright in the underlying materials). Machine-readable
  candidates were opened and rejected with reasons recorded in
  `tools/confessions/LICENSE-EVIDENCE.md` (one demographically
  incomplete at 109 of 331 sections; one not retrievable as a
  file tree; one with no licence; one NOASSERTION). No
  confession text is bundled — facts only.
- **Dataset:** 2 documents (Westminster Confession 1647;
  1689 London Baptist Confession), **331 sections** (WCF 171,
  1689 160), **5,005 deduped proof edges**, independently
  re-verified against canon bounds on both sides. Neither host
  publishes per-section anchors, so every section links out to
  its document URL — no anchor was invented.
- **Queued:** the Spurgeon sermon index is phase 2 — no open
  dataset exists, it is a build-from-PD-texts package, and this
  run's remaining budget went to integration and the gate fix
  round.

## Catholic layer

- **Text (bundled, public domain).** World English Bible
  Catholic Edition, eBible.org edition `eng-web-c`
  (`eng-web-c_usfm.zip`; the packet's unhyphenated filename
  404s). The zip's status file reads "Public Domain." **73
  books emitted: 64 core-mapped + 9 extras.** The edition folds
  Esther into its Greek edition and Daniel into Daniel with
  Greek portions, so core Esther (16) and Daniel (26) have no
  WEBC mapping: under the WEBC toggle those chapters fall back
  to KJV, and the reader's label block now **says so** and
  points to the full Greek edition in the Catholic Old
  Testament grid (gate fix P1-3).
- **Deuterocanon:** 9 books, **161 chapters** (Tobit 14, Judith
  16, Esther (Greek) 10, Wisdom 19, Sirach 51, Baruch 6 —
  chapter 6 is the Letter of Jeremiah — 1 Maccabees 16,
  2 Maccabees 15, Daniel (Greek) 14), read in a dedicated
  paged reader with highlights and notes on reserved book
  indices ≥ 1000 — the same user-data store, the same keys
  discipline. The Library tile counts each book once: **46
  books · 1066 chapters** (gate fix P1-1); until the table
  loads, no OT tile renders at all rather than an undercounted
  one (P1-2). First-chapter note states honestly that the
  woven web does not yet cover the deuterocanon.
- **Catechism corpus: BLOCKED.** No terms-clean route to a
  whole-Index extraction exists: the USCCB flipbook is the
  only official full-Index host and reserves rights; the USCCB
  permissions policy requires written permission for this kind
  of extraction; vatican.va exposes no Index of Citations and
  its Legal Notes bar collection/reprocessing without written
  authorization. The Fidelis precedent (4,600+ mappings shipped
  as facts) is recorded; its dataset was not downloaded or
  copied (licence unstated). Full analysis:
  `tools/catholic/CCC-ROUTE.md`. Unblocking routes: USCCB
  written permission, or a small hand-built starter subset
  under fair-use review. The app copy says plainly: "Catechism
  citations are not included yet."
- **Douay-Rheims: deferred as its own package.** The eBible
  text is public domain (Challoner revision), but Vulgate
  versification (Psalm numbering) needs a verse-mapping table;
  keying it to core chapters would misalign most Psalms.
  Evidence in `tools/catholic/LICENSE-EVIDENCE.md`.
- **Queued:** Catholic Fathers derivation (public-domain
  Schaff ANF/NPNF) is phase 2.

## Latter-day Saint layer

Unchanged from run 8 — it is now one tradition among five
(`tradition == lds`); the run-8 conference sheet, talk
routing, and dot behaviour carry over byte-for-byte. The
run-8 persistence oracle moved to `ww_tradition`.

## Petra gate

First gate: **FAIL** — one P0, five P1s, six P2 notes. Fix
round landed all six exactly as specified, each with a test
lock; verification on the fixed tree: analyze clean, 242/242
tests, web release green.

- **P0-1** Deutero note editor rendered typed text at 1.02:1
  (the LESSONS #20 theme-fill trap: the field inherited the
  dark-tuned theme fill on a paper sheet). The field now sets
  every surface explicitly, as both shipped editors do; typed
  text recomputes at **17.12:1**, and the "Saving an empty
  note removes it." line is disclosed.
- **P1-1** Catholic Library tile overcounted the canon it
  names (48 books · 1090 chapters) against Profiles' "73-book
  canon": the Greek Esther/Daniel are alternate editions of
  core books. Both sums now exclude them: **46 books · 1066
  chapters** (grid tiles unchanged).
- **P1-2** The not-loaded fallback rendered the shipped 39-book
  tile — an undercount, permanently if the load failed. Catholic
  mode now renders the NT tile only until the union tile can
  render; the codifying test was renamed to match the code.
- **P1-3** WEBC Esther/Daniel fell back to KJV silently. The
  reader label block now names the fallback and points to the
  full Greek edition (copy in the Catholic section above).
- **P1-4** Deutero selected-verse blend sat below the 3.0
  floor (2.66–2.94). It now uses the core reader's audited
  formula exactly; recomputed inside adjacencies **3.35–4.11**
  across all five highlight tints.
- **P1-5** Deutero note sheet ignored reduced motion; it now
  passes `wwSheetAnimationStyle(context)` like every other
  sheet.

Re-gate (Petra, affected computations only): **PASS — ship.**
No remaining P0/P1 findings.
P2 notes recorded, no fix required: Profiles Jewish copy
tightening (Malachi 4), chip-menu label role, deutero radius
token drift (values legal), deutero top-bar label role,
stored-translation RTL on confession/My Notes snippets,
Catholic grid header redundancy.

## Lessons

LESSONS #34–38 distilled from this run: verify desk summary
numbers against the artifact on disk; never write placeholders
over pipeline-owned paths; narrow unshippable datasets at the
pipeline with the truncation disclosed in-product; control
counts are a layout budget at 360dp; load-kicking setters must
await when callers read the state.

## Payroll

Per the ledger: $1,000 per shipped feature on founder
verification — tradition architecture + Jewish layer +
Protestant layer + Catholic layer (canon and text; the corpus
is blocked, reported above) accrue when Tyson verifies this
build on his phone.
