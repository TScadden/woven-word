# Library live search — ship report (search fix package)

Founder report (Tyson, Oct 15, 2026): "Make sure when you
search it shows results while you type" — he typed "john"
into the Library field and the screen still showed only the
static Old Testament / New Testament / General Conference
tiles.

## Root cause

The Library root's search field was **submit-only**. Its
`onChanged` did nothing but clear a no-match flag; the only
action in the widget was `onSubmitted` → `parseSearch` → a
single-chapter jump. No results model and no results UI
existed, so typing changed nothing on screen. (Verified in
`lib/screens/library_tab.dart`, `LibraryRootState`, pre-fix.)

## The fix (commit 004b236)

- **Model** — new pure file `lib/data/library_search.dart`.
  Results are a function of the field's current text + the
  loaded datasets + the layer states, derived synchronously
  at build: every keystroke re-derives, no debounce, no
  submit, no frame can show a previous query's results.
  Groups in order: **BOOKS** (name-contains or
  abbreviation-prefix matching, in the active tradition's
  presentation order — Jewish mode offers no New Testament
  books; deuterocanon books included under Catholic),
  **CHAPTERS** (parseSearch's reference grammar, every
  matching book contributes, an out-of-range chapter is no
  result — never clamped), **TALKS** (title/speaker match,
  newest first; the dataset enters the model only while the
  conference layer is on, so layer-off has no talks,
  structurally). Translations are not a search dimension.
- **UI** — the results replace the tile region under the
  field; an empty query renders the shipped browse path
  unchanged. Rows are the shipped browse-row construction
  (≥48dp, one semantics node each: "Open book: …",
  "Open chapter: …", "Open talk: …, by …"). The no-match
  state is the shipped line, verbatim, now shown live. The
  field hint names only the groups that can appear
  ("Search books, chapters, talks…" / "Search books and
  chapters…").
- **Navigation / back contract** — result taps push inside
  the Library navigator over the root (chapter grid, reader,
  deutero grid/reader, talk view via the direct push, not
  the stack-resetting sheet path), so Back returns to the
  root with the query and its live results intact. The
  keyboard search action keeps its shipped jump meaning via
  the model — and keeps the shipped run-7 field contract of
  clearing the field (the suite's NAV-3 pins the browse
  tiles after a search jump + re-tap; dropping the clear
  regressed NAV-3 in verification and was restored — spec
  §2.6 amendment).

## Gate

Petra: **PASS** (library-search-fix-gate.md). Contrast
computed from tokens: row title 15.29:1, subtitle 6.03:1,
group header 6.92:1, chevron 6.03:1, hint 5.63:1. Rows
≥48dp by construction; no overflow at text scale 2.0
(widget-tested); no new animation.

## Verification (Maren)

- `flutter analyze`: clean.
- New tests: 28/28 green (18 model unit tests; 10 widget
  tests — per-keystroke narrowing with no submit, chapters
  group + no-clamp, per-group navigation, query preserved
  on Back, layer on/off, Jewish scope, Catholic deutero
  scope, text scale 2.0).
- Full local suite on the package tree: 302/305. The 3
  failures are all `conference_shell_test.dart` tests
  failing with the ShellController used-after-dispose race
  — a HEAD defect: the same file fails identically on the
  pristine HEAD tree in the same environment (lesson 41
  baseline attached to the run log), and git confirms the
  package never touches those code paths. STORE-4 and NAV-3
  pass; shell_test.dart is fully green.
- Web release build: green.
- CI (branch `search-fix-verify`, workflow_dispatch):
  run **38793927825 — completed success** (analyze + full
  test suite + APK build on the clean runner).
- APK staged at `build-search-fix/woven_word_search_fix_20261015.apk`
  (32,010,573 bytes) from that run's artifact. Signer
  certificate SHA-256 parsed from the APK signing block:
  `05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11`
  — the pinned digest (parser validated byte-exact against
  run 10's APK first). The new code is in the binary
  (libapp.so carries the "Open book:" semantics label,
  new in this package).

## Landing note

Commit 004b236 (+ this report) sits on the pushed branch
`search-fix-verify`. The cherry-pick onto `main` waits for
the two sibling packages in flight in the shared tree
(run 11 Home sections, reader theme) to commit first:
`shell_screen.dart` and `LESSONS.md` are shared files and
their uncommitted work must land before this package's
hunks merge. On landing, this package's lessons (filed as
42–44 on the branch) renumber to the next free numbers —
the arch package took 42 in the meantime. The final-tree
CI run follows the landing push as usual.

## Payroll

Fix of a shipped feature — no new feature fee.
