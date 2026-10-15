# Catholic text pipeline — Woven Word run 9

Builds the Catholic reading text: World English Bible (Catholic)
as `flutter/assets/webc.json`, plus the extra-canon table the app
needs to present the deuterocanon.

## Files

| file | what |
| --- | --- |
| `build_webc.py` | USFM → JSON converter (downloads the zip if missing) |
| `webc_books.json` | book table for webc.json (output of the script) |
| `LICENSE-EVIDENCE.md` | quoted public-domain status lines: WEBC + Douay-Rheims |
| `CCC-ROUTE.md` | Catechism Index-of-Citations route check — verdict BLOCKED |
| `work/` | downloaded zips and extracted USFM (scratch, regenerable) |

App-side outputs (do not hand-edit; rerun the script):

- `flutter/assets/webc.json` — `[book][chapter][verse] -> string`,
  73 books in the edition's own order, 1,328 chapters, 35,423
  verse slots.
- `flutter/assets/deuterocanon.json` — the 9 extra books with
  chapter counts and per-chapter verse counts derived from
  webc.json (the script recomputes them from the written file and
  asserts equality before printing).

## Source

eBible.org edition **eng-web-c**, "World English Bible Catholic
Edition", USFM zip `eng-web-c_usfm.zip` (note the hyphens —
`engwebp` is the Protestant edition and `engwebc` 404s).
Public domain; evidence in `LICENSE-EVIDENCE.md`.

## The ESG / DAG mapping (read before integrating)

The edition contains **no Hebrew Esther (EST) and no Hebrew
Daniel (DAN)**. Instead it carries, as separate USFM books:

- **ESG — "Esther (Greek)"**, 10 chapters: the full Greek Esther,
  i.e. the Hebrew Esther text with the Septuagint additions merged
  in as extensions (per the book's own introduction in the USFM).
- **DAG — "Daniel (Greek)" / toc "The Book of Daniel with Greek
  Portions"**, 14 chapters: Daniel with the Greek portions
  (Prayer of Azariah / Song of the Three Children in ch. 3,
  Susanna as ch. 13, Bel and the Dragon as ch. 14).

Per the run packet they are mapped as **extra** books (slugs
`esther-greek`, `daniel-greek`) and are **not** interleaved into
Esther/Daniel. Consequences for integration (Maren):

- `webc_books.json` has 73 entries: 64 with a core index, 9 with
  `"core": null, "extra": <slug>`.
- Core indices **16 (Esther) and 26 (Daniel) have no webc entry** —
  in Catholic mode the Esther/Daniel reading text is the ESG/DAG
  extra entry. Every other core book maps 1:1.
- Catholic presentation order implied by the edition (webc.json
  order): the 37 core OT books in core order **without** Esther
  and Daniel, then TOB, JDT, ESG, WIS, SIR, BAR, 1MA, 2MA, DAG,
  then the 27 NT books in core order.
- The 9 extras are the deuterocanon.json books: the seven
  deuterocanonical books (Tobit 14 ch, Judith 16, Wisdom 19,
  Sirach 51, Baruch 6 — ch. 6 is the Letter of Jeremiah, 73
  verses — 1 Maccabees 16, 2 Maccabees 15) plus ESG (10 ch) and
  DAG (14 ch).

## Text fidelity notes

- Cleaning replicates the shipped `web.json` conventions (see the
  script docstring); validated 31,096 / 31,103 verses
  byte-identical against the classic-WEB USFM → web.json pair.
- 44 verse slots are empty strings, all faithful to the edition:
  verses the WEB omits (e.g. Luke 17:36, Acts 8:37, Rom 16:25 —
  the Romans doxology sits at the end of ch. 14 in this edition),
  numbering gaps in Greek Esther (4:6, 9:5, 9:30), Sirach verses
  absent from the Greek text used, and Sirach's 5 footnote-only
  verse ranges (11:15-16, 16:15-16, 19:18-19, 22:9-10, 26:19-27),
  each expanded to one slot per verse number so positional verse
  numbering never shifts.
- Douay-Rheims: evidence only this run (LICENSE-EVIDENCE.md §2).
  No dra.json — its Psalms use Vulgate numbering and need a
  verse-mapping table first (packet scope call 4).
