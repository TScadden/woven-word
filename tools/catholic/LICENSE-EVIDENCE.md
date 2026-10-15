# Licence evidence — Catholic texts, board run 9

Checked 2026-10-14. Quotes are verbatim from the `copr.htm` file
inside each eBible.org USFM zip actually downloaded (copr.htm is the
copyright/status file the publisher ships inside the download).
Both works below are public-domain; the quotes are the evidence
relied on, per the run-9 packet scope calls 4–5.

## 1. World English Bible (Catholic) — the run-9 Catholic reading text

- Edition id: **eng-web-c** ("World English Bible Catholic Edition")
- Download used: https://ebible.org/Scriptures/eng-web-c_usfm.zip
  (HTTP 200, 3,082,467 bytes, files dated 2026-10-13)
- Resolved against the look-alikes:
  - `engwebc_usfm.zip` — **404** (the unhyphenated guess is wrong).
  - `engwebp_usfm.zip` — 200, but that is the *Protestant* edition:
    its own details page says it "omits the Deuterocanon/Apocrypha";
    its USFM contains only the 66 core books (+ FRT/GLO front matter).
  - `engwebu_usfm.zip` — the full *Updated* superset (83 USFM files:
    the 66 + TOB, JDT, ESG, WIS, SIR, BAR, 1MA, 2MA, 1ES, MAN, PS2,
    3MA, 2ES, 4MA, DAG) — more than the Catholic canon, and not in
    Catholic presentation order as a set.
  - `eng-web-c` is described by eBible.org as: "This is the World
    English Bible Catholic Edition. It uses 'LORD' or 'GOD' for God's
    Proper Name in the Old Testament and U. S. A. spelling. It uses
    the Traditional Catholic book set and book order." and "Esther
    and Daniel include the sections translated from the Greek
    Septuagint that are not in the traditional Hebrew text."
- Book `\id` codes in `eng-web-c_usfm.zip` (73 files, in the zip's
  numeric-prefix order, which is the order webc.json preserves):
  GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH
  JOB PSA PRO ECC SNG ISA JER LAM EZK HOS JOL AMO OBA JON MIC NAM
  HAB ZEP HAG ZEC MAL TOB JDT ESG WIS SIR BAR 1MA 2MA DAG MAT MRK
  LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM
  HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV
  All seven deuterocanonical books are present: TOB, JDT, WIS, SIR,
  BAR, 1MA, 2MA. There is **no EST and no DAN** — see the ESG/DAG
  note in README.md.

### Status lines quoted from `copr.htm` inside eng-web-c_usfm.zip

> "The World English Bible is  in the Public Domain. That means
> that it is not copyrighted. However, "World English Bible" is a
> Trademark of eBible.org."

> "You may copy, publish, proclaim, distribute, redistribute, sell,
> give away, quote, memorize, read publicly, broadcast, transmit,
> share, back up, post on the Internet, print, reproduce, preach,
> teach from, and use the World English Bible as much as you want,
> and others may also do so. All we ask is that if you CHANGE the
> actual text of the World English Bible in any way, you not call
> the result the World English Bible any more."

> "…we who have worked on this translation freely give it to you
> by dedicating it to the Public Domain."

> Footer line in the same file: "This is the updated World English
> Bible with the traditional Catholic book set." / "The World
> English Bible is in the Public Domain. You may copy and share
> it freely." / "2020 stable text edition"

Compliance note: Woven Word does not change the verse text (the
build only strips USFM apparatus — footnotes, cross-reference
notes and Strong's markup — exactly as the shipped web.json did
for the classic WEB). The name "World English Bible" is a
trademark of eBible.org; surfaces should credit the translation
without branding the app or the derived file as a separate
"World English Bible" product.

## 2. Douay-Rheims 1899 — evidence only (text deferred, packet call 4)

- Download used: https://ebible.org/Scriptures/engDRA_usfm.zip
  (HTTP 200, 2,938,537 bytes, source files dated 2022-11-03)
- Book `\id` codes (73 files): GEN EXO LEV NUM DEU JOS JDG RUT 1SA
  2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO ECC SNG ISA JER LAM
  EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL TOB JDT
  WIS SIR BAR 1MA 2MA MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP
  COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV
  (EST and DAN present in Hebrew-book form; no ESG/DAG.)

### Status lines quoted from `copr.htm` inside engDRA_usfm.zip

> Title lines: "Douay-Rheims 1899" / "The Holy Bible in English,
> Douay-Rheims American Edition of 1899, translated from the
> Latin Vulgate"

> "Public Domain" (linked status line, twice in the file, including
> the footer: "Public Domain")

> "This Public Domain Bible text is brought to you courtesy of
> eBible.org."

> "Translation by: English College, Douai" / "Dialect: archaic
> American" / dated "2022-11-03"

### Psalm numbering (from the USFM files themselves)

- `20-PSAengDRA.usfm` carries **150 `\c` chapter markers numbered
  1–150** — the count alone does not reveal the basis; the content
  does. The numbering is the **Vulgate (Latin) numbering**, not the
  Hebrew numbering used by the core canon:
  - DRA Psalm **22** opens with the psalm that is Hebrew Psalm 23
    ("The Lord ruleth me: and I shall want nothing").
  - DRA Psalm **9** is a single psalm (Hebrew 9 and 10 combined
    in the Vulgate count).
  - DRA Psalm **113** begins with Hebrew 114's content ("When
    Israel went out of Egypt…"), DRA **114/115** split Hebrew 116,
    and DRA **147** begins mid-Hebrew-147 ("Praise the Lord, O
    Jerusalem…").
- This confirms the packet's reason for deferring DR text: keying
  this file's Psalms to core-canon chapter numbers would misalign
  most Psalms by one. A future DR package needs a Vulgate↔Hebrew
  verse-mapping table first. **No dra.json was built this run.**
