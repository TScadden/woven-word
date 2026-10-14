# Conference citation pipeline — Woven Word run 8

Builds `flutter/assets/conference.json`: Bible verse ↔ General
Conference talk citation facts for the app's LDS connections layer.

## Governing decisions (team memory)

- `team/memory/decisions/2026-10-14-founder-ruling-conference-facts.md`
  — the founder's ruling: citation **facts** (talk title, speaker,
  conference year/session, cited references) are not copyrightable
  (Feist); the app never contains talk text. The ruling overrides the
  earlier research gate; Rusty's method limits bind HOW the studio
  works (below).
- `team/memory/decisions/2026-10-14-citation-criterion.md` — formal
  citations, direct quotes, and spoken mentions all count as
  connections.

## Method limits (binding)

1. Facts only. No talk text is fetched for storage, and none is
   shipped. (The per-talk pages of the index were not used at all;
   the citation leaf pages carry metadata only.)
2. **No scraping of churchofjesuschrist.org** — its Terms of Use
   prohibit automated copying/redistribution. The only Church URLs
   in the dataset are link targets recorded from the index's own
   published links (see "Talk links").
3. **No extraction of the Scripture Citation Index app database.**
   Facts are recorded from the index's public web pages, in the
   app's own schema, one page at a time.
4. Ordinary-use pacing: sequential requests, ~1.0–1.5 s apart, an
   identifying user agent, backoff on 5xx, a 60 s cool-down on any
   429. Two shard processes (Old / New Testament) run concurrently —
   aggregate load stays at what a couple of browsing users generate.
5. Attribution: the app credits the Scripture Citation Index
   wherever its facts inform the data.

## Sources

- Conference talk facts: the index's public conference pages
  (`scriptures.byu.edu/citation_index/gc_ajax/<year>/<A|O>`,
  1942–2026) — speaker, title, session name, and the Gospel Library
  watch URL the index publishes per talk.
- Citation facts: the index's public citation pages
  (`/citation_index/citation_ajax/Any/1830/2026/all/s/f/<book>/<ch>`
  lists cited verse units per chapter; `?verses=<unit>` lists the
  citing sources). Only entries in General Conference format
  (`YYYY-A:page` / `YYYY-O:page`) are recorded; Journal of
  Discourses and TPJS entries on the same pages are counted and
  skipped (out of scope: this layer is conference talks).
- JST-marked cited units are included as citations of the same
  Bible verses and counted separately in the run stats.

## Talk links ("Read in Gospel Library")

Per the founder's addition (Oct 14, 2026), talk surfaces link OUT
to Gospel Library; the app hosts no talk content.

- When the index publishes a per-talk Church URL, it is recorded
  and normalized to the canonical form
  `https://www.churchofjesuschrist.org/study/general-conference/<year>/<month>/<slug>?lang=eng`
  (legacy `lds.org/general-conference/…` links are rebuilt into the
  same shape; the slug always comes from the index's published
  link, never guessed). These URLs are universal links: they open
  Gospel Library when installed and the web study view otherwise.
- Talks with no per-talk link (mostly pre-1971, before the Church
  site carries per-talk pages) link to the conference itself:
  `…/study/general-conference/<year>/<04|10>?lang=eng`, flagged
  `"c":1` in the asset so the UI can stay truthful about where the
  link lands.

## Pipeline

| step | script | output (work/) |
| --- | --- | --- |
| 1 | `harvest_conferences.py` | `talks.jsonl` |
| 2 | `harvest_citations.py ot` / `nt` | `edges_ot.jsonl`, `edges_nt.jsonl` |
| 3 | `build_dataset.py` | `flutter/assets/conference.json`, `dataset_stats.json` |

All steps are checkpointed and resumable; rerunning a harvester
skips completed conferences/chapters. `build_dataset.py` expands
cited units to verse-level edges, deduplicates, clamps to the
app's canon (`flutter/assets/data.json`), keeps only talks citing
at least one Bible verse, and prints full coverage stats.

## Run log (2026-10-14)

Harvest, as run (all counts from the pipeline's own logs):

- Conferences: 170 conference pages requested; **168 harvested**
  (5,874 talks). Two pages return HTTP 500 from the index itself,
  on repeated retry: **1957-O** and **2026-O**. Their talks are
  therefore absent (April 1957 is present; coverage runs
  April 1942 – April 2026). No talk had to be synthesized from
  leaf facts — every citing talk matched the conference harvest.
- Citations: all **1,189 of 1,189 Bible chapters** queried;
  9,856 cited verse-units fetched; **30,682** General Conference
  citation rows recorded; **~25,900** Journal of Discourses / TPJS
  entries on the same pages counted and skipped. Four shard
  processes (OT 1/2, NT 1/2) ran at the pacing above; two died on
  server timeouts and one on a host restart, all resumed from
  per-chapter checkpoints with no data loss.
- Dataset (`build_dataset.py`): cited units expanded to
  **68,999 deduped verse-level edges** (242 of them derived from
  JST-marked units, included as citations of the same verses);
  **4,964 talks** cite at least one Bible verse and appear in the
  dataset (the other 910 harvested talks cite no Bible verse and
  are excluded by design — the app is a Bible app, and the browse
  copy discloses the rule); **905 of 1,189 chapters** have at
  least one citing talk (the rest are simply never cited in
  conference, per the index); **3,014 talks** carry a per-talk
  Gospel Library link and **1,950** the flagged conference-level
  fallback. Asset size: **1,997,788 bytes**.
- Known gaps, stated plainly: October 1957 and October 2026
  conferences are missing (index-side, above); citation facts are
  exactly as complete as the index's own coverage — talks the
  index has not processed do not appear.
