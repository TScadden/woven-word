# Board run 8 — FIX ROUND GATE (Petra, Design Auditor & QC)

Date: 2026-10-14. Package gated: Maren's report
`team/specs/run8-fix-round-report.md`; code tree head `8e13fe2`
(plus docs-only `492d75d`); commits Defect 1 `69e0d07`, Defect 2
`bd3e458`, Item 3 `9e0fd7d`, Item 4 `cb540af`. CI "Build Flutter
app" run **38657791978** — verified by me via `gh`: headSha
`8e13fe2`, conclusion success, web/ios/android jobs all green.
Suite size re-derived by me: 202 `test`/`testWidgets`
declarations across `flutter/test/` — matches the claimed
202/202. (No Flutter SDK exists on this VM, so the suite itself
was not re-run locally; every number below that I call verified
was recomputed by me from the artifacts — code, captures, and
the shipped asset — per lessons 9, 16, 27.)

**Verdicts at a glance: Defect 1 PASS · Defect 2 PASS ·
Item 3 PASS · Item 4 PASS. No fix items. One flagged call ruled
below (the selection hue sweep SURVIVES), and one founder
disclosure recommended to Silas (not a fix item).**

---

## 1. DEFECT 2 — Ambient arch brightness — **PASS**

This was the computed core of the gate. Every number below is
mine, recomputed from `#B8860B` and from the capture files, not
copied from the report.

**The cap claim is correct.** WCAG relative luminance of the
token, computed by me from the hex: linearized channels
R 0.479320, G 0.238398, B 0.003347 → **L(#B8860B) = 0.272647 ≈
0.273**. The construction argument is sound: srcOver accumulation
of a single color over black converges monotonically to that
color and cannot exceed it, so 0.273 is a true ceiling, not a
tuning result (lesson 31: bounded by construction).

**The capture stats are exact.** I re-ran the filed
`compute_stats.py` AND a second, independently written vectorized
implementation; both agree with the report to six decimals on
both captures (1200×500, arc region rows 0–349, 420,000 pixels,
composited over black — the correct display model for this image
on the black stage):

| capture | mean | p99 | max | frac > 0.9 |
| --- | --- | --- | --- | --- |
| before (plus + hue sweep) | 0.592718 | 1.000000 | 1.000000 | 0.595550 |
| after (srcOver, gold token) | 0.103149 | 0.196040 | 0.215765 | 0.000000 |

After-max 0.216 sits below the 0.273 cap, as the report says —
finite accumulation, cap is the asymptote. **Palette audit by
me:** the fraction of arc-region pixels that are green-dominant
was 0.0455 before and **0.0000 after**; the brightest stored
pixels are gold-family (R > G ≫ B). One recording note, not a
violation: the token's blue channel (11/255 ≈ 4.3%) quantizes to
0 in the renderer's 8-bit premultiplied output — hue and
luminance are unaffected and no off-palette color appears.
**Visual read of both captures (mine):** before is a clipped
white/yellow dome with green/cyan fringes; after is a dim
mustard-gold web on black, arc texture visible, no white
anywhere. The founder's screenshot shows the same blown dome
the before-capture measures. **The founder's "too bright"
defect is CLOSED.**

Code confirms the mechanism: `bd3e458` changes only the non-faint
path of `renderArcImage` — `BlendMode.srcOver`, `ambientArcToken
= WwColors.gold`, per-arc alpha formula byte-identical in form
(0.0084–0.09 at the Home band 0.30, ≤0.30 at full density);
faint mode untouched; evidence generator asserts band 0.30 at
390dp width so the capture cannot silently drift from Home's
parameters.

**Selection separation — PASS, with Maren's framing corrected
on the record.** Her report argues from alpha ("up to 0.75
strength against an ambient p99 of 0.196"). Alpha is not
luminance: computed by me, the sweep colors at single-pass
strength over black span luminance **0.015–0.421** by hue —
mid/far hues clear the ambient max easily (hue 137°: 0.334,
hue 60°: 0.421 at alpha 0.75), but the near hues do not
(hue 275° purple: 0.091, hue 0° red: 0.115 at alpha 0.75 — below
the ambient p99 of 0.196). Separation nonetheless holds in both
composites that actually occur, and I rule on those:
(1) **Home, selected state:** `home_tab.dart` sets
`includeArcs = widget.selection == null` — the ambient arc
field is not rendered at all when a chapter is selected; the
selection arcs are the only arcs in frame, over chapter bars
and black, reinforced by the `goldBright` selection bar.
(2) **Full stage:** selection draws over the *faint* field
(flat color at 0.05 alpha), not over the ambient web. In
neither composite does a selection arc compete with the
measured ambient field, and against the gold family the sweep
hues also separate by hue. Separation is real; the report's
one-line justification for it was imprecise.

**THE FLAGGED CALL — the hue sweep SURVIVES in selection.**
`MiniSelectionPainter` is byte-untouched by this round (zero
mentions in the `bd3e458` diff) and I rule it stays, for four
reasons: (a) in selection the sweep is a **data encoding** —
hue carries arc distance (near → far), inherited from the
source visualization — not decoration; (b) the defect
mechanism is absent: single-pass normal blending cannot
accumulate or clip — the brightest possible selection stroke
is one 1.6dp arc at luminance ≤ 0.421, never a dome;
(c) it is shipped behavior from the founder's own Oct 13
selection redesign, verified by him since; his fix-round
complaint named the ambient arch's brightness only, and
extending a fix past the complaint is the mirror image of the
scope errors lessons 29/33 exist to prevent; (d) a palette
unification of selection is a design change that deserves the
founder's eyes, not a gate-room substitution in a fix round.
**Recommended disclosure (Silas, at delivery — not a fix
item):** tell the founder in one line that the ambient web is
now gold-only while selected-chapter arcs still carry the
rainbow distance encoding, so he can rule on gold-only
selection with the build in hand if he wants it.

## 2. DEFECT 1 — Tab bar geometry — **PASS**

Founder screenshot verified by me: the Home icon+label hug the
left edge while the gold indicator sits visibly right of them,
centered on the column — report's root cause matches the image
and the code.

**The fix obeys design law.** Two operative lines in
`shell_screen.dart` (`69e0d07`): the slot content `Container`
gains `width: double.infinity` and its `Column` an explicit
`crossAxisAlignment: CrossAxisAlignment.center`. No per-tab
padding, no offsets, no new spacing literals; the three
`Expanded` equal columns, the indicator, the badge construction,
semantics labels, and re-tap behavior are all absent from the
diff, i.e. untouched. The ≥48dp target is preserved: the same
container keeps `minHeight: WwSpace.topBarHeight` = **56dp**
(token read by me).

**The test asserts the right things.** `tab_bar_geometry_test.
dart` measures rendered positions (`tester.getCenter`), never
widget properties (lesson 30): (a) equal icon spacing, (b) each
icon center == its column center (65/195/325 at 390dp), (c)
indicator center == active column center == Home icon center —
at 390×844 and again at text scale 1.3. Icon center is a sound
proxy for the whole content column: icon and label are children
of the one centered `Column`, so they share its axis by
construction. **Tolerance 1.0dp is defensible:** column centers
are exact rationals at this width (390/3 = 130), so 1.0dp only
absorbs raster rounding, while the pre-fix defect offset is
≈43dp (a label-width container pinned to the slot's left edge
puts its center ~22dp into a 130dp slot vs the 65dp column
center) — the tolerance is ~2% of the defect magnitude. By that
geometry the test cannot pass on the pre-fix tree, which
corroborates Maren's mutation claim (hers, verified by
construction here, plus CI green on the final tree).

## 3. ITEM 3 — Citation Index routing surfaces — **PASS**

Gated against the AMENDED spec (§4.4.1 as amended; decision
record `2026-10-14-conference-talk-routing-citation-index.md`).

**Counts re-derived by me from the shipped asset**
(`flutter/assets/conference.json`, applying the code's own
routing precedence): 4,964 talks, 68,999 edges, 905 distinct
cited chapters — **Form A (per-talk Gospel Library) 3,014 ·
Form C (Citation Index) 1,950 · Form B residual 0 · neither
0**; all 4,964 talks carry the `x` field; the earliest talk is
April 1942, "Upholding the Hands of Our Leaders", `x` =
`https://scriptures.byu.edu/content/talks_ajax/3/`. Every
claimed count is exact, and the dataset did not shrink.

**Routing is data-driven — proven stronger than claimed.**
`_readAction()` branches in the amended order (A → C → B
residual → caption) on `url`/`urlIsConference`/`indexUrl` only.
My grep of the routing code finds year numbers only in doc
comments and a sort key — no cutoff exists. The asset itself
proves the point: **148 talks from 1980 onward route to Form
C** because they lack per-talk Gospel Library links, and Form
C spans the 1940s–2010s. The year correlates; the data rules
(lesson 32).

**Labels name their true destinations; semantics are exact
(lesson 25).** Form C visible label `Read in Citation Index`
(C-25), semantics `Read {title} in the Scripture Citation Index,
opens external app or website` (§7 table), failure snackbar
`Could not open the Citation Index.` (C-26) — all verbatim in
code, and the launch target is the talk's own `indexUrl` via
the parameterized `_openExternal(target, failureCopy)` (the
pre-fix method launched `talk.url` regardless of form; that
hazard is gone). Form A label/semantics/C-20 and Form B
label/C-18 caption/semantics are byte-identical to the original
spec. Widget tests assert Form C's label, semantics, launch
target, and C-26 snackbar — including that the Gospel Library
snackbar does NOT appear — plus Form A precedence when both
links exist, and the residual/neither forms on synthetic
fixtures. **No dead, disabled, or mislabeled controls:** every
branch renders either a working button or the honest C-19
caption; no disabled form exists.

**Copy is truthful everywhere the action is described.** The
amended C-2 Profiles copy is byte-exact in
`profiles_screen.dart` ("…open each talk in Gospel Library or
the Citation Index."). My grep across `flutter/lib/` finds no
other surface describing the read action; remaining "Gospel
Library" mentions are the Form A/B strings themselves, data
doc-comments, and the attribution (C-22, unchanged, names the
Index correctly).

## 4. ITEM 4 — System back ladder — **PASS** (stated limitation accepted)

**Per-rung evidence supports the verdicts.** `system_back_test.
dart` contains exactly 10 tests (counted by me); every one
drives `tester.binding.handlePopRoute()` — the real platform
event path — and none calls `handlePriorityBack()` or an in-app
Back button. The test names map 1:1 onto the report's rungs:
toolbar (including the ordering proof — the *next* back is the
one that consumes history), connections sheet, note editor,
dialog by system back, dialog by Cancel, history step, Library
grid pop, reader route pop, the three-level conference browse
pop, and tab-root switch + Home-root exit. The dialog tests
assert `takeException()` is null on both dismissal paths. CI is
green on this exact tree (§header). The claim "**no ladder
code changed**" is verified: `cb540af` touches only
`profiles_screen.dart`, `my_notes_screen.dart`, and the new
test — `ShellController`, the PopScope wiring, and every
navigator are untouched, which is the correct outcome for an
audit that found the ladder already correct (lesson 33).

**The refactors preserve copy and behavior — diffed by me,
not taken on the report's word (lesson 29 cuts both ways, and
here the diff backs the claim).** Profiles dialog: every
string ('Profile name', 'Cancel'), style, border, fill
(including the explicit surface fill inside the surfaceHigh
dialog, lesson 20), minimum sizes, autofocus,
textCapitalization, trim-disabled confirm, and submit-on-enter
are identical; only ownership moved — `StatefulBuilder` +
`whenComplete(controller.dispose)` → `_ProfileNameDialog`
State disposing in `dispose()` — and the call still goes
through `wwShowDialog`. My Notes sheet: identical tree,
strings ('Note', 'Saving an empty note removes it.', 'Cancel',
'Save'), decorations, and Save semantics (setNote +
persist, then pop, in the original order, via the `onSave`
callback); the sheet's explicit `backgroundColor`/`shape`
presentation survives. The seeded text is computed at the same
moment from the same source.

**The stated limitation is ACCEPTABLE.** The My Notes sheet fix
is verified by construction rather than by probe (its list load
never completes under the widget-test binding — a pre-existing
harness gap; no existing suite loads that list either). This
is acceptable because the anti-pattern and its fix are
mechanically identical to the Profiles dialog case, which IS
probe-proven on every dismissal path and mutation-verified —
same `whenComplete` disposal removed, same State-owned
controller construction, and I diffed the sheet's tree
token-by-token against the original. The residual risk is a
dismissal-time assertion of exactly the class the twin fix
eliminates. Recorded follow-ups, neither a fix item nor a
blocker: (1) when a My Notes list harness exists, add the
dismissal probe; (2) founder phone verification of this build
should include opening a note in My Notes and swiping back —
the one dismissal path no test here could drive.

---

## Gate summary

All four items PASS on independently verified numbers:
luminance cap 0.272647 ≈ 0.273 (mine); capture stats exact to
six decimals under two implementations; green-dominant pixels
0.0455 → 0.0000; dataset routing 3,014 / 1,950 / 0 / 0
re-derived from the asset; 148 post-1979 Form C talks prove
data-driven routing; CI 38657791978 success at headSha
`8e13fe2` confirmed via `gh`; 202 test declarations counted.
The hue sweep survives in selection, by my ruling above. The
package may go to the founder (lesson 8: his phone
verification is the final word — including the My Notes
dismissal in §4).

— **Petra**, Design Auditor & QC, Woven Word Studio
