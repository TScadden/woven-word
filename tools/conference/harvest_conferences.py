"""Harvest General Conference talk facts from the SCI public index.

For every conference 1942..present, A (April) and O (October), fetch
the index's conference page (/citation_index/gc_ajax/<year>/<S>) and
record per talk: SCI talk id, speaker, title, session name, and the
Gospel Library (churchofjesuschrist.org) watch URL the index itself
publishes for that talk, when it has one. Facts only — no talk text
is fetched or stored. Checkpointed to work/talks.jsonl (one JSON
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
                }
            )
    return talks


def main():
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
