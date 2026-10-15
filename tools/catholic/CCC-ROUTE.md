# Catechism (CCC) Index-of-Citations route check — board run 9

Checked 2026-10-14. Question (packet scope call 5): is there a
terms-clean route to the CCC's official *Index of Citations* facts
(paragraph ↔ scripture reference pairs) without scraping vatican.va
or usccb.org against their terms and without copying anyone's
finished dataset?

## Verdict: BLOCKED

No terms-clean online route exists from the sources checked. Every
candidate route is blocked by a specific clause or fact below. The
identified unblock paths are listed at the end — none of them is
executable from this desk this run, so the Catholic corpus ships
BLOCKED (run-8 gate pattern) while canon + text ship.

Method note: only terms/legal pages were fetched, plus the USCCB
flipbook's table-of-contents listing as indexed, plus one flipbook
page fetch that the TOC URL resolved to (no bulk fetching of
Catechism content pages was done, and no dataset was downloaded).

## Candidate route 1 — harvest vatican.va (IntraText CCC): BLOCKED

vatican.va's own Legal Notes / Terms of Use
(https://www.vatican.va/content/vatican/en/legal-notes.html,
fetched and read in full, 2026-10-14):

- §4 (Access and Use): portal content is "intended for personal
  and non-profit use only", and, verbatim:

  > "The reproduction and collection of Contents for reasons
  > other than personal use is expressly prohibited in the
  > absence of prior authorization issued in writing by the DPC."

  Building a citation dataset for an app is a *collection* of
  Contents for a non-personal use — squarely inside the ban.
- §7 (Intellectual and Industrial Property): the user is not
  authorised to reproduce, reprocess, distribute or commercially
  exploit portal content, even in part, without the DPC's express
  written authorisation.
- §5 additionally states that a user may not place a link to
  portal content on their own site without written permission
  from the DPC — notable because it is stricter than the
  link-out practice other apps use (see Fidelis, below).
- Separately, the CCC text on vatican.va is © Libreria Editrice
  Vaticana; the rights statement bound into the work itself (see
  route 3) reserves all rights to the Holy See.

Facts (paragraph ↔ reference pairs) are not themselves
copyrightable expression under *Feist*, but the studio's method
law is terms-based, not just copyright-based: harvesting against
an express written-permission clause is out, regardless of the
facts doctrine.

## Candidate route 2 — harvest usccb.org online CCC: BLOCKED

USCCB's operative document for the Catechism is its "Revised
Statement of Principles and Guidelines for Use of the Text
(2018)" (https://www.usccb.org/resources/principles-and-guidelines-consistency-review,
fetched and read 2026-10-14):

> "No edition of the Catechism of the Catholic Church, in any
> language, may be published in the United States … without the
> written permission of the USCCB."

Excerpts may be used in the U.S. "only in accordance with the
guidelines" in that document (a text-excerpt regime: the linked
guidelines PDF governs excerpt size, review and royalties — it
grants no licence to harvest the book's citation apparatus into a
dataset). The Holy See has given the USCCB "specific rights and
responsibilities" for the CCC in the U.S., so this is the rights
holder's own gate, not a reseller's.

Honest gap: usccb.org's general site-wide Terms of Use is
referenced in its page footers ("subject to our Terms of Use"),
but its body was not retrievable through this desk's fetch
routes this run. That gap does not soften the verdict: the
CCC-specific guidelines above already gate this use.

## Candidate route 3 — harvest the USCCB flipbook (usccb.cld.bz): BLOCKED

- Exposure: the flipbook *does* expose the whole book, including
  the Index of Citations, as ordinary readable pages. Its
  table of contents (as indexed from usccb.cld.bz) lists:
  "Index of Citations 709", followed by "Index 773" — i.e. the
  Index of Citations occupies printed pp. 709–772 of the U.S.
  edition, presented page-by-page in the flipbook.
- Terms posture: no licence or terms grant for extraction was
  found on the flipbook; it is the USCCB's own publication of the
  same copyrighted U.S. edition, hosted on a flipbook service.
  Its front matter (copyright page) states, verbatim, that
  "The Holy See reserves all rights to itself", credits the
  English translation © 1994 USCCB–Libreria Editrice Vaticana,
  and credits the **"Glossary and Index Analyticus copyright
  © 2000, United States Conference of Catholic Bishops"** — the
  index apparatus of the U.S. edition is itself a claimed
  USCCB copyright work.
- Readable ≠ licensed. Page-by-page readability is a reading
  feature for people; systematic extraction of the Index into a
  dataset is reproduction/collection of a copyrighted apparatus
  under the USCCB guidelines in route 2. BLOCKED on the same
  gate.

## Candidate route 4 — reuse the Fidelis dataset: BLOCKED

Recorded accurately, as precedent only (its dataset was **not**
downloaded):

- Fidelis (https://github.com/ogprotege/fidelis, as captured in
  the studio's Oct 14–15 deep-research report) is a live Catholic
  app that maps 4,600+ verses from the official Index of
  Citations, ships **only the citation facts**, bundles no
  Catechism text, and links each row out to the paragraph on
  vatican.va. It bundles only public-domain Bibles.
- Its citation file carries **no stated licence** in the captured
  README. Licence unstated = no reuse right the studio can rely
  on, and the packet's method law independently forbids copying
  anyone's finished dataset. Fidelis is proof the *method* is
  practised, not a source we may take.

## What would unblock it

1. **Written permission** — from the Dicastery for Communication
   (vatican.va Legal Notes §4/§7: prior authorisation "issued in
   writing by the DPC", spc@spc.va / policies@spc.va) covering
   collection of the Index-of-Citations facts; and/or from the
   USCCB under its CCC guidelines (it holds the U.S. rights and
   the © 2000 index apparatus). Either letter should expressly
   cover facts-only extraction and in-app link-out.
2. **A lawfully purchased print Index, transcribed by hand** —
   buy the print U.S. edition (whose pp. 709–772 are the Index of
   Citations), and transcribe the paragraph ↔ reference *facts*
   by hand into Woven Word's own schema, arranged as a reverse
   index in canonical verse order (our arrangement, not the
   Index's). No website terms govern a purchased book, and facts
   are not copyrightable (*Feist*); Fidelis is the working
   precedent for exactly this method. This is a future manual
   work package (purchase + transcription + founder sign-off),
   not a route this desk can execute from fetched sources.
3. Either path ships facts only: no CCC paragraph text, no
   Index wording or arrangement, link-out per paragraph to
   vatican.va / USCCB (noting route 1's §5 link clause — the
   permission letter in path 1 should cover linking too; under
   path 2, ordinary deep links are the Fidelis practice).

Until one of those lands, the Catechism corpus stays BLOCKED.
Canon + WEB Catholic Edition text (this run's other Catholic
deliverables) are unaffected: that text is public domain
(see LICENSE-EVIDENCE.md).
