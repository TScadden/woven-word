"""Harvest Bible-verse -> conference-talk citation facts from the SCI
public citation index (scriptures.byu.edu).

Method (facts only): for each Bible book/chapter, the index's chapter
page lists the cited verse units with counts; each unit's leaf page
lists the citing sources. Only General Conference entries (reference
format "YYYY-A:page" / "YYYY-O:page") are recorded — Journal of
Discourses / TPJS entries on the same pages are counted and skipped.
Talk text is never fetched or stored; the leaf pages carry metadata
only (year/session, page, speaker, title, talk id).

Checkpointed per chapter into work/edges_<shard>.jsonl +
work/chapters_done_<shard>.txt; reruns resume. Shards: ot | nt.
"""
import html as htmllib
import json
import os
import re
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sci_client import get

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "work")
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
FILTER = "/citation_index/citation_ajax/Any/1830/2026/all/s/f"

BOOK_RE = re.compile(
    r"getSci\('(\d+)'\)\">\s*<div class=\"book\">(.*?)</div>"
    r"<div class=\"citationcount\">\[(\d+)\]</div>",
    re.S,
)
UNIT_RE = re.compile(
    r"getSci\('(\d+)',\s*'(\d+)',\s*'([^']*)',\s*'([^']*)'\);?\">\s*"
    r"<div class=\"reference\">(.*?)</div>"
    r"<div class=\"citationcount\">\[(\d+)\]</div>",
    re.S,
)
ENTRY_RE = re.compile(
    r"class=\"refcounter\" onclick=\"getTalk\('(\d+)',\s*'(\d+)'\);?\">(.*?)</a>",
    re.S,
)
REF_RE = re.compile(
    r"<div class=\"reference[^\"]*\">(.*?)</div>"
    r"<div class=\"talktitle[^\"]*\">(.*?)</div>",
    re.S,
)
GC_RE = re.compile(r"^(\d{4})-([AO]):(\d+),\s*(.+)$")


def norm_page(h):
    """The index's templates inconsistently backslash-escape quotes;
    normalize once so the parse patterns stay simple."""
    return h.replace("\\'", "'").replace('\\"', '"')


def clean(s):
    return re.sub(r"\s+", " ", htmllib.unescape(s)).strip()


ALIASES = {
    "lev": "leviticus", "num": "numbers", "deut": "deuteronomy",
    "sam": "samuel", "chron": "chronicles", "neh": "nehemiah",
    "eccl": "ecclesiastes", "song": "song of solomon",
    "lam": "lamentations", "obad": "obadiah", "zech": "zechariah",
    "mal": "malachi", "matt": "matthew", "mk": "mark", "lk": "luke",
    "jn": "john", "rom": "romans", "cor": "corinthians",
    "gal": "galatians", "eph": "ephesians", "phil": "philippians",
    "col": "colossians", "thess": "thessalonians", "tim": "timothy",
    "philip": "philippians", "thes": "thessalonians", "philem": "philemon",
    "heb": "hebrews", "jas": "james", "pet": "peter", "rev": "revelation",
    "ps": "psalms", "psalm": "psalms", "prov": "proverbs",
    "isa": "isaiah", "jer": "jeremiah", "ezek": "ezekiel",
    "dan": "daniel", "hos": "hosea", "mic": "micah", "nah": "nahum",
    "hab": "habakkuk", "zeph": "zephaniah", "hag": "haggai",
    "est": "esther", "jdg": "judges", "josh": "joshua",
}


def norm_name(name):
    n = clean(name).lower().rstrip(".")
    m = re.match(r"^(\d)\s+(.*)$", n)
    prefix = ""
    if m:
        prefix, n = m.group(1) + " ", m.group(2)
    n = ALIASES.get(n, n)
    return prefix + n


def book_map():
    """Return {app_book_index: sci_book_id} for the 66 Bible books,
    verified by name-matching the index's book list to data.json."""
    cache = os.path.join(WORK, "bookmap.json")
    if os.path.exists(cache):
        return {int(k): v for k, v in json.load(open(cache)).items()}
    data = json.load(open(os.path.join(REPO, "flutter/assets/data.json")))
    app_names = {}
    for i, b in enumerate(data["books"]):
        app_names[norm_name(b["name"])] = i
    root = norm_page(get(FILTER))
    mapping = {}
    for sci_id, name, _count in BOOK_RE.findall(root):
        key = norm_name(name)
        if key in app_names:
            mapping[app_names[key]] = int(sci_id)
    if len(mapping) != 66:
        print(f"BOOK MAP INCOMPLETE: {len(mapping)}/66 matched")
        for i, b in enumerate(data["books"]):
            if i not in mapping:
                print("  unmatched app book:", i, b["name"])
        sys.exit(1)
    json.dump(mapping, open(cache, "w"))
    return mapping


def parse_leaf(html):
    """Yield (talk_sci_id, year, session, speaker, title) for GC
    entries; also returns the count of non-GC entries skipped."""
    out = []
    skipped = 0
    for talk_id, _cite_id, body in ENTRY_RE.findall(html):
        m = REF_RE.search(body)
        if not m:
            continue
        ref, title = clean(m.group(1)), clean(m.group(2))
        g = GC_RE.match(ref)
        if not g:
            skipped += 1
            continue
        year, session, _page, speaker = g.groups()
        out.append(
            {
                "talkSci": int(talk_id),
                "year": int(year),
                "session": session,
                "speaker": speaker,
                "title": title,
            }
        )
    return out, skipped


def main():
    shard = sys.argv[1] if len(sys.argv) > 1 else "all"
    mapping = book_map()
    if "--map-only" in sys.argv:
        data = json.load(open(os.path.join(REPO, "flutter/assets/data.json")))
        for i in sorted(mapping):
            print(f"app {i:2d} {data['books'][i]['name']:<20} sci {mapping[i]}")
        return
    data = json.load(open(os.path.join(REPO, "flutter/assets/data.json")))
    books = sorted(mapping)
    if shard == "ot":
        books = [b for b in books if b < 39]
    elif shard == "ot1":
        books = [b for b in books if b <= 17]
    elif shard == "ot2":
        books = [b for b in books if 18 <= b < 39]
    elif shard == "nt":
        books = [b for b in books if b >= 39]
    elif shard == "nt1":
        books = [b for b in books if 39 <= b <= 51]
    elif shard == "nt2":
        books = [b for b in books if b >= 52]
    done_path = os.path.join(WORK, f"chapters_done_{shard}.txt")
    done = set()
    if os.path.exists(done_path):
        done = set(open(done_path).read().split())
    out = open(os.path.join(WORK, f"edges_{shard}.jsonl"), "a", encoding="utf-8")
    t0 = time.time()
    tot_edges = tot_units = tot_skip = 0
    for b in books:
        sci = mapping[b]
        n_chapters = data["books"][b]["chapters"]
        for ch in range(1, n_chapters + 1):
            key = f"{b}:{ch}"
            if key in done:
                continue
            page = norm_page(get(f"{FILTER}/{sci}/{ch}"))
            units = {}
            for _sb, _sc, spec, jst, _label, count in UNIT_RE.findall(page):
                if spec:
                    units[(spec, jst)] = int(count)
            rows = []
            skipped = 0
            for (spec, jst), _count in sorted(units.items()):
                q = urllib.parse.quote(spec, safe="0123456789,-:")
                leaf = norm_page(get(f"{FILTER}/{sci}/{ch}?verses={q}"
                           + ("&jst=JST" if jst == "JST" else "")))
                entries, sk = parse_leaf(leaf)
                skipped += sk
                for e in entries:
                    e.update({"book": b, "ch": ch, "spec": spec,
                              "jst": jst == "JST"})
                    rows.append(e)
            for r in rows:
                out.write(json.dumps(r, ensure_ascii=False) + "\n")
            out.flush()
            with open(done_path, "a") as f:
                f.write(key + "\n")
            tot_edges += len(rows)
            tot_units += len(units)
            tot_skip += skipped
            print(f"[{shard}] {data['books'][b]['name']} {ch}: "
                  f"{len(units)} units, {len(rows)} GC edges, "
                  f"{skipped} non-GC skipped | totals: {tot_units} units, "
                  f"{tot_edges} edges, {int(time.time()-t0)}s",
                  flush=True)
    out.close()
    print(f"[{shard}] DONE: {tot_units} units, {tot_edges} edges, "
          f"{tot_skip} non-GC skipped, {int(time.time()-t0)}s")


if __name__ == "__main__":
    main()
