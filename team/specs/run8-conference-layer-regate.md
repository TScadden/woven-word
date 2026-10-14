# PETRA — RE-GATE, BOARD RUN 8: GENERAL CONFERENCE CONNECTIONS LAYER

**Auditor:** Petra, Design Auditor & QC
**Law audited against:** `team/specs/run8-conference-layer.md` (filed
spec, read in full again for this gate), gate checklist §11 items
1–22.
**First gate:** `team/specs/run8-conference-layer-gate.md` (FAIL —
the audited build did not exist). This re-gate is a sibling file,
not an append, so the first gate's record stands unedited.
**Repo state audited:** `~/workspace/woven-word`, working tree as
left by the builder (see §0 — the working tree and the committed
tree are not the same tree, and that difference is a fix item).

## VERDICT: PASS WITH FIXES

The build now exists and, clause by clause, the surfaces are the
spec's surfaces: the toggle, the sheet section, the browse branch,
and the talk view are built from the closed inventories, with the
ruled copy, the ruled semantics constructions, and the two §2.5
data fixes correctly landed at `0f657c8`. Five mechanical fixes
(§5) stand between this tree and a clean PASS; none requires a
design decision from me, and none may be waived. Gate item 8 (the
dataset) remains open and conditional, per §6 — the founder-visible
feature cannot ship until it closes, regardless of this verdict.

---

## 0. REPO STATE — VERIFIED, WITH THREE RECORD CORRECTIONS

Verified by me, not taken from the brief:

- HEAD is `83dfd92` ("Run 8 UI fix: labeled controls exclude inner
  semantics so the §7 container label is exact"), on top of
  `9dba98b` (sheet §3), `fa30995` (browse + talk view §4),
  `c132427` (Profiles §2), `0f657c8` (Maren's data fix).
- **Correction 1:** the brief's claimed Profiles commit `e3c95a7`
  does not exist (`git cat-file -t e3c95a7` → not a valid object).
  The Profiles §2 commit in this repo is `c132427`. `fa30995` and
  `9dba98b` resolve as claimed.
- **Correction 2:** there is no "url_launcher test-double fix
  commit." The fourth UI commit is `83dfd92`, the semantics
  exclusion fix. url_launcher enters as the talk view's
  `externalLauncher` seam (`conference_screens.dart:316ff, 467ff`),
  injected in tests — the mechanism is sound; the commit record in
  the brief is wrong.
- **Correction 3 — the audited tree is partly uncommitted.**
  `flutter/test/conference_browse_test.dart` and
  `flutter/test/conference_profiles_test.dart` are **untracked**,
  and `flutter/lib/screens/conference_screens.dart` carries an
  **uncommitted edit** (the Gospel Library button label wrapped in
  `Flexible` + centered, `conference_screens.dart` working-tree
  diff at the `_gospelButton` label). The claimed 211/211 suite
  therefore cannot describe the committed tree: on the committed
  tree, two of the three new UI suites do not exist. I audited the
  working tree as the real build; Fix F-3 closes the gap.
- **Item 22 verify — partial, recorded honestly:** I could not
  re-run `flutter test` / `analyze` / `build web` myself — no
  Flutter binary exists in this sandbox (`flutter: command not
  found`). The builder's claimed 211/211, analyze-clean, web-green
  is therefore **unverified by me** and is ruled on the strength of
  the test assertions as read (§3) plus the code as read (§2).
  Maren's verify must be re-run and reported on the committed tree
  after F-3 (see §5).

---

## 1. THE §2.5 DATA FIXES AT `0f657c8` — AUDITED, PASS

Both directives from my first gate §2.5 are implemented as ruled:

- **Dataset-order talks — PASS.** `talksInConference`
  (`conference_data.dart`, `0f657c8` diff) no longer sorts: it
  filters `_talks` in bundled order, doc-commented to §4.3/§3.3.
  The old title-sort assertion was replaced, not weakened:
  `conference_data_test.dart:193` now asserts ids `[1, 3, 7]` for
  2024 October and records in its comment that title order would
  be `[7, 3, 1]` — the assertion fails if any alphabetical re-sort
  returns. The talks list filters citing talks at the surface
  (`citingTalks`, `conference_screens.dart:60ff`: dataset order
  kept, `refsForTalk(talk.id).isNotEmpty` required), so §4.3's
  inclusion rule holds as rendered and is test-asserted
  (`conference_browse_test.dart`, "a talk with no Bible citation
  is not listed").
- **Citation-only conference counts — PASS.**
  `conferences()` now skips any talk whose `_byTalk` entry is
  missing or empty (`0f657c8` diff), so counts are talks with ≥1
  Bible citation (§4.1) and a zero-citing conference is absent
  (§4.2). Two new tests land with it
  (`conference_data_test.dart:204, 223`): a mixed 2025 October
  counts 1 not 2; a conference whose only talk cites out-of-canon
  or nothing is absent. Both assertions are concrete and can fail.
- **One ordering defect survives in the data layer** — it predates
  `0f657c8`, my first gate passed over it, and I record the miss
  as mine: see §2.3, sheet ordering, and Fix F-1.

---

## 2. CLAUSE-BY-CLAUSE AUDIT

### 2.1 Global / OFF contract (spec §1.1, items 1–3) — PASS

- Key `ww_conference_layer` (`shell_screen.dart:77`), default
  false (`shell_screen.dart:83`), non-bool/corrupt load degrades
  to false through the `_loadPrefs` catch (`shell_screen.dart:
  158ff`); a toggle writes at tap time
  (`setConferenceEnabled`, `shell_screen.dart:121ff`) and notifies,
  so an already-mounted Library root re-renders through
  `ListenableBuilder` (`library_tab.dart:342ff`) — §1.1's
  immediate-effect rule.
- OFF sheet: the `!confOn` branch (`reader_screen.dart:915ff`) is
  the shipped construction — fixed header, "Connections" in
  `refLabel`, the inner `ListView.separated`, shipped empty
  caption, no conference text, no gap. OFF Library root: the tile
  slot returns `SizedBox.shrink()` (`library_tab.dart:363ff`)
  contributing no gap; the root is search + exactly two testament
  tiles + the 24dp spacer. No teaser, no disabled furniture
  anywhere. Test-asserted for the root
  (`conference_browse_test.dart`, OFF group) — but **not** for the
  sheet; that half of item 1 is Fix F-2.
- Closed inventories (item 3): grepped the diff. No `TextStyle`
  literal in new code; every new `copyWith` is weight-only
  (`controlLabel.copyWith(fontWeight: w600)` —
  `conference_screens.dart:111`, `profiles_screen.dart:659`;
  `bodyOnPaper.copyWith(fontWeight: w600)` —
  `reader_screen.dart:888`, the §3.2 exception). The one
  color-changing `copyWith` in `reader_screen.dart:1145` is
  pre-existing shipped code (blame `35f62de`), not in this diff.
  No `Color(0x…)` literals, no new token/role/radius/duration.
  Radii in new code: `WwRadius.row`, `WwRadius.chip`,
  `WwRadius.sheet` only. Spacing literals in new code ⊆
  {2, 4, 8, 12, 16, 24}. Glyph sizes ⊆ {18, 20} (`open_in_new` 18
  at `conference_screens.dart:528`; chevrons/icons 20).

### 2.2 The toggle (spec §2, items 4–7) — PASS (D4/D7: §4)

- Placement and spacing (§2.2) are **literal**: New profile
  button → `SizedBox(24)` → header C-1 `selectionTitle` → 4 →
  copy C-2 `captionOnDark` → 16 → row → `SizedBox(24)` → Backup,
  still last (`profiles_screen.dart:529–542ff`). Copy C-1…C-4
  string-compared in code and in
  `conference_profiles_test.dart` — verbatim.
- Row (§2.4): Backup-row construction, whole row taps
  (`profiles_screen.dart:628ff`), leading `Icons.menu_book` 20dp
  `goldBright` (`:648`), title C-3 `controlLabel` w600, subtitle
  C-4 `captionOnDark`, minHeight `WwSpace.minTarget`, padding
  12/8.
- Switch (§2.4.1): every property set on the widget
  (`profiles_screen.dart:672ff`): ON track `goldBright`, OFF track
  `surfaceHigh`, ON thumb `onGold`, OFF thumb `mutedOnDark`,
  outline `borderDark` 1.0 OFF / transparent 0.0 ON, `thumbIcon`
  `Icons.check` in `goldBright` in the ON state only, null OFF.
  No disabled state (`onChanged` always live). Test-asserted
  property by property (`conference_profiles_test.dart`, switch
  test) — this is exactly the §2.4.1 table, including the check
  glyph.
- Semantics (§2.5): one node — `Semantics(container: true,
  button: true, toggled: value, label: 'Show conference talks')`
  wrapping `ExcludeSemantics` (`profiles_screen.dart:628ff`), so
  no descendant text can merge into the label and the `Switch`'s
  own node never appears. The profiles test asserts
  `find.bySemanticsLabel('Show conference talks')` finds exactly
  one node and reads `isToggled` false → true → false across two
  row taps — §2.5's gate requirement, in both states. PASS.

### 2.3 The reader sheet (spec §3, items 8–12) — CODE PASS, ONE ORDERING FAIL, TESTS FAIL

Code, as built:

- Construction (§3.1): sheet still `paper`, `WwRadius.sheet`,
  `wwSheetAnimationStyle(context)`
  (`reader_screen.dart:776–783`). ON branch: **one** scroll
  region — a single `ListView` (`reader_screen.dart:994`)
  below the fixed header block, holding "Connections" + rows (or
  the shipped empty caption), a 16dp gap, then the conference
  section. Connection rows render as rows in that region with
  shipped construction, dividers, and trailing buttons. No
  nested scrollable in the ON branch. PASS.
- Section (§3.2): header C-5 `Conference talks` in
  `WwType.refLabel` (`reader_screen.dart:969`); 8dp gap; rows
  (`talkRow`, `:864ff`) ≥48dp (`minTarget` floor), padding
  vertical 8, title `bodyOnPaper` w600 with **no line cap and no
  ellipsis**, 2dp gap, speaker line
  `{Speaker} · {Month} {Year}` via
  `'${talk.speaker} · ${talk.conferenceLabel}'` in
  `captionOnPaper` (`:894`), `Divider(height: 1, WwColors.line)`
  between rows, and **no trailing control on any talk row**.
  PASS.
- Empty state (§3.4): ON + no talks renders header + 8dp +
  `No conference talks are recorded for this verse.` in
  `captionOnPaper` (`reader_screen.dart:969ff`) — C-7 verbatim,
  present whenever ON, absent whenever OFF by construction.
  PASS as code.
- Row tap (§3.3/§4.5): the row pops the sheet, then
  `openConferenceTalk` (`reader_screen.dart:875`;
  `shell_screen.dart:430ff`) switches to the Library tab, pops
  the Library stack to root, and pushes conferences list → that
  conference's talks list → talk view, so Back lands on the
  talks list. The reader's place is untouched. PASS as code.
- Row semantics (§3.5/§7): `Semantics(container: true, button:
  true, label: 'Open talk: {title}, by {Speaker}, {Month}
  {Year}')` over `ExcludeSemantics` (`reader_screen.dart:
  864ff`) — the exact §7 label. PASS as code.
- **Ordering (§3.3) — FAIL, one sub-clause.** Year descending
  and October before April hold (`talksForVerse`,
  `conference_data.dart:158ff`). But within one conference,
  talks citing the same verse are ordered by **title
  ascending**, not the dataset's session order: `_newestFirst`
  (`conference_data.dart:66ff`) tie-breaks on
  `a.title.compareTo(b.title)`, and
  `conference_data_test.dart:125` ("newest first: year desc,
  October before April, title asc") encodes that order as
  expected — for John 1:1 the sheet lists Bednar, Freeman, Wada
  where §3.3 + the fixture's dataset order require Wada,
  Freeman, Bednar. §3.3 is explicit: "Within one conference,
  talks keep the dataset's own session order." This is the same
  defect class `0f657c8` fixed for the talks list, one surface
  over. Fix F-1.
- **Tests — FAIL (items 8, 10, 11, 12; §7 sheet row).** There is
  **no sheet widget test anywhere in the tree**: grep for the
  section, `ConferenceHost`, and `openConferenceTalk` across
  `flutter/test/` returns only the Profiles copy test. The §7
  master-table row for the sheet talk row therefore has no
  semantics-tree assertion, and items 8 (OFF identical / ON one
  region), 10 (rendered ordering + duplicates-once), 11 (C-7
  rendered), and 12 (row tap → talk view with talks list
  beneath) are unasserted as rendered surfaces. Under lesson
  25, a semantics requirement without an assertion is not real.
  The code passes my read; the gate's evidence standard does
  not. Fix F-2.

### 2.4 Library browse + talk view (spec §4, items 13–18) — PASS WITH ONE MINOR FAIL

- Root tile (§4.1, item 13): ON-only, testament-tile construction
  verbatim in kind (`library_tab.dart:363ff` — `surface`,
  `WwRadius.row`, minHeight 72, padding 16, `selectionTitle`
  title C-8, chevron 20dp), 8dp gap above it inside its slot
  column, caption C-9 counted at render: `n` from
  `conferences().length`, `m` summed from the citation-only
  counts (§1), pluralized by the shipped pattern. Dataset-empty
  suppression implemented exactly as ruled: zero conferences →
  tile does not render (`:368`); also suppressed while data is
  unloaded. Semantics `General Conference, {N} conferences, {M}
  talks` on one excluded container node. No coverage/year copy
  anywhere in the branch (grepped). Test-asserted in all four
  states (OFF, no-state, ON + tap, ON + empty). PASS.
- Conferences list (§4.2, item 14): C-10 intro verbatim above the
  first row (`conference_screens.dart:180ff`), 16dp gap, rows 8dp
  apart in the §4.2 construction (via `browseRow`, `:85ff` —
  minHeight 48, padding 12/8, title C-11 `controlLabel` w600,
  subtitle C-12 `captionOnDark`, chevron 20dp, no leading icon),
  semantics `Open {Month} {Year} conference, {M} talks`, and the
  C-22 attribution footer after a 16dp gap (§5 placement 2).
  Newest-first rendered order asserted by position in
  `conference_browse_test.dart`. PASS.
- Talks list (§4.3, item 15): dataset order as rendered
  (position-asserted: Wada < Freeman < Bednar — the F-1 contrast:
  this surface is right), subtitles `{Speaker} · {K} scriptures`
  with K = `talkScriptureCount` (summed distinct verses of
  `refsForTalk` groups — the same rows the talk view lists),
  semantics `Open talk: {title}, by {Speaker}`, inclusion and
  C-23 safety state (`conference_screens.dart:246ff`, centered
  `captionOnDark`) both test-asserted. PASS.
- Talk view (§4.4, item 16): body order matches §4.4 steps 1–16
  exactly (`conference_screens.dart:435ff`): title
  `selectionTitle`, 4, speaker `bodyOnDark`, 2, conference line
  C-14 `captionOnDark`, 16, Gospel Library action (+ C-18
  caption in Form B), 24, `Scriptures cited` C-15 in
  `refLabelOnDark`, 8, scripture rows 8dp apart, 16, C-21
  verbatim (constant at `:31ff`, string-compared in tests), 8,
  C-22 verbatim (constant at `:24ff`). Top bar title is the
  conference label; breadcrumb Library / General Conference /
  {Month} {Year} / current = talk title. PASS.
- Scripture rows (§4.4.2): one row per distinct verse (deduped
  edges grouped canon-ordered by `refsForTalk`), range citations
  render verse by verse, snippet via
  `ScriptureText.verseText(_translation, …)` in the **active**
  translation (`_scriptureRow`, `conference_screens.dart:
  560ff`), rendered in `bodyOnDark`, `maxLines: 3` + ellipsis —
  zero occurrences of the `snippet` role on this dark view
  (F-2's prohibition respected), reference in `refLabelOnDark`,
  semantics `Open {Reference}`, test-asserted including KJV
  snippet content and canon order by position. **Minor FAIL:**
  §4.4.2 rules the trailing chevron "vertically centered against
  the text column"; the row's `Row` is
  `crossAxisAlignment: CrossAxisAlignment.start`
  (`conference_screens.dart:573`), so the chevron sits at the
  top against the reference line. One-property fix (F-4).
  Chapter-only citations: no code path exists — the edge shape
  is verse-level and parse drops verse < 1
  (`conference_data.dart` parse bounds). With the dataset as
  specified (verse edges only) the state is unreachable; it
  becomes a live question only when the real dataset lands —
  recorded as conditional in §6, not failed against the UI.
- Gospel Library action (§4.4.1, item 17): gold-primary
  construction — `goldBright` fill, `WwRadius.chip`,
  `Size.fromHeight(minTarget)`, `goldButtonLabel`, `open_in_new`
  18dp `onGold`, 8dp gap (`conference_screens.dart:505ff`).
  Form A C-16 with semantics `Read {title} in Gospel Library,
  opens external app or website`; Form B C-17 + mandatory C-18
  caption directly beneath (8dp) with its distinct semantics
  `Open the {Month} {Year} conference in Gospel Library, opens
  external app or website`; no-link renders C-19 in the button's
  place, no button. Launch goes through url_launcher in
  external-application mode by default; failure **and** a
  throwing launcher both land in the C-20 snackbar
  (`surfaceHigh`, floating, `WwRadius.chip`, `bodyOnDark`).
  All three forms + both failure modes test-asserted in
  `conference_browse_test.dart`. PASS.
- Back / breadcrumb (§4.5, item 18): every level pops one level
  (`shell_screen.dart:440ff`); breadcrumb selections use the
  shipped `libraryTopBar` menu (explicit `surfaceHigh`,
  `WwRadius.chip`, 48dp items, current item non-tappable with
  check) and `popUntil` the named routes; tab re-tap follows
  the shipped shell rule. Scripture-row tap: see D1 (§4) —
  the shipped stack discipline is preserved. PASS.

### 2.5 Semantics master table (spec §7) — PASS EXCEPT THE SHEET ROW

Every §7 control has a falsifiable semantics-tree assertion in
the working tree — toggle (both states), root tile, conference
row, talks-list row, scripture row, Gospel Library Forms A and
B (distinct labels, both asserted) — **except the sheet talk
row**, which has none (Fix F-2). Back tooltips and breadcrumb
tooltips are the shipped patterns, unchanged. The `83dfd92`
exclusion construction (container + `ExcludeSemantics`) is
applied uniformly, so each asserted label is the node's exact
label — removing the container or altering the identifying text
fails its test.

### 2.6 Motion (spec §8, item 20) — PASS

No new animation primitive in the diff (grep for
`AnimationController`, `Tween`, `Animated*`, custom durations:
no additions). Browse pushes are `WwPageRoute`
(`shell_screen.dart:445, 462, 490`); the sheet opens through
`wwSheetAnimationStyle` (`reader_screen.dart:780`); the toggle
flip animates nothing app-authored. Reduced motion is
test-asserted for the browse pushes
(`conference_browse_test.dart`, §8 group, `disableAnimations:
true`); the sheet's reduced-motion half rides on F-2's suite.

### 2.7 Contrast (item 21) — PASS

Every pair in the rendered states re-derives from the diff's
actual tokens to the §9 table: the switch pairs (9.71:1 ON,
5.63:1 OFF thumb), the paper pairs (`refLabel` 4.62:1,
`bodyOnPaper` 17.12:1, `captionOnPaper` 4.57:1), the dark pairs,
and the gold-button pair (9.71:1). No prohibited pair appears:
no `snippet` on dark, no `goldBright` text on paper, no
`refLabelOnDark` inside the sheet (grepped).

---

## 3. DEVIATION RULINGS

- **D1 — scripture-row tap mechanism — REJECTED AS STATED; the
  spec text governs and the code already follows it.** The
  declared mechanism does not exist: grep for `openBook` and
  `LibraryNav` across `flutter/lib` and `flutter/test` returns
  **zero hits**. The talk view's scripture rows call
  `widget.onOpenVerse(globalChapter, verse)`
  (`conference_screens.dart:568`), wired in the shell to
  `openChapter(ch, verse: verse)` (`shell_screen.dart:511`) —
  the ReaderHost seam, exactly §4.4.2's "the shell's one
  open-chapter procedure." The stack concern in the builder's
  rationale is unfounded: `openChapter` switches to the Screens
  tab and leaves the Library stack (talk view included) exactly
  as it was underneath, which is what §4.4.2 requires. No fix;
  the deviation record is corrected so no future builder
  "fixes" conforming code toward a seam that does not exist.
- **D7 — Profiles spacing — REJECTED AS DESCRIBED; ACCEPTED AS
  BUILT.** The declared realization (section gap 24 / header 16
  / intro 12 / row gap 8) appears nowhere in the section. The
  as-built sequence is §2.2's literal sequence
  (`profiles_screen.dart:529–540`): 24 after New profile, 4
  header→copy, 16 copy→row, 24 row→Backup. §2.2 governs, the
  code matches it character for character, and the "net layout"
  equivalence argument is moot. No fix.
- **D4 — switch inside the row's InkWell — REJECTED AS
  DESCRIBED; ACCEPTED AS BUILT, with a test fix (F-5).** The
  declared `onChanged: null` is false: the switch's
  `onChanged` is `_toggleConference`
  (`profiles_screen.dart:674`) — the **same single function**
  the row's InkWell calls (`:645`), with an equality guard, so
  there is one toggle action and one state write whichever
  surface receives the tap, and the switch (the deeper gesture
  recognizer) consumes its own taps. §2.5 is satisfied as
  rendered: `ExcludeSemantics` removes the switch's own node,
  leaving exactly one toggled node, asserted in both states.
  §2.4's text ("does not need a second, separate handler with
  separate behavior") is met in behavior — same handler, same
  behavior — though not in the declared form. Because no test
  taps the switch itself, the single-flip property at the
  switch's own target is unproven; F-5 adds that assertion
  rather than restructuring conforming code.
- **D2 — single scroll region mechanics — ACCEPT.** The ON
  branch's one-`ListView` construction with the shipped OFF
  branch retained (`reader_screen.dart:915ff, 994`) is exactly
  the unification §3.1 permits: OFF rendering is the shipped
  rendering, ON has no nested scrollable. No clause touched
  beyond its terms.
- **D3 — fixture shape — ACCEPT.** `flutter/test/fixtures/
  conference_fixture.json` (8 talks, dedupe/out-of-canon edges
  included) backs the data, shell, and browse suites; a test
  fixture is not a surface and no spec clause governs its shape
  beyond what the assertions drawn from it must prove — they do
  (§2.4), with the one ordering exception encoded wrongly at
  the data level (F-1).
- **D5 — 8dp row padding — ACCEPT.** It is not a deviation:
  §3.2's construction is `padding: vertical 8` on a
  `minTarget`-floor container, and `talkRow` matches it
  (`reader_screen.dart:883ff`).
- **D6 — test-timing note — ACCEPT AS A NOTE.** Construction
  detail only; no clause depends on pump durations. The suites'
  assertions are positional, semantic, and state-based, not
  timing-based, as read.
- **D8 — NOT RULED; ITS TEXT WAS NOT IN MY HANDOFF.** The brief
  names D8 as a construction note but does not state it. I will
  not rule a deviation I have not read. Nothing in the diff
  presents an eighth unaccounted construction choice that
  touches a spec clause (my greps in §2.1 cover the diff's
  tokens, radii, spacings, glyphs, and motion); if D8's text
  exists, Silas sends it and I rule it in an addendum.

---

## 4. JUDGMENT ITEMS

- **JUDGMENT — verdict form.** PASS WITH FIXES, not FAIL: the
  contrast with the first gate is the point. There the build
  did not exist; here every surface exists and reads as the
  spec's surfaces, and the open items are five enumerated
  mechanical corrections (§5) plus the dataset gate (§6) that
  was always separate. The sheet-ordering defect (F-1) is a
  real rendered-behavior violation, and it is small, exact, and
  fixable in the data layer without touching any surface —
  the definition of a fix item in this studio.
- **JUDGMENT — D1/D4/D7 pattern.** Three of the builder's
  declared deviations describe code that is not the code. In
  each case the code conforms and the declaration does not. I
  rule the code, per lesson 24 — but the pattern is recorded:
  deviation declarations are gate evidence, and a declaration
  that misdescribes the diff costs the gate a verification
  pass it should not need. Future package reports: declare
  deviations from `git diff`, not from memory of building.

---

## 5. FIX LIST (mechanical, exact — all five block a clean PASS)

1. **F-1 — Sheet within-conference order (§3.3).** In
   `conference_data.dart`, `_newestFirst` must not tie-break
   by title: within the same year+session, order by dataset
   order (id ascending — ids are bundled-table indices, so id
   order is dataset order). Update
   `conference_data_test.dart:125`'s ordering test: for John
   1:1 the expected order becomes dataset order within 2024
   October — Wada ("The Words of Christ…"), Freeman ("Live Up
   to Your Privileges"), Bednar ("Be Still, and Know That I
   Am God") — then 2024 April, then 1990 October. Year desc /
   October-before-April assertions stand unchanged.
2. **F-2 — Sheet test suite (§3, §7, items 8/10/11/12/20).**
   Add a widget suite for `_openConnections` with a fake
   `ConferenceHost` asserting: OFF renders no "Conference
   talks" text and the shipped sheet; ON renders C-5, one
   populated row with the exact §7 semantics label
   `Open talk: {title}, by {Speaker}, {Month} {Year}` found
   once in the semantics tree; ON + uncited verse renders
   header + C-7 and no talk-row node; ordering as rendered
   with same-year April/October fixtures (post-F-1 order);
   a talk citing the verse via duplicate/range edges renders
   one row; row tap pops the sheet and invokes
   `openConferenceTalk` with that talk; sheet opens under
   `disableAnimations` via `wwSheetAnimationStyle`.
3. **F-3 — Commit the audited tree (item 22).** Commit
   `conference_browse_test.dart`, `conference_profiles_test.
   dart`, and the uncommitted `_gospelButton` Flexible edit
   (or revert the edit and say so); correct the package
   record (Profiles commit is `c132427`; the fourth commit is
   `83dfd92`, the semantics fix — there is no `e3c95a7` and
   no url_launcher-fix commit); re-run Maren's verify on the
   committed tree and report the actual counts (analyze,
   test, web release). My §0 note stands: the claimed
   211/211 was not independently re-runnable in this
   sandbox.
4. **F-4 — Scripture-row chevron alignment (§4.4.2).**
   `conference_screens.dart:573`: the scripture row's `Row`
   goes to `CrossAxisAlignment.center` so the chevron is
   vertically centered against the text column, as specced.
   (The browse rows already center theirs by default.)
5. **F-5 — Switch-target tap assertion (§2.4/D4).** In
   `conference_profiles_test.dart`, add a tap directly on the
   `Switch` asserting exactly one flip (one `onChanged`
   emission, toggled flag inverted once) — proving the
   row/switch single-action property at the switch's own
   target, not only at the row's text.

## 6. CONDITIONAL / OPEN ITEMS (not UI failures; the verdict is conditional on them)

- **Gate item 8 — dataset — OPEN.** `flutter/assets/
  conference.json` is still the empty placeholder
  (`{"edges":[],"talks":[],"v":1}`, 29 bytes). Per §4.1 the
  shipped app therefore renders no Library tile and the §3.4
  empty line for every verse: the UI verdict above is a
  verdict on fixture-driven surfaces. A final verify on the
  shipped tree is required when the pipeline dataset lands,
  and the following items can only close then: item 13's
  counts against real data, item 16's chapter-only handling
  (§2.4 — unreachable on verse-only edges; if the harvested
  dataset carries chapter-only citations, their
  representation must be resolved before that verify, since
  parse currently drops verse < 1), and the founder-visible
  check of the whole branch.
- **D8** (§3) remains unruled pending its text.

— **Petra**, Design Auditor & QC, Woven Word Studio
