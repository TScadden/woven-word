"""Harvest General Conference talk facts from the SCI public index.

For every conference 1942..present, A (April) and O (October), fetch
the index's conference page (/citation_index/gc_ajax/<year>/<S>) and
record per talk: SCI talk id, speaker, title, session name, the
Gospel Library (churchofjesuschrist.org) watch URL the index itself
publishes for that talk, when it has one, and the talk's own page
URL on the index itself (see sci_talk_url). Facts only — no talk
text is fetched or stored. Checkpointed to work/talks.jsonl (one JSON
object per talk); reruns skip conferences already recorded in
work/conferences_done.txt.
"""
import html as htmllib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sci_client import get

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "work")
FIRST_YEAR = 1942
LAST_YEAR = 2026

SESSION_RE = re.compile(r'class="sessiontitle">([^<]+)<')
TALK_RE = re.compile(
    r"getTalk\('(\d+)'\);?\">\s*<div class=\"speaker\">(.*?)</div><!--\s*-->"
    r"<div class=\"talktitle[^\"]*\">(.*?)</div>",
    re.S,
)
WATCH_RE = re.compile(r"watchTalk\('(\d+)',\s*'([^']+)'\)")


def sci_talk_url(tid):
    """The talk's own page on the Scripture Citation Index.

    The conference pages link each talk only through
    getTalk('<id>') — there is no href to copy. The URL form is
    the index's own published resolution of that link: the site's
    frontend code (static/homepage/scripts/base.js, decodeCenter)
    maps a talk id to /content/talks_ajax/<id>/, and that endpoint
    serves the talk's own page (verified live 2026-10-14: id 1 =
    the 1942 Heber J. Grant talk recorded below it in this file's
    harvest). The id comes from the conference page's link, never
    from a guessed slug or pattern over titles.
    """
    return f"https://scriptures.byu.edu/content/talks_ajax/{tid}/"


def clean(s):
    return re.sub(r"\s+", " ", htmllib.unescape(s)).strip()


def normalize_church_url(url):
    """Return (url, kind): the index's own per-talk URL normalized to
    the modern canonical study URL, or (None, 'none'). Legacy
    lds.org /general-conference/<y>/<m>/<slug> links are rebuilt as
    churchofjesuschrist.org/study/general-conference/<y>/<m>/<slug>;
    the slug always comes from the index's published link, never
    guessed. Anything unrecognized is dropped (kind 'none')."""
    url = htmllib.unescape(url).strip()
    m = re.search(
        r"(?:churchofjesuschrist\.org/study|lds\.org)"
        r"/general-conference/(\d{4})/(\d{2})/([A-Za-z0-9\-]+)",
        url,
    )
    if m:
        y, mo, slug = m.groups()
        return (
            f"https://www.churchofjesuschrist.org/study/"
            f"general-conference/{y}/{mo}/{slug}?lang=eng",
            "talk",
        )
    return None, "none"


def parse_conference(html, year, session):
    # Split the page into session blocks in document order.
    parts = SESSION_RE.split(html)
    # parts: [pre, name1, body1, name2, body2, ...]
    talks = []
    watch = {}
    for tid, url in WATCH_RE.findall(html):
        nurl, kind = normalize_church_url(url)
        if kind == "talk":
            watch[tid] = nurl
    for i in range(1, len(parts) - 1, 2):
        session_name = clean(parts[i])
        body = parts[i + 1]
        for tid, speaker, title in TALK_RE.findall(body):
            talks.append(
                {
                    "sci": int(tid),
                    "speaker": clean(speaker),
                    "title": clean(title),
                    "year": year,
                    "session": session,
                    "sessionName": session_name,
                    "url": watch.get(tid),
                    "indexUrl": sci_talk_url(tid),
                }
            )
    return talks


def backfill_index_urls():
    """Add indexUrl to checkpointed talks.jsonl records that predate
    the field. No fetches: each record's sci id was itself recorded
    from the conference page's getTalk link, so the URL derives
    from data the harvest already took from those pages. Order and
    all other fields are preserved byte-for-byte per record (the
    JSON is re-serialized with the same separators json.dumps
    produced originally)."""
    path = os.path.join(WORK, "talks.jsonl")
    lines = open(path, encoding="utf-8").read().splitlines()
    out, added = [], 0
    for line in lines:
        t = json.loads(line)
        if not t.get("indexUrl"):
            t["indexUrl"] = sci_talk_url(t["sci"])
            added += 1
        out.append(json.dumps(t, ensure_ascii=False))
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"backfilled indexUrl on {added} of {len(out)} records")


def main():
    if "--backfill-index-urls" in sys.argv:
        backfill_index_urls()
        return
    os.makedirs(WORK, exist_ok=True)
    done_path = os.path.join(WORK, "conferences_done.txt")
    done = set()
    if os.path.exists(done_path):
        done = set(open(done_path).read().split())
    out = open(os.path.join(WORK, "talks.jsonl"), "a", encoding="utf-8")
    total = 0
    for year in range(FIRST_YEAR, LAST_YEAR + 1):
        for session in ("A", "O"):
            key = f"{year}-{session}"
            if key in done:
                continue
            try:
                html = get(f"/citation_index/gc_ajax/{year}/{session}")
            except Exception as e:  # one bad page must not kill the run
                print(f"{key}: FETCH FAILED {e} (left for resume)",
                      flush=True)
                continue
            talks = parse_conference(html, year, session) if html else []
            for t in talks:
                out.write(json.dumps(t, ensure_ascii=False) + "\n")
            out.flush()
            total += len(talks)
            with open(done_path, "a") as f:
                f.write(key + "\n")
            print(f"{key}: {len(talks)} talks", flush=True)
    out.close()
    print(f"done, {total} talks this run")


if __name__ == "__main__":
    main()
