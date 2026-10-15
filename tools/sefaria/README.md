# Sefaria / Jewish-layer pipeline — Woven Word board run 9

Data desk output for the Jewish tradition layer (packet:
`team/memory/decisions/2026-10-14-board-run-9-packet.md`, scope
calls 2 and 6). Three assets, three builders, one evidence file.
No app code lives here — Maren integrates the assets.

| builder | asset | what it is |
| --- | --- | --- |
| `build_jps.py` | `flutter/assets/jps.json` (3,276,049 bytes) | JPS 1917 English text, Tanakh scope |
| `build_hebrew.py` | `flutter/assets/hebrew.json` (5,426,198 bytes) | Hebrew text (UXLC, derived from WLC 4.20), Tanakh scope |
| `build_links.py` | `flutter/assets/sefaria.json` (174,684,764 bytes — see ⚠ below) | Sefaria citation facts per Tanakh verse |

All three assets use the app shape of `kjv.json` / `web.json`
(texts) or the run-8 facts shape (links): a JSON list of 66 book
slots in CORE canon order (`flutter/assets/data.json`: index 0
Genesis … 38 Malachi, 39 Matthew … 65 Revelation). For the two
Tanakh texts the NT slots 39–65 are `[]`. Verse *n* of a chapter is
array index *n−1*.

> ⚠ **Size flag for Maren/Silas:** `sefaria.json` is 174.7 MB as
> specified (links + works alone serialise to 40.7 MB; the `refs`
> map is the other ~134 MB — 2,446,151 per-triple entries). That
> will not bundle sanely in an APK next to a ~35 MB app. Levers,
> in order of information loss: (1) drop `refs` and build link-out
> URLs from work title + Tanakh ref alone (Sefaria resolves
> book-level refs; −134 MB); (2) collapse section-level work titles
> (33,854 of them, e.g. individual Siddur sections and essay
> titles) to their parent works before aggregation; (3) ship the
> asset as a download-on-first-use file instead of a bundle asset.
> The desk shipped the full-fidelity file the spec asked for; the
> choice between levers is an integration call, not a data call.

## Shared verification (all assets, 2026-10-14)

- Every JSON parses with `json.load`.
- `jps.json` / `hebrew.json`: exactly 66 slots; slots 39–65 empty.
- `sefaria.json`: every link's chapter is a valid OT global chapter
  (see indexing note), every verse is within that chapter's
  `data.json` verse count, every workIndex < len(works); links are
  sorted by (chapter, verse, workIndex). 0 out-of-bounds links.
- **Indexing note / correction to the work order:** the order said
  OT global chapters are "0..186". Verified against
  `flutter/assets/data.json` itself, that is not what the file
  holds: books 0..38 have **929 chapters**, so OT global chapter
  indices run **0..928** (Malachi ch. 4 = 928; ch. 186 is Numbers
  34). This pipeline uses the file's real indexing.
  In `sefaria.json`, `chapter` = 0-based global chapter index into
  `data.json`'s `chapters[]`, `verse` = 1-based verse number.

## 1. JPS 1917 — `build_jps.py`

- **Source:** eBible.org, `https://ebible.org/Scriptures/engjps_usfm.zip`
  (1,049,599 bytes; fetched once, cached in `work/`).
- **Status:** the zip's own `copr.htm` says "Public Domain" —
  quoted verbatim in `LICENSE-EVIDENCE.md` §1. The same file
  separates this 1917 text from the NEW JPS TaNaKH (1972/1978/1980):
  NJPS was never downloaded and is never a source.
- **Method:** unzip; parse the 39 USFM files. Marker census of the
  corpus: only `\id \h \toc1 \toc2 \toc3 \mt1 \c \p \v` occur — no
  inline markers, no footnotes — so verse text is the raw line text
  after `\v N`, whitespace-normalised. Books are mapped to core
  slots by USFM `\id` code, not file position.
- **JPS book list** (`\id` code = `\h` header, in USFM order):
  GEN=Genesis, EXO=Exodus, LEV=Leviticus, NUM=Numbers,
  DEU=Deuteronomy, JOS=Joshua, JDG=Judges, RUT=Ruth, 1SA=1 Samuel,
  2SA=2 Samuel, 1KI=1 Kings, 2KI=2 Kings, 1CH=1 Chronicles,
  2CH=2 Chronicles, EZR=Ezra, NEH=Nehemiah, EST=Esther, JOB=Job,
  PSA=Psalms, PRO=Proverbs, ECC=Ecclesiastes, SNG=Song of Solomon,
  ISA=Isaiah, JER=Jeremiah, LAM=Lamentations, EZK=Ezekiel,
  DAN=Daniel, HOS=Hosea, JOL=Joel, AMO=Amos, OBA=Obadiah, JON=Jonah,
  MIC=Micah, NAM=Nahum, HAB=Habakkuk, ZEP=Zephaniah, HAG=Haggai,
  ZEC=Zechariah, MAL=Malachi. (This order equals core order 0..38.)
- **Counts:** 39 books, 929 chapters, **23,145 verses**.
- **Verse-count differences vs `data.json`: NONE.** Every chapter's
  JPS verse count equals the core count, and every book's chapter
  count matches. (The eBible JPS 1917 follows the English
  versification the core canon uses.)

## 2. Hebrew — `build_hebrew.py`

- **Source:** tanach.us, `https://www.tanach.us/Books/Tanach.xml.zip`
  (2,365,002 bytes) — the site's own published whole-Tanakh archive:
  `Books/<Book>.xml` for all 39 books plus the site's `License.html`.
  Note: the work order's `https://www.tanach.us/Tanach.xml` does
  **not** serve XML — it returns the site's About page wrapped in a
  `<Tanach>` element (2,888 bytes of HTML). Per-book files also
  exist individually under `https://tanach.us/Books/<Book>.xml`
  (archive member names use underscores: `Samuel_1`, `Kings_1`,
  `Chronicles_2`, `Song_of_Songs`); the `*.DH.xml`
  Documentary-Hypothesis members of the zip are ignored.
- **Text identity:** Unicode/XML Leningrad Codex (UXLC 2.5, build
  27.6, Apr 2026 per each book's TEI header), derived from
  "WLC 4.20 provided by the Groves Center" and updated through the
  site's process. Per the site's own precision (quoted in
  `LICENSE-EVIDENCE.md` §2) this is **not** the WLC itself and must
  not be represented as such; call it UXLC.
- **Status:** the site's `License.html` (copy inside the zip) —
  biblical Hebrew text "may be viewed or copied without
  restriction"; citation of Tanach.us appreciated (attribution:
  Unicode/XML Leningrad Codex: UXLC 2.5 (27.6), Tanach.us Inc.).
  Verbatim lines in `LICENSE-EVIDENCE.md` §2, including the
  robots.txt posture note.
- **Method:** per book, `<book>` → `<c n>` → `<v n>` → `<w>` words
  in reading order. Verse string = word tokens joined by one space,
  except no space after a token ending in maqaf (U+05BE). Qere/ketiv
  pairs: the running text uses the **qere** (`<q>`), the `<k>`
  ketiv is skipped (1,269 occurrences). Skipped as non-text
  (3,182): `<pe/>`/`<samekh/>` paragraph markers, `<reversednun/>`,
  and `<x>` annotation anchors (their content is a note code —
  "X" = verse absent from the Leningrad Codex, included for
  numbering continuity; "8" = inverted nun). Versification is the
  XML's own (Hebrew) numbering, kept as-is.
- **Counts:** 39 books, **23,213 verses** (core OT: 23,145).
- **Chapter-count differences vs `data.json` (2):** Joel — Hebrew
  4 chapters vs core 3; Malachi — Hebrew 3 vs core 4. (Verses are
  redistributed across the boundary, not lost: e.g. core Malachi 4
  = Hebrew Malachi 3:19–24.)
- **Verse-count differences vs `data.json` (137 chapters;
  format "chapter: Hebrew vs core"):**
  - Genesis — 31: 54 vs 55; 32: 33 vs 32
  - Exodus — 7: 29 vs 25; 8: 28 vs 32; 21: 37 vs 36; 22: 30 vs 31
  - Leviticus — 5: 26 vs 19; 6: 23 vs 30
  - Numbers — 16: 35 vs 50; 17: 28 vs 13; 25: 19 vs 18; 29: 39 vs 40; 30: 17 vs 16
  - Deuteronomy — 12: 31 vs 32; 13: 19 vs 18; 22: 29 vs 30; 23: 26 vs 25; 28: 69 vs 68; 29: 28 vs 29
  - 1 Samuel — 21: 16 vs 15; 23: 28 vs 29; 24: 23 vs 22
  - 2 Samuel — 18: 32 vs 33; 19: 44 vs 43
  - 1 Kings — 4: 20 vs 34; 5: 32 vs 18; 22: 54 vs 53
  - 2 Kings — 11: 20 vs 21; 12: 22 vs 21
  - 1 Chronicles — 5: 41 vs 26; 6: 66 vs 81; 12: 41 vs 40
  - 2 Chronicles — 1: 18 vs 17; 2: 17 vs 18; 13: 23 vs 22; 14: 14 vs 15
  - Nehemiah — 3: 38 vs 32; 4: 17 vs 23; 7: 72 vs 73; 9: 37 vs 38; 10: 40 vs 39
  - Job — 40: 32 vs 24; 41: 26 vs 34
  - Psalms — 3: 9 vs 8; 4: 9 vs 8; 5: 13 vs 12; 6: 11 vs 10; 7: 18 vs 17; 8: 10 vs 9; 9: 21 vs 20; 12: 9 vs 8; 18: 51 vs 50; 19: 15 vs 14; 20: 10 vs 9; 21: 14 vs 13; 22: 32 vs 31; 30: 13 vs 12; 31: 25 vs 24; 34: 23 vs 22; 36: 13 vs 12; 38: 23 vs 22; 39: 14 vs 13; 40: 18 vs 17; 41: 14 vs 13; 42: 12 vs 11; 44: 27 vs 26; 45: 18 vs 17; 46: 12 vs 11; 47: 10 vs 9; 48: 15 vs 14; 49: 21 vs 20; 51: 21 vs 19; 52: 11 vs 9; 53: 7 vs 6; 54: 9 vs 7; 55: 24 vs 23; 56: 14 vs 13; 57: 12 vs 11; 58: 12 vs 11; 59: 18 vs 17; 60: 14 vs 12; 61: 9 vs 8; 62: 13 vs 12; 63: 12 vs 11; 64: 11 vs 10; 65: 14 vs 13; 67: 8 vs 7; 68: 36 vs 35; 69: 37 vs 36; 70: 6 vs 5; 75: 11 vs 10; 76: 13 vs 12; 77: 21 vs 20; 80: 20 vs 19; 81: 17 vs 16; 83: 19 vs 18; 84: 13 vs 12; 85: 14 vs 13; 88: 19 vs 18; 89: 53 vs 52; 92: 16 vs 15; 102: 29 vs 28; 108: 14 vs 13; 140: 14 vs 13; 142: 8 vs 7
    (Mostly +1: the psalm superscription is verse 1 in Hebrew
    numbering.)
  - Ecclesiastes — 4: 17 vs 16; 5: 19 vs 20
  - Song of Solomon — 6: 12 vs 13; 7: 14 vs 13
  - Isaiah — 8: 23 vs 22; 9: 20 vs 21; 64: 11 vs 12
  - Jeremiah — 8: 23 vs 22; 9: 25 vs 26
  - Ezekiel — 20: 44 vs 49; 21: 37 vs 32
  - Daniel — 3: 33 vs 30; 4: 34 vs 37; 5: 30 vs 31; 6: 29 vs 28
  - Hosea — 1: 9 vs 11; 2: 25 vs 23; 11: 11 vs 12; 12: 15 vs 14; 13: 15 vs 16; 14: 10 vs 9
  - Joel — 2: 27 vs 32; 3: 5 vs 21 (and Hebrew ch. 4 exists; core has none)
  - Jonah — 1: 16 vs 17; 2: 11 vs 10
  - Micah — 4: 14 vs 13; 5: 14 vs 15
  - Nahum — 1: 14 vs 15; 2: 14 vs 13
  - Zechariah — 1: 17 vs 21; 2: 17 vs 13
  - Malachi — 3: 24 vs 18 (Hebrew Malachi ends at ch. 3; core ch. 4's 6 verses are Hebrew 3:19–24)
  - No difference: Joshua, Judges, Ruth, Ezra, Esther,
    Lamentations, Proverbs, Haggai, Zephaniah, Habakkuk, Obadiah,
    Amos (and all unlisted chapters elsewhere).

## 3. Sefaria links — `build_links.py`

- **Source:** Sefaria's public export bucket (bulk download):
  `https://storage.googleapis.com/sefaria-export/links/links0.csv`
  … `links12.csv` — 13 files, 518,973,861 bytes total, downloaded
  **sequentially** with an identifying user agent, cached in
  `work/links/`. Downloads are size-verified against the bucket's
  stored-content-length and resumed with `curl -C -` (a plain
  streamed read silently truncated one file mid-character; the
  size check in `fetch()` is load-bearing — do not remove it).
- **CSV format** (inspected before parsing). Header, verbatim —
  including Sefaria's own mis-spelling:
  `Citation 1,Citation 2,Conection Type,Text 1,Text 2,Category 1,Category 2`
  Each row links two refs. `Citation N` is the full ref
  (e.g. `Rashi on Genesis 1:1:1`, `Berakhot 2a:1`, `Genesis 1:1-5`);
  `Text N` is that side's work title (the book part of the ref);
  `Category N` is the top-level Sefaria category. Note: Tanakh
  commentaries (Rashi, Radak, Malbim…) sit under the top-level
  category "Tanakh" in this export, so the Tanakh side of a row is
  identified by exact `Text` title match against the 39 Tanakh
  book titles (`Genesis`, `I Samuel`, `Psalms`, …), never by
  category alone.
- **Filter rules (as specified):** keep a row only when EXACTLY
  ONE side is a Tanakh verse ref and the other side is a
  non-Tanakh work (any category: Talmud, Midrash, commentary,
  halakhah, liturgy, reference, etc.). Drop Tanakh↔Tanakh rows.
  Drop rows touching the New Testament entirely (title guard list;
  **0 such rows exist** — Sefaria's corpus here is Jewish). A
  Tanakh verse range expands to its verses, walking chapters with
  `data.json` verse counts; an end verse past its chapter's count
  caps at that count. A chapter-only ref (`Genesis 1`) expands to
  the whole chapter. A single ref — or a range's start — outside
  `data.json`'s counts drops the row: refs are never clamped into
  a different verse.
- **Known consequence of the no-clamp rule (read before
  integrating):** Sefaria numbers some books by Hebrew
  versification. Refs past the core counts drop, so e.g. all
  `Malachi 3:19–24` links (which are core Malachi 4:1–6) and
  `Joel 4` links (core Joel 3) are absent, and global chapter 928
  (Malachi 4) has **no links at all**. 928 of 929 OT chapters are
  covered. A Hebrew→core verse-mapping table would recover these;
  it is a separate work package, not something to improvise here.
- **Aggregation:** per (globalChapter, verse, citingWorkTitle):
  count of kept rows (post-expansion). Output:
  `{"v":1, "works":[…33,854 titles, alphabetical…],
    "links":[[chapter, verse, workIndex, count], …2,446,151…],
    "refs":{"chapter:verse:workIndex": "<source ref>", …}}`
  `refs` holds, per triple, the single most specific source
  citation seen (specificity = number of numeric ref components
  after the work title; ties → lexicographically smallest).
  Worked check: Genesis 1:1 × "Rashi on Genesis" → count 3,
  ref `Rashi on Genesis 1:1:1`.
- **Work titles:** the `Text` field of the non-Tanakh side, as
  specified (the book part of the source ref). Be aware the export
  carries section-level titles for composite works — individual
  Siddur sections, Zohar per-parsha volumes, essay titles in
  modern works — which is why `works` has 33,854 entries, not a
  few hundred. This is the source's own granularity, kept
  faithfully; collapsing it is lever (2) in the size flag above.
- **Link-out URLs (for Maren):** Sefaria's ref-URL format is
  `https://www.sefaria.org/<ref>` with the ref's **spaces replaced
  by underscores** and its segment separators as **dots**:
  `Rashi on Genesis 1:1:1` → `https://www.sefaria.org/Rashi_on_Genesis.1.1.1`.
  Verified live 2026-10-14: `…/Genesis.1.1` returns 200;
  `…/Genesis_1:1` redirects to `…/Genesis.1.1`;
  `…/Rashi_on_Genesis.1.1.1` returns 200. So from a stored `refs`
  value: replace spaces with `_`, replace `:` with `.`. From
  (work title + Tanakh ref) alone, the same transform on
  `"<work title> <segment>"` needs the work's own segment, which
  only `refs` carries — another reason `refs` exists.
- **Run counts (2026-10-14):**
  - Rows read: **3,899,752**
  - Kept rows: **1,224,694** → link instances after expansion:
    **3,779,291** → aggregated triples: **2,446,151**
  - Dropped, no Tanakh side: 2,658,621
  - Dropped, Tanakh↔Tanakh: 6,040
  - Dropped, out-of-range Tanakh ref: 10,395 (Hebrew-versification
    refs — see the no-clamp note above)
  - Dropped, unparseable Tanakh citation: 2 (both are the
    book-only citation `Judges` with no chapter)
  - Dropped, New Testament touched: 0
  - Kept rows by the citing side's category: Tanakh (i.e.
    commentaries) 541,479; Reference 180,138; Midrash 147,196;
    Talmud 78,393; Chasidut 75,015; Jewish Thought 64,040;
    Mishnah 34,602; Halakhah 32,625; Kabbalah 29,859; Responsa
    2,495; Musar 22,089; Liturgy 10,775; Tosefta 3,459;
    Second Temple 2,529.

## Sefaria posture

Sefaria runs a documented developer programme and publishes this
bulk export (the `Sefaria-Export` repository and the public
`sefaria-export` bucket) precisely so its data can be taken in
bulk; this pipeline used only that offered route — no site
scraping, no API hammering, sequential downloads with an
identifying user agent. Per the export's own `LICENSE.md`
(quoted in `LICENSE-EVIDENCE.md` §3), **texts are licensed
per-item** (Public Domain / CC0 / CC-BY / CC-BY-SA / CC-BY-NC).
This layer honours that split strictly: the app bundles **only
citation facts** from Sefaria (which work cites which verse, and
how often — facts, not text) and **links out** to Sefaria for the
citing texts themselves. The only texts bundled in the Jewish
layer are public-domain / unrestricted ones obtained from their
own sources: JPS 1917 (eBible.org, public domain) and the UXLC
Hebrew (tanach.us, unrestricted). NJPS 1985 was never touched —
not downloaded, not a source, not a fallback.

**Terms-of-Use read attempt (required record):** one `curl`
attempt at `https://www.sefaria.org/terms` on 2026-10-14 returned
HTTP 200 with 40,502 bytes — and **confirms** the studio's prior
finding. The returned HTML is a JS-rendered shell: after
stripping tags/scripts/styles it carries 550 characters of
visible text, every word of it site navigation ("Terms of Use |
Sefaria Skip to main content Texts Topics Donate Sign Up …"),
with zero occurrences of "copyright", "license", "intellectual"
or "You agree" anywhere in the body. The ToU text itself is
rendered client-side and could not be read through this fetch
route. Per packet scope call 6, a manual ToU read and written
confirmation from Sefaria are filed as **pre-launch checklist
items**; this pipeline proceeded on the documented developer
programme + public export + per-item licence posture above, and
nothing in this README should be read as "the ToU was read".

## Re-running

Each builder caches its downloads under `work/` and is safe to
re-run; builders print their full run stats (the JPS/Hebrew
mismatch reports above are the builders' own stdout, also saved
in `work/hebrew_run.log` / `work/links_run2.log` for this run).
Deleting an asset and re-running its builder regenerates it
byte-identically from the cached sources (sources are re-fetched
only if the cache is removed).

## Integration addendum (Maren, board run 9, 2026-10-14)

The desk's §3 numbers above describe `build_links.py`'s faithful
output. Integration narrowed that output for the app, in the
build order **build_links.py → cap_links.py → gzip**:

1. **Canonical work titles** (in `build_links.py` itself): the
   export's Text field carries section-level titles for
   composite works (Siddur sections, Zohar volumes, dictionary
   headwords). The app's unit is the work; Sefaria's composite
   convention is a comma path, so the canonical title is the
   first comma segment (33,854 → 3,407 works).
2. **The Reference category is excluded** (in `build_links.py`):
   lexicons and dictionaries link verses by word occurrence, not
   by engagement with the verse (180,138 kept rows before this
   cut; BDB alone carried ~145k segment triples). Every other
   category stands.
3. **Per-verse cap of 25 works** (`cap_links.py`): 1,749,968
   (verse, work) triples after steps 1–2 — a median of 41 citing
   works per linked verse, p90 of 203 — is beyond an app bundle
   and a phone JSON parser. Each verse keeps its 25 most-cited
   works (count of citing segments, descending; titles
   ascending). The output records each capped verse's full total
   in `"capped"` (17,379 verses), and the app renders "See all N
   links on Sefaria" for those verses — the truncation is
   disclosed in the product, never silent. Counts include
   range-expansion spillover (a work citing a range counts for
   every verse in it), so the ranking favours works with broad
   segment coverage; Genesis 1:1's full total is 478 works.
4. **Gzip**: the capped JSON is 37 MB; the shipped asset is
   `flutter/assets/sefaria.json.gz` at 4.85 MB, inflated in the
   parse isolate at load.

One desk-summary correction, for the record: an early summary
of this desk's work quoted 330,702 triples / 1,707 works /
4,962,240 bytes. Those numbers describe no artifact this
pipeline produced; §3's run counts and this addendum's are the
verified ones.

Also at integration: `build_jps.py` gained a guard that merges
USFM overflow chapters into a book's final core chapter (a
section-break split would otherwise truncate the reader's last
chapter under positional verse numbering); this run's JPS
output needed no merge (31 chapters for Proverbs, 0 verse-count
mismatches).
