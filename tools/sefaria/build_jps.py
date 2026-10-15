#!/usr/bin/env python3
"""Build flutter/assets/jps.json — JPS 1917 (public domain) in app shape.

Source: eBible.org USFM zip
    https://ebible.org/Scriptures/engjps_usfm.zip
The zip's copr.htm states the text's status verbatim (see
LICENSE-EVIDENCE.md): "Public Domain" — "The Jewish Bible (Old
Testament) in English, published by the Jewish Publication Society
in 1917".

App shape (same as kjv.json / web.json): a list of 66 book slots in
CORE canon order (flutter/assets/data.json: 0 Genesis … 38 Malachi,
39 Matthew … 65 Revelation). Each filled slot is a list of chapters;
each chapter is a list of verse strings (verse n = index n-1).
JPS 1917 is Tanakh-only, so NT slots 39..65 are [].

Books are mapped to core slots by their USFM \\id code, NOT by file
position; chapters/verses keep JPS's own order and numbering inside
each book (no re-versification: where JPS's verse count for a chapter
differs from data.json's count, the JPS text is emitted as-is and the
difference is reported in the run stats printed at the end).

USFM parsing: the eBible JPS files use only \\id, \\h, \\toc*, \\mt1,
\\c, \\p and \\v markers (verified by marker census 2026-10-14); verse
text is the raw text after "\\v N" up to the next marker, whitespace
normalised. No inline markers occur in this corpus.

Downloads are cached under work/ (the zip is fetched once, with an
identifying user agent, ordinary pacing).
"""

import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # ~/workspace/woven-word
WORK = HERE / "work" / "jps"
ZIP_URL = "https://ebible.org/Scriptures/engjps_usfm.zip"
ZIP_PATH = HERE / "work" / "engjps_usfm.zip"
DATA_JSON = ROOT / "flutter" / "assets" / "data.json"
OUT_JSON = ROOT / "flutter" / "assets" / "jps.json"
UA = "WovenWordStudio/1.0 (JPS data pipeline; public-domain text)"

# USFM \id code -> core book index (data.json order)
USFM_TO_CORE = {
    "GEN": 0, "EXO": 1, "LEV": 2, "NUM": 3, "DEU": 4, "JOS": 5,
    "JDG": 6, "RUT": 7, "1SA": 8, "2SA": 9, "1KI": 10, "2KI": 11,
    "1CH": 12, "2CH": 13, "EZR": 14, "NEH": 15, "EST": 16, "JOB": 17,
    "PSA": 18, "PRO": 19, "ECC": 20, "SNG": 21, "ISA": 22, "JER": 23,
    "LAM": 24, "EZK": 25, "DAN": 26, "HOS": 27, "JOL": 28, "AMO": 29,
    "OBA": 30, "JON": 31, "MIC": 32, "NAM": 33, "HAB": 34, "ZEP": 35,
    "HAG": 36, "ZEC": 37, "MAL": 38,
}


def fetch_zip() -> None:
    ZIP_PATH.parent.mkdir(parents=True, exist_ok=True)
    if ZIP_PATH.exists() and ZIP_PATH.stat().st_size > 100_000:
        return
    req = urllib.request.Request(ZIP_URL, headers={"User-Agent": UA})
    with urllib.request.urlopen(req) as r, open(ZIP_PATH, "wb") as f:
        f.write(r.read())
    with zipfile.ZipFile(ZIP_PATH) as z:
        z.extractall(WORK)


def parse_usfm(path: Path):
    """Return (id_code, header_name, chapters) for one USFM file."""
    text = path.read_text(encoding="utf-8-sig")
    book_id = None
    header = None
    chapters: list[list[str]] = []
    current: list[str] | None = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("\\id "):
            book_id = line.split()[1]
        elif line.startswith("\\h "):
            header = line[3:].strip()
        elif line.startswith("\\c "):
            current = []
            chapters.append(current)
        elif line.startswith("\\v ") and current is not None:
            m = re.match(r"\\v\s+\d+\s*(.*)", line)
            verse = re.sub(r"\s+", " ", m.group(1)).strip()
            current.append(verse)
        elif line.startswith("\\v") and current is not None:
            # verse marker with no number spacing variant; be loud
            raise ValueError(f"{path.name}: unhandled verse line: {line!r}")
    return book_id, header, chapters


def main() -> int:
    fetch_zip()
    core = json.loads(DATA_JSON.read_text(encoding="utf-8"))
    books_meta = core["books"]
    # core verse count per (book, chapter-1based)
    core_counts: dict[tuple[int, int], int] = {}
    for ch in core["chapters"]:
        core_counts[(ch["b"], ch["c"])] = ch["v"]

    slots: list = [[] for _ in range(66)]
    book_list = []          # (id_code, header) in USFM file order
    total_verses = 0
    mismatches = []         # (book name, chapter, jps count, core count)
    chapter_count_diffs = []

    usfm_files = sorted(WORK.glob("*engjps.usfm"))
    if len(usfm_files) != 39:
        print(f"ERROR: expected 39 USFM files, found {len(usfm_files)}",
              file=sys.stderr)
        return 1
    for path in usfm_files:
        book_id, header, chapters = parse_usfm(path)
        book_list.append((book_id, header))
        core_idx = USFM_TO_CORE[book_id]
        slots[core_idx] = chapters
        total_verses += sum(len(c) for c in chapters)
        if len(chapters) != books_meta[core_idx]["chapters"]:
            chapter_count_diffs.append(
                (books_meta[core_idx]["name"], len(chapters),
                 books_meta[core_idx]["chapters"]))
        for ci, chapter in enumerate(chapters, start=1):
            cc = core_counts.get((core_idx, ci))
            if cc is not None and len(chapter) != cc:
                mismatches.append(
                    (books_meta[core_idx]["name"], ci, len(chapter), cc))

    # Integration fix (Maren, board run 9): a book whose USFM
    # carries MORE chapters than the core canon (Proverbs: JPS
    # splits chapter 31's section break into a 32nd slot) would
    # leave the reader's last chapter showing only the first
    # fragment under positional verse numbering. Merge overflow
    # slots into the book's final core chapter — the verses are
    # the chapter's own, in order; the split is a section break,
    # not a chapter boundary in any canon.
    for core_idx in range(39):
        want = books_meta[core_idx]["chapters"]
        got = slots[core_idx]
        if len(got) > want:
            merged = got[: want - 1] + [[v for part in got[want - 1:] for v in part]]
            print(
                f"merge: {books_meta[core_idx]['name']}: {len(got)} USFM "
                f"slots -> {want} core chapters (overflow merged into "
                f"chapter {want})"
            )
            slots[core_idx] = merged

    OUT_JSON.write_text(json.dumps(slots, ensure_ascii=False,
                                   separators=(",", ":")),
                        encoding="utf-8")
    print(f"wrote {OUT_JSON} ({OUT_JSON.stat().st_size} bytes)")
    print(f"JPS books ({len(book_list)}): "
          + ", ".join(f"{c}={h}" for c, h in book_list))
    print(f"total verses: {total_verses}")
    print(f"chapter-count differences vs data.json: {chapter_count_diffs}")
    print(f"verse-count mismatches ({len(mismatches)}):")
    for name, ci, jc, cc in mismatches:
        print(f"  {name} {ci}: JPS {jc} vs core {cc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
