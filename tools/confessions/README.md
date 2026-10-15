# Confessions proof-text pipeline — Woven Word board run 9 (Protestant layer)

Builds `flutter/assets/confessions.json`: citation **facts** only —
which sections of the Westminster Confession of Faith (1647) and the
1689 London Baptist Confession cite which Bible verses — as
`(section, globalChapter, verse)` edges into the core canon of
`flutter/assets/data.json` (66 books, global chapters 0–1188).
No confession text, and no quoted Bible text, is bundled.

Governing scope call: `team/memory/decisions/2026-10-14-board-run-9-packet.md`
call 7 — machine-readable sources only when the repo LICENSE file
itself is opened and quoted; otherwise facts derived from the
public-domain texts (OPC PDFs / CCEL) with the derivation documented.
This run took the derivation route for **both** documents (see
"Route selection" below).

## Output shape

```json
{"v": 1,
 "docs": [{"id": "wcf", "title": "Westminster Confession of Faith",
           "year": 1647, "url": "https://opc.org/wcf.html"},
          {"id": "lbc1689", "title": "1689 London Baptist Confession",
           "year": 1689, "url": "https://ccel.org/ccel/anonymous/bcf.html"}],
 "sections": [{"d": 0, "id": "1.1", "label": "Chapter 1 · Section 1"}, …],
 "edges": [[sectionIndex, globalChapter, verse], …]}
```

Edges are deduplicated and sorted. `globalChapter`/`verse` are the
core-canon coordinates of `data.json` (`book.start + chapter − 1`).

**Section structure mirrors each document's real divisions.** The WCF
is divided into chapters and numbered **sections** (33 chapters, 171
sections): label `Chapter N · Section M`, id `N.M`. The 1689 is
divided into chapters and numbered **paragraphs** (32 chapters, 160
paragraphs): label `Chapter N · Paragraph M`, id `N.M`. Sections are
listed WCF first (`d: 0`), then 1689 (`d: 1`); edge section indices
refer to that combined list.

## Route selection (per document)

**Checked first (packet route 1), not used for either document:**

| candidate | what was verified | outcome |
|---|---|---|
| `github.com/normanormata/westminster_cli` | Repo page: "License: MIT License (MIT)"; README: corpus is WCF + Larger + Shorter Catechisms derived from OPC, entries carry `proofs` arrays (letter → references). Covers the WCF only — no 1689. Head commit observed: `3fdd5fcf37180e3ede551193c572f7d43a52810a`. | Not ingested (see below). |
| `github.com/ReformedDevs/christian-standards` | Repo page: "License: MIT License (MIT)"; README: carries WCF and LBCF among its confessions, paragraphs carry `proofs[]`; its own README notes document texts are public domain where noted and "Repository metadata and schema are MIT". Head commit observed: `30a52cd15b858aca943db433242dabc6eb51de3d`. | Not ingested (see below). |

When the ingest step called the GitHub API to pin the exact commit
and open the actual `LICENSE` files, the API returned **HTTP 403
"rate limit exceeded"**. Under the studio's rate-limit rule that is
a hard stop for that provider for the run: no retries and no
workaround through another GitHub endpoint. The packet's condition
for route 1 — the LICENSE file itself opened and quoted, the exact
commit pinned — therefore could not be completed, and **no data
from either repository is in the asset**. Both documents were
derived under route 2 instead. (The repo-page licence status lines
that *were* read are recorded in `LICENSE-EVIDENCE.md` under
"checked, not used".)

**Used (packet route 2, both documents):**

| doc | source (publisher's own site) | raw file in `sources/` |
|---|---|---|
| WCF | Orthodox Presbyterian Church, standards page `https://opc.org/confessions.html` → "Westminster Confession of Faith with Scripture proofs" PDF, `https://opc.org/documents/CFLayout.pdf` | `wcf_opc_proofs.pdf` (615,268 bytes, sha256 `d24cbbcdd3e581f2…`) |
| 1689 | Christian Classics Ethereal Library, work page `https://ccel.org/ccel/anonymous/bcf.html` → PDF `https://ccel.org/ccel/a/anonymous/bcf/cache/bcf.pdf` ("…with Scripture Proofs") | `lbc1689_ccel.pdf` (1,316,106 bytes, sha256 `2392f2a8d77786b7…`) |

Downloads were sequential, one request each, with an identifying
user agent, on 2026-10-14. The OPC PDF is the OPC's constitutional
edition of the standards (the 1647 confession as adopted with the
American revisions the OPC page describes); the proof *references*
are what is extracted. The CCEL PDF also contains an appendix and
modern editorial matter after chapter XXXII; only the confession
body (chapters I–XXXII) is parsed.

Public-domain basis for both derivations is stated in
`LICENSE-EVIDENCE.md`: both works were published in the 17th century
(WCF 1647; the Baptist confession adopted in London in 1689), so the
works themselves are public domain. What is extracted is citation
facts (which verses each section cites). No CCEL file is
redistributed in the app bundle: the PDFs and their text extracts
stay under `tools/confessions/sources/`, outside
`flutter/assets/`; only the derived facts JSON ships.

## Method

Script: `build_confessions.py` (re-runnable; downloads the PDFs if
absent, extracts with `pdftotext -layout`, rebuilds, then verifies).

### WCF (OPC PDF)

- On each page, lines from the first indented `<letter>. ` line
  onward are footnote text (the OPC prints the proofs as lettered
  footnotes at the page foot, each reference followed by the quoted
  verse text). Footnote blocks: **578**, kept in stream order.
- Letters run per chapter in the classical alphabet (a–z skipping
  `j`). In the body, superscript letters print attached to
  punctuation (e.g. `salvation.b`, `only,a`). Candidate markers are
  extracted with that pattern, carrying their (chapter, section)
  context, and aligned to the footnote blocks by longest-common-
  subsequence alignment on the letter sequence: **572 matched
  directly, 0 false candidates**.
- 6 blocks' printed markers take unusual forms and produce no
  candidate: 3 were assigned by the neighbour rule (both neighbouring
  matched markers in the same section); 3 needed documented
  overrides, each verified by eye against the printed page —
  `1 Tim. 5:21…` → 3.3 (marker printed attached to "angels":
  "men and angelsᶠ are predestinated…"), `Mic. 3:11…` → 18.1 and
  `Amos 9:10…` → 18.1 (markers attached to "salvationᵃ" / "perishᵇ").
  Any other unassignable block aborts the build.
- Section detection validated: 33 chapters, sections numbered
  sequentially per chapter, **171 sections** total — matching the
  OPC corpus count (33 chapters / 171 sections).
- Reference parsing (modern form): a book name counts only when a
  `C:V` tail parses immediately after it (footnote text also quotes
  the verses; quoted text carries no `C:V` patterns). Lists
  (`4:4, 7, 10`), same-chapter ranges (`2:14–15`) and cross-chapter
  ranges (`1:32–2:1`) are expanded verse by verse. Single-chapter
  books are cited by verse alone in this edition (`Jude 6.`,
  `2 John 9–11.`) and are parsed as chapter 1.
- One footnote (ch. 6 §1, letter b) is not a Scripture proof at all —
  it reads "See chapter 5, section 4.", an internal cross-reference —
  and correctly yields no edges.

### 1689 (CCEL PDF)

- Footnote lines start at column 0 with the footnote number and 2+
  spaces; the extracted numbers validate as exactly **1–493 in
  order** (the CCEL edition numbers the proofs continuously through
  the whole confession). Footnote text contains references only.
- Body superscript markers are bare numbers attached to a word,
  standing after punctuation, standing alone on a line, or (once,
  № 473) attached before `&`. Candidates are aligned to the
  footnote numbers by the same LCS alignment (values must equal
  footnote numbers): **492 matched directly**, 14 false candidates
  (the book lists in ch. 1 ¶2, etc.), and № 368 assigned by the
  neighbour rule (its marker prints out of order across a page
  break, in the same paragraph, 22.3, as both neighbours).
- Paragraph detection validated: 32 chapters, paragraphs numbered
  sequentially per chapter, **160 paragraphs** total.
- Reference parsing (old style): after a book name the first number
  is the chapter and following numbers are its verses (separated by
  `.`, `,` or space); `-` makes a verse range; `ch.` starts a new
  chapter group; `v.` marks verses; `&`/`and` followed by a number
  too large to be a verse of the current chapter starts a new
  chapter group (`Ps. 19. 7. and 119. 130.`; `Psal. 32:5. & 51.`).
  Single-chapter books are cited by verse alone (`Jud. 4.` = Jude
  1:4). Abbreviations handled include `Is.` (Isaiah), `Ro.` (Romans),
  `Ezk.`, `Mar.`, `Phi.` (Philippians, as printed at `Phi. 1.6`),
  `1/2 Cro.`/`Chro.`, `Exo.`, `Levit.`, `Revel.`
- **CCEL editorial notes in square brackets are stripped before
  parsing** (7 notes) and never extracted: they are modern matter,
  and two of them suggest modern substitute references for errors in
  the original — those substitutes are not citations of the
  confession. One footnote (№ 424) is entirely such a note and
  yields no edges.
- `&c.` (etcetera) continuations name no verse: **8 dropped**,
  counted, never guessed.

### Canon mapping and drops

Every parsed reference is expanded to individual verses and checked
against the verse counts in `flutter/assets/data.json`. Out-of-range
verses are **dropped, never clamped**:

- WCF: **0 dropped**.
- 1689: **3 verses dropped** — Acts 12:29, Acts 12:30 and Luke 13:36.
  All three are errors in the original 1689 printing itself, and
  CCEL's own bracketed notes say so in as many words (Acts 12 has 25
  verses; Luke 13 has 35). They are dropped on the canon check, not
  on CCEL's say-so; no substitute references were taken from the
  notes.
- **Whole-chapter citations** (a chapter named with no verse) are
  expanded to every verse of the chapter: 7 in the 1689 — Psalms 51,
  88, 107; Leviticus 18; 1 Corinthians 15; Revelation 2; Revelation
  3 (the last three are one printed footnote, `1 Cor. 15. Rev. 2.
  & ch. 3.`, taken literally as printed; CCEL's note on it is
  editorial and was stripped, as above). None in the WCF.
- References are taken **as printed** in the source editions,
  including old-style list forms (e.g. `1 John 2. 2.20.27.` is parsed
  literally as 1 John 2:2, 20, 27).

## Counts (pipeline output, 2026-10-14 run)

| doc | sections | footnote blocks | markers matched | edges |
|---|---|---|---|---|
| WCF | 171 (33 ch.) | 578 | 572 (+3 neighbour, +3 override) | **3,414** |
| 1689 | 160 (32 ch.) | 493 | 492 (+1 neighbour) | **1,591** |
| total | **331** | 1,071 | | **5,005** |

Output: `flutter/assets/confessions.json`, 83,129 bytes.

## Link-out URLs

Document-level only, taken from the publishers' own site structure
(no per-section anchors exist in either host's URL structure for
these editions, and none were invented):

- WCF → `https://opc.org/wcf.html` — the OPC's own Confession of
  Faith page, linked from the standards page above.
- 1689 → `https://ccel.org/ccel/anonymous/bcf.html` — CCEL's work
  page for this edition, the URL the PDF itself prints for the book.

## Verification

The build script ends with an independent verification pass: it
re-reads the written `confessions.json`, asserts edges are sorted
and deduplicated, and re-checks **every** edge's global chapter and
verse against the `data.json` verse counts. Result of the shipped
run: **5,005 edges re-checked, 0 out of range.**

Spot-checks by eye against the source PDFs (references listed in the
source, compared to the edges emitted):

1. **WCF 1.1** — OPC footnotes a–f: Rom 2:14–15, Rom 1:19–20,
   Ps 19:1–4, "See Rom. 1:32–2:1", John 17:3, 1 Cor 1:21,
   1 Cor 2:13–14, Heb 1:1–2, Luke 1:3–4, Rom 15:4, Matt 4:4, 7, 10,
   Isa 8:20, 2 Tim 3:15, 2 Pet 1:19, John 20:31, 1 Cor 14:37,
   1 John 5:13, 1 Cor 10:11, Heb 2:2–4. All present in the output,
   no extras (32 verse edges). ✔
2. **WCF 3.3** — footnotes f (the override block) + g: 1 Tim 5:21,
   Jude 6, Matt 25:31, 41; Eph 1:5–6, Rom 9:22–23. Output: exactly
   those (8 verse edges). ✔
3. **1689 ch. 1 ¶1** — CCEL footnotes 1–4: 2 Tim 3:15, 16, 17;
   Isa 8:20; Luke 16:29, 31; Eph 2:20; Rom 1:19, 20, 21; Rom 2:14,
   15; Ps 19:1, 2, 3; Heb 1:1; Prov 22:19, 20, 21; Rom 15:4;
   2 Pet 1:19, 20. Output: exactly those (22 verse edges). ✔
4. (Extra) **WCF 18.1** — both override blocks verified: Mic 3:11,
   Deut 29:19, John 8:41 (a); Amos 9:10, Matt 7:22–23 (b); plus
   1 John 5:13, 1 John 2:3, 1 John 3:14, 18–19, 21, 24 (c);
   Rom 5:2, 5 (d). All present, no extras. ✔

## Re-running

```bash
python3 tools/confessions/build_confessions.py
```

Requires `pdftotext` (poppler) and network access on first run
(the two PDFs are cached in `sources/` afterwards). The script
fails loudly — it does not guess — if section numbering, footnote
numbering, or marker alignment ever stop validating.
