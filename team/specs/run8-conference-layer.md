# PETRA — DESIGN SPEC, BOARD RUN 8: GENERAL CONFERENCE CONNECTIONS LAYER (BINDING)

**From:** Petra, Design Auditor & QC
**To:** Maren, Lead Flutter Engineer (verbatim handoff, via Silas)
**Scope:** The General Conference connections layer, and nothing else:
(1) a settings toggle on the Profiles screen, (2) a "Conference talks"
section in the reader's verse connections sheet, (3) a conference
browse inside the Library drill-down (conferences → talks → talk view),
(4) the talk view's outbound Gospel Library action, and (5) the honest
copy that bounds all of it. When the layer is OFF — the default — the
app behaves exactly as it does today, with no conference UI anywhere.

**Authorities read before writing:** `team/TEAM.md`; `team/memory/
LESSONS.md` (esp. #2 composition over scale, #13 role-split tokens,
#15 research reconciliation, #16 audit every state, #17 the surface
matrix and non-color cues, #20 presentation defaults are traps,
#23 specs persist as files, #24 verify the mechanism, #25 a tooltip IS
the semantics label and a semantics requirement is only real with a
semantics-tree assertion); the design law (`tabs-design-audit/SKILL.md`,
Woven Word adaptation per TEAM.md: `ww_theme.dart` tokens win, every
mechanical rule applies in full); the founder ruling and method limits
(`decisions/2026-10-14-founder-ruling-conference-facts.md`) and the
citation criterion (`decisions/2026-10-14-citation-criterion.md`); and
the current code, read in full for the surfaces this run touches:
`flutter/lib/theme/ww_theme.dart`, `flutter/lib/screens/
profiles_screen.dart`, `flutter/lib/screens/reader_screen.dart`
(`_openConnections`), `flutter/lib/screens/library_tab.dart`, plus
`shell_screen.dart` and `my_notes_screen.dart` for the navigation and
row patterns this spec reuses.

**Method note:** Every contrast ratio below is computed by me from
token hexes by the audit §2 method (composite alpha to opaque,
linearize sRGB, `L = 0.2126R + 0.7152G + 0.0722B`, ratio
`(Llight+0.05)/(Ldark+0.05)`). No ratio is copied from a comment or a
prior gate; where a number matches one, I recomputed it. Thresholds:
normal text ≥ 4.5:1; large text (≥24sp, or ≥19sp bold) ≥ 3.0:1;
meaningful icons and meaning-carrying boundaries ≥ 3.0:1; decorative
hairlines exempt. Mechanical thresholds are law. Where I exercise
judgment inside them, the ruling is marked **JUDGMENT** with its
rationale, so the gate can tell law from call.

**Copyright boundary (founder ruling, binding here):** The app hosts
citation FACTS only — talk title, speaker, conference year/session,
cited scripture references. It never hosts, bundles, or reproduces
talk text. Every scripture snippet in this run is KJV or WEB text
from the app's own bundled texts, in the active translation, exactly
as the shipped connections sheet and My Notes already render it. The
one outbound path is the talk view's Gospel Library action (§4.4).

---

## 0. RULINGS AT A GLANCE — AND ONE PREMISE CORRECTED

- **Toggle placement: the Profiles screen, as a new "General
  Conference" section between the profiles block and the Backup
  section** (§2.1, with rationale). The founder suggested settings;
  Profiles is this app's settings surface, and the ruling is mine to
  record, per the brief.
- **PREMISE CORRECTION (lesson 24 — verify the mechanism):** the
  brief describes Profiles as already hosting "Translation and
  Backup sections." The code hosts **Backup only**. Translation is
  not a Profiles section and never has been; it is the segmented
  toggle in the reader's top bar (`_translationToggle`). This spec's
  placement therefore rests on the Backup precedent, which is real,
  and on Profiles being the app's only settings-like surface — not
  on a Translation section that does not exist. Maren: do not build
  a Translation section, and do not move the reader's toggle. If
  Silas intended a different settings surface, this is the point to
  say so; there is no other candidate in the codebase.
- **Ordering CONFIRMED, not amended:** conference lists and the
  sheet's talk section sort **newest first — year descending, and
  October before April within a year** (§3.3, §4.2). Rationale in
  §3.3.
- **No new tokens, no new `WwType` roles, no new radius, no new
  duration.** Every surface in this run maps to an existing audited
  role and pair (§1.2, §9). If the build believes it needs one, it
  stops and returns to me first — the run-6 rule, unchanged.
- **Layer state is a global app preference, not a profile scope**
  (§1.1). **JUDGMENT:** profiles are buckets of highlights and notes;
  a content layer that silently changed when the user switched
  profiles would read as data loss. Translation — the nearest
  precedent — is a global preference (`ww_translation`), and this
  layer follows it.

---

## 1. GLOBAL RULES FOR THE LAYER

### 1.1 State, persistence, and the OFF contract

- **Preference key (new, binding):** `ww_conference_layer`, a bool
  in SharedPreferences, read with the app's defensive-load discipline
  (lessons #18/#19): missing, unreadable, or any non-bool value
  resolves to **false**. There is no migration; the key simply
  begins to exist the first time the user toggles.
- **Default is OFF.** A fresh install, an upgraded install, and a
  corrupt store all present the layer OFF.
- **OFF means absent, not disabled.** With the layer OFF: the
  Profiles toggle row renders in its OFF state (that row *is* the
  layer's switch; it is the one conference element that always
  renders), the connections sheet renders byte-for-byte as shipped
  (header, verse, "Connections", rows — no "Conference talks"
  header, no empty-state line, no gap where the section would sit),
  the Library root renders exactly the shipped search field and two
  testament tiles, and no conference route can be reached by back
  navigation, breadcrumb, or tab re-tap. A greyed-out tile, a locked
  row, or a "turn this on in Profiles" teaser anywhere is a Blocker:
  an absent feature leaves no furniture (run-7 §3.1 reservation,
  now spent by this run and only by this run).
- **The toggle takes effect immediately and everywhere.** Flipping
  the switch writes the preference at the moment of the tap (the
  Profiles `_persist` pattern: visible state first, the write
  fire-and-forget with a catch — a failed write loses persistence,
  never the change the user just saw). The next sheet opened, the
  next Library render, and any already-pushed Library stack that
  re-renders must agree with the stored value. No restart, no
  "changes take effect later" copy. Turning OFF while a conference
  route is on the Library stack: the stack is **not** yanked from
  under the user mid-read — the pushed routes finish their life
  normally, but the Library root reached afterward renders OFF-state,
  and no new conference route can be pushed. (The toggle lives on
  the Home navigator and the browse on the Library navigator, so
  this can only happen across a tab switch; the rule exists so the
  two navigators never disagree about which is allowed.)
- **The layer is not scoped to a profile, a translation, or a
  screen.** It is one bool for the app. Scripture snippets inside it
  follow the active translation, as every other snippet in the app
  does (the run-6 follow-up ruling: My Notes snippets follow the
  active translation; talk-view snippets do the same, §4.4).

### 1.2 The closed inventories this run builds from

- **Type roles:** `screenTitle`, `selectionTitle`, `controlLabel`
  (weight-only `copyWith(w600)`, the shipped profile-row pattern —
  a `copyWith` that changes **color** in new code fails the gate),
  `bodyOnDark`, `captionOnDark`, `refLabelOnDark`, `goldButtonLabel`,
  `bodyOnPaper`, `captionOnPaper`, `refLabel`, `snippet`,
  `sheetRefTitle`, `readerSheetVerse`. That is the whole list. One
  weight-only exception is named in §3.2 (talk-row title). Any other
  `TextStyle` literal in new code fails the gate.
- **Surfaces:** dark surfaces are `stage` (L0 page) → `surface`
  (L1 rows/tiles) → `surfaceHigh` (L2: menus, snackbars, switch
  track) — steps only, no shadows, no nesting L2 in L2. The sheet
  is `paper`, exactly as shipped.
- **Radius:** `WwRadius.row` (10) for every row and tile in this
  run; `WwRadius.chip` (12) for the Gospel Library button and the
  snackbar; `WwRadius.sheet` (16) for the connections sheet, as
  shipped. No other radius appears.
- **Spacing:** screen margin 16 everywhere; every gap literal in
  {2, 4, 8, 12, 16, 24}. Nothing else.
- **Glyph sizes:** 18 (`open_in_new` action), 20 (leading row icons,
  disclosure chevrons, breadcrumb chevron). Nothing outside the
  audited set {18, 20} is introduced.

### 1.3 State matrix (lesson 16 — audit every state actually rendered)

This run's elements render in exactly these states, and §9 tabulates
every one: toggle switch ON / OFF (no disabled state exists and none
may be invented); Library root tile (one resting state; it renders
or it does not); browse rows (one resting state each — rows
navigate, they never show a selected state); sheet talk rows (one
resting state — no selected, highlighted, or flashed variant exists
on them, so the run-4 highlight surface matrix does **not** expand);
Gospel Library button (one resting state in each of its two link
forms, §4.4 — no disabled form: when no link of either kind exists
for a talk, see §4.4's no-link rule); snackbar (one state). A state
not listed here that appears in the diff is un-audited by definition
and fails the gate until it comes back to me.

---

## 2. THE TOGGLE — PROFILES SCREEN

### 2.1 Placement — the ruling and its rationale

**Ruling:** a new section titled `General Conference` inside
`_body()` of `profiles_screen.dart`, in the same `ListView` (16dp
padding unchanged), placed **after the New profile button and before
the Backup section**. The Backup section's own structure, copy, and
position as the screen's last section are otherwise unchanged; a
24dp gap separates the new section from Backup, exactly as 24dp
separates New profile from Backup today.

Rationale, recorded as the brief requires:

1. **It is a reading preference, not an identity action and not a
   data-safety action.** The screen's three jobs sort naturally:
   who is reading (profiles), what the reading shows (this layer),
   what happens to the data (Backup). Placing the layer between the
   first and third keeps each job's furniture together.
2. **It must not split the profiles block.** The profile rows and
   the New profile button are one unit (the button creates what the
   rows list). Interposing a settings section between them would
   separate an action from its list.
3. **It must not displace Backup from the foot.** Backup is the
   screen's terminal utility, and run 6 specced it as the last
   section with the ListView's bottom padding closing the screen.
   That stands; the new section goes *above* it, and Backup remains
   last.
4. **It is discoverable without hunting.** Profiles is reached by
   the profile chip in the Home top bar — one tap from Home root,
   the run-5 anti-burial standard. A conference layer buried deeper
   (inside the reader, inside a profile's edit flow) would fail the
   same discoverability rule that put My Notes on Home.

### 2.2 Section structure and spacing (binding, in render order)

1. `SizedBox(height: 24)` after the New profile button.
2. Section header: Text `General Conference`, style
   `WwType.selectionTitle`. This is the section's one primary
   element (audit §4): 17sp serif w600 against 13sp row titles
   below it.
3. `SizedBox(height: 4)` (the codified header→caption micro-gap,
   as in Backup).
4. Explanatory copy: one Text, `WwType.captionOnDark`, exact copy
   in §2.3.
5. `SizedBox(height: 16)`.
6. The toggle row (§2.4).
7. `SizedBox(height: 24)`, then the Backup section exactly as
   shipped.

All spacing literals are in the allowed set {4, 16, 24}. The
section adds no card, no divider, no container invention — it is
built from this screen's existing vocabulary, exactly as run 6
built Backup.

### 2.3 Copy — exact

Section header (verbatim):

> General Conference

Explanatory copy (verbatim, one Text, `captionOnDark`):

> Conference talks are not stored in this app. When this is on, you can see which talks cite a verse, browse talks in the Library, and open each talk in Gospel Library or the Citation Index.

Toggle row title (verbatim):

> Show conference talks

Toggle row subtitle (verbatim):

> Verse connections and the Library browse

Copy rules: no copy in this section claims the app contains,
downloads, or syncs talks; the phrase "in this app" is used only
for what the app actually holds (citation facts). The word
"conference" is never shortened to "GC" anywhere in this run's UI.

### 2.4 The toggle row and the switch — construction and states

The row is built **exactly like a Backup row** (run-6 §2.3
construction, which is the profile-row construction): `Material(
color: surface, borderRadius: WwRadius.row)` + `InkWell` (same
radius), `Container(constraints: minHeight: WwSpace.minTarget,
padding: horizontal 12, vertical 8)`. Inside, left to right:

- Leading icon: `Icons.menu_book`, 20dp, `goldBright` on `surface`
  = **9.55:1** (meaningful icon, pass). **JUDGMENT:** the Library
  tab's own glyph is `menu_book`; the section that switches the
  Library's extra browse carries the Library's mark, and the icon
  promises the surface the toggle most visibly creates.
- 12dp gap.
- `Expanded` column, `CrossAxisAlignment.start`: title
  `Show conference talks` in `controlLabel` with
  `copyWith(fontWeight: w600)` (the shipped row-title pattern;
  `navInk` on `surface` = **15.29:1**, pass); 2dp micro-gap;
  subtitle in `captionOnDark` (`mutedOnDark` on `surface` =
  **6.03:1**, pass).
- 12dp gap.
- The switch (§2.4.1), trailing.

**The whole row is the tap target** (full ListView content width ×
≥48dp high, growing with its two text lines; 48 is a floor, never
a cap). Tapping anywhere on the row toggles — a row whose subtitle
describes the feature but whose only live area is a 48dp switch at
its edge would be a mis-tap trap at exactly the target size the
audit exists to prevent. The switch inside the row is the visual
control and reflects the same state; it does not need a second,
separate handler with separate behavior — one toggle action, one
state write, whether the tap lands on the row or on the switch.

#### 2.4.1 The switch — every color set explicitly (lesson 20)

`wwTheme()` defines **no `switchTheme`**, so a stock `Switch` is an
unexamined presentation default and is prohibited (Flag F-4). The
switch is a Material `Switch` with every role below set on the
widget. Its state is carried by **three cues, never color alone**
(lesson 17): thumb position (right = on, left = off), a check
glyph in the ON thumb, and the `toggled` semantics flag (§2.5).

| Element | ON state | Ratio / verdict | OFF state | Ratio / verdict |
|---|---|---|---|---|
| Track fill | `goldBright` #E8B33C, on the `surface` row | **9.55:1** against the row — meaning-carrying boundary, pass | `surfaceHigh` #1B1B24 with a 1dp `borderDark` #33333F outline (the shipped input construction: `surfaceHigh` fill, `borderDark` border) | Outline is decorative here — state is carried by thumb position, glyph, and semantics, never by the track edge alone; the fill steps L1→L2 exactly as an input on a row does |
| Thumb fill | `onGold` #161300 on the `goldBright` track | **9.71:1** — pass | `mutedOnDark` #9A947F on the `surfaceHigh` track | **5.63:1** — pass (meaningful element) |
| Thumb glyph | `Icons.check`, in `goldBright`, drawn on the `onGold` thumb — `goldBright` on `onGold` = **9.71:1** (the §9 pair, symmetric), meaningful icon, pass | — | No glyph | — |
| Track/thumb motion | The framework's own switch animation; no app-authored animation, duration, or curve is added (§8) | — | Same | — |

There is **no disabled state**. The toggle is always live: OFF is a
value, not a disability. If the preference write fails, the row
still shows the new state for the session (the `_persist`
discipline, §1.1); no error UI is invented for a bool write.

### 2.5 Toggle semantics (lesson 25)

- The switch carries an explicit semantics label, set so the label
  is the node's own (a `Semantics(container: true, toggled: value,
  label: …)` construction or the `Switch`'s equivalent explicit
  seam — the mechanism is Maren's, the label is mine):
  **`Show conference talks`**, with the `toggled` flag carrying
  the state. The label must **not** bake the state into its text
  (no "…, on" / "…, off" suffix): the flag announces it, and a
  baked-in suffix would double-announce.
- Because the whole row also toggles, the row's merged semantics
  must resolve to that same single control — one node, one label,
  `button`/`toggled` semantics, never a row node and a switch node
  announcing two different things for one action.
- Gate requirement: a semantics-tree assertion in the widget tests
  (`find.bySemanticsLabel('Show conference talks')`) that also
  reads the `toggled` flag in both states. A label that exists only
  as a tooltip or only in a code comment is not a semantics label
  (lesson 25).

### 2.6 What the toggle does not do

It does not confirm (no dialog — flipping a display layer is
reversible by the same tap), it does not snack (no SnackBar — the
row's own state change is the feedback, exactly as a profile switch
feeds back by rendering), and it does not navigate (the user stays
on Profiles; discovering the browse is the Library's job, and the
subtitle already names it).

---

## 3. THE READER SHEET — "CONFERENCE TALKS" SECTION

Surface: the shipped verse connections sheet from
`_openConnections` — `paper` background, `WwRadius.sheet` top
corners, 16dp padding, `wwSheetAnimationStyle`, 75%-of-viewport max
height. Everything shipped stays: the reference title
(`sheetRefTitle`), the verse text (`readerSheetVerse`), the
"Connections" section (`refLabel` header, connection rows with
their trailing open-in-new-screen `IconButton`, the empty-state
caption). This section adds one section **below** Connections,
rendered **only when the layer is ON**. When OFF, §1.1's absent
contract applies — the sheet is the shipped sheet.

### 3.1 Scroll construction — one scroll region, binding

The shipped sheet is a `Column` whose only flexible child is the
Connections `ListView`. Two independently scrolling lists in one
sheet is prohibited: it traps scroll (the sheet-lesson the founder
taught on the web build — a surface the user cannot fully move
through is a defect), and it makes the second section's extent
unreachable on short viewports.

**Ruling:** when the layer is ON, the sheet's content below the
fixed header block (reference title + verse text, which stay fixed
exactly as shipped) becomes **one** flexible scroll region
containing, in order: the "Connections" header and its rows (or
its shipped empty caption), a 16dp section gap, the "Conference
talks" header (§3.2), and its rows (or its empty caption, §3.4).
Connection rows lose their inner `ListView` and render as rows in
the single region, with their shipped construction, dividers, and
trailing buttons unchanged. When the layer is OFF the shipped
construction stands untouched — Maren may unify the construction
internally only if the OFF rendering is provably identical, and
the gate will diff it as such.

Section gap: 16dp between the last Connections element (last row's
divider, or the empty caption) and the "Conference talks" header —
the sheet's own 12dp gap sits *above* "Connections" from the verse
block; 16 between the two peer sections keeps the peers visibly
peer. Both literals are in the allowed set.

### 3.2 Section header and talk-row anatomy

Section header (verbatim), style `WwType.refLabel` — the same
role, size, weight, and color as the "Connections" header directly
above it (sibling construction identical, audit §6):

> Conference talks

`goldTextOnPaper` #956D09 on `paper` #FFFDF8 = **4.62:1**, normal
text, pass. This is the only gold permitted for small text on
paper (lesson 13). `goldBright` as text on paper computes
**1.89:1** and `refLabelOnDark` is a dark-surface role: either
appearing on this sheet is a Blocker (Flag F-3).

8dp gap below the header (the shipped header→rows gap), then the
talk rows. Each talk row, in order top to bottom:

- Container: `InkWell` row, `Container(constraints: minHeight:
  WwSpace.minTarget, padding: vertical 8)` — the shipped
  connection-row target construction. The whole row is the tap
  target: full sheet content width × ≥48dp high.
- Title line: the talk's title, one Text, `WwType.bodyOnPaper`
  with `copyWith(fontWeight: FontWeight.w600)` — the one
  weight-only exception named in §1.2 (13sp w600 `ink` on `paper`
  = **17.12:1**, pass). Titles wrap; no line cap and no ellipsis
  on the title (a truncated talk title is a wrong title, and the
  row's height is content-derived — the 48dp is a floor).
- 2dp micro-gap (the shipped title→subtitle gap).
- Speaker line: one Text, `WwType.captionOnPaper`
  (`mutedOnPaper` on `paper` = **4.57:1**, pass), exact template:
  `{Speaker} · {Month} {Year}` — e.g. `Russell M. Nelson · October
  2024`. Month is the full English month name (`April` or
  `October`); the year is the four-digit conference year. No
  session subdivision, no "General Conference" suffix — the
  section header already says what these are.
- Divider: `Divider(height: 1, color: WwColors.line)` between
  rows, exactly as between connection rows (`line` on `paper` =
  1.33:1, decorative hairline, exempt — it carries no meaning
  alone; rows are separated by their targets and titles).
- **No trailing control.** Connection rows carry an
  open-in-new-screen button because a connection can open as a
  reading screen. A talk cannot — it has no screen in this app —
  so a talk row carries no trailing `IconButton`, and inventing
  one (an external-link glyph on the row, a new-screen glyph)
  would promise an action the row does not perform. The external
  action lives in exactly one place: the talk view (§4.4).

Hierarchy inside the row (audit §4): title over speaker line
differs by weight (w600 vs regular) **and** size (13 vs 12) — size
and weight before color, satisfied. The two lines also differ by
color token, but never by color alone.

### 3.3 Row tap, and the ordering rule — CONFIRMED

**Tap behavior — JUDGMENT:** tapping a talk row **closes the sheet
and opens that talk's talk view** (§4.4) in the Library tab: the
sheet pops first, then the shell switches to the Library tab and
pushes the talk view onto the Library navigator (through the
browse path's stack state — the conferences list and that
conference's talks list are placed beneath it, so Back from the
talk view lands on its conference's talks list, and the breadcrumb
unwinds coherently, §4.5). Rationale: the row is in-app data, and
its tap must do the in-app thing; the one external action in this
feature is the talk view's explicitly labeled Gospel Library
button. A row tap that silently left the app would be a surprise
exit with no labeled external control — and would make the talk
view unreachable from the very surface that lists talks most
often. The reader's place is not disturbed: the reading screen
keeps its chapter page and verse anchor in the Screens tab, as it
does for every Library excursion.

**Ordering — CONFIRMED as briefed:** talks sort **newest first**:
conference year descending; within one year, **October before
April** (October is the later conference of that year — descending
chronological order puts it first; this also matches how the
Church's own archive and Gospel Library present conferences,
newest at the top, and the user's most likely target is the most
recent conference). Within one conference, talks keep the dataset's
own session order (the order the talks were given) — a conference
is a program, and re-sorting its talks alphabetically would
scramble a meaningful sequence to no user's benefit. **JUDGMENT**
on the tie-break only; the year/session ordering itself is the
brief's rule and I confirm it without amendment.

**No cap, no truncation, no "show more."** A heavily cited verse
(John 3:16 class) may list many talks; all of them render in the
sheet's single scroll region (§3.1). A silent cap would make the
section's completeness a lie of omission; a "show more" control
is a second list state this sheet does not need. If the dataset
side ever needs a display bound, it comes back to me with numbers.

**Duplicate rule:** a talk that cites the selected verse more than
once, or cites a range containing it, appears **once** in this
section. Rows are talks, not citations.

### 3.4 Empty-state rule — binding

When the layer is ON and no talk in the dataset cites the selected
verse, the section still renders: the `Conference talks` header,
the 8dp gap, and exactly one caption line, `WwType.captionOnPaper`
(**4.57:1** on `paper`, pass), verbatim:

> No conference talks are recorded for this verse.

The header-plus-empty-line construction mirrors the shipped
Connections empty state (`No cross references are recorded for
this verse.` in the same role) — the two peer sections read as
peers in emptiness as in fullness. **The section never collapses
to nothing when ON:** a missing section is indistinguishable from
the layer being off, and the user who just enabled the layer in
Profiles must be able to tell "on, and this verse has none" from
"off". When OFF, per §1.1, neither header nor line renders.

### 3.5 Sheet semantics

- Each talk row carries one explicit semantics node:
  `Semantics(container: true, button: true, label: …)` with label
  exactly: `Open talk: {Talk title}, by {Speaker}, {Month} {Year}`
  — e.g. `Open talk: Think Celestial, by Russell M. Nelson,
  October 2023`. The row contains two text lines and no icon; the
  container label is what guarantees assistive tech hears one
  control with the talk's full identity, not two orphan texts
  (lesson 25's container lesson, learned on the Screens close
  button).
- The section header is a plain Text, not a control, and takes no
  semantics decoration.
- Gate requirement: semantics-tree assertions for at least one
  populated row label and for the empty state's *absence* of any
  talk-row node.

---

## 4. THE LIBRARY BROWSE — CONFERENCES → TALKS → TALK VIEW

The browse lives **inside the Library tab's existing navigator**,
extending the shipped drill-down (`LibraryRoot` → `BookGrid` →
`ChapterGrid` → reader) with a parallel branch (`LibraryRoot` →
conferences list → talks list → talk view). Every level uses the
shipped sub-screen pattern: `libraryTopBar` construction (`nav`
fill, `borderDarkSoft` bottom hairline, `minHeight:
WwSpace.topBarHeight`, 48dp back `IconButton` where a back exists,
title in `screenTitle` — `goldBright` on `nav` = **10.23:1**,
pass), pushes via `WwPageRoute` (300ms slide from the right, no
fade; reduced motion renders instantly — §8), and the breadcrumb
title-button (§4.5). Nothing in this branch invents a new bar, a
new route type, or a new list construction.

### 4.1 Library root — the conference tile (layer ON only)

Below the New Testament testament tile, an 8dp gap (the shipped
inter-tile gap), then **one** additional tile, built **exactly
like a testament tile** — same `Material` (`surface` fill,
`WwRadius.row`), same `InkWell`, same `Container(minHeight: 72,
padding: 16 on all sides)`, same trailing chevron — because it is
the same kind of object at the same level (sibling construction
identical, audit §6):

- Title: `General Conference`, in `WwType.selectionTitle`
  (`goldBright` on `surface` = **9.55:1**, normal text, pass) —
  the same role as `Old Testament` / `New Testament` on its
  sibling tiles. Gold here is the level's accent, spent identically
  on all three root entries; it does not compete with them because
  each tile is its own section's primary element.
- Caption under the title, 2dp micro-gap, `WwType.captionOnDark`
  (`mutedOnDark` on `surface` = **6.03:1**, pass), exact template:
  `{N} conferences · {M} talks` — pluralized by the shipped counted
  pattern (`1 conference`, `1 talk`). **Both numbers are computed
  from the loaded conference dataset**, where `M` counts the talks
  the browse actually lists (talks with at least one Bible
  citation, §4.3's inclusion rule). No year range, no "1942 to
  present" claim, no coverage language of any kind may appear on
  this tile: the tile claims exactly what the dataset delivers,
  counted (Flag F-6).
- Trailing: `Icons.chevron_right`, 20dp, `mutedOnDark` on
  `surface` = **6.03:1** (meaningful icon, pass), vertically
  centered.
- The whole tile is the tap target (full content width × ≥72dp).
  Tap pushes the conferences list (§4.2).
- The root's trailing 24dp spacer still closes the list, below
  this tile. When OFF, the tile and its 8dp gap do not exist
  (§1.1).
- **Dataset-empty rule:** if the layer is ON but the dataset loads
  with zero conferences, the tile does **not** render — a tile
  into an empty browse is a dead control, and dead controls are
  Blockers in this studio. The rest of the app is unaffected; the
  toggle stays ON and truthful (the layer is enabled; there is
  simply nothing to browse), and the sheet section renders its
  §3.4 empty line for every verse. This state is a data-gate
  failure to be reported in the package, not a UI state to design
  around.

Semantics: the tile carries label `General Conference, {N}
conferences, {M} talks` (button semantics) so the counts the tile
shows visually are the counts assistive tech hears.

### 4.2 Conferences list

- Top bar: back (pops to Library root), title `General Conference`
  (`screenTitle`), breadcrumb items: `Library`, current
  `General Conference` (§4.5).
- Body: `ListView`, padding 16 on all sides (the shipped
  My Notes / Profiles list construction), on `stage`.
- Intro caption, first element, `WwType.captionOnDark`
  (`mutedOnDark` on `stage` = **6.92:1**, pass), verbatim:

> Newest first. Talk counts include only talks that cite the Bible.

  This line is the browse's honesty key for every count below it:
  a conference whose talks cite mostly the Book of Mormon will
  show a small count here, and this caption is what keeps that
  small count from reading as a complete count. It renders once,
  above the first row, never repeated per row.
- 16dp gap, then one row per conference, 8dp gaps between rows.
- **Inclusion rule:** a conference appears only if it has at least
  one listed talk (§4.3). A conference with zero Bible-citing
  talks is absent, for the same dead-end reason as §4.1's
  dataset-empty rule; the intro caption is what makes the absence
  honest rather than silent — the browse never claimed to be a
  complete conference archive, it claims talks that cite the
  Bible.
- **Order:** newest first, the §3.3 rule — year descending,
  October before April within a year.
- Row construction — the shipped list-row construction (profile /
  Backup / My Notes rows): `Material(surface, WwRadius.row)` +
  `InkWell`, `Container(minHeight: 48, padding: horizontal 12,
  vertical 8)`, whole row is the tap target:
  - Title: `{Month} {Year}` (e.g. `October 2024`), `controlLabel`
    w600 (`navInk` on `surface` = **15.29:1**, pass).
  - 2dp micro-gap.
  - Subtitle: `{M} talks` / `1 talk`, counted as in §4.1,
    `captionOnDark` (**6.03:1** on `surface`, pass).
  - Trailing chevron: `Icons.chevron_right` 20dp `mutedOnDark`
    (**6.03:1**, pass). No leading icon on these rows — a date is
    not an action, and the testament/profile leading-icon pattern
    belongs to named objects, not to list entries in a long
    chronological list. **JUDGMENT:** ~170 conferences of icons
    would be wallpaper; the rows' identity is their dates.
- Semantics per row: `Open {Month} {Year} conference, {M} talks`
  (container, button). Gate-asserted.

### 4.3 Talks list (one conference)

- Top bar: back (pops to the conferences list), title = the
  conference label `{Month} {Year}` (`screenTitle`), breadcrumb:
  `Library`, `General Conference`, current `{Month} {Year}`.
- Body: `ListView`, padding 16, on `stage`. No intro caption —
  §4.2's caption governs the branch, and the talk view carries the
  per-talk honesty copy (§4.4); repeating it at every level is
  noise that trains the user to skip it.
- One row per talk, 8dp gaps, same row construction as §4.2:
  - Title: the talk's title, `controlLabel` w600 (**15.29:1** on
    `surface`, pass). Wraps without a line cap, as §3.2.
  - 2dp micro-gap.
  - Subtitle: `{Speaker} · {K} scriptures` / `1 scripture`,
    `captionOnDark` (**6.03:1**, pass), where `K` is the number of
    distinct Bible verses the talk view will list for this talk
    (§4.4) — the subtitle counts what the tap delivers, never the
    talk's total citations across all standard works.
  - Trailing chevron, 20dp `mutedOnDark` (**6.03:1**, pass).
- **Inclusion rule (binding):** only talks with at least one Bible
  citation are listed. **JUDGMENT, with rationale:** this is a
  Bible app's browse; a listed talk whose view could show zero
  scriptures is a dead end dressed as content. The exclusion is
  disclosed where it operates — §4.2's intro caption states the
  counts' basis, and §4.4's caption states the per-talk basis — so
  the filter is a stated scope, not a silent one.
- **Order:** the dataset's session order for that conference
  (§3.3's tie-break applied at list level): the order the talks
  were given. No alphabetical re-sort, no citation-count sort.
- Semantics per row: `Open talk: {Talk title}, by {Speaker}`
  (container, button). Gate-asserted.
- **Safety empty state:** the inclusion rule makes an empty talks
  list unreachable by construction (a conference is listed only
  when it has a listed talk). If a data fault reaches it anyway,
  the body renders one centered caption, `captionOnDark`,
  verbatim: `No talks are listed for this conference.` — a stated
  fact, never a spinner that never resolves and never a blank
  screen.

### 4.4 Talk view

The talk view is a pushed route in the Library navigator. It shows
**facts about one talk and the Bible verses it cites** — never talk
text.

- Top bar: back (pops to the talks list), title = the conference
  label `{Month} {Year}` (`screenTitle`; the bar names the
  conference because the talk's own title, which may be long,
  lives in the body where it can wrap in full), breadcrumb:
  `Library`, `General Conference`, `{Month} {Year}`, current =
  the talk title (shown with the shipped current-item construction:
  check icon + muted text, not tappable).
- Body: `ListView`, padding 16, on `stage`, in this order:
  1. **Talk title:** one Text, `WwType.selectionTitle` (17sp serif
     w600, `goldBright` on `stage` = **10.94:1**, normal text,
     pass), wrapping without a cap. This is the view's one primary
     element.
  2. 4dp gap.
  3. **Speaker line:** the speaker's name, one Text,
     `WwType.bodyOnDark` (`navInk` on `stage` = **17.54:1**, pass).
  4. 2dp gap.
  5. **Conference line:** one Text, `WwType.captionOnDark`
     (**6.92:1** on `stage`, pass), exact template:
     `{Month} {Year} General Conference` — e.g. `October 2024
     General Conference`.
  6. 16dp gap.
  7. **The Gospel Library action** (§4.4.1) — full width, minimum
     height 48. Placed above the scripture list, not below it: the
     user who came to read the talk should not have to scroll a
     long citation list to find the door out, and the user who
     came for the citations has the list directly underneath.
  8. The fallback caption, when the fallback form applies
     (§4.4.1) — 8dp below the button.
  9. 24dp gap.
  10. **Section header:** verbatim `Scriptures cited`, style
      `WwType.refLabelOnDark` (13sp w600 `goldBright` on `stage`
      = **10.94:1**, pass) — the dark-surface peer of the sheet's
      `refLabel` header, so "the verses" reads as the same kind of
      section on both surfaces.
  11. 8dp gap.
  12. **Scripture rows** (§4.4.2), 8dp gaps between rows.
  13. 16dp gap after the last row.
  14. **The non-Bible-citations caption** (§4.4.3), verbatim,
      `captionOnDark` on `stage` (**6.92:1**, pass).
  15. 8dp gap.
  16. **The attribution line** (§5), verbatim, `captionOnDark` on
      `stage` (**6.92:1**, pass).
  17. No trailing spacer beyond the ListView's 16dp bottom padding
      (the tab bar is in flow; no clearance is owed, run-7 §1.2).

#### 4.4.1 Read in Gospel Library — the outbound action

Construction: a full-width `ElevatedButton`, built exactly like
the app's shipped gold primary actions (New profile; the
end-of-book Open button): `goldBright` fill, `WwRadius.chip`
radius, `minimumSize: Size.fromHeight(WwSpace.minTarget)` (≥48dp
high, full content width), label in `WwType.goldButtonLabel`
(`onGold` on `goldBright` = **9.71:1**, normal text, pass), with a
leading `Icons.open_in_new` glyph, 18dp, in `onGold` on the
`goldBright` fill = **9.71:1** (meaningful icon, pass), 8dp
icon-to-label gap. The glyph is mandatory: it is the non-color,
non-text cue that this control *leaves the app* (lesson 17 applied
to navigation), and it matches the glyph the sheet already uses
for "opens somewhere else."

The control has **two forms**, and the dataset's link data decides
which renders. A talk has either a per-talk link or it does not;
there is no third state and no disabled state.

**Form A — per-talk link exists.** Label (verbatim):

> Read in Gospel Library

Behavior: opens the talk's own page on churchofjesuschrist.org in
the system's external handling (the Gospel Library app when
installed, the browser otherwise). Semantics label:
`Read {Talk title} in Gospel Library, opens external app or
website` (button). The visible label is short because the title
directly above the button supplies the object; the semantics label
carries the full destination because an icon-bearing external
control must name where it goes (lesson 25).

**Form B — no per-talk link; conference-level fallback.** Some
older talks have no per-talk link; the dataset supplies the
conference's link instead. The control must not wear Form A's
label — a button that says "Read in Gospel Library" and lands on
a conference index has promised the talk and delivered a listing.
Label (verbatim):

> Open this conference in Gospel Library

And directly beneath it (8dp gap, step 8 of §4.4's order), one
caption, `WwType.captionOnDark` (**6.92:1** on `stage`, pass),
verbatim:

> This talk has no direct link, so this opens its conference in Gospel Library.

Semantics label: `Open the {Month} {Year} conference in Gospel
Library, opens external app or website` (button). The caption is
not optional decoration: it renders in every Form B instance, and
its absence is a gate Blocker — it is the difference between a
fallback and a misrepresentation.

**No-link rule:** if a talk has neither a per-talk link nor a
conference link, the button **does not render**, and in its place
(§4.4 step 7's position) one caption renders, `captionOnDark`,
verbatim:

> This talk is not linked in Gospel Library.

A dead button is prohibited; a missing button with no explanation
would read as a bug. This caption is a statement of the data's
limits, in the data's place.

**Launch failure:** if the external open itself fails (no handler,
OS refusal), the feedback is one SnackBar built to the run-6 §2.8
standard, verbatim copy: `Could not open Gospel Library.` —
`backgroundColor: surfaceHigh`, floating, `WwRadius.chip` shape,
content in `bodyOnDark` (`navInk` on `surfaceHigh` = **14.27:1**,
pass), framework-default duration, no action. A silent failed tap
is a dead control by another name.

**Amendment — founder correction, Oct 14, 2026 (run-8 fix round;
decision record
`team/memory/decisions/2026-10-14-conference-talk-routing-citation-index.md`).**
The founder's screenshot of Gospel Library's own conference
archive shows it bottoming out at the "1971–1979" bucket — nothing
before 1971 exists there — so Form B's conference-level Gospel
Library landing cannot serve the pre-1971 talks the layer exists
to surface. Founder, verbatim: "We should still have the talks
that go all the way back in our app, you just can't open them in
Gospel Library. You have to open them in the Citation Index."
§4.4.1 is therefore amended:

- **The dataset does not shrink.** All 4,964 talks back to April
  1942 stay. This is a link-routing change only, and routing is
  **data-driven per talk, never a hard-coded year cutoff**.
- **Form C — no per-talk Gospel Library link, Index page
  recorded.** The talk's own page in the Scripture Citation Index
  (scriptures.byu.edu; the pipeline's new `x` field, recorded from
  the index's conference pages) replaces Form B wherever an Index
  talk URL exists. Label (verbatim, copy C-25):

  > Read in Citation Index

  Semantics label: `Read {Talk title} in the Scripture Citation
  Index, opens external app or website` (button). No caption: the
  label promises the talk at a named destination and delivers
  exactly that. Launch failure uses the same snackbar
  construction with copy C-26: `Could not open the Citation
  Index.`
- **Form B is residual only**: it renders solely when a talk has
  a conference-level Gospel Library link and NO Index page. In
  the shipped dataset that set is empty (routing counts:
  per-talk Gospel Library 3,014 · Citation Index 1,950 · residual
  Form B 0 · neither 0).
- **Form A is unchanged**, and it wins over Form C when both
  links exist. The no-link caption (C-19) still renders for a
  talk with neither a Gospel Library link nor an Index page.
- Construction, glyph, contrast, and ≥48dp rules of §4.4.1 apply
  to Form C unchanged (same shipped gold primary action).

#### 4.4.2 Scripture rows

Each row is one distinct Bible verse the talk cites, built exactly
like a My Notes row (the shipped dark scripture-row pattern):
`Material(surface, WwRadius.row)` + `InkWell`, `Container(
minHeight: 48, padding: horizontal 12, vertical 8)`, whole row is
the tap target:

- Reference label: `WwType.refLabelOnDark` (13sp w600 `goldBright`
  on `surface` = **9.55:1**, pass) — e.g. `John 3:16`.
- 2dp micro-gap.
- Snippet: the verse's text in the **active translation** (KJV or
  WEB, the app's own text — §1.1), `WwType.bodyOnDark` (`navInk`
  on `surface` = **15.29:1**, pass), `maxLines: 3`,
  `TextOverflow.ellipsis` — the shipped sheet snippet truncation.
  **The role mapping is a ruling, stated so it is never "fixed"
  back:** `WwType.snippet` is a paper role (its color is `ink`);
  `ink` on `surface` computes **1.05:1** and any use of it on this
  dark view is a Blocker (Flag F-2). On dark, the snippet's role
  is `bodyOnDark`, exactly as My Notes renders verse text on dark.
- Trailing chevron: `Icons.chevron_right` 20dp `mutedOnDark` on
  `surface` (**6.03:1**, pass), vertically centered against the
  text column — in-app navigation takes the disclosure chevron;
  the external glyph belongs only to §4.4.1.
- **Order — JUDGMENT:** canonical Bible order (book, then chapter,
  then verse), the My Notes precedent: every scripture list in
  this app reads in canon order, so a user scanning two lists
  meets one order. The talk's own argument order is a property of
  its text, which this app does not host and does not reconstruct.
- **One row per distinct verse.** A cited range renders each verse
  in the range as its own row with its own snippet (verse
  granularity is the app's citation unit everywhere, criterion
  record). A chapter-only citation (the margin the research
  recorded: a tiny fraction of citations name a whole chapter)
  renders one row whose label is the chapter reference (`{Book}
  {Chapter}`) and whose snippet is that chapter's verse 1 in the
  active translation; its tap opens the chapter at its top. The
  label never invents a verse number the citation does not have.
- **Tap:** opens the reader at that verse through the shell's one
  open-chapter procedure (run-7 §7.4) — same-screen jump in the
  active reading screen, switch to the Screens tab, flash and
  land per the shipped mechanism. The Library stack is left
  exactly as it was underneath, talk view included (the shipped
  grid-tap discipline).
- Semantics per row: `Open {Reference}` (container, button) — e.g.
  `Open John 3:16`. Gate-asserted.
- **Safety empty state:** a talk view reached with zero Bible
  citations (unreachable through the lists by §4.3's rule;
  reachable if the sheet's data and the browse data ever disagree)
  renders, in place of the rows, one caption `captionOnDark`,
  verbatim: `No Bible verses are listed for this talk.` The
  non-Bible caption and attribution still render below it — the
  honesty copy does not depend on the list being non-empty.

#### 4.4.3 The non-Bible-citations caption — exact text and placement

A talk's citations do not end at the Bible, and a Bible-only list
presented without a word would silently under-represent every talk
in the browse. The caption below is **mandatory on every talk
view**, in the position §4.4 step 14 fixes (directly after the
scripture list, before the attribution), in `captionOnDark`,
left-aligned, full content width. Verbatim:

> This list shows Bible citations only. The talk may also cite the Book of Mormon, Doctrine and Covenants, Pearl of Great Price, and other sources, which this Bible app does not list.

The wording is deliberately **"may also cite"**: it is true of
every talk (it claims no specific non-Bible citation for a talk
whose record we do not show) while still telling the user, on
every talk, that the list above it is a Bible-filtered view of a
larger citation record. Substituting a per-talk enumeration of
non-Bible works would require data this spec does not display and
is out of scope; softening or dropping the caption is a Blocker.

The sheet (§3) carries **no** equivalent caption, by design: its
section answers "which talks cite *this verse*" — a question about
a Bible verse, where no under-representation arises. The caption
belongs exactly where a talk's citation record is presented as a
list: the talk view.

### 4.5 Back behavior and breadcrumb (whole branch)

- **Back:** each level's back `IconButton` (tooltip `Back`, the
  shipped library bar pattern) and system back pop **one level**:
  talk view → its talks list → conferences list → Library root.
  The reader opened from a scripture row is not in this stack (§7.4
  switches tabs), so back from the reader follows the reader's own
  shipped contract, untouched by this run.
- **Tab re-tap:** re-tapping the Library tab pops the Library
  navigator to its root (shipped shell rule) — conference routes
  pop with everything else; no special case.
- **Breadcrumb:** every level below the root carries the shipped
  title-button breadcrumb (`PopupMenuButton`, `color:
  surfaceHigh` set on the widget, `WwRadius.chip` shape, items
  ≥48dp high, item text `controlLabel` — `navInk` on `surfaceHigh`
  = **14.27:1**, pass; the current item in `mutedOnDark` —
  **5.63:1** on `surfaceHigh`, pass — with the shipped check icon).
  Menu contents, root first: conferences list → [`Library`,
  current]; talks list → [`Library`, `General Conference`,
  current]; talk view → [`Library`, `General Conference`,
  `{Month} {Year}`, current]. Selecting a level pops the Library
  stack to that level. The current level is a label, never a
  control (shipped rule). Menu presentation sets every property
  explicitly (lesson 20), as the shipped Library menus already do
  — no new menu construction is introduced.

---

## 5. ATTRIBUTION — EXACT TEXT AND PLACEMENT

The citation facts in this layer come from the Scripture Citation
Index, and the founder's method ruling keeps attribution in the app
wherever its facts inform the data. Attribution text (verbatim,
one Text wherever it appears):

> Citation facts are from the Scripture Citation Index (scriptures.byu.edu), compiled by Richard C. Galbraith and Stephen W. Liddle.

Placement — **both**, binding:

1. **Talk view footer** — §4.4 step 16: below the non-Bible
   caption, 8dp gap, `captionOnDark` on `stage` (**6.92:1**, pass).
   The talk view is where citation facts are consumed one talk at
   a time; its footer is where this app already puts provenance
   class copy (the sheet's data is OpenBible/TSK, the talk view's
   is the Index).
2. **Conferences list footer** — after the last conference row in
   §4.2's ListView, a 16dp gap, then the same Text in
   `captionOnDark` on `stage` (**6.92:1**, pass). The conferences
   list is where the user first meets the dataset as a dataset;
   provenance belongs at the collection's root, not only at its
   leaves.

The attribution is **plain text, not a control**: it is not
tappable, carries no link styling, no gold, no underline, and no
semantics decoration. Making it a link would add an un-audited
external destination; the founder's ruling requires attribution,
not a referral. It does not appear on the talks list (its parent
and its child both carry it; a third repetition is noise), nor in
the connections sheet (the sheet's talk rows lead to the talk view,
which carries it — one tap away, at the surface where the facts
are listed), nor in the Profiles section (a settings surface is
not a data surface; the toggle's copy is governed by §2.3).

---

## 6. CONSOLIDATED EXACT COPY (verbatim — any deviation fails the gate)

| # | Surface | Text |
|---|---|---|
| C-1 | Profiles section header | `General Conference` |
| C-2 | Profiles explanatory copy | `Conference talks are not stored in this app. When this is on, you can see which talks cite a verse, browse talks in the Library, and open each talk in Gospel Library or the Citation Index.` |
| C-3 | Toggle row title | `Show conference talks` |
| C-4 | Toggle row subtitle | `Verse connections and the Library browse` |
| C-5 | Sheet section header | `Conference talks` |
| C-6 | Sheet speaker line template | `{Speaker} · {Month} {Year}` |
| C-7 | Sheet empty line | `No conference talks are recorded for this verse.` |
| C-8 | Library root tile title | `General Conference` |
| C-9 | Library root tile caption template | `{N} conferences · {M} talks` (shipped pluralization) |
| C-10 | Conferences intro caption | `Newest first. Talk counts include only talks that cite the Bible.` |
| C-11 | Conference row title template | `{Month} {Year}` |
| C-12 | Conference row subtitle template | `{M} talks` / `1 talk` |
| C-13 | Talk row subtitle template | `{Speaker} · {K} scriptures` / `1 scripture` |
| C-14 | Talk view conference line template | `{Month} {Year} General Conference` |
| C-15 | Scripture section header | `Scriptures cited` |
| C-16 | Gospel Library button, per-talk link | `Read in Gospel Library` |
| C-17 | Gospel Library button, conference fallback | `Open this conference in Gospel Library` |
| C-18 | Fallback caption | `This talk has no direct link, so this opens its conference in Gospel Library.` |
| C-19 | No-link caption | `This talk is not linked in Gospel Library.` |
| C-20 | Launch-failure snackbar | `Could not open Gospel Library.` |
| C-21 | Non-Bible-citations caption | `This list shows Bible citations only. The talk may also cite the Book of Mormon, Doctrine and Covenants, Pearl of Great Price, and other sources, which this Bible app does not list.` |
| C-22 | Attribution | `Citation facts are from the Scripture Citation Index (scriptures.byu.edu), compiled by Richard C. Galbraith and Stephen W. Liddle.` |
| C-23 | Talks-list safety empty state | `No talks are listed for this conference.` |
| C-24 | Talk-view safety empty state | `No Bible verses are listed for this talk.` |
| C-25 | Citation Index button (Form C, amended §4.4.1) | `Read in Citation Index` |
| C-26 | Citation Index launch-failure snackbar | `Could not open the Citation Index.` |

Month names are the full `April` / `October`. No copy in this run
uses "GC", claims complete coverage of any conference or of the
Index, or states a count it does not compute from the dataset at
render time.

---

## 7. SEMANTICS — MASTER TABLE (lesson 25)

Every control in this run, with the exact label assistive tech must
hear. Every row requires a **semantics-tree assertion in the widget
tests** (`find.bySemanticsLabel` or the equivalent flag check);
a requirement without an assertion is not real (lesson 25), and
removing the container or the identifying part of any label must
fail its test.

| Control | Semantics | Exact label / flags |
|---|---|---|
| Profiles toggle (row + switch, one node) | container, toggled flag = state | Label `Show conference talks`; state from the `toggled` flag only |
| Library root conference tile | button | `General Conference, {N} conferences, {M} talks` |
| Conferences list row | container, button | `Open {Month} {Year} conference, {M} talks` |
| Talks list row | container, button | `Open talk: {Talk title}, by {Speaker}` |
| Sheet talk row | container, button | `Open talk: {Talk title}, by {Speaker}, {Month} {Year}` |
| Talk view scripture row | container, button | `Open {Reference}` (e.g. `Open John 3:16`; chapter-only: `Open {Book} {Chapter}`) |
| Gospel Library button, Form A | button (the button's own label, extended) | `Read {Talk title} in Gospel Library, opens external app or website` |
| Gospel Library button, Form B | button | `Open the {Month} {Year} conference in Gospel Library, opens external app or website` |
| Citation Index button, Form C | button (the button's own label, extended) | `Read {Talk title} in the Scripture Citation Index, opens external app or website` |
| Back buttons (all browse levels) | shipped pattern | Tooltip `Back` (unchanged) |
| Breadcrumb title buttons | shipped pattern | Tooltip `Breadcrumb` (unchanged); current item is not a control |

The two Gospel Library forms have **different** semantics labels,
as they have different visible labels and different destinations —
assistive tech must never hear Form A's promise on a Form B
control.

---

## 8. MOTION AND REDUCED MOTION

| Surface / action | Normal motion | Reduced motion (`MediaQuery.disableAnimations`) |
|---|---|---|
| Browse pushes (root → conferences → talks → talk view) and the sheet-row push into the talk view | `WwPageRoute`: 300ms slide from the right, `easeOut` in / `easeIn` back, **no fade** (audit §8, shipped) | The route's own check renders the final state instantly (zero duration) — shipped behavior, verified present in the new routes' construction, not re-implemented |
| Connections sheet opening | Stock sheet entrance governed by `wwSheetAnimationStyle(context)` (shipped) | Zero-duration style from the same helper. Calling `showModalBottomSheet` for this sheet without the helper is a Blocker |
| Toggle flip; layer appearing/disappearing in sheet and Library | **No app-authored animation of any kind.** No `AnimatedSize`, `AnimatedSwitcher`, fade, or stagger on layer content: the switch's state change and the surfaces' next render are the whole transition | Identical — there is no animation to suppress, which is the point |
| Switch thumb/track | Framework switch animation only; no custom duration or curve is set anywhere in this run | Framework behavior; app content never depends on the thumb animation completing |
| Gospel Library launch; snackbar | System surface / framework default snackbar behavior; no custom duration (§4.4.1) | No app animation involved; the snackbar's text is static and fully legible regardless of entrance motion |
| Lists (all browse levels, talk view) | No entrance animation, no programmatic scroll animation is introduced | N/A — nothing to check, and the gate verifies nothing was added |

No duration outside `WwMotion`'s allowed set appears in this run.
No fade appears on any push in this run.

---

## 9. COMPUTED CONTRAST — MASTER TABLE

All ratios computed by me from token hexes (method note). Classes:
normal text ≥ 4.5:1; meaningful icons ≥ 3.0:1. Every pair below
passes its class. Pairs marked ✗ are **prohibitions** — the
computation that forbids a tempting substitution.

| Element | Foreground | Effective surface | Ratio | Class / verdict |
|---|---|---|---|---|
| Profiles header `General Conference` (`selectionTitle`) | `goldBright` #E8B33C | `stage` #000000 | **10.94:1** | Normal text — pass |
| Profiles explanatory copy (`captionOnDark`) | `mutedOnDark` #9A947F | `stage` | **6.92:1** | Normal text — pass |
| Toggle row title (`controlLabel` w600) | `navInk` #F2EAD8 | `surface` #14141C | **15.29:1** | Normal text — pass |
| Toggle row subtitle (`captionOnDark`) | `mutedOnDark` | `surface` | **6.03:1** | Normal text — pass |
| Toggle leading icon (`menu_book`, 20dp) | `goldBright` | `surface` | **9.55:1** | Meaningful icon — pass |
| Switch ON: thumb `onGold` on track `goldBright`; check glyph `goldBright` on the `onGold` thumb | #161300 / #E8B33C | #E8B33C / #161300 | **9.71:1** | Meaningful element / icon — pass |
| Switch ON: track `goldBright` against row | #E8B33C | `surface` | **9.55:1** | Meaningful boundary — pass |
| Switch OFF: thumb `mutedOnDark` on track `surfaceHigh` | #9A947F | #1B1B24 | **5.63:1** | Meaningful element — pass |
| Sheet section header `Conference talks` (`refLabel`) | `goldTextOnPaper` #956D09 | `paper` #FFFDF8 | **4.62:1** | Normal text — pass |
| Sheet talk title (`bodyOnPaper` w600) | `ink` #1A1A1A | `paper` | **17.12:1** | Normal text — pass |
| Sheet speaker line (`captionOnPaper`) | `mutedOnPaper` #7A7466 | `paper` | **4.57:1** | Normal text — pass |
| Sheet empty line (`captionOnPaper`) | `mutedOnPaper` | `paper` | **4.57:1** | Normal text — pass |
| Library root tile title (`selectionTitle`) | `goldBright` | `surface` | **9.55:1** | Normal text — pass |
| Library root tile caption (`captionOnDark`) | `mutedOnDark` | `surface` | **6.03:1** | Normal text — pass |
| Root tile / row chevrons (20dp) | `mutedOnDark` | `surface` | **6.03:1** | Meaningful icon — pass |
| Top-bar titles, browse (`screenTitle`) | `goldBright` | `nav` #0B0B10 | **10.23:1** | Normal text — pass |
| Breadcrumb menu item text (`controlLabel`) | `navInk` | `surfaceHigh` | **14.27:1** | Normal text — pass |
| Breadcrumb current item (`mutedOnDark`) | #9A947F | `surfaceHigh` | **5.63:1** | Normal text — pass |
| Conferences intro caption (`captionOnDark`) | `mutedOnDark` | `stage` | **6.92:1** | Normal text — pass |
| Conference / talk row titles (`controlLabel` w600) | `navInk` | `surface` | **15.29:1** | Normal text — pass |
| Conference / talk row subtitles (`captionOnDark`) | `mutedOnDark` | `surface` | **6.03:1** | Normal text — pass |
| Talk title (`selectionTitle`) | `goldBright` | `stage` | **10.94:1** | Normal text — pass |
| Talk speaker line (`bodyOnDark`) | `navInk` | `stage` | **17.54:1** | Normal text — pass |
| Talk conference line, fallback caption, no-link caption, non-Bible caption, attribution (`captionOnDark`) | `mutedOnDark` | `stage` | **6.92:1** | Normal text — pass |
| `Scriptures cited` header (`refLabelOnDark`) | `goldBright` | `stage` | **10.94:1** | Normal text — pass |
| Scripture row reference (`refLabelOnDark`) | `goldBright` | `surface` | **9.55:1** | Normal text — pass |
| Scripture row snippet (`bodyOnDark`) | `navInk` | `surface` | **15.29:1** | Normal text — pass |
| Gospel Library button label (`goldButtonLabel`) | `onGold` | `goldBright` fill | **9.71:1** | Normal text — pass |
| Gospel Library button glyph (`open_in_new`, 18dp) | `onGold` | `goldBright` fill | **9.71:1** | Meaningful icon — pass |
| Launch-failure snackbar text (`bodyOnDark`) | `navInk` | `surfaceHigh` | **14.27:1** | Normal text — pass |
| ✗ `snippet` role (`ink`) reused on dark (talk view) | `ink` #1A1A1A | `surface` | **1.05:1** | **PROHIBITED** — §4.4.2 maps snippets on dark to `bodyOnDark` |
| ✗ `goldBright` as text on paper (sheet) | #E8B33C | `paper` | **1.89:1** | **PROHIBITED** — sheet gold text is `goldTextOnPaper` only |
| ✗ `gold` as small text on paper (sheet) | #B8860B | `paper` | **3.20:1** | **PROHIBITED** for text (lesson 13: fills/large/icons only) |
| Row dividers on paper (`line`) / browse hairlines (`borderDarkSoft`) | — | — | 1.33:1 / decorative | Exempt — hairlines carrying no meaning alone (audit §2) |

Reused audited patterns, stated explicitly as the brief requires:
the toggle row is the run-6 Backup row; the browse rows are the
shipped profile/My Notes rows; the root tile is the shipped
testament tile; the talk-view scripture row is the My Notes row;
the Gospel Library button is the shipped gold primary action (New
profile / end-of-book); the snackbar is the run-6 §2.8 construction;
the sheet section is the shipped Connections section. No surface in
this run introduces a foreground/background pair that is not either
(a) already shipped in one of those patterns, or (b) tabulated above
from my own computation — the switch's ON/OFF pairs and the
attribution/caption lines on `stage` are the only genuinely new
pairings, and both are in the table.

---

## 10. FLAGS — WHERE THE FEATURE AS DESCRIBED COULD NOT MEET THE AUDIT

- **F-1 — Brief premise: "Profiles already hosts Translation."**
  It does not (§0). Not a design violation, a record correction:
  the toggle's placement is ruled on the real surface. No fix is
  required of Maren; Silas owns the brief wording going forward.
- **F-2 — The tempting snippet reuse fails by 3.45 points.**
  Reusing `WwType.snippet` (ink) for talk-view snippets on dark
  computes **1.05:1** — a Blocker if built. **Fix required, and
  specified:** §4.4.2 maps dark snippets to `bodyOnDark`
  (15.29:1), the My Notes precedent. Any `snippet` role appearing
  on a dark surface in this diff fails the gate on sight.
- **F-3 — Gold on the paper sheet.** The sheet's new header and
  rows sit on `paper`, where the dark-surface golds fail:
  `goldBright` text = **1.89:1**, `gold` small text = **3.20:1**.
  **Fix specified:** the sheet uses the paper gold law throughout
  (`refLabel` / `goldTextOnPaper`, 4.62:1), exactly as the shipped
  Connections section does. `refLabelOnDark` appearing inside the
  sheet is a Blocker.
- **F-4 — No `switchTheme` exists; a stock switch is an unexamined
  default** (lesson 20). Material's default track/thumb colors were
  never audited against these tokens and several sit outside the
  palette entirely. **Fix specified:** §2.4.1 sets every switch
  color from tokens, in both states, with computed pairs. A switch
  property left to the theme in this diff fails the gate.
- **F-5 — The fallback link, as described, is one label away from
  a misrepresentation.** "Read in Gospel Library" over a
  conference-level link promises the talk page. **Fix specified:**
  Form B's distinct label (C-17), mandatory caption (C-18), and
  distinct semantics label (§7). Shipping Form A's label on a
  conference link is an honesty Blocker, not a copy nit.
- **F-6 — Coverage claims the data cannot yet cash.** The research
  records Index coverage from 1942, but this run's dataset is
  assembled under the founder's method limits and its shipped
  coverage is whatever was honestly reached. Any UI text stating
  or implying a year range or completeness ("all conferences
  since 1942") would outrun the data. **Fix specified:** every
  count in this run is computed from the loaded dataset at render
  time (§4.1), no coverage copy exists anywhere (§6), and §4.2's
  intro caption scopes the counts to Bible-citing talks. If the
  data package later verifies a coverage claim, the copy to carry
  it comes back through me.
- **F-7 — Nothing else in the feature as described violates the
  law.** The toggle, the sheet section, the drill-down branch, and
  the outbound action all resolve to existing audited tokens,
  roles, radii, and motion. The risks in this run are the default
  traps above (stock switch, role reuse across the paper/dark
  boundary, label honesty) — each pre-empted by an explicit
  requirement in this spec.

---

## 11. GATE CHECKLIST — THE DIFF WILL BE AUDITED AGAINST EVERY ITEM

**Global / OFF contract**
1. With the preference unset, false, or corrupt, the app renders
   exactly as shipped: existing suites pass unmodified, and a
   widget test proves the sheet contains no `Conference talks`
   text and the Library root contains exactly two tiles.
2. Preference key is `ww_conference_layer`; a toggle writes it at
   tap time; no profile, translation, or screen state is read or
   written by the layer's state code.
3. No new token, `WwType` role, radius, or duration in the diff;
   no `TextStyle` literal and no color-changing `copyWith` in new
   code (the §3.2 weight-only exception excepted).

**Toggle (§2)**
4. Section order and spacing exactly per §2.2; copy verbatim per
   C-1…C-4; Backup section unchanged and still last.
5. Row = Backup-row construction; whole row toggles; leading icon
   `menu_book` 20dp `goldBright`; targets ≥48dp high, full width.
6. Switch colors exactly per §2.4.1 in both states, every property
   set on the widget (no theme reliance); ON thumb carries the
   check glyph; no disabled state exists.
7. Semantics: one toggled node labeled `Show conference talks`,
   asserted in tests in both states (§2.5).

**Sheet (§3)**
8. OFF rendering identical to shipped; ON adds exactly one section
   below Connections, inside **one** scroll region; no nested
   scrollable lists; sheet construction otherwise shipped
   (paper, `WwRadius.sheet`, `wwSheetAnimationStyle`).
9. Header verbatim C-5 in `refLabel`; rows per §3.2 (48dp floor,
   title wraps uncapped, speaker template C-6, dividers as
   shipped, **no trailing control on any talk row**).
10. Ordering: year descending, October before April, dataset
    session order within a conference — asserted by a test with
    same-year April/October fixtures; duplicate citations of one
    verse by one talk render one row.
11. Empty state: header + C-7 in `captionOnPaper`, present whenever
    ON and no talks cite the verse; absent whenever OFF.
12. Row tap closes the sheet and lands on the talk view with its
    conference's talks list beneath it on the Library stack;
    row semantics per §7, asserted.

**Browse (§4)**
13. Root tile (ON only, dataset non-empty): testament-tile
    construction verbatim in kind; caption counts computed from
    the dataset at render time; no coverage/year copy anywhere in
    the branch.
14. Conferences list: intro caption C-10 verbatim above the first
    row; inclusion and ordering rules (§4.2) test-asserted; row
    anatomy, gaps (16 intro, 8 between rows), and semantics per
    §4.2/§7.
15. Talks list: inclusion rule (≥1 Bible citation) test-asserted;
    subtitle counts equal the talk view's row counts for the same
    talk; session order preserved.
16. Talk view: body order exactly per §4.4 steps 1–16; all copy
    verbatim (C-14, C-15, C-21, C-22 in their fixed positions);
    scripture rows per §4.4.2 (canonical order, distinct verses,
    range/chapter-only handling, 3-line snippets in `bodyOnDark` —
    zero occurrences of the `snippet` role on this dark view).
17. Gospel Library action: gold-primary construction, ≥48dp,
    `open_in_new` 18dp `onGold`; Form A / Form B / no-link render
    exactly per §4.4.1 with verbatim labels and captions (C-16…
    C-19) and distinct semantics labels (§7); a Form A label on a
    conference link fails the gate as an honesty Blocker; launch
    failure produces the C-20 snackbar in the run-6 construction.
18. Back pops one level per level; breadcrumb menus per §4.5
    (explicit `surfaceHigh` color, `WwRadius.chip`, ≥48dp items,
    current item non-tappable); tab re-tap pops the branch with
    the rest of the Library stack.
19. Attribution C-22 appears verbatim in exactly the two §5
    placements, as plain non-tappable text.

**Motion, contrast, process**
20. Reduced motion: pushes and the sheet verified under
    `disableAnimations` by test; no new animation widget, duration,
    curve, or fade anywhere in the diff (§8 table).
21. Every foreground/background pair in the final rendered states
    re-computes from the diff's actual tokens to §9's values. A
    pair that differs from the table means the diff differs from
    the spec — Blocker until reconciled.
22. Maren's verify is green and included in the package report:
    `flutter analyze` clean, `flutter test` green, `flutter build
    web --release` green.

Anything on this checklist that cannot be met as written comes
back to me **before** merge, with numbers. A design that fails its
own spec does not reach the founder — that is the gate, and it
does not bend for schedule.

— **Petra**, Design Auditor & QC, Woven Word Studio
