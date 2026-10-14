# Board run 7, Part B — Research gate: General Conference citation-metadata source

- **Date:** 2026-10-14
- **Desk:** Research (reporting to Silas)
- **Founder direction (Oct 14, 2026):** "LDS version" layer — users see which LDS General Conference talks connect to Bible verses; toggle in settings. App stays fully on-device and copyright-free.
- **Guardrail (absolute):** citation metadata only (talk title, speaker, conference/session/date, cited references). No talk text bundled, scraped for content, or reproduced.
- **Gate question:** is there a source whose terms affirmatively permit an independent app to BUNDLE its citation metadata into a shipped product? A source with no findable terms is a finding, not a pass.
- **Method:** real page fetches only; every claim grounded in a fetched URL. Short operative-language quotes only; everything else paraphrased.

## Verdict: FAIL — no terms-clean source exists today

The single best source (BYU Scripture Citation Index) is a complete, maintained, verse-level index, but its only published rights statement is a plain **"All rights reserved"** copyright notice with no terms of use, no license, and no API or dataset — so nothing in the published material grants bundling into a shipped app. The Church's own terms explicitly reserve redistribution to prior written permission and prohibit the scraping route that would rebuild the dataset independently. Every derivative dataset inherits one of those two problems and none carries a license covering the underlying data.

This is a **"no lawful basis to ship on, as of today"** FAIL, not a "feature impossible" FAIL. The viable path to PASS is written permission: from the SCI's rights holders (Galbraith/Liddle) and/or the Church's Intellectual Property office (permissions.churchofjesuschrist.org; the site notes ~45 days for a reply). Until that is in hand, do not build on any candidate below.

---

## Candidate table

| # | Source | Coverage | Fields | Machine-readability | Terms status | Gate read |
|---|--------|----------|--------|--------------------|--------------|-----------|
| 1 | BYU Scripture Citation Index (scriptures.byu.edu) | GC talks **1942–present**; also Journal of Discourses 1839–1886, TPJS | Verse-level: year + session code (A/O), speaker, talk title, page ref; scripture side keyed by book/chapter/verse | **No API, no dataset, no download.** Interactive site + mobile apps only. Third parties have extracted the app's SQLite DBs — extraction is not authorization | "Copyright © 2010-2025, Richard C. Galbraith and Stephen W. Liddle. All rights reserved." No terms of use or license granting reuse found anywhere on the site | FAIL as-is. Needs written permission from the two rights holders |
| 2 | churchofjesuschrist.org (talk pages / study API) | GC online archive starts **April 1971** | Footnotes carry machine-linked scripture refs (`scripture-ref` hrefs with book/chapter/verse), plus title/speaker/date via TOC API. Verse-level via links; free text in older footnotes | A JSON study API exists behind the site, but using it to bulk-copy data is exactly what the site's terms forbid | Terms limit use to personal, noncommercial; forbid any robot, spider, or automated access "for monitoring or copying"; forbid manual copying of material; reserve redistribution to **prior written permission** | FAIL. Scraping for a bundled dataset is contractually prohibited; permission path exists but takes ~45 days and may be denied |
| 3 | GitHub scraper derivatives (carsonordyna, davehedengren, cnoyes/ldt-data, jared-hardinger, cahlan) | Mostly 1971–present or 2016–2025 | Aggregates (counts per verse or per standard work), not talk-level verse edges, in nearly all cases | Code/datasets exist but each derives from one of candidates 1–2 | No LICENSE files in carsonordyna, davehedengren, jared-hardinger; cnoyes claims MIT for its own code but its **citation graphs are gitignored — not published**, so the MIT text cannot cover them anyway | FAIL. They inherit the upstream restrictions and add no rights |
| 4 | nate-kelley-buster / danielbaldwin47 extensions (SCI app DB extracts) | Inherits SCI coverage | Full SCI citation graph (~125.8k citations) as extracted shards | Shipped data exists in these repos | The authors themselves label the extracted data "personal study only" and "not redistributable," and keep it out of any store listing | FAIL. Evidence **against** reuse — even the extractors won't redistribute it |
| 5 | Davies LDS General Conference Corpus (lds-general-conference.org) | Text corpus 1851–present (~24M words in 10k talks per third-party summaries) | Word/phrase search only; **no citation graph** | Search UI; downloadable corpus for purchase with heavy restrictions | English-Corpora purchase terms forbid placing data or derived frequency/collocate data on any network accessible outside the licensee organization | FAIL. No citation data, and terms forbid shipping derived data to users |
| 6 | BYU RSC studies (e.g., Book of Mormon citations 1965–2014) | Published aggregates only | Statistical tables, not row-level citation edges | PDF/article, not a dataset | Academic publication; no data license | FAIL. Not machine data |

---

## 1. BYU Scripture Citation Index (candidate 1, detail)

### Coverage
General-conference talks **1942 to the present**, per the site's own overview page (https://scriptures.byu.edu/content/talks_ajax/); the same page covers *Journal of Discourses* (1839–1886) and *Teachings of the Prophet Joseph Smith*. Currency: the Play listing (https://play.google.com/store/apps/details?id=edu.byu.scriptures&hl=en_US), updated Jul 15, 2026, and third-party version notes record database updates for the October 2025 and April 2026 conferences — actively maintained. Completeness: it is the product of Galbraith's multi-decade manual compilation, used as the data source in BYU Religious Studies Center research (e.g., https://rsc.byu.edu/vol-17-no-3-2016/book-mormon-citations-general-conference-1965-2014, which filtered the index for 1965–2014 and found 40,102 scripture citations in general conferences in that span). No public source disputes its completeness; it is the field's reference index.

### Fields
Verse granularity, confirmed: the overview explains that selecting an item like "2 Pet. 1:4" shows citations for that specific chapter/verse, and a citation entry carries year, session (A = April, O = October), speaker, and talk title (e.g., "2006–A:114, James E. Faust / Your Light—a Standard to All Nations"). The RSC study confirms the index records references at verse level and in commonly-cited units (verse ranges). Filtering to Bible-only references is feasible: results are keyed by scripture book, and the RSC analysis itself splits counts by standard-work volume (OT/NT/BoM/D&C/PGP). Both Bible and non-Bible references are present, so a Bible filter is a data-side WHERE clause.

### Machine-readability
None published. No API, no CSV/database download, no data-export page found on the site (fetched overview + search). The Android app (edu.byu.scriptures) ships the database to the device (earlier versions downloaded it from a BYU server; since v3.10.1 it ships as a Google Play Asset Pack per third-party changelogs). Extracting it is technically demonstrated by third-party extension authors (candidate 4) — but the technique is irrelevant to the gate; only rights matter.

### Terms (operative language)
The site's rights footer, quoted verbatim from https://scriptures.byu.edu/content/talks_ajax/:
"Scripture Citation Index, Copyright © 2010-2025, Richard C. Galbraith and Stephen W. Liddle. All rights reserved."
That is the **entire** terms picture: no terms-of-use page, no license grant, no permission statement was found on the site. A separate mobile-app project page (https://scriptures.byu.edu/sci/) describes the app but carries no license either. The site also explicitly distances itself from the Church ("not an official publication"; offered by the two named individuals). Net: an all-rights-reserved compiled database with no published path to lawful reuse. The Play listing carries no license grant.

Notable corroboration from candidate 4 (https://github.com/nate-kelley-buster/study-translations): extension authors who extracted the SCI app databases (~62 MB, 88 book shards, **~125.8k citations**) state on their own README that the data is "personal study only" and "not redistributable" — which is exactly why their extension stays load-unpacked and off the Web Store. Even the people who already did the extraction treat bundling as impermissible.

---

## 2. churchofjesuschrist.org (candidate 2, detail)

### Coverage / fields / machine-readability
Online GC archive begins **April 1971** (pre-1971 talks exist in print Conference Reports only). Modern talk footnotes contain machine-linked scripture references (`scripture-ref` hrefs encoding book/chapter/verse); older talks use inline parenthetical citations. A TOC/content JSON API exists behind the study site. These facts are documented in a third-party crawl plan (https://github.com/cahlan/general-conference-bibliography/blob/HEAD/PLAN.md), which estimated ~3,800 talks, ~30,000 footnotes total for 1971–2026 — useful as scale data only.

### Terms (operative language, quoted short excerpts from the fetched Terms of Use, https://www.churchofjesuschrist.org/services/platform/v4/resources/terms-of-use)
- Use is limited to "your own personal, noncommercial use"; non-Gospel-Media material "may not be posted ... to another website or computer network without our prior written permission."
- "Any other use ... including any use by organizations or legal entities, is not permitted without our prior written permission."
- The Code of Conduct forbids use of "any robot, spider, or other automatic device, process, or means to access this site for any purpose, including, without limitation, for monitoring or copying any of the material on this site," and also bars "any manual process to monitor or copy any material on this site ... without our prior written consent."
- No commercial use of site information; the Church reserves sole discretion to "deny, revoke, and limit use."

Gate read: a terms-clean route does **not** exist. Bundling citation data extracted via crawling/scraping violates the terms in two independent ways (automated copying + redistribution). The only sanctioned route is the formal permission process (permissions.churchofjesuschrist.org), which the terms say takes about 45 days and "may take longer" for large requests — and the terms explicitly disclaim any guarantee that materials are cleared for alternate use. **Scraping talk pages or the study API without a terms basis is off the table**; do not propose it as a fallback.

---

## 3. GitHub derivatives (candidate 3, detail)

- **carsonordyna/lds_scripture_counts_and_citations** (https://github.com/carsonordyna/lds_scripture_counts_and_citations): scrapes church site for 2016–2025, outputs **aggregate** verse-citation counts only (no talk→verse edges). No LICENSE file; 1 commit; root files show no license.
- **davehedengren/general_conference_citations** (https://github.com/davehedengren/general_conference_citations): scrapes church site; extracts title/speaker/year/month and counts per standard-work section — **not verse-level edges**. No LICENSE file.
- **cnoyes/ldt-data** (https://github.com/cnoyes/ldt-data): 1971–present, claims citation graphs — but those live in `data/citations/`, which is **gitignored** (not published); only metadata/public summaries are version-controlled. README says "MIT" but the root files list contains no LICENSE file, and MIT from the repo author cannot cover the underlying Church content anyway.
- **jared-hardinger/latter-day-data** (https://github.com/jared-hardinger/latter-day-data): full-text talk corpus builder + public-domain scripture DB; no citation extraction layer. No LICENSE file in root.
- **cahlan/general-conference-bibliography** (PLAN.md only, https://github.com/cahlan/general-conference-bibliography/blob/HEAD/PLAN.md): a well-researched crawl plan against the church API — not a dataset, and its build strategy is exactly what the Church terms prohibit.

Gate read: none carries a rights grant for the underlying data, and most don't even ship the citation edges. All inherit the restrictions of the source they scrape or extract from.

---

## 4. Davies General Conference Corpus (candidate 5)

The text corpus at lds-general-conference.org (search interface; fetch of the site itself failed — recorded as a gap, not a pass). It is a word/phrase search tool, **not a citation index** — it cannot supply talk→verse edges. Its data-download route (English-Corpora.org, documented via Penn State's library guide https://guides.libraries.psu.edu/c.php?g=1139753&p=8383533) imposes restrictions that forbid placing the data — or derived frequency/collocate/concordance data — on any network accessible outside the licensee's organization. Incompatible with shipping an app feature to users regardless.

## 5. RSC studies (candidate 6)

Academic aggregate statistics (e.g., 40,102 citations 1965–2014, split NT 32% / BoM 25% / D&C 25% / OT 12% / PGP 6%) — useful for scale estimates, not a row-level dataset.

---

## Data-shape sanity

- **Talks (full GC coverage, 1942–present):** ~6,000 talks (estimate: ldt-data's scraper counts 4,890 talks for 1971–2025; pre-1971 conferences were smaller — roughly another ~1,000–1,200).
- **Citation edges (all sources, all works):** one third-party extraction of the SCI app database reports **~125.8k citations**. RSC's published 1965–2014 count (40,102 citations) is consistent in order of magnitude with that total for the wider range + JD + TPJS.
- **Bible-only edges:** RSC's 1965–2014 split (OT 12% + NT 32% = 44% Bible) implies ~17.6k Bible citations for that window; extrapolating to full 1942–present coverage gives roughly **~25–35k Bible verse→talk edges** — small for an on-device SQLite table (single-digit MB with talk metadata).
- **Verse-level:** available from SCI (verse and cited-unit granularity). Chapter-level-only records exist in the margin (the nate-kelley README notes a tiny fraction of citations reference a whole chapter/section with no verse), acceptable as verse-range or chapter rows.
- **Non-Bible references:** mixed in at the source (BoM, D&C, PGP, JST) but every candidate's fields key edges by scripture book/volume, so a Bible-only filter is a trivial query-side filter. Note: the Bible-only app would silently under-represent talks whose citations are mostly non-Bible — flag in UX copy if the layer ever ships.

---

## Path to PASS (not building; recording only)

1. Written permission from **Richard C. Galbraith and Stephen W. Liddle** (the named copyright holders of the SCI database) to bundle the citation metadata (talk title, speaker, conference/session/date, cited references) in the app, with the scope of use defined (free app, on-device data).
2. And/or formal permission via **permissions.churchofjesuschrist.org** for Church-site-derived metadata — expect ~45+ days; approval not assured.
3. Facts alone (title/speaker/date/reference are facts) are not relied on as a basis — the gate requires an affirmative, documented grant, and neither rights holder has published one.

**Recommendation:** FAIL the gate. Do not dispatch any build package on this feature. Next action belongs to Rusty/Tyson: either seek written permission (option 1 or 2) or formally park the conference layer.
