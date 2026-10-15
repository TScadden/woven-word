# Reader Theme Choice — spec (Silas, producer; founder ruling Oct 15, 2026)

Founder (verbatim): "Add a reader theme choice: paper or dark" — and
"Default should be dark though."

## 1. The setting

- A persisted reader theme, `ww_reader_theme` (`'paper'` / `'dark'`),
  owned by `ShellController` on the tradition pattern (run 9):
  `WwReaderTheme.fromStored` maps anything absent or unrecognized
  to **Dark**. Fresh installs and every existing install that has
  never stored a choice open the reader in Dark. Paper is one
  switch away, always.
- Placement (the studio's recorded call): a "Reader theme" section
  in Profiles, directly after "Your tradition" and before "Backup" —
  Dark first (it is the standard), then Paper, rows built exactly
  like the tradition rows (one semantics node each, radio + check).
  Honest copy: Dark — "Cream ink on black, gold accents. The
  standard reader." Paper — "The original cream paper page."
- PLUS an in-reader quick switch: a 48dp icon button in the reader
  top bar (both readers) whose icon names the target theme and
  whose semantics label states the current theme and the action
  ("Reader theme: Dark. Switch to Paper theme"). It writes through
  the same controller path as Profiles (the reader already owns its
  translation write; theme follows the same seam via
  `ReaderThemeHost`).

## 2. Scope — every reader surface follows the theme

Chapter-page reader (all three states, top chrome incl. the
translation toggle and its menus, label/end blocks, verse blocks,
verse toolbar, run-10 selection mode + selection bar, connections
sheet, note editor), the deuterocanon reader (top chrome, action
bar, selection menu, verse blocks, note editor), and the My Notes
note-editor sheet (the one reader surface living outside a reader;
the My Notes screen itself is app chrome and stays dark). Nothing
else re-themes: Home, Library, Profiles, sheets and dialogs outside
the reader keep the shipped dark chrome.

## 3. The palettes (tokens only in `lib/theme/ww_theme.dart`)

One `ReaderPalette` per theme carries every role a reader surface
uses; screens resolve roles from the palette, never from a raw
`WwColors` paper token. Paper palette values are the shipped
tokens, value-for-value — the paper reader renders identically.

Dark palette (computed before building, lesson 13):
- Page `surface` #14141C; chrome (top bar, deutero action bar)
  `nav` #0B0B10; body ink `navInk` #F2EAD8 (15.29:1 on surface);
  muted `mutedOnDark` (6.03:1 on surface); small gold text
  `goldBright` (9.55:1 on surface); hairlines `borderDarkSoft` on
  chrome, card/field borders `borderDark`; cards on the page
  (toolbar, selection bar, note editor) step UP to `surfaceHigh`
  (the shipped dark-dialog construction) with note fields stepping
  back down to `surface`.
- Dark highlight tints (new tokens; deep, saturated counterparts
  of the paper pastels, all carrying navInk body text ≥ 5.84:1):
  gold #6E560F, green #3E5A24, blue #2F4A6E, pink #6E3548,
  purple #4E3A66.
- Selected verse: tint when the verse is tinted (paper's own
  precedent — selected-over-same-tint shows zero fill difference
  there too; the 2dp outline carries selection, lesson 17), else
  `gold` #B8860B at 0.25 over the page (navInk 10.73:1). Outline
  `goldBright`: 9.55:1 against the page, 3.65:1 against the worst
  adjacent tint.
- Selection mode: overlay `gold` at 0.20 (worst stack — over the
  gold tint — navInk 4.94:1; handles goldBright 3.08:1 against that
  same stack, 9.55:1 against the page); handles and cursor
  goldBright.
- Verse number: goldBright at rest (9.55:1); on a tint or the
  selected fill it takes the ink role (navInk, 5.84–10.73:1) —
  goldBright on the gold tint computes 3.65:1 and fails the text
  band, exactly why paper switches the number to ink on tints.
- Connection dot and note icon: goldBright in every state (page
  9.55:1; on tints 3.65–5.16:1, icon band).

## 4. Behavior

- Switching is instant (no animation; reduced motion renders the
  same final state because there is no motion to reduce).
- Switching themes never touches user data: spans, notes,
  profiles, tradition, translation are byte-identical across a
  switch (theme is a view concern only).
- Both readers and every sheet resolve the theme at build/open
  time from the one stored choice; a change made in Profiles or
  by the quick switch is the same write.

## 5. Tests (brief-mandated)

Fresh state defaults to Dark (unit + shell + reader render);
stored choice survives relaunch; switching re-renders both
readers and every sheet surface (connections sheet, selection
bar, note editors, My Notes editor); per-theme render assertions
for span tints (block background = palette tint, body ink on
tint); a token-computed contrast gate for BOTH themes (body,
verse numbers, all five tints, selected composites, selection
overlay stacks, controls); 360dp at text scale 2.0 in both
themes with no overflow.
