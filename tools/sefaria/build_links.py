#!/usr/bin/env python3
"""Build flutter/assets/sefaria.json — Sefaria citation facts.

Source: Sefaria's public bulk export bucket (offered for bulk
download; see LICENSE-EVIDENCE.md and README.md):
    https://storage.googleapis.com/sefaria-export/links/links0.csv
    … links12.csv   (13 files, fetched sequentially, cached in work/)

CSV format (header, verbatim — including Sefaria's own spelling):
    Citation 1,Citation 2,Conection Type,Text 1,Text 2,Category 1,Category 2
Each row links two refs (Citation 1 / Citation 2); Text N is the
book/work title of side N and Category N its Sefaria category.

FILTER (board run 9 packet, scope call 6; data-desk instructions):
  * Keep a row only when EXACTLY ONE side is a Tanakh verse ref and
    the other side is a non-Tanakh work (Talmud, Midrash, commentary,
    halakhah, reference, etc. — any category other than Tanakh).
  * Drop Tanakh<->Tanakh rows.
  * Drop any row touching the New Testament entirely (Sefaria's
    corpus is Jewish; a title guard list is applied anyway).
  * A Tanakh verse RANGE expands to its verses (walking chapters
    with data.json verse counts; an end verse past the chapter count
    caps at that count — that is the only capping; a range's START,
    and any single ref, that is out of range drops the row: refs are
    never clamped into a different verse).
  * Chapter-only Tanakh refs (e.g. "Genesis 1") expand to the whole
    chapter.

OUTPUT: {"v":1, "works":[titles, sorted alphabetically],
"links":[[globalChapter, verse, workIndex, count], …],
"refs":{"<globalChapter>:<verse>:<workIndex>": "<source ref>"}}
  * globalChapter = 0-based index into data.json chapters[]
    (OT spans 0..928 — verified from data.json: books 0..38 have 929
    chapters total; Malachi ch.4 = global 928).
  * verse = 1-based verse number within that chapter.
  * works are sorted alphabetically; links sorted by
    (chapter, verse, workIndex).
  * refs holds, per (chapter, verse, work), the single MOST SPECIFIC
    source citation string seen for that triple: specificity =
    number of numeric ref components after the work title (more =
    deeper), ties broken by the lexicographically smallest string.
  * The citing work's display title is the Text field of the
    non-Tanakh side — the book part of its refs (e.g. "Rashi on
    Genesis", "Berakhot", "Bereshit Rabbah").

Link-out URL (for the app): https://www.sefaria.org/<ref> with the
ref's spaces replaced by underscores (Sefaria's ref-URL format).
"""

import csv
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORK = HERE / "work" / "links"
DATA_JSON = ROOT / "flutter" / "assets" / "data.json"
OUT_JSON = ROOT / "flutter" / "assets" / "sefaria.json"
UA = "WovenWordStudio/1.0 (Sefaria links pipeline; bulk export)"
BASE = "https://storage.googleapis.com/sefaria-export/links"
N_FILES = 13

# Sefaria Tanakh Text title -> core book index (data.json)
TANAKH = {
    "Genesis": 0, "Exodus": 1, "Leviticus": 2, "Numbers": 3,
    "Deuteronomy": 4, "Joshua": 5, "Judges": 6, "Ruth": 7,
    "I Samuel": 8, "II Samuel": 9, "I Kings": 10, "II Kings": 11,
    "I Chronicles": 12, "II Chronicles": 13, "Ezra": 14,
    "Nehemiah": 15, "Esther": 16, "Job": 17, "Psalms": 18,
    "Proverbs": 19, "Ecclesiastes": 20, "Song of Songs": 21,
    "Isaiah": 22, "Jeremiah": 23, "Lamentations": 24, "Ezekiel": 25,
    "Daniel": 26, "Hosea": 27, "Joel": 28, "Amos": 29, "Obadiah": 30,
    "Jonah": 31, "Micah": 32, "Nahum": 33, "Habakkuk": 34,
    "Zephaniah": 35, "Haggai": 36, "Zechariah": 37, "Malachi": 38,
}
NT_TITLES = {
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "I Corinthians", "II Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "I Thessalonians",
    "II Thessalonians", "I Timothy", "II Timothy", "Titus",
    "Philemon", "Hebrews", "James", "I Peter", "II Peter",
    "I John", "II John", "III John", "Jude", "Revelation",
}

REF_RE = re.compile(
    r"^(\d+)(?::(\d+))?(?:-(?:(\d+):)?(\d+))?$")


class Core:
    def __init__(self, data_path: Path):
        core = json.loads(data_path.read_text(encoding="utf-8"))
        self.books = core["books"]            # [{abbr,name,chapters,start}]
        self.counts = {}                       # (book, ch1) -> verse count
        for ch in core["chapters"]:
            self.counts[(ch["b"], ch["c"])] = ch["v"]

    def expand(self, book: int, ref_tail: str):
        """Expand a Tanakh ref tail ('1:1', '1:1-5', '1:1-2:3', '1')
        to [(globalChapter, verse)] or return None if the ref is
        unparseable or its start is out of range."""
        m = REF_RE.match(ref_tail.strip())
        if not m:
            return None
        sc = int(m.group(1))
        sv = int(m.group(2)) if m.group(2) else None
        ec = int(m.group(3)) if m.group(3) else None
        ev = int(m.group(4)) if m.group(4) else None
        nch = self.books[book]["chapters"]
        if sc < 1 or sc > nch:
            return None
        if sv is not None and (sv < 1 or sv > self.counts[(book, sc)]):
            return None
        if ev is None:                       # single verse or chapter
            if sv is None:
                cnt = self.counts[(book, sc)]
                return [(self.books[book]["start"] + sc - 1, v)
                        for v in range(1, cnt + 1)]
            return [(self.books[book]["start"] + sc - 1, sv)]
        # range
        if ec is None:
            ec = sc
        if ec < sc:
            return None
        if ec > nch:
            ec = nch                           # cap walk at book end
            ev = None
        out = []
        for ch in range(sc, ec + 1):
            cnt = self.counts[(book, ch)]
            lo = sv if (ch == sc and sv) else 1
            hi = cnt
            if ch == ec and ev is not None:
                hi = min(ev, cnt)              # cap at chapter count
            if hi < lo:
                continue
            g = self.books[book]["start"] + ch - 1
            out.extend((g, v) for v in range(lo, hi + 1))
        return out or None


def specificity(ref: str, title: str) -> tuple:
    tail = ref[len(title):].strip() if ref.startswith(title) else ref
    parts = [p for p in re.split(r"[:.\s]+", tail) if p]
    return (len(parts), -len(ref))


def fetch(i: int) -> Path:
    """Download links{i}.csv via curl with resume (-C -) and retries,
    verified against the HEAD Content-Length. (Load-bearing: a plain
    streamed urllib read silently truncated links0.csv mid-character
    on run 1, and the proxy repeatedly dropped links3.csv ~500 KB
    short; size verification + resume is what makes the cache safe
    to trust.)"""
    import subprocess
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / f"links{i}.csv"
    url = f"{BASE}/links{i}.csv"
    head = subprocess.run(
        ["curl", "-sI", "-A", UA, url], capture_output=True, text=True)
    expected = None
    for line in head.stdout.splitlines():
        if line.lower().startswith("x-goog-stored-content-length:"):
            expected = int(line.split(":")[1].strip())
    if expected is None:
        raise RuntimeError(f"{path.name}: no stored-length header")
    for _ in range(30):
        have = path.stat().st_size if path.exists() else 0
        if have == expected:
            return path
        if have > expected:
            path.unlink()
        subprocess.run(
            ["curl", "-sL", "-C", "-", "--retry", "5",
             "--retry-all-errors", "-A", UA, "-o", str(path), url],
            check=False)
        time.sleep(0.5)  # sequential, ordinary pacing
    have = path.stat().st_size if path.exists() else 0
    raise RuntimeError(f"{path.name}: got {have} of {expected} bytes")


def main() -> int:
    core = Core(DATA_JSON)
    stats = {
        "rows_read": 0, "kept_rows": 0, "link_instances": 0,
        "dropped_both_tanakh": 0, "dropped_no_tanakh": 0,
        "dropped_nt": 0, "dropped_out_of_range": 0,
        "dropped_unparseable": 0,
    }
    unparseable_examples = []
    unknown_tanakh_category_texts = {}
    kept_categories = {}
    agg: dict[tuple[int, int, str], int] = {}
    best_ref: dict[tuple[int, int, str], tuple[tuple, str]] = {}

    for i in range(N_FILES):
        path = fetch(i)
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.reader(f)
            header = next(reader)
            if header[:7] != ["Citation 1", "Citation 2",
                               "Conection Type", "Text 1", "Text 2",
                               "Category 1", "Category 2"]:
                print(f"ERROR {path.name}: unexpected header {header}",
                      file=sys.stderr)
                return 1
            for row in reader:
                if len(row) < 7:
                    continue
                stats["rows_read"] += 1
                cit1, cit2, _ct, txt1, txt2, cat1, cat2 = row[:7]
                if txt1 in NT_TITLES or txt2 in NT_TITLES:
                    stats["dropped_nt"] += 1
                    continue
                t1 = txt1 in TANAKH
                t2 = txt2 in TANAKH
                # transparency: Tanakh-category texts we do not map
                for txt, cat in ((txt1, cat1), (txt2, cat2)):
                    if cat == "Tanakh" and txt not in TANAKH:
                        unknown_tanakh_category_texts[txt] = \
                            unknown_tanakh_category_texts.get(txt, 0) + 1
                if t1 and t2:
                    stats["dropped_both_tanakh"] += 1
                    continue
                if not t1 and not t2:
                    stats["dropped_no_tanakh"] += 1
                    continue
                if t1:
                    book, tail_src = TANAKH[txt1], cit1
                    work, work_cit, work_cat = txt2, cit2, cat2
                else:
                    book, tail_src = TANAKH[txt2], cit2
                    work, work_cit, work_cat = txt1, cit1, cat1
                # Integration narrowing (Maren, board run 9):
                # (a) canonical work titles — the export's Text
                # field carries section-level titles for composite
                # works (Siddur sections, Zohar volumes, dictionary
                # headwords); the app's unit is the work, Sefaria's
                # composite convention is a comma path, so the
                # canonical title is the first comma segment.
                work = work.split(", ")[0]
                # (b) the Reference category (lexicons, dictionaries)
                # links verses by word occurrence, not by engagement
                # with the verse — 180k rows of noise for a
                # connections layer (BDB alone: ~145k segment
                # triples). Excluded; every other category stands.
                if work_cat == "Reference":
                    stats["dropped_reference"] =                         stats.get("dropped_reference", 0) + 1
                    continue
                if not tail_src.startswith(
                        (txt1 if t1 else txt2) + " ") and \
                        tail_src != (txt1 if t1 else txt2):
                    stats["dropped_unparseable"] += 1
                    if len(unparseable_examples) < 10:
                        unparseable_examples.append(tail_src)
                    continue
                title = txt1 if t1 else txt2
                tail = tail_src[len(title):].strip()
                if not tail:
                    stats["dropped_unparseable"] += 1
                    if len(unparseable_examples) < 10:
                        unparseable_examples.append(tail_src)
                    continue
                verses = core.expand(book, tail)
                if verses is None:
                    # distinguish unparseable from out-of-range
                    if REF_RE.match(tail):
                        stats["dropped_out_of_range"] += 1
                    else:
                        stats["dropped_unparseable"] += 1
                        if len(unparseable_examples) < 10:
                            unparseable_examples.append(tail_src)
                    continue
                stats["kept_rows"] += 1
                kept_categories[work_cat] = \
                    kept_categories.get(work_cat, 0) + 1
                spec = specificity(work_cit, work)
                for gchap, verse in verses:
                    key = (gchap, verse, work)
                    agg[key] = agg.get(key, 0) + 1
                    stats["link_instances"] += 1
                    cur = best_ref.get(key)
                    cand = (spec, work_cit)
                    if cur is None or cand[0] > cur[0] or \
                            (cand[0] == cur[0] and work_cit < cur[1]):
                        best_ref[key] = cand
        print(f"links{i}.csv done; rows so far {stats['rows_read']}",
              flush=True)

    works = sorted({k[2] for k in agg})
    widx = {w: n for n, w in enumerate(works)}
    links = sorted([g, v, widx[w], c] for (g, v, w), c in agg.items())
    refs = {f"{g}:{v}:{widx[w]}": ref
            for (g, v, w), (_s, ref) in best_ref.items()}
    out = {"v": 1, "works": works,
           "links": [list(x) for x in links], "refs": refs}
    OUT_JSON.write_text(json.dumps(out, ensure_ascii=False,
                                   separators=(",", ":")),
                        encoding="utf-8")
    print(f"wrote {OUT_JSON} ({OUT_JSON.stat().st_size} bytes)")
    print(json.dumps(stats, indent=1, ensure_ascii=False))
    print(f"distinct works: {len(works)}")
    print(f"aggregated link triples: {len(links)}")
    print(f"kept by non-Tanakh category: {kept_categories}")
    print(f"Tanakh-category texts not in book map: "
          f"{unknown_tanakh_category_texts}")
    print(f"unparseable examples: {unparseable_examples}")
    print("works list:", works)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
