"""Assemble flutter/assets/conference.json from the harvest outputs.

Inputs (tools/conference/work/):
  talks.jsonl   — one record per conference talk (SCI id, speaker,
                  title, year, session, session name, Gospel Library
                  URL or null) from harvest_conferences.py
  edges_*.jsonl — one record per (talk, cited verse-unit) GC citation
                  from harvest_citations.py

Output asset shape (fixed contract with the app):
  {"v":1,
   "talks":[{"i":int,"t":title,"s":speaker,"y":year,"e":"A"|"O",
             "n":sessionName,"u":url-or-fallback,"c":0|1,
             "x":index-talk-url-or-null}],
   "edges":[[talkId, globalChapterZeroBased, verse], ...]}
"c" is 1 when "u" is the conference-level fallback link (talks with
no per-talk link, mostly pre-1971). "x" is the talk's own page on
the Scripture Citation Index (scriptures.byu.edu), recorded by
harvest_conferences.py from the index's conference pages — the
founder's Oct 14, 2026 routing correction: talks with no per-talk
Gospel Library link open in the Citation Index, because Gospel
Library's own archive bottoms out at 1971–1979. Only talks citing
at least one Bible verse appear — this is a Bible app's dataset.
Cited units are expanded to verse-level edges and deduplicated;
verses are clamped to the KJV/WEB canon in flutter/assets/data.json.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "work")
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def parse_spec(spec, verse_count, next_verse_count):
    """Expand a cited-unit spec ('26-27', '1,3,27', '26-2:2') into
    (chapter_offset, verse) pairs, clamped to canon lengths."""
    out = []
    for tok in spec.split(","):
        tok = tok.strip()
        if not tok:
            continue
        m = re.fullmatch(r"(\d+)-(\d+):(\d+)", tok)  # cross-chapter
        if m:
            start, _c2, end = (int(x) for x in m.groups())
            for v in range(start, verse_count + 1):
                out.append((0, v))
            for v in range(1, min(end, next_verse_count) + 1):
                out.append((1, v))
            continue
        m = re.fullmatch(r"(\d+)-(\d+)", tok)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            for v in range(a, min(b, verse_count) + 1):
                out.append((0, v))
            continue
        if tok.isdigit():
            v = int(tok)
            if 1 <= v <= verse_count:
                out.append((0, v))
    return out


def main():
    data = json.load(open(os.path.join(REPO, "flutter/assets/data.json")))
    # Global chapter offsets + verse counts from the app canon:
    # books carry {chapters: count, start: global offset}; the
    # top-level chapters array carries each chapter's verse count.
    offsets = [b["start"] for b in data["books"]]
    counts = [c["v"] for c in data["chapters"]]
    total_chapters = len(counts)

    talks_by_sci = {}
    for line in open(os.path.join(WORK, "talks.jsonl"), encoding="utf-8"):
        t = json.loads(line)
        talks_by_sci[t["sci"]] = t

    rows = []
    for name in sorted(os.listdir(WORK)):
        if name.startswith("edges_") and name.endswith(".jsonl"):
            for line in open(os.path.join(WORK, name), encoding="utf-8"):
                rows.append(json.loads(line))
    print(f"harvest rows: {len(rows)}")

    synthesized = 0
    edge_set = set()
    jst_only = set()
    for r in rows:
        sci = r["talkSci"]
        if sci not in talks_by_sci:
            talks_by_sci[sci] = {
                "sci": sci, "speaker": r["speaker"], "title": r["title"],
                "year": r["year"], "session": r["session"],
                "sessionName": "", "url": None,
                # Same published form harvest_conferences.sci_talk_url
                # records from the conference pages' getTalk links.
                "indexUrl": ("https://scriptures.byu.edu/content/"
                             f"talks_ajax/{sci}/"),
            }
            synthesized += 1
        b, ch = r["book"], r["ch"]
        gch = offsets[b] + ch - 1
        vc = counts[gch]
        nvc = counts[gch + 1] if gch + 1 < total_chapters else 0
        for coff, v in parse_spec(r["spec"], vc, nvc):
            key = (sci, gch + coff, v)
            if r["jst"]:
                jst_only.add(key)
            edge_set.add(key)
    jst_edges = len(jst_only & edge_set)
    print(f"verse-level edges (deduped): {len(edge_set)} "
          f"(of which JST-unit-derived: {jst_edges})")
    print(f"talks synthesized from leaf facts (missing from conf "
          f"harvest): {synthesized}")

    # Dataset order = conference program order: year, then session
    # (April before October), then the talk's position in the
    # conference harvest (talks.jsonl preserves the index's own
    # program order within each conference). Surfaces render talks
    # in dataset order (spec §4.3) — never re-sort by title.
    harvest_order = {t["sci"]: n for n, t in enumerate(
        json.loads(l) for l in open(os.path.join(WORK, "talks.jsonl"),
                                    encoding="utf-8"))}
    cited_sci = sorted({k[0] for k in edge_set},
                        key=lambda s: (talks_by_sci[s]["year"],
                                       talks_by_sci[s]["session"],
                                       harvest_order.get(s, 1 << 30)))
    app_id = {sci: i for i, sci in enumerate(cited_sci)}
    talks_out = []
    for sci in cited_sci:
        t = talks_by_sci[sci]
        url, c = t.get("url"), 0
        if not url:
            mm = "04" if t["session"] == "A" else "10"
            url = ("https://www.churchofjesuschrist.org/study/"
                   f"general-conference/{t['year']}/{mm}?lang=eng")
            c = 1
        talks_out.append({
            "i": app_id[sci], "t": t["title"], "s": t["speaker"],
            "y": t["year"], "e": t["session"],
            "n": t.get("sessionName", ""), "u": url, "c": c,
            "x": t.get("indexUrl"),
        })
    edges_out = sorted([app_id[s], g, v] for s, g, v in edge_set)
    asset = {"v": 1, "talks": talks_out, "edges": edges_out}
    out_path = os.path.join(REPO, "flutter/assets/conference.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(asset, f, ensure_ascii=False, separators=(",", ":"))

    confs = {(t["y"], t["e"]) for t in talks_out}
    chapters_hit = {g for _s, g, _v in edge_set}
    with_url = sum(1 for t in talks_out if t["c"] == 0)
    # Read-action routing (founder correction, Oct 14, 2026), counted
    # in the app's own precedence: per-talk Gospel Library first,
    # then the talk's Citation Index page, then the residual
    # conference-level Gospel Library link, then neither.
    route_gl = sum(1 for t in talks_out if t["c"] == 0)
    route_ci = sum(1 for t in talks_out if t["c"] == 1 and t["x"])
    route_conf = sum(1 for t in talks_out if t["c"] == 1 and not t["x"]
                     and t["u"])
    route_none = sum(1 for t in talks_out if t["c"] == 1 and not t["x"]
                     and not t["u"])
    print(f"talks in dataset: {len(talks_out)} across {len(confs)} "
          f"conferences ({min(t['y'] for t in talks_out)}–"
          f"{max(t['y'] for t in talks_out)})")
    print(f"talks with per-talk Gospel Library link: {with_url}; "
          f"conference-level fallback: {len(talks_out) - with_url}")
    print(f"read-action routing: Gospel Library per-talk {route_gl}; "
          f"Citation Index {route_ci}; conference-level residual "
          f"{route_conf}; neither {route_none}")
    print(f"chapters with >=1 edge: {len(chapters_hit)}/{total_chapters}")
    print(f"asset bytes: {os.path.getsize(out_path)} -> {out_path}")
    json.dump({
        "talks": len(talks_out), "edges": len(edges_out),
        "jstEdges": jst_edges, "conferences": len(confs),
        "chaptersHit": len(chapters_hit), "totalChapters": total_chapters,
        "withTalkUrl": with_url, "fallbackUrl": len(talks_out) - with_url,
        "routeGospelLibrary": route_gl, "routeCitationIndex": route_ci,
        "routeConferenceResidual": route_conf, "routeNeither": route_none,
        "synthesizedTalks": synthesized,
        "bytes": os.path.getsize(out_path),
    }, open(os.path.join(WORK, "dataset_stats.json"), "w"), indent=2)


if __name__ == "__main__":
    main()
