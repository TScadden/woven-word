#!/usr/bin/env python3
"""Cap flutter/assets/sefaria.json at the 25 most-cited works
per verse.

Integration step (Maren, board run 9) over build_links.py's
output. Sefaria's link density is far beyond an app bundle or a
phone's JSON parser: 1.75M (verse, work) triples, a median of
41 citing works per linked verse and a p90 of 203. The app
keeps, per verse, the 25 works with the most citing segments
(count desc, title asc — the connections sheet's own order),
each with its recorded source ref for link-out.

Nothing is hidden: the output records, per capped verse, the
full work total in "capped": {"<chapter>:<verse>": total}, and
the app renders a "See all links on Sefaria" row for those
verses — Sefaria itself is the layer's reading destination by
design. Verses with 25 or fewer works are complete as shipped.

Idempotent: re-running on capped output changes nothing (the
kept set is already the top 25 and totals are preserved).
Run after build_links.py.
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
ASSET = ROOT / "flutter" / "assets" / "sefaria.json"
CAP = 25


def main() -> int:
    raw = json.loads(ASSET.read_text(encoding="utf-8"))
    works = raw["works"]
    refs_in = raw.get("refs", {})
    capped_in = raw.get("capped", {})

    by_verse: dict[tuple[int, int], list[list[int]]] = {}
    for ch, v, wi, count in raw["links"]:
        by_verse.setdefault((ch, v), []).append([ch, v, wi, count])

    links = []
    refs = {}
    capped = {}
    for (ch, v), rows in by_verse.items():
        total = capped_in.get(f"{ch}:{v}", len(rows))
        rows.sort(key=lambda r: (-r[3], works[r[2]]))
        kept = rows[:CAP]
        links.extend(kept)
        if total > len(kept):
            capped[f"{ch}:{v}"] = total
        for _ch, _v, wi, _c in kept:
            key = f"{ch}:{v}:{wi}"
            if key in refs_in:
                refs[key] = refs_in[key]

    links.sort()
    out = {"v": 1, "works": works, "links": links, "refs": refs}
    if capped:
        out["capped"] = capped
    ASSET.write_text(
        json.dumps(out, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"links: {len(raw['links'])} -> {len(links)}")
    print(f"capped verses: {len(capped)}")
    print(f"refs kept: {len(refs)}")
    print(f"wrote {ASSET} ({ASSET.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
