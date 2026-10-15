# PETRA — DESIGN SPEC, BOARD RUN 10: TEXT-SELECTION HIGHLIGHTING (BINDING)

**From:** Petra, Design Auditor & QC
**To:** Maren, Lead Flutter Engineer (verbatim handoff, via Silas)
**Scope:** (1) press-and-hold text selection with a color action
bar in the chapter-page reader and the deuterocanon reader;
(2) the span data model + store v3 with per-translation highlights
AND notes; (3) migration of pre-run-10 data; (4) My Notes and the
Home notes card under per-translation visibility + canon dormancy;
(5) backup export/import carrying the new shape. Nothing else.

**Authorities:** TEAM.md; LESSONS.md (esp. #13 role-split tokens,
#16 audit every state, #17 the surface matrix and non-color cues,
#18 both bounds, #19 profiles are a store concern, #20 presentation
defaults, #22 validation is a gate in front of the parser, #23
specs persist as files, #33 controller lifetimes); the design law
(tabs-design-audit, Woven Word adaptation); the founder rulings
(`decisions/2026-10-15-highlights-notes-per-translation.md` and the
Oct 15 canon-dormancy clarification); the run-10 packet
(`decisions/2026-10-15-board-run-10-packet.md`).

**Method note:** every ratio below I computed from token hexes by
the audit §2 method. Thresholds: normal text ≥ 4.5:1; meaningful
icons/boundaries ≥ 3.0:1. **No new tokens, no new WwType roles, no
new radius, no new duration.** One new USE of an existing token:
the platform selection overlay is `hlGold` at 0.50 alpha (§3.3).

---

## 1. DATA MODEL (store v3)

### 1.1 Shapes

`UserData.version` becomes **3**. Per profile:

```json
{ "spans": { "kjv": [ {"v":"b0c1v1","s":0,"e":-1,"a":"","c":"gold"} ] },
  "notes": { "kjv": { "b0c1v1": "note text" } } }
```

- The translation key is `WwTranslation.name` (`kjv`, `web`,
  `jps`, `hebrew`, `webc`). Deuterocanon spans/notes live under
  `webc` — the only text that reader renders.
- A span: `v` canonical verse key (parseable by `parseVerseKey`,
  both bounds — lesson 18); `s` start offset ≥ 0; `e` end offset,
  either `-1` ("to the end of the verse") or `> s`; `a` the anchor
  text the user selected (provenance; may be empty ONLY for
  migrated spans, §1.3); `c` a valid `HlColor` key.
- Notes: per translation, verse key → text (empty-after-trim
  clears, as shipped).

### 1.2 Invariants (model-enforced, not caller-enforced)

Within one (profile, translation, verse): spans are **sorted by
start and never overlap**. All writes go through two operations:

- `applySpan(profile, t, span, verseText)` — subtract
  `[span.start, span.end)` from every existing span (trim/split,
  pure offset arithmetic; `e = -1` reads as +∞ and a surviving
  right-hand piece keeps `e = -1`), then insert. Anchor text of a
  trimmed piece is the corresponding slice of the source span's
  anchor when lengths agree, else `''` — offsets are the truth,
  the anchor is provenance.
- `clearSpanRange(profile, t, key, start, end)` — the subtraction
  alone.

Rendering resolves a span against the verse's actual text:
`(start, end == -1 ? text.length : end)`, both clamped into
`[0, text.length]`; a span that resolves empty renders nothing.
The model never throws on stored data (defensive parse drops
malformed spans: unparseable key, bad color, `s < 0`, `e == 0`,
`e < -1`, `e <= s` when `e != -1`, non-string anchor).

### 1.3 Migration (v1/v2 documents)

`UserData.fromJson` gains `{String legacyTranslation = 'kjv'}`.
Version < 3 documents carry profile-level `highlights`
(key → color) and `notes` (key → text) with no translation. On
parse: each legacy highlight becomes a full-verse span
`{v: key, s: 0, e: -1, a: '', c: color}` in the
`legacyTranslation` set; legacy notes land in the
`legacyTranslation` set. **No duplication into other sets.**
`UserDataStore.load` supplies the key from the stored translation
preference (`ww_translation`, read in the data layer — the
constant moves to `user_data.dart` as `translationPrefsKey` and
`ReaderScreen.translationKey` aliases it, one source of truth).
Migration is a pure function of the stored document: two loads
before any save produce the identical model; the first save
writes v3. `validateImport` takes the same parameter — a v1/v2
backup imports into the translation active at import; a v3
backup validates under the existing error classes (a version
above 3 is `newerVersion`, as shipped).

### 1.4 API (UserData / ProfileData)

- `spansFor(profile, t, key)` → the verse's spans, sorted.
- `fullVerseColor(profile, t, key)` → the color of a span whose
  range is `(0, -1)`, else null. (By §1.2 such a span is the
  verse's only span.)
- `applySpan`, `clearSpanRange`, `clearVerseSpans` (toolbar None).
- `note(profile, t, key)`, `setNote(profile, t, key, text)`,
  `notesFor(profile, t)` — canonical order exactly as shipped
  (book, chapter, verse; deutero indices sort after core books).
- `totalSpans`, `totalNotes` — across ALL profiles and ALL
  translations (backup counts; dormancy never touches storage).
- The old `highlight`/`setHighlight`/`notesFor(profile)`/
  `note`/`setNote` signatures are removed; every caller moves.

## 2. INTERACTION

### 2.1 Selection (both readers) — AMENDED at build (2026-10-15)

**Selection is a mode, entered by long-press.** As first written,
this section made the verse text an always-on `SelectableText.rich`;
the shipped pager tests proved that construction broken: on
Android, `SelectableText` installs a `TapAndHorizontalDragGesture
Recognizer` with eager victory on drag, which claims horizontal
swipes starting on text before the pager can — an F-2-class
regression on the app's most-used gesture. The built construction:

- The verse text is the shipped plain `Text` at rest. **Long-press
  on a verse enters selection mode for that verse only**: its text
  becomes `SelectableText.rich` (segments per §3.1); the verse
  toolbar, if open, closes — while selecting, the §2.2 bar is the
  surface.
- Inside the mode, platform behavior rules: a drag or a second
  long-press takes the exact words; the handles extend; double-tap
  takes a word. The selection never crosses the verse boundary.
- The mode exits on: a selection-bar write, a tap on any other
  verse (which proceeds as the shipped verse tap), the reader's
  outside-tap dismiss, or a page turn. (A tap on the selecting
  verse's own text places the cursor — platform behavior inside
  a selection session.) It adds NO rung to the run-7 back
  ladder.
- Outside the mode, every shipped gesture is untouched by
  construction: tap opens the verse toolbar, horizontal swipes
  page (including swipes starting on verse text — the brief's
  explicit test), in-page scroll is unchanged.

### 2.2 The selection action bar

`contextMenuBuilder` returns the app's own bar (the platform menu
never renders): a paper card (radius `WwRadius.sheet`, border
`line`, padding 8) anchored at the selection by the state's
`contextMenuAnchors`, holding ONE row: the five swatches (the
reader toolbar's exact `_swatch` construction and semantics
labels — 'Gold highlight', …, 48dp targets, 36dp circles), a
**Clear** action (icon `format_color_reset`, semantics 'Clear
highlight on selected text', 48dp) and **Copy** (icon `copy`,
semantics 'Copy selected text', 48dp) which copies via the
editable state and dismisses. (Amended at build: Clear and Copy
are icon buttons, not text labels — the 360dp layout budget,
LESSONS #37: five 48dp swatches + two 48dp actions + padding =
352dp; two text buttons cannot fit. The semantics labels carry
the names, per LESSONS #25.) A swatch reads `active` when one
span covers the whole selection in that color; Clear reads
enabled only when a span overlaps the selection.

- Choosing a color: hide the bar FIRST (the framework contract),
  then `applySpan` with the selection's offsets and the selected
  substring as anchor, in the CURRENT effective translation; the
  write exits selection mode (the verse widget is recreated via
  a generation key) — the applied tint is the feedback.
- Choosing Clear: `clearSpanRange` over the selection; hide and
  exit likewise.
- A collapsed (cursor-only) selection shows NO bar
  (`SizedBox.shrink`): the tap toolbar is the cursor-level tool.

### 2.3 The verse toolbar and the deutero action bar (verse scope)

Unchanged surfaces, new writes: the color row writes a FULL-VERSE
span `(0, -1, anchor = the verse's full text)` in the current
translation through `applySpan` (so a full-verse color replaces
any partial spans — the shipped "highlight the whole verse"
meaning). Tapping the active full-verse color again clears the
verse's spans; **None clears ALL of the verse's spans** in this
translation (the shipped None meaning, span edition). The note
button edits the current translation's note. Deutero: identical,
under `webc`.

## 3. RENDERING

### 3.1 Segments

The verse text renders as `TextSpan` segments from the disjoint
span walk: unspanned runs carry no background; spanned runs carry
`backgroundColor` = the span's tint token (`hlGold`/`hlGreen`/
`hlBlue`/`hlPink`/`hlPurple`). No stacked tints can occur (§1.2).

### 3.2 Block presentation (shipped construction, span edition)

- A verse with a full-verse span: the BLOCK carries the tint
  (shipped Material background) and the text renders WITHOUT
  segment backgrounds — byte-identical presentation to run 4.
- A verse with partial spans only: block background transparent
  (or the selected composite, §3.3); tints live in the text.
- Selected (flash/tap) state: the shipped composite —
  `hlGold @ 0.45` blended over the full-verse tint or paper —
  and the 2dp `goldTextOnPaper` outline, unchanged.
- Verse number and connection dot: the run-4/17 rule with
  "highlighted" read as "carries any span in this translation":
  gold roles only when NOT selected AND span-free; ink otherwise.
  The note icon reads the current translation's note only.

### 3.3 Computed audit (mine, from token hexes)

Text is `ink` #1A1A1A on every span surface:

| surface | ratio |
|---|---|
| ink on paper | 17.12 |
| ink on hlGold / hlGreen / hlBlue / hlPink / hlPurple | 13.25 / 12.98 / 12.04 / 12.34 / 11.92 |
| ink on selected composite (hlGold .45 over tint) | 12.41 – 13.25 |
| ink under selection overlay (hlGold .50 over tint or paper) | worst 12.48 |

All ≥ 4.5 — no token changes. `goldTextOnPaper` on the tints
computes 3.22–3.58 (< 4.5), which is why §3.2 keeps the shipped
ink rule for numbered spans. Tint-vs-paper (1.29–1.44) is a
background fill under audited text — the run-4 precedent; a
span's presence is additionally carried by its persistence and,
for notes, the note icon's non-color cue.

### 3.4 Selection chrome (both readers)

Wrap each reader's chapter pages in `TextSelectionTheme`:
`selectionColor` = `hlGold @ 0.50` (worst ink ratio 12.48, §3.3),
`selectionHandleColor` = `goldTextOnPaper` (4.62 on paper;
3.22–3.58 on tints — ≥ 3.0 meaningful-boundary band),
`cursorColor` = `goldTextOnPaper`. Reduced motion: selection
renders its final state (no animation exists in this feature);
sheets/dialogs keep the shipped helpers.

## 4. COPY (exact strings)

- My Notes header: `Notes in {profileName} · {translationLabel}`
  (e.g. "Notes in My Profile · KJV").
- My Notes, profile has notes but none are visible (all in other
  translations or dormant books): title `No notes to show here`;
  body: `Notes are saved per translation and shown for the books
  in your current tradition. Notes saved in another translation,
  or for a book outside this canon, are kept and return when you
  switch back.`
- My Notes, profile has no notes at all: the shipped empty state,
  unchanged.
- Profiles backup blurb becomes: `Export saves every profile —
  with every translation's highlights and notes — as one JSON
  file. Import replaces everything here with the contents of a
  backup file. Nothing leaves this device unless you export it.`
- Selection bar: labels per §2.2. No other copy changes.

## 5. DORMANCY (view rule only)

Predicate (in `tradition.dart`): `canonContainsBook(tradition,
data, bookIndex)` — core books: membership in
`CanonView.forTradition(tradition, data)`; book indices
≥ `DeuteroBook.bookIndexBase`: `tradition == catholic`.
A note/span is VISIBLE at a list surface iff its translation set
is the active translation AND its book passes the predicate.
Surfaces: My Notes (gains a `tradition` parameter from the
shell; standalone pumps default to `WwTradition.none`) and the
Home My Notes card (the shell's own count, same predicate, the
shell's current translation + tradition). Storage, backup,
export, import: NO filtering, ever — a tradition switch leaves
the stored document byte-identical (run 9's proof, re-asserted
in this run's tests at the model level).

## 6. TESTS (the gate reads these by name)

1. Store: per-translation isolation (span + note in KJV →
   invisible in WEB → intact on return); span overlap arithmetic
   (trim left, trim right, split, full-cover replace, clear
   range, `e = -1` survival); defensive drops; totals across
   translations.
2. Migration: a seeded v2 document + stored preference WEB →
   spans/notes in the `web` set only, full-verse spans `e = -1`,
   KJV set empty; a v1 document likewise; export of a migrated
   model is v3 and round-trips byte-stable.
3. Backup: v3 valid; v2 backup validates and migrates into the
   import-time translation; the 8 shipped malformed classes
   still change nothing (stored string byte-untouched).
4. Reader: long-press a word → bar appears, page does NOT turn;
   choose Gold → span persisted with the word's offsets and
   anchor; horizontal fling across text → page turns, no bar;
   span survives a relaunch (fresh store load + repump); span
   renders in the resting state and under the selected state
   (segment background asserted from the rendered TextSpan tree);
   toolbar full-verse color writes a `(0, -1)` span and swaps
   the block presentation; translation switch swaps visible
   spans and restores on return.
5. Deutero reader: selection + color writes a `webc` span;
   action-bar color writes a full-verse span.
6. Dormancy (the founder's three): (1) NT note (KJV) hidden
   under Jewish, present under Bible-only, stored bytes
   unchanged throughout; (2) deuterocanon note (WEBC) present
   under Catholic, hidden under Protestant, present again under
   Catholic; (3) composition — hidden by canon alone, hidden by
   translation alone, visible only when both clear.
7. Regressions: the shipped suites (toolbar, back ladder, pager,
   tradition, conference) stay green under the new APIs — update
   call sites, never delete assertions.

## 7. GATE

I re-derive every count from the artifacts (lesson 34): the
suite total, the migration fixture's span count, and the §3.3
table against the theme file. Any surface not in this spec stops
the build (lesson 23). The delivery states the founder's rule in
one plain sentence:

**"Your highlights and notes now belong to the translation you
made them in: switch translations and you see that translation's
set, switch back and yours are exactly where you left them."**
