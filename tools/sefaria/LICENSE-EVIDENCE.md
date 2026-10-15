# Licence evidence — Jewish layer (board run 9)

Every status/licence line this pipeline relies on, quoted verbatim
with its source. Collected 2026-10-14 (MDT). Quotes are kept to the
operative lines only; anything summarised is marked as a summary,
not a quote. Nothing in this layer bundles a text on the strength
of a summary.

## 1. JPS 1917 — eBible.org USFM zip

Source file: `copr.htm`, inside
`https://ebible.org/Scriptures/engjps_usfm.zip` (the copyright/status
file shipped in the archive itself). Verbatim lines:

> "JPS TaNaKH 1917"

> "The Jewish Bible (Old Testament) in English, published by the Jewish Publication Society in 1917"

> "Public Domain"

> "Translation by: Jewish Publication Society"

> "2023-09-19"

"Public Domain" is the status line relied on: the 1917 JPS text is
public domain. The same file also (summary, not quoted) points
readers to jps.org for the NEW JPS TaNaKH dated 1972/1978/1980 —
the NJPS family is a different, copyrighted work, is never a source
here, and was never downloaded.

## 2. Hebrew — tanach.us (Unicode/XML Leningrad Codex, UXLC)

Source: the site's own `License.html` — read from the copy shipped
inside the downloaded archive `Books/Tanach.xml.zip` and confirmed
at https://tanach.us/License.html. Verbatim operative lines:

> "All biblical Hebrew text, in any format, may be viewed or copied without restriction ."

> "The text presented at this site is not the Westminster Leningrad Codex (WLC) ; please do not represent it as such."

The same page also (summary, not quoted) says citation of
Tanach.us as the source is appreciated and gives the citation form
("Unicode/XML Leningrad Codex: UXLC 2.5 (27.6), Tanach.us Inc.,
West Redding, CT, USA, Apr 2026"), and restricts OTHER site
material (fonts are third-party property; the site's other files
and look-and-feel are copyrighted and need written permission).

Consequences, honoured by this pipeline: (a) the biblical Hebrew
TEXT is copied under the first line's unrestricted grant; (b) the
app attributes the text as UXLC 2.5 (27.6), Tanach.us Inc., as the
page requests; (c) the asset is described as UXLC derived from
WLC 4.20 — never as "the WLC" itself; (d) nothing else from the
site (fonts, look-and-feel, page text) is taken.

Corroborating lines inside the data files themselves (verbatim,
from `Books/Genesis.xml`'s TEI header — the same header ships in
every book file):

> `<availability status="free">Freely available</availability>`

> `<creation>From WLC 4.20 provided by the Groves Center.</creation>`

The site's About page (the page served at
https://www.tanach.us/Tanach.xml — an About page, not the XML; see
README) carries the same "without restriction" sentence as the
first quote above.

Fetch posture (recorded for completeness): tanach.us `robots.txt`,
read 2026-10-14, disallows `/` to `User-agent: *` in its first
stanza and separately carries a `User-agent: Claude-User` /
`Allow: /` stanza. The download made here is of the site's own
published bulk archive (one zip), of text its licence page
expressly says may be copied without restriction. The zip route —
not page scraping — is the site's offered bulk route, and only
that one archive was fetched from tanach.us by this pipeline
(plus the License/About/robots pages named here).

## 3. Sefaria links — Sefaria-Export licence posture

Source: https://raw.githubusercontent.com/Sefaria/Sefaria-Export/master/LICENSE.md
(the repository behind the public export bucket the links CSVs
were downloaded from). Verbatim operative lines:

> "Each text is licensed separately, so there is no overall license for this repository."

> "You can find the license for each text in their JSON versions under the `license` field."

The file adds (summary) that per-text licences are generally one
of Public Domain, CC0, CC-BY, CC-BY-SA or CC-BY-NC.

What this pipeline takes from Sefaria is citation FACTS only —
which work cites which Tanakh verse, and how often — never Sefaria
text content. Per-item licences therefore bind the texts Maren's
UI links OUT to on sefaria.org; no Sefaria text of any licence
class (CC-BY-NC included) is bundled in the app. The two texts
this layer does bundle (JPS 1917, UXLC Hebrew) come from
eBible.org and tanach.us under sections 1–2 above, not from
Sefaria.

## 4. Sefaria Terms of Use — read attempt (2026-10-14)

One `curl` attempt at https://www.sefaria.org/terms (full record
in the README): HTTP 200, 40,502 bytes returned, but the body is
a JS-rendered shell — 550 characters of visible text, all of it
site navigation; zero occurrences of "copyright", "license",
"intellectual" or "You agree" in the returned HTML. The studio's
prior finding stands confirmed from this desk's own attempt: the
ToU body could not be read through this fetch route. Per the
run-9 packet (scope call 6), a manual ToU read and written
confirmation from Sefaria remain pre-launch checklist items;
nothing here treats the unread ToU as read.
