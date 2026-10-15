# Licence evidence — confessions pipeline (board run 9)

Collected 2026-10-14. Quotations are brief status lines only.
The asset `flutter/assets/confessions.json` contains citation facts
derived from the two public-domain works in section 1; section 2
records sources that were checked and **not** used.

## 1. Sources used (facts derived from the public-domain works)

### 1a. Westminster Confession of Faith — OPC edition with Scripture proofs

- Publisher page: `https://opc.org/confessions.html`
  (Orthodox Presbyterian Church, "Confession and Catechisms").
- Status lines read on that page:

  > "it adopted (with minor revisions) the Westminster Confession of
  > Faith, Larger and Shorter Catechisms (1647)"

  > "The following PDF documents contain the Confession and
  > Catechisms with full Scripture proofs:"

- Document ingested: `https://opc.org/documents/CFLayout.pdf`
  ("Westminster Confession of Faith with Scripture proofs"),
  kept as `sources/wcf_opc_proofs.pdf`
  (615,268 bytes, sha256 prefix `d24cbbcdd3e581f2`).
- Public-domain basis: the Confession was published in **1647**
  (date as stated on the publisher's own page, quoted above); a
  work of that date is in the public domain. What was extracted is
  citation facts — the reference strings in the OPC edition's
  footnote apparatus — not the confession text and not the quoted
  proof texts, neither of which is in the asset.

### 1b. 1689 London Baptist Confession — CCEL edition with Scripture proofs

- Work page: `https://ccel.org/ccel/anonymous/bcf.html`
  (Christian Classics Ethereal Library, "1677/89 London Baptist
  Confession of Faith", author anonymous).
- Document ingested: `https://ccel.org/ccel/a/anonymous/bcf/cache/bcf.pdf`,
  kept as `sources/lbc1689_ccel.pdf`
  (1,316,106 bytes, sha256 prefix `2392f2a8d77786b7`).
- Status lines read in that PDF:

  Title page:

  > "Thirty-Two Articles of Christian Faith and Practice with
  > Scripture Proofs"

  > "Adopted by the Ministers and Messengers of the General
  > Assembly Which Met in London in 1689"

  CCEL boilerplate page:

  > "This PDF file is copyrighted by the Christian Classics
  > Ethereal Library. It may be freely copied for non-commercial
  > purposes as long as it is not modified."

- Public-domain basis and posture (as the run packet prescribes):
  the confession itself was adopted and published in **1689**
  (drafted 1677; title page quoted above), so the work is in the
  public domain. The CCEL boilerplate covers **CCEL's own files**
  (its PDF and formatting), not the underlying work. Accordingly:
  facts were extracted from the public-domain work; **no CCEL file
  is redistributed** — the PDF and its text extract stay in
  `tools/confessions/sources/`, outside the app bundle, and the
  asset contains only derived citation facts. CCEL's modern
  editorial notes (in square brackets) were stripped before
  parsing and are not in the data (see README, "Method").

## 2. Checked, not used (packet route 1 candidates)

Both repositories below were opened and read on 2026-10-14. When the
ingest step called the GitHub API to pin the exact commit and open
the actual `LICENSE` file text, the API returned **HTTP 403
"rate limit exceeded"**; per the studio's rate-limit rule that ended
GitHub access for the run, so the packet's route-1 condition
(LICENSE file itself opened and quoted, commit pinned for ingest)
could not be completed and **no data from either repository was
ingested or is in the asset**. The status lines below are what the
repository pages themselves displayed; they are recorded so a later
run can re-check route 1 quickly.

### 2a. `github.com/normanormata/westminster_cli`

- Repository page details: "License: MIT License (MIT)".
- Default branch `main`; head commit shown on the repo page:
  `3fdd5fcf37180e3ede551193c572f7d43a52810a` (also returned by the
  API before the rate limit was hit).
- Coverage per its README: Westminster Confession of Faith plus the
  Larger and Shorter Catechisms (no 1689), entries carry `proofs`
  arrays of OPC scripture-proof references.
- The `LICENSE` file text itself was **not** opened (see above).

### 2b. `github.com/ReformedDevs/christian-standards`

- Repository page details: "License: MIT License (MIT)".
- Default branch `master`; head commit shown on the repo page:
  `30a52cd15b858aca943db433242dabc6eb51de3d`.
- Coverage per its README: confessions include WCF and LBCF;
  confession paragraphs carry `proofs[]`. Its README licence section:

  > "Document texts are public domain where noted in each file's
  > `meta.license`. Repository metadata and schema are MIT"

- The `LICENSE` file text itself was **not** opened (see above).

## 3. What the asset contains, licence-wise

Citation facts only: document titles/years, section numbers and
labels, Bible-verse coordinates, and one document-level link-out URL
per document (OPC / CCEL). No confession text, no quoted Scripture
proof text, no text or data from the repositories in section 2, and
no CCEL editorial matter.
