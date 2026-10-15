#!/usr/bin/env python3
"""Build flutter/assets/hebrew.json — Hebrew Tanakh in app shape.

Source: tanach.us — Unicode/XML Leningrad Codex (UXLC), derived from
the Westminster Leningrad Codex (WLC 4.20, Groves Center) and updated
through the site's formal process. The site publishes the whole
Tanakh as ONE archive of per-book XML files:
    https://www.tanach.us/Books/Tanach.xml.zip
(members Books/<Book>.xml for all 39 books, plus the site's own
License.html). This script fetches that single archive.
(The URL https://www.tanach.us/Tanach.xml named in the work order
does NOT serve the Tanakh XML — it returns the site's About page
wrapped in a <Tanach> element (2.9 KB of HTML). Per-book files also
exist at https://tanach.us/Books/<Book>.xml — note the archive's
underscore names: Samuel_1, Kings_1, Chronicles_2, Song_of_Songs —
but the archive is the site's canonical bulk route and is what this
pipeline uses. The *.DH.xml members (Documentary Hypothesis
markings) are ignored.)

Licence basis (quoted verbatim in LICENSE-EVIDENCE.md): the site's
License page states "All biblical Hebrew text, in any format, may be
viewed or copied without restriction", and each book's TEI header
carries <availability status="free">Freely available</availability>.
Note the site's own precision: "The text presented at this site is
not the Westminster Leningrad Codex (WLC); please do not represent
it as such." — this asset is therefore described as UXLC (derived
from WLC 4.20), never as the WLC itself.

App shape: 66 slots in CORE order (data.json), OT books filled in
Hebrew versification (the XML's own chapter/verse numbering — Psalms
superscriptions count as verse 1 etc.), NT slots []. Differences vs
data.json verse counts are printed as run stats.

Verse reconstruction from the XML: a <v> holds <w> word elements in
reading order. Tokens are joined with a single space, except no
space follows a token ending in maqaf (U+05BE, the Hebrew hyphen
that binds words). Qere/Ketiv: a <k> (ketiv, written form) followed
by <q> (qere, read form) — the running text uses the QERE, so <k>
text is skipped and <q> text is included in place. Empty paragraph
markers <pe/> and <samekh/> are structural and carry no text.
<x> elements are annotation anchors, NOT text (their content is a
note code: "X" = verse not in the Leningrad Codex, included for
continuity of verse numbering; "8" = inverted nun in the text —
paired with an empty <reversednun/>); both are skipped.
"""

import json
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORK = HERE / "work" / "hebrew"
DATA_JSON = ROOT / "flutter" / "assets" / "data.json"
OUT_JSON = ROOT / "flutter" / "assets" / "hebrew.json"
UA = "WovenWordStudio/1.0 (Hebrew data pipeline; unrestricted text)"
MAQAF = "־"

# core book index -> member name inside Books/Tanach.xml.zip
CORE_TO_FILE = {
    0: "Genesis", 1: "Exodus", 2: "Leviticus", 3: "Numbers",
    4: "Deuteronomy", 5: "Joshua", 6: "Judges", 7: "Ruth",
    8: "Samuel_1", 9: "Samuel_2", 10: "Kings_1", 11: "Kings_2",
    12: "Chronicles_1", 13: "Chronicles_2", 14: "Ezra", 15: "Nehemiah",
    16: "Esther", 17: "Job", 18: "Psalms", 19: "Proverbs",
    20: "Ecclesiastes", 21: "Song_of_Songs", 22: "Isaiah",
    23: "Jeremiah", 24: "Lamentations", 25: "Ezekiel", 26: "Daniel",
    27: "Hosea", 28: "Joel", 29: "Amos", 30: "Obadiah", 31: "Jonah",
    32: "Micah", 33: "Nahum", 34: "Habakkuk", 35: "Zephaniah",
    36: "Haggai", 37: "Zechariah", 38: "Malachi",
}
ZIP_URL = "https://www.tanach.us/Books/Tanach.xml.zip"
ZIP_PATH = HERE / "work" / "Tanach.xml.zip"


def fetch(name: str) -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / f"{name}.xml"
    if path.exists() and path.stat().st_size > 10_000:
        return path
    if not ZIP_PATH.exists():
        req = urllib.request.Request(ZIP_URL,
                                     headers={"User-Agent": UA})
        with urllib.request.urlopen(req) as r:
            ZIP_PATH.write_bytes(r.read())
    import zipfile
    with zipfile.ZipFile(ZIP_PATH) as z:
        data = z.read(f"Books/{name}.xml")
    path.write_bytes(data)
    return path


def verse_text(v: ET.Element, stats: dict) -> str:
    tokens: list[str] = []
    for child in v:
        if child.tag in ("w", "q"):
            if child.text:
                tokens.append(child.text.strip())
        elif child.tag == "k":
            stats["ketiv_skipped"] += 1
        elif child.tag in ("pe", "samekh", "x", "reversednun"):
            stats["markers_skipped"] += 1
        else:
            stats.setdefault("unknown_tags", {})
            stats["unknown_tags"][child.tag] = \
                stats["unknown_tags"].get(child.tag, 0) + 1
            if child.text and child.text.strip():
                tokens.append(child.text.strip())
    out = ""
    for tok in tokens:
        if not out:
            out = tok
        elif out.endswith(MAQAF):
            out += tok
        else:
            out += " " + tok
    return out


def main() -> int:
    core = json.loads(DATA_JSON.read_text(encoding="utf-8"))
    books_meta = core["books"]
    core_counts = {(ch["b"], ch["c"]): ch["v"] for ch in core["chapters"]}

    slots: list = [[] for _ in range(66)]
    total = 0
    mismatches = []
    chapter_diffs = []
    stats = {"ketiv_skipped": 0, "markers_skipped": 0}
    for idx in range(39):
        path = fetch(CORE_TO_FILE[idx])
        root = ET.parse(path).getroot()
        book_el = root.find("tanach/book")
        if book_el is None:
            print(f"ERROR: {path.name}: no tanach/book element",
                  file=sys.stderr)
            return 1
        name_el = book_el.find("names/name")
        xml_name = name_el.text if name_el is not None else "?"
        chapters = []
        for c in book_el.findall("c"):
            verses = [verse_text(v, stats) for v in c.findall("v")]
            chapters.append(verses)
        slots[idx] = chapters
        total += sum(len(c) for c in chapters)
        if len(chapters) != books_meta[idx]["chapters"]:
            chapter_diffs.append((books_meta[idx]["name"], xml_name,
                                  len(chapters),
                                  books_meta[idx]["chapters"]))
        for ci, chapter in enumerate(chapters, start=1):
            cc = core_counts.get((idx, ci))
            if cc is not None and len(chapter) != cc:
                mismatches.append((books_meta[idx]["name"], ci,
                                   len(chapter), cc))
    OUT_JSON.write_text(json.dumps(slots, ensure_ascii=False,
                                   separators=(",", ":")),
                        encoding="utf-8")
    print(f"wrote {OUT_JSON} ({OUT_JSON.stat().st_size} bytes)")
    print(f"total verses: {total}")
    print(f"stats: {stats}")
    print(f"chapter-count differences vs data.json: {chapter_diffs}")
    print(f"verse-count mismatches ({len(mismatches)}):")
    for name, ci, hc, cc in mismatches:
        print(f"  {name} {ci}: Hebrew {hc} vs core {cc}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
