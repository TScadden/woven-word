# Spec — Library live search (search fix package, Oct 15, 2026)

Founder report (verbatim): "Make sure when you search it shows
results while you type" — screenshot: "john" typed in the Library
field, the Old Testament / New Testament / General Conference
tiles unchanged.

## §1 Root cause (verified in code, library_tab.dart)

The Library root field is a **submit-only reference jumper**.
`onChanged` does nothing but clear the `_noMatch` flag; the only
action is `onSubmitted` → `_submit` → `BibleData.parseSearch` →
one chapter jump. No results model and no results UI exist; the
tile region renders unconditionally. Typing therefore changes
nothing on screen, and a bare book name ("john") has no visible
effect at all until a submit that was never hinted at.

## §2 Behavior

- 2.1 Results are a pure function of the field's current text +
  loaded data + layer states, derived synchronously at build.
  Every keystroke re-derives: no debounce, no submit step, no
  frame can show a previous query's results.
- 2.2 Empty or whitespace-only query → the shipped browse,
  structurally unchanged (tiles region + conference tile slot).
- 2.3 Non-empty query → results replace the tile region: groups
  BOOKS, CHAPTERS, TALKS in that order, each present only when
  non-empty. Group headers are the group name in the shipped
  section-header style (appSubtitle, uppercase).
- 2.4 All groups empty → the shipped no-match line, verbatim:
  "No match — try a book name and chapter, like John 3."
  (test STORE-4 pins this string; it now appears live.)
- 2.5 Field hint follows the layer: conference on →
  "Search books, chapters, talks…"; off →
  "Search books and chapters…". Hint copy never names a group
  that cannot appear.
- 2.6 Submit (keyboard search action) keeps its shipped jump
  meaning, resolved through the §3 model: the first CHAPTERS
  result when one exists; else, when the query carries no
  trailing number and BOOKS is non-empty, chapter 1 of the
  first book result; else nothing. (STORE-4's contract:
  "Genesis" → Genesis 1, "John 3" → John 3, gibberish → stays.)
  A submitted jump also keeps the shipped run-7 field
  contract: it CLEARS the field, so the root beneath the
  destination is the browse view (the shipped suite's NAV-3
  pins those tiles after a search jump + Library re-tap).
  Result-row taps are the other contract — they keep the
  query (§4). Amendment Oct 15, 2026: verification caught
  the dropped clear regressing NAV-3; restored.

## §3 Matching model (pure, lib/data/library_search.dart)

Normalize: trim, lowercase; "squashed" = whitespace removed.

- 3.1 BOOKS, core: the tradition's presented books
  (`CanonView.forTradition(...).bookOrder`, presentation order;
  Jewish = Tanakh order, Tanakh books only). A book matches when
  its display name contains the query or its squashed
  abbreviation starts with the squashed query.
- 3.2 BOOKS, deuterocanon: only when tradition is Catholic and
  the deuterocanon table is loaded; table order; same rule.
  Rows carry the Catholic grid's "· Deuterocanon" marker.
- 3.3 CHAPTERS: the query's trailing number is split with
  parseSearch's grammar (`^(.*?)\s+(\d+)$`). When a number
  exists, every §3.1/§3.2 book whose name starts with the book
  part or whose squashed abbreviation equals the squashed book
  part (parseSearch's rule) contributes that chapter when
  1 ≤ n ≤ its chapter count. **No clamping** — parseSearch
  clamps "John 99" to John 21; search never invents a chapter
  that does not exist, so "John 99" yields no CHAPTERS row.
- 3.4 TALKS: only when the conference layer is on (enabled +
  data loaded — the tile slot's exact conditions). Title or
  speaker contains the query. Order is ConferenceData's shared
  newest-first: year desc, October before April, dataset order.
- 3.5 Translations are never a search dimension. The model
  takes data + tradition + deuterocanon + conference as inputs;
  a null conference input yields no TALKS group, structurally.

## §4 Rows and navigation

All rows are the shipped `browseRow` construction (surface,
row radius, minHeight 48, whole row the target, one container
semantics node — lesson 25). All navigation pushes inside the
Library navigator over the root; the root's State (field text
included) persists underneath, so Back from any destination
returns to the live results for the same query.

- Book row: title = book name; subtitle = "N chapter(s)"
  (+ " · Deuterocanon" for §3.2). Label: "Open book: <name>".
  Tap → that book's chapter grid (shell `_pushChapterGrid`;
  §3.2 → the deutero chapter grid).
- Chapter row: title = "John 3" / "Tobit 3"; subtitle =
  "N verses" (+ " · Deuterocanon"). Label: "Open chapter:
  <title>". Tap → the reader at that chapter (deutero → the
  deutero reader at that chapter).
- Talk row: title = talk title; subtitle =
  "<speaker> · <conferenceLabel>" (the talks list's shape).
  Label: "Open talk: <title>, by <speaker>" (identical to the
  talks list). Tap → the talk view pushed directly
  (`_pushTalkView`) — NOT the stack-resetting sheet path
  (`openConferenceTalk`), which would destroy the search state
  underneath; that path keeps its own §4.5 behavior.

## §5 Wiring

LibraryRoot gains four optional callbacks: onOpenBook,
onOpenDeuteroBook, onOpenDeuteroChapter, onOpenTalk. A group
whose navigation callback was not supplied does not render
(never a dead row); CHAPTERS ride the pre-existing required
onOpenChapter. The shell wires all four. The results region
rebuilds on the layer states' notifications under the tile
slot's rule (ListenableBuilder over the first Listenable
state; in the shell both states are the one controller).

## §6 Gate

- Contrast from tokens: row title navInk on surface (15.29:1,
  theme-annotated pairing); subtitle mutedOnDark on surface —
  compute; group header mutedOnDark on stage — compute;
  chevron mutedOnDark on surface ≥ 3.0 (icon floor).
- Targets ≥ 48dp by construction (browseRow floor); rows are
  the whole target.
- Text scale 2.0: rows grow (48 is a floor), the list scrolls;
  gate pumps 2.0 with results up and asserts no overflow.
- No new animation; pushes ride WwPageRoute; reduced motion
  is the shipped behavior.
- Semantics: one node per row, §4 labels exact (asserted in
  tests by find.bySemanticsLabel).
