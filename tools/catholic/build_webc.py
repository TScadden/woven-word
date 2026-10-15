#!/usr/bin/env python3
"""
Build the Catholic reading text for Woven Word board run 9.

Source: World English Bible (Catholic) — eBible.org edition id `eng-web-c`
        ("World English Bible Catholic Edition", traditional Catholic book
        set and book order, a subset of the World English Bible Updated).
        USFM zip: https://ebible.org/Scriptures/eng-web-c_usfm.zip
        Status: Public Domain (see LICENSE-EVIDENCE.md in this directory,
        quoting copr.htm inside the zip).

NOTE on the edition id: the file is `eng-web-c_usfm.zip` (hyphenated).
`engwebc_usfm.zip` 404s and `engwebp_usfm.zip` is a different edition
(the Protestant edition, 66 books, no deuterocanon).

Outputs:
  flutter/assets/webc.json          [book][chapter][verse] -> string,
                                    in the edition's own book order
                                    (numeric USFM filename prefix order).
  tools/catholic/webc_books.json    book table for webc.json:
                                    {"usfm","name","core"} where core is
                                    the book's index in flutter/assets/
                                    data.json (66-book canon), or
                                    {"usfm","name","core":null,"extra":slug}
                                    for books outside the core canon.
  flutter/assets/deuterocanon.json  {"books":[{slug,name,abbr,chapters,
                                    verseCounts}]} for exactly the extra
                                    books, counts derived from webc.json.

Mapping decisions (see the run-9 data-desk report):
  * The edition carries NO Hebrew Esther (EST) and NO Hebrew Daniel
    (DAN). In their place it carries ESG "Esther (Greek)" (10 chapters)
    and DAG "Daniel with Greek Portions" (14 chapters) as separate
    USFM books. Per the run packet they are mapped as "extra" books
    (slugs esther-greek / daniel-greek) and are NOT interleaved into
    Esther/Daniel. Consequence: core indices 16 (Esther) and 27
    (Daniel) have no entry in webc_books.json; the Catholic text for
    Esther/Daniel lives in the ESG/DAG extra entries.
  * Text cleaning replicates the shipped flutter/assets/web.json
    (which was built from the classic WEB VPL): footnotes (\\f..\\f*)
    and cross-reference notes (\\x..\\x*) are removed, Strong's word
    markup (\\w word|strong=".."\\w*) is unwrapped, paragraph/poetry
    markers become spaces, descriptive titles (\\d) and Song speaker
    labels (\\sp) stay in the reading text at their stream position
    (prefix of verse 1 before a chapter's first verse, otherwise
    appended to the open verse — matching the VPL behaviour), section
    headings (\\s, \\ms), introductions (\\ip, \\is) and title/toc
    material are dropped, and spaces before punctuation are tightened.
    Validated against the classic WEB USFM -> web.json: 31,096 of
    31,103 verses byte-identical (the 7 diffs are 4 Song speaker-label
    placements since kept, and 3 stray spaces before a closing quote
    in the VPL asset itself).
  * Sirach contains 5 empty verse-range markers (\\v 15-16 etc.) whose
    only content is a footnote saying the verses are omitted by the
    best authorities. Ranges are expanded to one empty string per
    verse number so positional verse numbering never shifts.

Run:  python3 tools/catholic/build_webc.py
The script re-reads the written webc.json and independently recomputes
the deuterocanon verse counts from it before printing them.
"""

import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # ~/workspace/woven-word
WORK = Path(__file__).resolve().parent / "work"
ZIP_PATH = WORK / "eng-web-c_usfm.zip"
ZIP_URL = "https://ebible.org/Scriptures/eng-web-c_usfm.zip"
WEBC_JSON = ROOT / "flutter" / "assets" / "webc.json"
BOOKS_JSON = Path(__file__).resolve().parent / "webc_books.json"
DEUT_JSON = ROOT / "flutter" / "assets" / "deuterocanon.json"
DATA_JSON = ROOT / "flutter" / "assets" / "data.json"

# USFM id -> (display name, core index in data.json or None, extra slug, abbr)
# Core names are the data.json names; core indices are verified against
# data.json at runtime, never trusted from this table alone.
BOOK_TABLE = {
    "GEN": ("Genesis", "Genesis", None, None),
    "EXO": ("Exodus", "Exodus", None, None),
    "LEV": ("Leviticus", "Leviticus", None, None),
    "NUM": ("Numbers", "Numbers", None, None),
    "DEU": ("Deuteronomy", "Deuteronomy", None, None),
    "JOS": ("Joshua", "Joshua", None, None),
    "JDG": ("Judges", "Judges", None, None),
    "RUT": ("Ruth", "Ruth", None, None),
    "1SA": ("1 Samuel", "1 Samuel", None, None),
    "2SA": ("2 Samuel", "2 Samuel", None, None),
    "1KI": ("1 Kings", "1 Kings", None, None),
    "2KI": ("2 Kings", "2 Kings", None, None),
    "1CH": ("1 Chronicles", "1 Chronicles", None, None),
    "2CH": ("2 Chronicles", "2 Chronicles", None, None),
    "EZR": ("Ezra", "Ezra", None, None),
    "NEH": ("Nehemiah", "Nehemiah", None, None),
    "JOB": ("Job", "Job", None, None),
    "PSA": ("Psalms", "Psalms", None, None),
    "PRO": ("Proverbs", "Proverbs", None, None),
    "ECC": ("Ecclesiastes", "Ecclesiastes", None, None),
    "SNG": ("Song of Solomon", "Song of Solomon", None, None),
    "ISA": ("Isaiah", "Isaiah", None, None),
    "JER": ("Jeremiah", "Jeremiah", None, None),
    "LAM": ("Lamentations", "Lamentations", None, None),
    "EZK": ("Ezekiel", "Ezekiel", None, None),
    "HOS": ("Hosea", "Hosea", None, None),
    "JOL": ("Joel", "Joel", None, None),
    "AMO": ("Amos", "Amos", None, None),
    "OBA": ("Obadiah", "Obadiah", None, None),
    "JON": ("Jonah", "Jonah", None, None),
    "MIC": ("Micah", "Micah", None, None),
    "NAM": ("Nahum", "Nahum", None, None),
    "HAB": ("Habakkuk", "Habakkuk", None, None),
    "ZEP": ("Zephaniah", "Zephaniah", None, None),
    "HAG": ("Haggai", "Haggai", None, None),
    "ZEC": ("Zechariah", "Zechariah", None, None),
    "MAL": ("Malachi", "Malachi", None, None),
    "TOB": ("Tobit", None, "tobit", "Tob"),
    "JDT": ("Judith", None, "judith", "Jdt"),
    "ESG": ("Esther (Greek)", None, "esther-greek", "EsthGr"),
    "WIS": ("Wisdom", None, "wisdom", "Wis"),
    "SIR": ("Sirach", None, "sirach", "Sir"),
    "BAR": ("Baruch", None, "baruch", "Bar"),
    "1MA": ("1 Maccabees", None, "1-maccabees", "1Macc"),
    "2MA": ("2 Maccabees", None, "2-maccabees", "2Macc"),
    "DAG": ("Daniel (Greek)", None, "daniel-greek", "DanGr"),
    "MAT": ("Matthew", "Matthew", None, None),
    "MRK": ("Mark", "Mark", None, None),
    "LUK": ("Luke", "Luke", None, None),
    "JHN": ("John", "John", None, None),
    "ACT": ("Acts", "Acts", None, None),
    "ROM": ("Romans", "Romans", None, None),
    "1CO": ("1 Corinthians", "1 Corinthians", None, None),
    "2CO": ("2 Corinthians", "2 Corinthians", None, None),
    "GAL": ("Galatians", "Galatians", None, None),
    "EPH": ("Ephesians", "Ephesians", None, None),
    "PHP": ("Philippians", "Philippians", None, None),
    "COL": ("Colossians", "Colossians", None, None),
    "1TH": ("1 Thessalonians", "1 Thessalonians", None, None),
    "2TH": ("2 Thessalonians", "2 Thessalonians", None, None),
    "1TI": ("1 Timothy", "1 Timothy", None, None),
    "2TI": ("2 Timothy", "2 Timothy", None, None),
    "TIT": ("Titus", "Titus", None, None),
    "PHM": ("Philemon", "Philemon", None, None),
    "HEB": ("Hebrews", "Hebrews", None, None),
    "JAS": ("James", "James", None, None),
    "1PE": ("1 Peter", "1 Peter", None, None),
    "2PE": ("2 Peter", "2 Peter", None, None),
    "1JN": ("1 John", "1 John", None, None),
    "2JN": ("2 John", "2 John", None, None),
    "3JN": ("3 John", "3 John", None, None),
    "JUD": ("Jude", "Jude", None, None),
    "REV": ("Revelation", "Revelation", None, None),
}

SKIP_CHUNK = {
    "id", "ide", "h", "toc1", "toc2", "toc3", "mt1", "mt2", "mt3",
    "is1", "is2", "ip", "io1", "s1", "s2", "s3", "ms1", "ms2", "sr",
    "cl", "cp", "r", "rem", "sts", "restore",
}
PARA = {
    "p", "m", "q1", "q2", "q3", "q4", "li1", "li2", "mi", "pc",
    "pi1", "pi2", "b", "nb", "pm", "pmo", "pmc", "pmr",
}


def clean_book(text: str) -> str:
    # Footnotes and cross-reference notes are apparatus, not text.
    text = re.sub(r"\\f\s.*?\\f\*", " ", text, flags=re.S)
    text = re.sub(r"\\x\s.*?\\x\*", " ", text, flags=re.S)
    # Unwrap Strong's-tagged words: \w word|strong="H1234"\w* -> word
    text = re.sub(r"\\\+w\s+([^|\\]+?)\|[^\\]*?\\\+w\*", r"\1", text)
    text = re.sub(r"\\w\s+([^|\\]+?)\|[^\\]*?\\w\*", r"\1", text)
    return text


def parse_usfm(text: str):
    """Return (chapters, warnings); chapters = [[verse, ...], ...]."""
    text = clean_book(text)
    tokens = re.split(r"(\\\+?[a-zA-Z]+[0-9]*\*?)", text)
    chapters = {}
    cur_ch = None
    cur_v = None
    pending_prefix = ""
    warnings = []

    def append(txt):
        if cur_ch is not None and cur_v is not None:
            chapters[cur_ch][cur_v] = chapters[cur_ch].get(cur_v, "") + txt

    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if not tok.startswith("\\"):
            append(tok)
            i += 1
            continue
        base = tok.lstrip("\\").lstrip("+").rstrip("*")
        if tok.rstrip("*") != tok:  # closing marker like \w* : keep text after it
            i += 1
            continue
        nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
        if base == "c":
            m = re.match(r"\s*(\d+)", nxt)
            cur_ch = int(m.group(1))
            chapters.setdefault(cur_ch, {})
            cur_v = None
            pending_prefix = ""
            tokens[i + 1] = nxt[m.end():]
        elif base == "v":
            m = re.match(r"\s*(\d+)(?:-(\d+))?", nxt)
            start = int(m.group(1))
            end = int(m.group(2)) if m.group(2) else start
            cur_v = start
            if cur_ch is not None:
                for vn in range(start, end + 1):
                    chapters[cur_ch].setdefault(vn, "")
                if end > start:
                    warnings.append(
                        f"ch{cur_ch} verse range {start}-{end} expanded "
                        "to one slot per verse (text, if any, on first)"
                    )
            tokens[i + 1] = nxt[m.end():]
            if pending_prefix and cur_ch is not None:
                chapters[cur_ch][cur_v] = (
                    pending_prefix + " " + chapters[cur_ch].get(cur_v, "")
                )
                pending_prefix = ""
        elif base in ("d", "sp"):
            # Descriptive title / speaker label: reading text. Before a
            # chapter's first verse it prefixes verse 1; mid-chapter it
            # appends to the open verse (VPL behaviour, e.g. Psalm 119's
            # stanza letters, Song's speaker labels).
            t = " ".join(nxt.split())
            if cur_v is not None:
                chapters[cur_ch][cur_v] = (
                    chapters[cur_ch].get(cur_v, "") + " " + t
                )
            else:
                pending_prefix = t
            tokens[i + 1] = ""
        elif base in SKIP_CHUNK:
            tokens[i + 1] = ""
        elif base in PARA:
            append(" ")
        # every other marker is inline (w, bk, qs, wj, ...): keep its text
        i += 1

    out = []
    for ch in range(1, (max(chapters) + 1) if chapters else 1):
        vd = chapters.get(ch, {})
        verses = []
        for vn in range(1, (max(vd) + 1) if vd else 1):
            v = " ".join(vd.get(vn, "").split())
            v = re.sub(r"\s+([.,;:!?\)\u201d\u2019])", r"\1", v)
            v = re.sub(r"([\(\u201c\u2018])\s+", r"\1", v)
            verses.append(v)
        out.append(verses)
    return out, warnings


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    if not ZIP_PATH.exists():
        print(f"downloading {ZIP_URL}")
        urllib.request.urlretrieve(ZIP_URL, ZIP_PATH)

    core_names = [b["name"] for b in json.loads(DATA_JSON.read_text())["books"]]
    assert len(core_names) == 66

    with zipfile.ZipFile(ZIP_PATH) as z:
        names = sorted(n for n in z.namelist() if n.endswith(".usfm"))
        raw = {n: z.read(n).decode("utf-8") for n in names}

    webc = []
    books_meta = []
    extras = []  # (slug, name, abbr, chapters-data)
    all_warnings = []
    for fname in names:  # filename sort = the edition's own book order
        text = raw[fname]
        usfm = re.search(r"\\id\s+(\S+)", text).group(1)
        if usfm not in BOOK_TABLE:
            print(f"FATAL: unmapped USFM id {usfm} ({fname})", file=sys.stderr)
            sys.exit(1)
        name, core_name, slug, abbr = BOOK_TABLE[usfm]
        chapters, warnings = parse_usfm(text)
        all_warnings += [f"{usfm}: {w}" for w in warnings]
        webc.append(chapters)
        if slug is None:
            core_idx = core_names.index(core_name)
            books_meta.append({"usfm": usfm, "name": name, "core": core_idx})
        else:
            books_meta.append(
                {"usfm": usfm, "name": name, "core": None, "extra": slug}
            )
            extras.append((slug, name, abbr, chapters))

    WEBC_JSON.write_text(json.dumps(webc, ensure_ascii=False, separators=(",", ":")))
    BOOKS_JSON.write_text(json.dumps(books_meta, ensure_ascii=False, indent=1))
    deut = {
        "books": [
            {
                "slug": slug,
                "name": name,
                "abbr": abbr,
                "chapters": len(chapters),
                "verseCounts": [len(c) for c in chapters],
            }
            for slug, name, abbr, chapters in extras
        ]
    }
    DEUT_JSON.write_text(json.dumps(deut, ensure_ascii=False, separators=(",", ":")))

    # ---- independent verification: re-read webc.json from disk and
    # recompute every extra book's verse counts from it alone.
    reread = json.loads(WEBC_JSON.read_text())
    meta = json.loads(BOOKS_JSON.read_text())
    deut2 = json.loads(DEUT_JSON.read_text())
    assert len(reread) == len(meta), (len(reread), len(meta))
    pos = {m["usfm"]: i for i, m in enumerate(meta)}
    for b in deut2["books"]:
        m = next(x for x in meta if x.get("extra") == b["slug"])
        data = reread[pos[m["usfm"]]]
        recomputed = [len(c) for c in data]
        assert recomputed == b["verseCounts"], (b["slug"], recomputed, b["verseCounts"])
        assert len(data) == b["chapters"]
    used_core = sorted(m["core"] for m in meta if m["core"] is not None)
    missing_core = sorted(set(range(66)) - set(used_core))

    print(f"books in edition order: {len(webc)}")
    print("order: " + " ".join(m["usfm"] for m in meta))
    print(f"core-mapped: {len(used_core)}  extra: {len(extras)}")
    print(f"core indices with NO webc entry: {missing_core} "
          f"({[core_names[i] for i in missing_core]}) — their Catholic "
          "text is the ESG/DAG extra entries")
    print(f"total chapters: {sum(len(b) for b in webc)}  "
          f"total verses: {sum(len(c) for b in webc for c in b)}")
    empties = [
        f"{meta[bi]['usfm']} {ci+1}:{vi+1}"
        for bi, b in enumerate(webc)
        for ci, c in enumerate(b)
        for vi, v in enumerate(c)
        if v == ""
    ]
    print(f"empty verses: {len(empties)} {empties}")
    for slug, name, abbr, chapters in extras:
        print(f"extra {slug:14s} {name:18s} chapters={len(chapters):3d} "
              f"verseCounts={[len(c) for c in chapters]}")
    for w in all_warnings:
        print("warning:", w)
    print("verification: deuterocanon.json verseCounts recomputed from "
          "webc.json on disk — MATCH")


if __name__ == "__main__":
    main()
