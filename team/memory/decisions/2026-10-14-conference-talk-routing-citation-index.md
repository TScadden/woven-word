# Decision: Conference talk routing — Citation Index for talks Gospel Library does not carry (2026-10-14)

Founder correction during the board run 8 fix round, from his
screenshot of Gospel Library's own General Conference archive:
its oldest bucket is "1971–1979" — nothing before 1971 exists
there.

## The correction

Founder (Tyson), Oct 14, 2026, verbatim: "It looks like the
conference talks only go back to 1979 in Gospel Library. We
should still have the talks that go all the way back in our app,
you just can't open them in Gospel Library. You have to open them
in the Citation Index."

## What it changes (run-8 spec §4.4.1 amended the same day)

1. **The dataset does not shrink.** All 4,964 talks back to April
   1942 stay. This is a link-routing change only.
2. **Routing is data-driven per talk, never a hard-coded year
   cutoff:**
   - Talk WITH a per-talk Gospel Library URL → "Read in Gospel
     Library" (Form A, unchanged).
   - Talk WITHOUT a per-talk Gospel Library URL but WITH a
     Scripture Citation Index talk page → "Read in Citation
     Index", linking out to that talk's own page on
     scriptures.byu.edu (new Form C). This replaces the Form B
     conference-level Gospel Library fallback wherever an Index
     talk URL exists.
   - Talk with a conference-level Gospel Library link and NO
     Index page → Form B remains as the residual form.
   - Talk with NEITHER → the existing honest no-link caption.
   Shipped-dataset routing counts: Gospel Library per-talk
   3,014 · Citation Index 1,950 · residual Form B 0 · neither 0.
3. **Pipeline:** the Index talk URL is recorded per talk from the
   Index's own published structure — its conference pages link
   each talk via `getTalk('<id>')`, and the site's own frontend
   resolves that id to the talk's page at
   `scriptures.byu.edu/content/talks_ajax/<id>/` (new asset field
   `x`, recorded by `tools/conference/harvest_conferences.py`).
   The binding method limits stand unchanged: facts + the Index's
   own link targets only; no churchofjesuschrist.org scraping; no
   SCI database extraction; ordinary-use pacing.
4. Global copy that described the action (Profiles explanatory
   copy, spec C-2) now names both destinations truthfully.
