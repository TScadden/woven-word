# PETRA — GATE VERDICT, BOARD RUN 8: GENERAL CONFERENCE CONNECTIONS LAYER

**Auditor:** Petra, Design Auditor & QC
**Law audited against:** `team/specs/run8-conference-layer.md` (read in full
for this gate — not memory), `team/memory/LESSONS.md` (esp. #24 judge the
surface / verify the mechanism, #25 semantics is only real with a
semantics-tree assertion, #23 a spec that isn't in the brief-as-file
doesn't exist).
**Repo state audited:** `~/workspace/woven-word`, branch `main`,
HEAD `92d31fe` ("Run 8 plumbing: lazy conference layer toggle state"),
on top of `7d16ae1` ("Run 8 data: ConferenceData with bidirectional
indexes + tests"), on top of `d59c585`.

## VERDICT: FAIL — BLOCKER. THE AUDITED BUILD DOES NOT EXIST.

This is a mechanical verdict, not a judgment call. There is no UI
surface to pass, pass-with-fixes, or judge. "PASS WITH FIXES" in this
studio means a built surface with enumerated corrections; here the
correction list is "build the entire run," and stamping that
PASS WITH FIXES would misrepresent the state of the repo to the
founder. Every clause below is therefore ruled on evidence, and the
fix list routes back through Silas to Maren.

---

## 0. THRESHOLD FINDINGS (each independently blocks the gate)

### 0.1 The three claimed build commits do not exist — FAIL

The brief states the build is committed as `fabaa26` (Profiles Data
+ About), `19c05e0` (reader sheet section), and `3660531` (Library
browse + talk view). In this repo:

- `git cat-file -t fabaa26` → `fatal: Not a valid object name`
- `git cat-file -t 19c05e0` → `fatal: Not a valid object name`
- `git cat-file -t 3660531` → `fatal: Not a valid object name`
- `git log --all --oneline` contains no such commits on any branch
  (branches: `main`, `parked/board-run-7-partb-stream-reader-wip`).
- HEAD is `92d31fe`; its own commit message ends: **"No UI built."**
- The data layer says the same in code:
  `flutter/lib/data/conference_data.dart:8` — "board run 8, data
  layer only — **no UI consumes this yet**."

### 0.2 The claimed files do not exist — FAIL

| Brief-claimed file | State |
|---|---|
| `flutter/lib/screens/about_screen.dart` | MISSING |
| `flutter/lib/screens/conference_screens.dart` | MISSING |
| `flutter/lib/widgets/conference_link.dart` | MISSING |
| `flutter/lib/widgets/verse_row_painter.dart` | MISSING |
| `flutter/lib/data/conference_links.dart` | MISSING (the data file is `conference_data.dart`) |
| `flutter/test/conference_ui_test.dart` | MISSING |
| `flutter/test/conference_reader_test.dart` | MISSING |

Directory listings of `flutter/lib/screens`, `flutter/lib/widgets`,
`flutter/lib/data`, and `flutter/test` confirm none of these files
exist in the repo. The screens that do exist contain zero conference UI:
`grep -ri conference flutter/lib/screens/profiles_screen.dart
flutter/lib/screens/library_tab.dart flutter/lib/screens/reader_screen.dart`
→ no matches in any of the three. The only conference code in `lib/`
is `data/conference_data.dart` and the toggle plumbing in
`screens/shell_screen.dart:71–127` (key at line 75, default at
line 80, load at lines 93–111, setter at lines 117–127).

### 0.3 The brief's clause list conflicts with the binding spec on file — RECORD CORRECTION (lessons #23, #24)

The brief I was given describes a different spec than the one saved
at `team/specs/run8-conference-layer.md`. I audited against the
file, per instructions ("the law — audit against it, not against
your memory of it"). Where the brief and the file conflict, the file
wins, and the conflicts are recorded here because a builder working
from the brief's version would fail this gate by construction:

1. **Profiles placement.** Brief: section "between Translation and
   Backup." Spec §0 (premise correction) + §2.1: **Profiles has no
   Translation section and never has** — Translation is the reader
   top-bar toggle. The ruled placement is *after the New profile
   button and before the Backup section*. Evidence the premise is
   false in code: `profiles_screen.dart` has no "Translation" text
   anywhere; `_body()` runs profiles → New profile button
   (`profiles_screen.dart:498`) → 24dp gap → `Backup`
   (`profiles_screen.dart:501`).
2. **Switch colors.** Brief: "switch with NO color overrides — any
   hit is a FAIL." Spec §2.4.1 + Flag F-4: the exact opposite —
   `wwTheme()` defines no `switchTheme`, a stock switch is a
   **Blocker**, and **every switch color must be set explicitly on
   the widget** in both states, with computed pairs. A build
   following the brief fails F-4 on sight.
3. **Sheet rows.** Brief: rows ≥64dp, title `WwType.bodyStrong`
   max 2 lines ellipsis, meta in `colors.body`, trailing
   `IconButton` exactly 48×48 labeled "Read {title} in Gospel
   Library," attribution footer in the sheet. Spec §3.2: rows are
   ≥48dp (`WwSpace.minTarget` floor, content-derived height), title
   is `bodyOnPaper` w600 **wrapping with no line cap and no
   ellipsis** ("a truncated talk title is a wrong title"), speaker
   line is `captionOnPaper`, and there is **no trailing control** —
   inventing one is explicitly prohibited. Spec §5: attribution
   does **not** appear in the sheet. The brief's 48×48 labeled
   button conflates the sheet row with §4.4.1's talk-view action,
   whose semantics label is `Read {Talk title} in Gospel Library,
   opens external app or website` (§7) and whose construction is a
   full-width gold `ElevatedButton`, not an `IconButton`.
4. **Invented tokens.** The brief names `WwType.sectionHeader`,
   `accentSoft`, `colors.body`, `colors.bodyMuted`,
   `colors.bodyStrong`, and `radiusFull`. None exist.
   `flutter/lib/theme/ww_theme.dart`: `WwType` (line 61) offers
   `bodyOnDark`, `captionOnDark`, `bodyOnPaper`, `captionOnPaper`,
   `controlLabel`, `selectionTitle`, `refLabel`, `refLabelOnDark`,
   `snippet`, etc.; `WwRadius` (line 322) is the closed set
   {input 8, row 10, chip 12, sheet 16}; `WwSpace.minTarget` is
   48.0. Grep for every brief token across `flutter/lib`,
   `flutter/test`, and the spec file: **none found**.
5. **Browse counts and coverage.** Brief: a "coverage line" from
   `ConferenceData.coverage`, conference tiles with trailing
   `{n} talks`, talk tiles with a `citedByCount` chip. Spec: **no
   coverage copy may appear anywhere** (Flag F-6); the Library root
   tile caption is the template `{N} conferences · {M} talks`
   (§4.1); conference-row counts are a **subtitle** `{M} talks`
   (§4.2); talk-row subtitles are `{Speaker} · {K} scriptures`
   (§4.3); there are no chips in this run. In code,
   `ConferenceData` has **no `coverage` property and no
   `citedByCount`** — grep: none found (its stats are `talkCount`,
   `firstYear`, `lastYear`, `edgeCount`,
   `conference_data.dart:138,143–153`).
6. **Range-collapsed labels.** Brief: refs render range-collapsed
   ("Genesis 1:26, 27" style). Spec §4.4.2: **one row per distinct
   verse**; a cited range renders each verse as its own row with
   its own snippet. Range-collapsing contradicts the spec.
7. **About screen.** Brief §6 audits an About screen with an
   attribution paragraph, a criterion note, and four source rows.
   The spec's scope (header + §5) contains **no About surface at
   all**; attribution appears in exactly two placements (talk-view
   footer, conferences-list footer) as plain non-tappable text.
   An About screen is un-audited invention until it comes back
   through a spec.

**Consequence:** Silas must reconcile the dispatch brief with the
filed spec before any rebuild. I do not know which text Maren was
given; if she built to the brief's version somewhere, that work is
not in this repo and would still fail §§2–5 of the filed spec.

### 0.4 The dataset itself is the empty placeholder — FAIL (data gate)

`flutter/assets/conference.json` is exactly
`{"edges":[],"talks":[],"v":1}` (see `7d16ae1`: "Placeholder
assets/conference.json (empty v1 dataset) until the pipeline
dataset lands"). Even a perfect UI build would, under spec §4.1's
dataset-empty rule, render no Library tile and the §3.4 empty line
for every verse. The founder-visible feature cannot ship on this
dataset regardless of the UI verdict.

---

## 1. WHAT ACTUALLY EXISTS — AND ITS OWN VERDICTS

These two commits are real and are not the subject of the FAIL
above except where noted; I record them so the rebuild starts from
an accurate base.

- **Data layer (`7d16ae1`) — PASS for its scope, with two
  divergences flagged in §2.5 below.** Pure parse, canon
  clamp-by-dropping on both bounds, edge dedupe
  (`conference_data.dart:255–317`); `talksForVerse` newest-first
  (year desc, October before April: `_newestFirst`,
  `conference_data.dart:66–74`) matching spec §3.3;
  `refsForTalk` canon-ordered chapter groups
  (`conference_data.dart:181–201`) matching §4.4.2's order rule;
  `url` / `urlIsConference` carried verbatim
  (`conference_data.dart:44–52`).
- **Toggle plumbing (`92d31fe`) — PASS for its scope.**
  `ShellController.conferenceLayerKey = 'ww_conference_layer'`
  (`shell_screen.dart:75`, spec §1.1 key verbatim), default
  `false` (`shell_screen.dart:80`), persisted at toggle time
  (`shell_screen.dart:117–127`), lazy load with failure degrading
  to unloaded, never throwing (`shell_screen.dart:93–111`).
  `url_launcher` was added to `pubspec.yaml` "ahead of the
  Read-in-Gospel-Library action" — it is **unused anywhere in
  `lib/`** (grep: no import), consistent with no action existing.
- **Existing tests — PASS for their scope, and they are real.**
  `flutter/test/conference_data_test.dart` (51 `expect`s: verbatim
  fields, null-url, `c:1` fallback, dedupe counts, canon dropping,
  ordering, canon-order groups) and
  `flutter/test/conference_shell_test.dart` (20 `expect`s: default
  off / no load, persisted-on startup load, persist-on-toggle,
  failed-load degradation). These assertions can fail; none is
  vacuous. They assert **nothing about any UI surface** — see §2.6.

---

## 2. CLAUSE-BY-CLAUSE AUDIT

Citations to "spec" are the filed spec. Brief clause numbers are
mapped alongside so Silas can trace every check he asked for.

### 2.1 Profiles toggle — spec §2 / spec gate items 4–7; brief §3 — **FAIL**

- Order/spacing (§2.2), copy C-1…C-4 (§2.3), row construction
  (§2.4): **absent.** `profiles_screen.dart` `_body()` (lines
  471–526) renders intro caption → profile rows → New profile
  button (line 498) → 24dp gap → Backup header (line 501) →
  Export/Import rows, and ends. There is no `General Conference`
  section in the slot §2.1 rules, nor anywhere else.
- Switch: **no `Switch` widget exists in the screen or anywhere in
  `lib/`** (grep for `Switch`, `activeTrackColor`,
  `activeThumbColor`, `trackOutlineColor`: no hits). Neither the
  brief's "no overrides" check nor the spec's §2.4.1 explicit-colors
  check can pass on a switch that does not exist; under the filed
  spec the required state is explicit colors, check glyph in the
  ON thumb, no disabled state.
- Row heights (brief: ≥56dp toggle / ≥48dp About row): no toggle
  row exists to measure; the spec's floor for this row is
  `WwSpace.minTarget` (48dp) via the Backup-row construction. The
  brief's 56dp figure appears nowhere in the filed spec.
- "About & sources" subtitle (brief §3.2): no such string exists in
  code or in the filed spec (grep: none found). The §2.4 row's
  actual subtitle is C-4, `Verse connections and the Library
  browse` — also absent.
- Semantics (§2.5, gate item 7): no toggled node labeled
  `Show conference talks`; no semantics-tree assertion in any test
  (grep `bySemanticsLabel` in `flutter/test/conference_*.dart`:
  none). FAIL under lesson #25.

### 2.2 Reader sheet section — spec §3 / gate items 8–12; brief §4 — **FAIL**

- `_openConnections` (`reader_screen.dart:736`) is the shipped
  sheet, untouched: header (line 764 `sheetRefTitle`), verse
  (lines 766–768 `readerSheetVerse`), `Connections` header in
  `WwType.refLabel` (line 771), shipped empty caption, shipped
  rows in their inner `ListView`. There is **no "Conference talks"
  section in any state** — not when enabled, not when disabled.
  The OFF contract (§1.1) therefore holds only vacuously: the sheet
  is byte-for-byte shipped because the ON rendering was never
  built. Gate item 8's ON half, item 9 (header C-5 in `refLabel`,
  §3.2 rows, no trailing control), item 10 (ordering / duplicate
  rule as rendered), item 11 (header + C-7 empty line when ON), and
  item 12 (row tap → sheet pops → talk view on the Library stack;
  §7 row semantics `Open talk: {title}, by {Speaker}, {Month}
  {Year}`) all FAIL for absence.
- For the record, against the brief's §4 specifics: no
  `sectionHeader` role exists (§0.3.4), no count chip exists, no
  ≥64dp row exists, no title is capped at 2 lines (the spec
  prohibits capping it), and the trailing `IconButton` the brief
  requires is the one element spec §3.2 expressly forbids on these
  rows. The brief's §4.4 attribution footer in the sheet contradicts
  spec §5 ("nor in the connections sheet").
- "No other sheet behavior changed" (brief): TRUE and verified —
  the pre-existing sections are untouched (the file's last change
  predates run 8). This sub-check passes; it does not mitigate the
  missing section.

### 2.3 Library browse + talk view — spec §4 / gate items 13–18; brief §5 — **FAIL**

- Root entry (§4.1): **absent.** `library_tab.dart:246–248` renders
  exactly the two shipped testament tiles and the 24dp spacer.
  No `General Conference` tile in the enabled state, no
  disabled-while-loading state, no dataset-empty suppression —
  because no tile code exists at all. (Gate item 1's "Library root
  contains exactly two tiles" is currently true in *both* toggle
  states, which is the defect.)
- Coverage line (brief §5.2): no such line, no
  `ConferenceData.coverage` to source it (§0.3.5), and under the
  filed spec any coverage copy is prohibited (F-6). The spec's
  root-tile caption is the counted template C-9 — also absent.
- Conferences list (§4.2): absent. No intro caption C-10, no rows,
  no `{M} talks` subtitles, no attribution footer (§5 placement 2).
- Talks list (§4.3): absent. No rows, no `{Speaker} · {K}
  scriptures` subtitles, no `citedByCount` chip (brief) — the spec
  defines no such chip.
- Talk view (§4.4): absent — no file, no route. Therefore: no
  header block (title `selectionTitle`, speaker `bodyOnDark`,
  conference line C-14), no `Scriptures cited` header (C-15), no
  scripture rows in canon order, **no snippet code path to trace**
  (the spec §4.4.2 / brief C8 requirement — snippet from
  `ScriptureText.verseText` in the *active* translation,
  `scripture_text.dart:80` — is unimplemented; there is no call
  site), no tap → reader via `openChapter` from any talk surface,
  no Gospel Library button in either form, no fallback caption
  (C-18), no no-link caption (C-19), no launch-failure snackbar
  (C-20).
- **Non-Bible caption (brief §5.4 / spec C-21) — string compare:**
  spec text is: "This list shows Bible citations only. The talk
  may also cite the Book of Mormon, Doctrine and Covenants, Pearl
  of Great Price, and other sources, which this Bible app does
  not list." Grep for that string in `flutter/`: **absent**. FAIL.
- **Attribution (spec C-22):** "Citation facts are from the
  Scripture Citation Index (scriptures.byu.edu), compiled by
  Richard C. Galbraith and Stephen W. Liddle." Grep in `flutter/`:
  **absent** from both ruled placements. FAIL.
- Back behavior / breadcrumb (§4.5): no branch exists to pop;
  standard back is preserved only because nothing was added.

### 2.4 About — spec §5 placements / gate item 19; brief §6 — **FAIL, and NOT IN THE FILED SPEC**

- No `about_screen.dart`, no About route, no source rows, nothing
  to string-compare the brief's "exact attribution paragraph" or
  "criterion note" against — and neither text exists in the filed
  spec to compare *to*. The filed spec's attribution (C-22) lives
  in the talk view and conferences list (§2.3 above), both absent.
- `colors.body` vs `bodyMuted` (brief): neither token exists
  (§0.3.4); the dark-surface caption role the spec assigns to all
  of this copy is `captionOnDark` (`mutedOnDark` on `stage`,
  6.92:1, §9 table).
- Ruling: if the founder wants an About surface, it needs its own
  spec amendment through me first (closed inventories, §1.2/§1.3:
  an unlisted surface/state in a diff fails the gate by
  definition). It cannot be built from the brief paragraph.

### 2.5 Data-layer divergences that will block the UI build — **FAIL (mechanical, pre-existing)**

Found while tracing the APIs the brief cites; both contradict the
filed spec and must be resolved before or during the rebuild,
because a UI built naively on these APIs inherits the violations:

1. **Talks order.** `talksInConference`
   (`conference_data.dart:232–245`) sorts **by title ascending** —
   its own test asserts this (`conference_data_test.dart:193`,
   "talksInConference sorts by title"). Spec §4.3 + §3.3: talks
   keep **the dataset's own session order**; no alphabetical
   re-sort. (The bundled `talks` list preserves dataset order, so
   a conforming UI can filter it — but the named API invites the
   violation.)
2. **Counts include uncited talks.** `conferences()`
   (`conference_data.dart:215–231`) counts every talk in the
   dataset, with no citation-edge check. Spec §4.1: `M` counts
   **talks with at least one Bible citation**; §4.2: a conference
   with zero Bible-citing talks is **absent** from the list. The
   current API can produce counts and conferences the browse is
   forbidden to show.

### 2.6 Edge cases — spec §4.4.1/§4.4.2 safety states; brief §7 — **FAIL (no surface)**

- `url == null`: handled as *data* (`conference_data.dart:47,54`;
  test `conference_data_test.dart:54` — null stays null, not a
  conference fallback). The UI rule (button does not render, C-19
  caption renders in its place) is unimplemented — no button, no
  caption. FAIL.
- `urlIsConference`: carried as data (`conference_data.dart:52`)
  and tested (`conference_data_test.dart:60`). The Form B rule
  (button iff fallback, with C-17 label + mandatory C-18 caption)
  is unimplemented. FAIL.
- Empty refs: `refsForTalk` returns `[]` for unknown talks
  (`conference_data.dart:184–185`); the talk-view safety state
  (C-24 caption, with C-21 + C-22 still rendering below it) has no
  surface to render on. FAIL.
- Back behavior: standard by absence (§2.3). No conference route
  exists to test tab re-tap / stack discipline against.

### 2.7 Motion — spec §8 / gate item 20; brief §9 — **PASS (vacuous)**

Grep of the full run-8 diff (`7d16ae1^..92d31fe`) for
`AnimationController`, `Tween`, `Animated*`: **no additions**.
No new animation exists because no new surface exists. This pass
is recorded for completeness; it offsets nothing.

### 2.8 Tests — spec §7 + gate items 1, 7, 10–17; brief §10 — **FAIL**

- The claimed suites `conference_ui_test.dart` and
  `conference_reader_test.dart` **do not exist** (§0.2).
- The suites that exist (§1) assert data and plumbing only. For
  every control in spec §7's master table (toggle, root tile,
  conference row, talk row, sheet row, scripture row, both Gospel
  Library forms) the required semantics-tree assertion is
  **missing** — `find.bySemanticsLabel` appears nowhere in the
  run-8 tests. Under lesson #25, every §7 requirement is therefore
  not real yet, independent of the missing UI.
- No widget test proves gate item 1 (OFF sheet has no "Conference
  talks" text; OFF Library root has exactly two tiles), item 10
  (sheet ordering with same-year April/October fixtures as
  *rendered*), item 14/15 (inclusion rules as rendered), or item 20
  (reduced-motion pushes/sheet).
- No assertion-that-cannot-fail finding is raised against the two
  existing suites — read in full, their expectations are concrete
  and falsifiable (§1). The finding is absence, not vacuity.

### 2.9 Token discipline — spec §1.2 / gate items 3, 21; brief token check — **PASS for the existing diff; FAIL for the claimed build**

- In the existing run-8 diff: no `Color(0x…)` literals, no
  `fontSize` literals, no `TextStyle` literals, no new token /
  `WwType` role / radius / duration (grep of the diff: none). The
  data + plumbing commits are token-clean — trivially, since they
  render nothing.
- For the claimed UI build there is nothing to grep. The brief's
  own token vocabulary (§0.3.4) would itself fail this clause if
  built: every named role it requires is outside the closed
  inventory.

---

## 3. THE THREE REPORTED DEVIATIONS — RULINGS

### Deviation 1 — sheet row trailing slot holds ONE control; the labeled IconButton lives on TalkDetail / browse instead — **REJECT as framed; premise false under the filed spec**

Under the filed spec there is nothing to deviate *from*: §3.2
mandates **no trailing control at all** on sheet talk rows, and
§3.3 makes the whole row the tap target (sheet pops → talk view).
A single-control sheet row is not a deviation; it is the spec.
Conversely, the control the brief says was "moved" — a 48×48
`IconButton` labeled "Read {title} in Gospel Library" — exists in
**neither** location: no sheet, no TalkDetail, no browse (§0.2,
§2.2, §2.3). And §4.4.1's actual talk-view action is a full-width
gold `ElevatedButton` (≥48dp, `open_in_new` 18dp, semantics
`Read {Talk title} in Gospel Library, opens external app or
website`), not an `IconButton`. **Ruling: FIX** — build §3.2/§3.3
and §4.4.1 exactly; do not reintroduce a trailing sheet control in
any form, and do not describe the talk-view button as an
IconButton.

### Deviation 2 — §8's "sheetLevel" realized as openReaderAt's bookStart param (name only) — **REJECT; neither name exists**

Grep across `flutter/lib`, `flutter/test`, and the filed spec for
`sheetLevel`, `openReaderAt`, `bookStart`: **zero hits for all
three**. The filed spec contains no `sheetLevel` (§8 is Motion).
The app's real reader seam is
`ReaderHost.openChapter(int ch, {int? verse, bool inNewScreen})`
(`reader_screen.dart:20`), implemented at
`shell_screen.dart:274`. A name-only deviation cannot be accepted
for code that does not exist, under names that do not exist.
**Ruling: FIX** — in the rebuild report, name the actual seam
used for talk-view scripture-row taps and sheet-row landings; if
it is `openChapter`, say `openChapter`.

### Deviation 3 — coverage line suppressed when talkCount == 0 — **REJECT as framed; the line itself is the violation**

The filed spec has **no coverage line to suppress**: Flag F-6 and
§4.1 prohibit coverage/year-range copy anywhere in the branch, and
`ConferenceData` exposes no `coverage` (§0.3.5). What the spec does
rule for the empty case is §4.1's dataset-empty rule: when the
dataset loads with **zero conferences, the root tile does not
render** — tile suppression, not line suppression (and note the
dataset *is* currently empty, §0.4, so this rule is the live one).
Suppressing an un-spec'd line at `talkCount == 0` is therefore
neither acceptable nor a violation of a real clause; it is a
record of work against a spec that isn't on file (lesson #23).
**Ruling: FIX** — drop the coverage line entirely; implement
§4.1's tile suppression and counted caption C-9 instead. If Silas
holds a newer brief that adds coverage copy, it comes back to me
for a spec amendment with the data to cash the claim (F-6) before
it is built.

---

## 4. JUDGMENT ITEMS (lesson #24: name them, keep them separate from law)

- **JUDGMENT — verdict form.** I chose FAIL over PASS WITH FIXES.
  Rationale is in the verdict header: every other clause failure in
  this report is mechanical (a missing file, a missing commit, a
  greppable absence), and the single judgment I exercised is that
  a gate stamp must not describe a non-existent build as a built
  build with fixes.
- **No other judgment was exercisable.** Composition, hierarchy,
  and surface quality — the things my judgment exists for — cannot
  be assessed on surfaces that were never built. I decline to
  pre-approve the brief's alternative surface designs (About
  screen, count chips, range-collapsed labels, capped sheet
  titles): each contradicts the filed spec mechanically, and none
  was presented to me as a spec amendment.

---

## 5. FIX LIST (mechanical, exact — routed via Silas; no app code was edited by this gate)

1. **Produce the build in this repo.** Land the run-8 UI on `main`
   (or name the branch) with commit hashes that resolve under
   `git log --all`. `fabaa26` / `19c05e0` / `3660531` do not.
2. **Reconcile the dispatch brief with the filed spec first**
   (§0.3, items 1–7). The brief's token names, heights (56/64dp),
   sheet trailing button, coverage line, chips, range-collapsing,
   and About screen are superseded by the filed spec in full.
3. **Profiles (§2):** insert the `General Conference` section after
   the New profile button, before Backup (24dp gaps; header C-1
   `selectionTitle`; copy C-2 `captionOnDark`; 16dp gap; toggle
   row). Row = Backup-row construction, whole row taps, leading
   `Icons.menu_book` 20dp `goldBright`, title C-3 `controlLabel`
   w600, subtitle C-4 `captionOnDark`. Switch: every color set on
   the widget per §2.4.1 (ON track `goldBright`, thumb `onGold`
   with `Icons.check` in `goldBright`; OFF track `surfaceHigh`
   with `borderDark` outline, thumb `mutedOnDark`), no disabled
   state. Semantics: one toggled node, label `Show conference
   talks`, asserted in both states.
4. **Sheet (§3):** when ON, one scroll region below the fixed
   header containing Connections then the `Conference talks`
   section (header C-5 in `refLabel`; 16dp section gap; rows per
   §3.2 — ≥48dp, title `bodyOnPaper` w600 uncapped, speaker line
   C-6 template in `captionOnPaper`, shipped dividers, **no
   trailing control**; ordering §3.3; duplicates once; empty state
   header + C-7). When OFF, the shipped sheet byte-for-byte. Row
   tap: pop sheet → talk view on the Library stack with its
   talks list beneath (§3.3, §4.5). Row semantics per §7.
5. **Browse (§4):** root tile ON-only and dataset-non-empty,
   testament-tile construction, caption C-9 counted at render
   time; conferences list with C-10 intro, §4.2 rows/semantics,
   C-22 footer; talks list per §4.3; talk view in §4.4's exact
   order (title, speaker, C-14, Gospel Library action, fallback
   caption when Form B, C-15 header, scripture rows per §4.4.2 —
   one row per distinct verse, canon order, snippet via
   `ScriptureText.verseText` in the **active** translation in
   `bodyOnDark`, tap via `openChapter` — then C-21 verbatim, then
   C-22 verbatim). Gospel Library action per §4.4.1: Form A C-16 /
   Form B C-17 + C-18 / no-link C-19, `open_in_new` 18dp `onGold`
   on `goldBright`, ≥48dp full width, launch failure → C-20
   snackbar in the run-6 construction, distinct §7 semantics per
   form. Back pops one level; breadcrumbs per §4.5.
6. **Fix the data APIs (§2.5):** `talksInConference` must preserve
   dataset session order (or the UI must not use it for the list);
   browse counts and conference inclusion must count only talks
   with ≥1 Bible citation. Update `conference_data_test.dart:193`'s
   title-sort assertion accordingly.
7. **Tests (§7, gate items 1, 7, 10–17, 20):** add the UI suites
   (whatever they are named, they must exist in `flutter/test/`)
   with semantics-tree assertions for every §7 control,
   OFF-contract assertions (no "Conference talks" in the sheet;
   exactly two Library root tiles), sheet ordering with same-year
   April/October fixtures, inclusion-rule assertions, Form A/B/
   no-link assertions, and reduced-motion verification.
8. **Dataset:** land the real pipeline dataset in
   `flutter/assets/conference.json` or record the empty-dataset
   state as a package blocker per §4.1 — the feature is
   founder-invisible until then (§0.4).
9. **Re-gate:** resubmit to Petra with Maren's verify in the
   package report (`flutter analyze` clean, `flutter test` green,
   `flutter build web --release` green — gate item 22). No verify
   output accompanied the claimed build; none could be checked.

— **Petra**, Design Auditor & QC, Woven Word Studio
