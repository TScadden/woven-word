# PETRA — DESIGN SPEC, BOARD RUN 6 (BINDING)

**From:** Petra, Design Auditor & QC
**To:** Maren, Lead Flutter Engineer (verbatim handoff)
**Scope:** (1) Offset-model home scrolling — behavior only. (2) Export/import UI on Profiles.
**Authorities read before writing:** `team/TEAM.md`; `LESSONS.md` (esp. #13 role-split tokens, #16 audit every state, #17 non-color cues / surface matrix, #20 presentation defaults are traps); the design law (`tabs-design-audit/SKILL.md`, Woven Word adaptation per TEAM.md: `ww_theme.dart` tokens win, every mechanical rule applies); `ww_theme.dart`; `profiles_screen.dart`; `home_screen.dart`; decision record `2026-10-14-board-run-6-rulings.md`.

**Method note:** Every ratio below is computed by me from token hexes by the audit §2 method (composite to opaque, linearize sRGB, `L = 0.2126R + 0.7152G + 0.0722B`, ratio `(Llight+0.05)/(Ldark+0.05)`). No ratio is copied from a comment, a screenshot, or a prior gate. Thresholds: normal text ≥ 4.5:1, large text (≥24sp, or ≥19sp bold) ≥ 3.0:1, meaningful icons ≥ 3.0:1.

---

## PART 1 — OFFSET-MODEL HOME SCROLLING

### 1.1 The rule: behavior only, zero visual change

Nothing new renders. No rendering literal in `home_screen.dart` may change — no color, style, size, padding, gap, radius, order, or copy. If your diff touches a build-path styling literal on Home, the gate fails it on sight, regardless of test results. Internal, non-rendering changes (scroll controller use, removal or retention of `_bookKeys`, the model itself) are yours.

What must not drift, enumerated so there is no ambiguity about "visual":

- Scaffold `stage` background; top bar (`nav`, `WwSpace.topBarHeight` 56, `borderDarkSoft` bottom hairline, appTitle/appSubtitle, profile chip exactly as shipped).
- Tools row: 8dp vertical padding, 16dp screen margin, scope dropdown (`surfaceHigh`, `WwRadius.input`, 48 high), search field (theme fill, 48 high), 8dp gap.
- Mini-map: `stage` fill, bottom `borderDarkSoft` hairline, height `width × 500/1200`, `BoxFit.fill`, same image cache keys/density logic, same selection-layer painter.
- Selection panel: `surface` fill, 16dp padding on all sides, every child, style, and gap exactly as shipped.
- Section headers: `appSubtitle`, padding L16/T16/R16/B0, OT before book 0 and NT before book 39 in scope `all` only.
- Book sections: header padding L16/T16/R16/B8; book name `bodyOnDark` w600; chapter-count `captionOnDark`; chapter `Wrap` at 16dp horizontal padding, spacing 8, runSpacing 8.
- Chapter chips: 48×48, `WwRadius.row`, unselected `surface`/`bodyOnDark`, selected `goldBright` fill / `onGold` w700 label.
- Trailing `SizedBox(height: 24)` after the last sliver. Scroll physics untouched (no custom `physics:`), no scrollbar added, no overscroll change.

### 1.2 The model: exact by construction, or it does not ship

The model is a pure function of: current scope, current selection (the chapter whose panel, if any, will be present **after** the jump's own state change), viewport width, and the framework's text metrics at the current text scale. It sums, in render order, every component of the scroll content:

1. **Selection panel (conditional).** Present iff a chapter is selected in the post-jump state. Its height must be computed from its actual construction: 16 top padding + title row (the row's height is the max of the title/caption column and the 48dp clear button) + 12 gap + 48 Read button + 12 gap + caption line + 8 gap + partner `Wrap` + 16 bottom padding. Partner chips are `minHeight` 48, horizontal padding 12, `controlLabel` name + 6 gap + `captionOnDark` count, Wrap spacing/runSpacing 8 — chip widths and row breaks are text-dependent and must be derived (see 1.3), never estimated per character.
2. **Section headers** (scope `all` only): 16 top padding + the `appSubtitle` line height.
3. **Per book section, in scope order:** header block (16 top + the header row's line height + 8 bottom) + chapter grid, where rows = ⌈chapters ÷ perRow⌉, perRow = ⌊(viewportWidth − 32 + 8) ÷ (48 + 8)⌋, grid height = rows×48 + (rows−1)×8. Chapter counts come from the loaded `BibleData` object, never from a hard-coded table.
4. **Bottom spacer:** 24.

The jump target for a book is the offset of the **top edge of that book's section** (its `Column`, including its 16dp top padding), matching the landing today's `ensureVisible(alignment: 0.0)` produces for built sections. The applied offset is `min(modelOffset, maxScrollExtent)` — for the final books the content can be shorter than a full viewport of travel, and top-alignment is physically impossible; that clamp is the existing behavior, not a defect. First-book targets are panel height (if a panel is present) or 0.

State sequencing requirements:

- **Search jump:** `_select` may widen scope to `all` and always sets the selection — the panel that exists after the jump is the *new* chapter's panel. Compute the offset against the post-jump state. An offset computed against the pre-jump layout is a defect by definition.
- **Restore:** the restored scope and selection are set before the jump; same post-state rule. Restore is a jump like any other (see 1.4 for motion).
- **Scope switch** (`_setScope`) is not a book jump: it stays `jumpTo(0)`, instant, unchanged.
- **Selection cleared:** later jumps use the panel-absent model.
- **Partner chips:** see Flag F-2. They open the reader. There is no partner-tap scroll path and you will not create one.

### 1.3 No estimation — the exactness evidence I will require at the gate

Heuristic line heights, per-character width tables, copied device measurements, and "close enough" constants are rejected at the gate without discussion. Where a height depends on text, derive it from the framework's own text metrics (`TextPainter` with the widget's exact `TextStyle`, font chain, and the ambient text scaler) — the same metrics the renderer uses — so model and framework agree by construction, including in tests, where the test font serves both sides equally.

Your package must ship widget tests proving all of the following (names may vary; coverage may not):

- **T1 — Extent truth.** For each scope (`all`/`ot`/`nt`) × selection state (none, one mid-Bible chapter, one chapter whose partner Wrap spans multiple rows) at the test viewport: `controller.position.maxScrollExtent` equals the model's predicted total content extent within **0.5dp**.
- **T2 — Rendered positions.** For a spread of books (first in scope, Psalms, a late OT book, Matthew, a mid-NT book, Revelation): after a model jump settles, the target section's rendered top (via its key) sits at the scroll viewport's top within **0.5dp** — except where the offset clamped, where the test asserts `offset == maxScrollExtent` and the section is rendered.
- **T3 — Cold jump (the lesson-14 regression case).** The jump to a never-built late book is the *first* scroll action after load. Same assertions as T2. A test that scrolls incrementally to build the target first proves nothing and will be sent back.
- **T4 — Framework cross-check.** For at least one mid-list book, after the model jump lands, invoking `Scrollable.ensureVisible` on that same section in the test moves the offset by ≤ 0.5dp. The model must agree with the framework, not merely with itself.
- **T5 — Reduced motion.** With `MediaQuery.disableAnimations` true, a jump is at the final model offset after one pump — no tween pending, same landing as T2.
- **T6 — Motion is real.** With animations enabled, at ~150ms into a search/restore jump the offset is strictly between start and target; at 300ms + settle it equals the target within 0.5dp. This proves `animateTo`, not `jumpTo` in disguise.
- **T7 — Second geometry.** T1 and T2 repeated at a second viewport width **and** at text scale 1.3. If your model hard-codes a line height, T7 is where it dies — by design.

Additionally, in code review I will trace **every constant in the model** to a literal in Home's widget tree or to a `TextPainter` derivation. One untraced magic number is a Blocker.

### 1.4 Motion for jumps

- Duration `WwMotion.push` (300ms), curve `WwMotion.curve` (`Curves.easeOut`). No new duration, no new curve, no fade.
- Reduced motion (`WwMotion.reduced(context)` / `MediaQuery.disableAnimations`): duration zero — final state instantly. Every jump path (search, restore) must check it; a path that skips the check is a Blocker per audit §8.
- This applies to restore as briefed by Rusty's ruling. If you believe restore should land silently instead, that is a ruling change for Silas — you build it as specified here.

---

## PART 2 — BACKUP SECTION ON PROFILES (EXPORT / IMPORT)

### 2.1 Placement and structure

The Backup section lives in `_body()` of `profiles_screen.dart`, **after** the New profile button, inside the same `ListView` (16dp padding unchanged). Construction reuses this screen's existing vocabulary — section text on `stage`, action rows built exactly like profile rows. No card, no new container, no divider invention.

In order:

1. `SizedBox(height: 24)` after the New profile button.
2. Section header: Text `Backup`, style `WwType.selectionTitle`. This is the section's one primary element (audit §4): 17sp serif w600 against 13sp row titles below it — size and typeface both step down, hierarchy holds. The screen's primary element remains the 22sp `screenTitle` in the top bar; different section, no competition.
3. `SizedBox(height: 4)` (the codified header→subtitle micro-gap).
4. Explanatory copy: `WwType.captionOnDark`, exact copy in §2.2.
5. `SizedBox(height: 16)`.
6. Export action row (§2.3).
7. `SizedBox(height: 8)`.
8. Import action row (§2.3). No trailing spacer — the ListView's 16dp bottom padding closes the screen, as it does today.

All spacing literals are in the allowed set {4, 8, 16, 24}. Anything else is off-grid drift.

### 2.2 Copy — exact

Header: `Backup`

Explanatory copy (verbatim, one Text, `captionOnDark`):

> Export saves every profile, highlight, and note on this device as one JSON file. Import replaces everything here with the contents of a backup file. Nothing leaves this device unless you export it.

(The final sentence is mandatory — see Flag F-3.)

Export row title: `Export backup`
Export row subtitle: `Share a JSON file of all your profiles`
Import row title: `Import backup`
Import row subtitle: `Replace current data from a backup file`

Rules: counts never appear on this screen's rows (counts live in the confirm dialog, where they are current); no copy anywhere in this package claims sync, cloud, account, or automatic backup; the word "backup" is the noun throughout, matching the header.

### 2.3 Action rows — styling and computed contrast

Each row: `Material(color: WwColors.surface, borderRadius: WwRadius.row)` + `InkWell` (same radius), `Container(constraints: minHeight: WwSpace.minTarget, padding: horizontal 12, vertical 8)`, `Row`: leading icon 20dp, 12dp gap, `Expanded` column (title over subtitle, 2dp gap, `CrossAxisAlignment.start`), trailing disclosure chevron.

- **Targets:** the whole row is the tap target — full ListView content width × ≥48dp high. The row grows with its two text lines; the 48dp is a floor, never a cap.
- **No gold fill, no gold text on the rows.** The screen's gold full-width primary action is New profile; a second gold block would create two competing primaries and falsely rank a utility action. Import's row carries **no danger styling** — tapping it opens a file picker; nothing destructive happens at the row. Danger appears exactly once in this package: the confirm dialog's action text (§2.5).
- **Disabled state:** none is specified and none may be invented. If your implementation ever needs one, the label/icon tokens become `mutedOnDark` at full opacity (6.03:1 on `surface`, below) — alpha-reduced `navInk` is prohibited (audit §2: no alpha-reduced text tokens). Bring it back to me rather than improvising.

Computed pairs for every foreground/background pair in the rows and section text:

| Element | Foreground | Background (effective surface) | Ratio | Class / verdict |
|---|---|---|---|---|
| Section header `Backup` (`selectionTitle`) | `goldBright` #E8B33C | `stage` #000000 | **10.94:1** | Normal text — pass |
| Explanatory copy (`captionOnDark`) | `mutedOnDark` #9A947F | `stage` #000000 | **6.92:1** | Normal text — pass |
| Row title (`controlLabel`, w600 per the profile-row pattern) | `navInk` #F2EAD8 | `surface` #14141C | **15.29:1** | Normal text — pass |
| Row subtitle (`captionOnDark`) | `mutedOnDark` #9A947F | `surface` #14141C | **6.03:1** | Normal text — pass |
| Leading icons (`Icons.share`, `Icons.folder_open`, 20dp) | `goldBright` #E8B33C | `surface` #14141C | **9.55:1** | Meaningful icon — pass |
| Trailing chevron (`Icons.chevron_right`, 20dp) | `mutedOnDark` #9A947F | `surface` #14141C | **6.03:1** | Meaningful icon — pass |

The row fill `surface` on `stage` is the sanctioned L1-on-L0 elevation step (audit §1) — a surface step, not a text pair, and identical to the profile rows above it. Text is never carried by color alone here: each row pairs icon + title + subtitle (lesson 17's non-color-cue discipline, applied to actions).

Icons are specified: export = `Icons.share` (its tap opens the system share sheet; the glyph must promise what happens), import = `Icons.folder_open` (its tap opens the system file picker). Both at 20dp, inside the allowed glyph set, matching the profile rows' 20dp action glyphs.

### 2.4 Type roles — no new role

**No new `WwType` role is mathematically required, and you will not add one.** Every text in this package maps to an existing, already-audited role: `selectionTitle` (section header, dialog titles), `captionOnDark` (explanatory copy, row subtitles), `controlLabel` (row titles), `bodyOnDark` (dialog content, snackbar), `buttonLabel` (Cancel), `dialogActionLabel` (primary dialog action), `dangerActionLabel` (destructive dialog action). Counts inside the confirm dialog are inline prose within `bodyOnDark` sentences — they are not a metric display, so no metric role is needed and none may be coined. Any `TextStyle` literal, or a `copyWith` that changes **color**, in new code fails the gate; `copyWith` for weight only follows the screen's existing pattern. If you hit a case you believe forces a new role, stop and return it to me with the computed ratio — do not ship it first.

### 2.5 Dialog construction — run-5 rulings carried forward

Both new dialogs (import confirm, import error) are `AlertDialog`s built exactly as the shipped run-5 dialogs (delete profile, delete note, name entry) are built. The run-5 fixes apply in full:

- **D-1 — explicit background:** `backgroundColor: WwColors.surfaceHigh`, set on the widget. Never the theme/platform default surface (lesson 20: the Material default is the wrong elevation and reads as a light-fallback fault on this app).
- **Transparent tint:** `surfaceTintColor: Colors.transparent`, set explicitly. Tint-based elevation is a violation.
- **D-3 — closed radius:** `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WwRadius.sheet))` — 16dp from `WwRadius`, never the stock 28dp corner, never a new literal.
- **F-1 / field fills step down:** neither new dialog contains a text field, so the field rule does not trigger — the theme's `surfaceHigh` input fill must not appear inside a `surfaceHigh` dialog. If your build introduces any field into either dialog, its fill steps **down** to `WwColors.surface` with the standard `WwRadius.input` / `borderDark` / focused-`goldBright` borders, exactly as the name dialog's explicit override does — and its presence comes back to me before it ships.
- **Presentation:** both dialogs open **only** through `wwShowDialog` — never `showDialog` directly (see §2.7).
- **Actions:** `TextButton`s with `minimumSize: Size(64, WwSpace.minTarget)` — 48dp target height, matching every dialog action in the app. Order: non-destructive first, destructive last, as in both shipped confirm dialogs. Barrier dismissal equals Cancel: no state changes.

### 2.6 Import confirm dialog — copy and the danger ruling

Sequence is fixed: file pick → **validate** → (error dialog **or** this confirm dialog) → replace wholesale → persist → success feedback (§2.8). Validation always precedes confirmation; the confirm dialog describes a file already known to be importable.

Title: `Replace all data?` — `WwType.selectionTitle`.

Content: one Text, `WwType.bodyOnDark`, built to this exact template (numbers substituted, pluralization following the delete dialog's pattern — `1 profile`, `2 profiles`, likewise highlights/notes):

> Importing this backup will replace all current data. The {C profiles}, {C highlights}, and {C notes} now on this device will be removed, and {F profiles}, {F highlights}, and {F notes} from the file will take their place. This cannot be undone.

Binding requirements on that content:

- **Both sides are named, always** — current-side counts (C) and file-side counts (F), each as profiles + highlights + totals across **all** profiles. Equal counts on both sides do not waive either side. Totals computed by one counting method for both sides (profile count = number of profiles in the document; highlights/notes = sums over every profile).
- **File-side counts are the counts of the exact `UserData` instance that will be installed** — i.e., counted after defensive parsing, from the model object itself, never tallied from the raw file. The dialog is a statement of fact about what will happen; a count the install won't match makes it a lie (see Flag F-4).
- The sentence `This cannot be undone.` appears verbatim, as the final sentence.

Actions:

- `Cancel` — `WwType.buttonLabel`. `navInk` #F2EAD8 on `surfaceHigh` #1B1B24 = **14.27:1**, normal text pass.
- `Replace` — `WwType.dangerActionLabel`, **danger TEXT only**: `danger` #FFB9C0 on `surfaceHigh` #1B1B24 = **10.54:1**, normal text pass.
- **No `dangerFill` anywhere in this package** — no filled destructive button, no tinted action background. The reason is boundary, not text contrast: `danger` text on `dangerFill` would itself compute 8.56:1, but the fill's boundary against the dialog surface is what fails — `dangerFill` #4A1F24 against `surfaceHigh` #1B1B24 computes **1.23:1**, an indistinct edge that cannot carry a control's shape (run-5 ruling, re-computed by me for this spec). A `dangerFill` surface behind the action, a `dangerFill` dialog background, or a `dangerFill` row all fail the gate. Title of the dialog: `goldBright` on `surfaceHigh` = **8.91:1**, normal text pass. Content: `navInk` on `surfaceHigh` = **14.27:1**, pass.

### 2.7 Import error dialog — malformed files

Title: `This file could not be imported` — `WwType.selectionTitle` (8.91:1 on `surfaceHigh`).

Content: one Text, `WwType.bodyOnDark` (14.27:1 on `surfaceHigh`), two parts, both mandatory:

1. `Nothing was changed.` — verbatim, first.
2. A specific reason sentence naming the failure the validator actually detected. Generic copy ("invalid file", "something went wrong") alone fails the gate. The reason must distinguish at least these classes, in plain words:
   - not JSON / unreadable as a file: `The file is not readable as a backup (it is not valid JSON).`
   - valid JSON, wrong document: `The file is not a Woven Word backup document.`
   - right family, unsupported version: `This backup was made by a newer version of Woven Word.`
   - parses to nothing (see Flag F-4): `This backup contains no profiles, highlights, or notes.`

Action: single `OK` — `WwType.dialogActionLabel` (`goldBright` on `surfaceHigh` = **8.91:1**, pass), `minimumSize: Size(64, 48)`. No danger styling anywhere in this dialog: nothing was destroyed and nothing is at risk; danger is reserved for the destructive action in §2.6. Dismissing by barrier is equivalent. After this dialog, the app state is byte-for-byte what it was before the file pick — "changes nothing" is a gate-checked property, not a hope (§3, item 14).

Validation scope (design-honesty boundary, stated here because the confirm dialog's truthfulness depends on it): acceptance by `UserData.fromJson` is **not** validation — that parser is defensive by design and silently drops malformed entries (lesson 18: parse-acceptance is not validity). Your import validator must reject, before the confirm dialog, at minimum: undecodable JSON; a non-object root; a document whose `profiles` member is missing or not an object; a `version` newer than the store's current version. A document that passes shape validation but parses to zero profiles **and** zero highlights **and** zero notes is treated as malformed and routed to this error dialog with the fourth reason above — replacing a user's library with an empty document behind a counts dialog reading "0 profiles, 0 highlights, 0 notes" is a trap, not a confirmation.

File-picker cancellation is not an error: it returns to the Profiles screen silently — no dialog, no snackbar, no feedback of any kind.

### 2.8 Success feedback

- **Import success:** one `SnackBar` via `ScaffoldMessenger`, shown **only after the replace has been persisted** (the success message downstream of the save completing — a "replaced" message over an unsaved replace is a false receipt and fails the gate). Copy, verbatim: `Data replaced from backup.` No action on the snackbar — specifically **no Undo**: the confirm dialog stated the replace cannot be undone, and a contradictory Undo affordance is a copy/honesty violation.
- **Export:** the opening of the system share sheet is the feedback. No snackbar, no dialog after export, whether the share completes or is dismissed — export mutates nothing.
- **SnackBar construction (explicit, per lesson 20 — `wwTheme` defines no snackbar slot, so stock presentation is an unexamined default):** `backgroundColor: WwColors.surfaceHigh` (L2 — the correct step for a surface floating over the L0 page / L1 rows, audit §1), `behavior: SnackBarBehavior.floating`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WwRadius.chip))` (12dp, from the closed scale — the stock corner is off-scale), content Text `Data replaced from backup.` in `WwType.bodyOnDark`: `navInk` on `surfaceHigh` = **14.27:1**, pass. Duration: the framework default — do not set a custom duration (the allowed duration set governs app animation, and inventing one is drift).

### 2.9 Reduced motion — every new surface

| Surface | Required behavior |
|---|---|
| Confirm dialog | Opens via `wwShowDialog` only: under `MediaQuery.disableAnimations` it renders its final state instantly (zero-duration general-dialog path). Calling `showDialog` directly is a Blocker. |
| Error dialog | Same — `wwShowDialog` only. |
| Backup action rows | No custom animation of any kind. Stock `InkWell` feedback only, identical to the profile rows. |
| Success snackbar | No custom animation, transition, or duration introduced. The message is static text, fully legible regardless of entrance motion — comprehension never depends on an animation completing. |
| Share sheet / file picker | System surfaces. They are not themed, not token-styled, and their motion is the OS's — do not attempt to restyle or re-time them, and do not treat their stock appearance as a finding. |
| Home jumps | Part 1, §1.4: zero-duration under reduced motion, on every path. |

---

## FLAGS — package as briefed, against the design law

- **F-1 — `dangerFill`: the brief is correct; this flag is the standing prohibition, restated with its number.** Rusty's ruling (danger TEXT, no fill) complies. I re-computed its boundary for this package: `dangerFill` #4A1F24 vs the dialog surface `surfaceHigh` #1B1B24 = **1.23:1** (vs the section surface `surface` it is 1.32:1 — equally indistinct). Any fill-based destructive treatment, in any state, fails. Fix required if encountered: `dangerActionLabel` text on the explicit dialog surface, nothing else.
- **F-2 — Decision record §1 says "partner taps" scroll; ruling §4 of the same record and the shipped code say partner chips open the reader.** The record contradicts itself. Ruling §4 governs (it is also the founder's own Oct 13 direction): the offset model serves search jumps and relaunch restore. Maren: do not build or resurrect a partner-tap scroll. Silas: correct the record's wording when convenient.
- **F-3 — The Profiles intro caption ("Profiles live on this device only.") sits in tension with a user-initiated export.** It remains true of storage — no sync, no account — and it is **out of this package's scope**: Maren does not edit it. The tension is resolved inside this package by the mandatory final sentence of the Backup copy (§2.2). If the founder ever flags the caption itself, that is a separate copy ruling.
- **F-4 — "Validates against the store's defensive-load rules" (ruling §2) must not be implemented as "`fromJson` accepted it."** The defensive parser drops bad entries silently by design (LESSONS #18/#19). Built naively, import would (a) install partial data behind a confirm dialog whose counts were tallied from the raw file, and (b) accept an empty parse as a valid backup. §2.6 (counts from the installed instance) and §2.7 (shape validation + empty-document rejection) are the required fixes, and both are gate items.
- **F-5 — No token, radius, duration, or type role in the brief as handed to me violates the law.** The package's specified surfaces all resolve to existing audited roles (see the tables). The violations this package is *at risk* of are all default-behavior traps (lesson 20): stock dialog surface/radius/tint, stock snackbar presentation, theme input fill inside a dialog — each is pre-empted by an explicit requirement above.

---

## GATE CHECKLIST — the diff will be audited against every item

**Home / offset model**
1. Diff to `home_screen.dart` touches no rendering literal (color, style, size, padding, gap, radius, copy, child order) and adds no rendered widget, scrollbar, or physics override.
2. Model constants all trace to widget-tree literals or `TextPainter` derivations; no per-character or copied-device estimates anywhere in the model.
3. Tests T1–T7 (§1.3) exist and pass, including the cold-jump case as the first scroll action and the framework cross-check (T4). Tolerances ≤ 0.5dp as specified.
4. Every jump path (search, restore) animates 300ms / `Curves.easeOut` and checks reduced motion; scope switch remains an instant `jumpTo(0)`.
5. Model accounts for the post-jump selection panel and the current scope; no partner-tap scroll path exists.

**Backup section**
6. Structure, order, and spacing exactly per §2.1; all spacing literals in {4, 8, 16, 24}; screen margin and ListView padding unchanged.
7. Copy verbatim per §2.2 (including the mandatory final sentence); no sync/cloud/account claim anywhere in the package.
8. Rows: `surface` / `WwRadius.row`, minHeight ≥ 48, full-width tap, icon set and glyph sizes per §2.3, no gold fill, no danger styling on the import row, no invented disabled state or alpha-reduced text.
9. No new `WwType` role; no `TextStyle` literal and no color-changing `copyWith` in new code.

**Dialogs**
10. Both dialogs: explicit `surfaceHigh` background, `surfaceTintColor: Colors.transparent`, `WwRadius.sheet` shape, opened via `wwShowDialog` only, action `minimumSize` 64×48.
11. No field with a `surfaceHigh` fill inside any dialog (D-2 step-down if a field exists at all — and its existence was returned to me first).
12. Confirm dialog: both count sides named (profiles/highlights/notes, all profiles), counts taken from the exact instance to be installed, `This cannot be undone.` verbatim and final, `Replace` in `dangerActionLabel` text only, **zero occurrences of `dangerFill` in the diff**.
13. Error dialog: `Nothing was changed.` plus a specific reason from the §2.7 classes; single `OK` in `dialogActionLabel`; no danger styling; picker cancellation produces no UI at all.
14. Post-error state unchanged and post-confirm state equal to the validated model — demonstrated by test, not asserted in prose.

**Feedback & motion**
15. Import snackbar: explicit `surfaceHigh` background, floating, `WwRadius.chip` shape, `bodyOnDark` text, exact copy, no action/Undo, no custom duration, shown only after persistence completes.
16. No snackbar or dialog follows export; share sheet and file picker carry no app theming.
17. Reduced-motion behavior per the §2.9 table, with a widget test covering at least one dialog under `disableAnimations`.

**Process**
18. Maren's verify is green and included in the package report: `flutter analyze` clean, `flutter test` green, `flutter build web --release` green.
19. Every contrast pair in the final rendered states (resting, dialog, snackbar) re-computes from the diff's actual tokens to the values in this spec's tables. A pair that differs from the table means the diff differs from the spec — Blocker until reconciled.

Anything on this checklist that cannot be met as written comes back to me **before** merge, with numbers. A design that fails its own spec does not reach the founder — that is the gate, and it does not bend for schedule.

— **Petra**, Design Auditor & QC, Woven Word Studio
