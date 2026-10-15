#!/usr/bin/env python3
"""Narrow flutter/assets/sefaria.json to canonical works.

Integration step (Maren, board run 9) over build_links.py's
faithful output. The export's Text field carries section-level
titles for composite works (individual Siddur sections, Zohar
per-parsha volumes, dictionary headwords, essay titles), which
produced 33,854 "works" and a 174 MB asset — unusable in an app
bundle and wrong for the app's model, which is ONE row per work
per verse ("which works cite this verse").

Canonicalization: a work's title is its first comma segment —
Sefaria's composite-title convention is a comma path
("Siddur Ashkenaz, Weekday, Shacharit, …" -> "Siddur Ashkenaz";
"A Dictionary of the Talmud, <headword>" -> "A Dictionary of
the Talmud"). Titles without commas are already canonical
("Rashi on Genesis", "Berakhot", "Bereshit Rabbah").

Counts re-aggregate (sum) per (chapter, verse, canonical work).
Refs re-pick per triple by the pipeline's own specificity rule
(most numeric components after the title; ties -> smallest
string). No verse-level fact is dropped: every (chapter, verse,
segment work) fact survives inside its canonical work's count.

Idempotent: canonical titles contain no comma, so re-running
changes nothing. Run after build_links.py.
"""

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
ASSET = ROOT / "flutter" / "assets" / "sefaria.json"


def canonical(title: str) -> str:
    return title.split(", ")[0]


def specificity(ref: str) -> int:
    return len(re.findall(r"\d+", ref))


def main() -> int:
    raw = json.loads(ASSET.read_text(encoding="utf-8"))
    works = raw["works"]
    canon_of = [canonical(w) for w in works]
    canon_works = sorted(set(canon_of))
    cidx = {w: i for i, w in enumerate(canon_works)}

    agg: dict[tuple[int, int, int], int] = {}
    for ch, v, wi, count in raw["links"]:
        key = (ch, v, cidx[canon_of[wi]])
        agg[key] = agg.get(key, 0) + count

    refs_in = raw.get("refs", {})
    best: dict[tuple[int, int, int], tuple[int, str]] = {}
    for key, ref in refs_in.items():
        ch_s, v_s, wi_s = key.split(":")
        ck = (int(ch_s), int(v_s), cidx[canon_of[int(wi_s)]])
        cand = (specificity(ref), ref)
        cur = best.get(ck)
        if (
            cur is None
            or cand[0] > cur[0]
            or (cand[0] == cur[0] and cand[1] < cur[1])
        ):
            best[ck] = cand

    links = sorted([list(k) + [c] for k, c in agg.items()])
    refs = {
        f"{ch}:{v}:{wi}": ref for (ch, v, wi), (_s, ref) in best.items()
    }
    out = {"v": 1, "works": canon_works, "links": links, "refs": refs}
    ASSET.write_text(
        json.dumps(out, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"works: {len(works)} -> {len(canon_works)}")
    print(f"links: {len(raw['links'])} -> {len(links)}")
    print(f"refs: {len(refs_in)} -> {len(refs)}")
    print(f"wrote {ASSET} ({ASSET.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
