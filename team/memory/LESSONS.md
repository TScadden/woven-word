# Verified Lessons — Woven Word Studio

Read at the start of every work package. Every lesson here was verified by
founder feedback or a measured result on Oct 13, 2026 (the logo and splash
rounds Rusty ran before the studio was founded).

## Icons
1. **Fill the tile.** Pro Bible app icons (YouVersion, Blue Letter Bible,
   Dwell, Gospel Library, Logos — reference sheet in `logo/refs/`) fill
   75–85% of the tile with ONE flat glyph. A glyph at ~50% reads as a small
   object floating in a box and the founder rejects it.
2. **Empty space is composition, not scale.** Widening the book did not fix
   the icon: the emblem sat low on the cover with a large empty field above
   it. Balance the field around the emblem (roughly equal bands above and
   below) and size the whole composition, not one dimension.
   *Addendum (P1, measured Oct 13, 2026):* the repair quantified it — web
   apex band 570 = baseline band 570 at render scale, glyph 78.3% of tile
   width, portrait proportions (h/w 1.10) restored — and was judged on
   192/96/48px renders, not at master size. Judge every icon fix by
   measured bands and a 48px read. Founder verification of v3 pending (#8).
3. **Arc placement physics.** Arcs with their feet on top of a book read as
   a bag handle. Concentric nested arcs read as a rainbow. Arcs read as a
   woven web only when they cross each other on one shared baseline with
   staggered endpoints (the app's actual cross-reference geometry).
4. **Professional icon language.** One glyph, flat solid colors, the symbol
   made by negative space or cut-out, zero page lines / rings / seals /
   fussy detail. Gradients, glows, and photoreal renders read as "AI image"
   to the founder; flat vector shapes read as clip-art unless the geometry
   carries them (lessons 1–3).

## Motion
5. **Confetti vs ash.** Bright multicolor dots bursting radially read as
   confetti. The founder's reference is the Avengers: Infinity War
   disintegration: fine gray/tan ash, an erosion front that sweeps the
   form, slow lift-off, then wind drift (sideways + up) with turbulence,
   and the form visibly crumbling at the front — a uniform fade of the
   whole word does not sell it.
   *Scope (Oct 14, 2026):* kept as craft knowledge for any dust effect,
   anywhere. The every-launch sequence it was built for was RETIRED by
   the intro decision (see #12) — this lesson is not a mandate to use it.
6. **Typing feel.** 85ms per character reads as too fast/machine. Human
   typing has per-key variance; ~150ms average with variance is the floor.
   *Scope (Oct 14, 2026):* same narrowing as #5 — governs typing effects
   wherever they appear; the typewriter opening itself is retired.

## Process
7. **The QC gate.** Never present an option your own review flags as bad
   (the founder caught a seal icon that read as a handbag after it had
   already been judged a miss in review). Cut rejects before delivery.
8. **Verify on the phone.** A design is not done when it renders; it is
   done when the founder sees it on his home screen / in the app and
   approves it.
9. **The gate checks numbers against lessons, not just the brief.** WP1's
   brief specified 95–190ms typing intervals; the seeded schedule's
   130.6ms average broke lesson 6's verified ~150ms floor even though
   every interval was in spec. Petra caught it by comparing the
   implementation's actual sum and average against LESSONS.md. Verified
   founder feedback outranks a package spec when they conflict, and a
   floor on an average binds the mean, not the range.

## Release & platform (Oct 14, 2026 board run)
10. **Pin one release keystore, and prove it every run.** CI runners
    generate a fresh debug keystore per run, so debug-signed builds all
    carry different signatures and Android refuses install-over-install
    (the founder hit this on WP1's APK). One keystore lives outside the
    repo; CI decodes it from secrets; the workflow prints the APK signer
    SHA-256 digest every run — matched across runs 38520351378 and the
    P3 run. Trap inside the fix: PKCS12 keystores ignore a distinct key
    password (keytool warns and silently uses the store password) —
    generate JKS when store and key passwords differ, or the delivered
    secret is wrong.
11. **The system splash crops; give it its own asset.** Android 12's
    splash mask keeps only the central ~2/3-diameter circle: the v3
    home-screen glyph (93.7% of tile height) lost 52.9% of its pixels to
    the crop. The splash icon is a separate asset with the whole glyph
    scaled inside the safe circle (measured: max glyph radius 339.6px
    vs the 341px limit on the 1024 master — only 1.4px of slack; never
    grow the glyph in the splash master) and is verified by circle-crop
    renders at 96/48px, the same small-size discipline as lesson #2.
12. **Research outranks attachment to a built feature.** The package-1
    opening was fully built and gate-passed; the founder reopened the
    concept anyway, and the research was one-sided — 0 of 5 leading
    Bible apps run an every-launch brand animation, and Apple HIG +
    Android guidance both say launch instantly / splash only while
    loading. The studio retired the sequence and shipped a static
    first-run intro + silent launches (decision record
    `decisions/2026-10-14-intro-decision.md`). When the evidence is that
    clear, decide from it, record it, and keep the craft lessons (#5, #6)
    for wherever the technique belongs.

## Design & data (Oct 14, 2026 board run 2 — home redesign)
13. **Audit a palette before building on it; split tokens by role.**
    Petra's computed audit kept black/cream/gold but caught `gold`
    (#B8860B) at 3.20:1 on paper — and the luminance windows prove no
    single hex can be both normal text on paper (needs L ≤ 0.1795) and
    a fill under an `onGold` label (needs L ≥ 0.2036). The fix is a
    role split, not a nudge: `gold` = fills/large/icons on paper only,
    new `goldTextOnPaper` (#956D09, 4.62:1) = small paper text, and
    `goldBright` documented dark-surfaces-only (1.89:1 on paper). Run
    the audit in the package BEFORE the one that depends on the tokens
    (here: the reader), and correct contrast comments to computed
    values — two annotations in ww_theme.dart were stale.
    *Addendum (board run 3):* one narrowed exception — `goldBright` as
    a selected-state/primary-action FILL on paper behind an `onGold`
    label (9.71:1) is ratified in
    `decisions/2026-10-14-goldbright-fill-exception.md`; as text, icon,
    or border on paper it stays prohibited.
14. **A lazy list cannot scroll to an item it has not built.** The
    home list's GlobalKey + `ensureVisible` jumps (search, partner,
    restore) silently no-op when the target book's section is outside
    the built window. Auto-scroll in a lazy sliver list needs an offset
    model; shipping without one is acceptable only when the limitation
    is named in the package report, never left for the founder to find.
15. **Research reconciliation is a producer step with teeth.** The
    category research validated the founder's spine (list-as-home,
    chapter grid, scope filtering list + map together, partners ranked
    by count) and still changed the build: resume state was adopted
    (Gospel Library / Logos / Dwell all restore your place), while
    keyword/topic search was rejected because the licensed TSK data is
    a reference graph that cannot answer it honestly, and per-chapter
    count badges were rejected inside the 48dp picker grid on
    legibility. Research that changes nothing was decoration.
16. **Audit every meaningful element in every state it renders in.**
    Board run 3's gate: the verse number got a selected-state role
    proactively (ink on the hlGold highlight, 15.23:1), but the
    connection dot beside it stayed state-blind `gold` — 3.20:1 on
    paper (pass) and 2.85:1 on the selected background (fail, below
    the 3.0 icon band). A token is not audited when its resting-state
    ratio passes; it is audited when every surface it can actually
    sit on passes — selected, flashed, and reduced-motion-persistent
    states included. Petra caught it by computing the selected chain;
    the fix made the dot conditional exactly like the number.
17. **Highlights multiply the surface matrix; selection needs a
    non-color cue.** Board run 4 (highlights + notes): adding 5 tints
    turned the verse block's audit into 12 surfaces (resting × paper +
    5 tints, selected × the same 6) — the verse number's gold was
    legal on exactly 1 (rest/paper 4.62) and the dot's `gold` on
    exactly 1 (3.20), failing everywhere else (2.23–4.11). Roles
    became rules, not states: number and dot use their gold only when
    NOT selected AND NOT highlighted, ink / `goldTextOnPaper`
    otherwise; the note indicator took one color on all 12 surfaces
    (goldTextOnPaper, min 3.22). And a selected state built by
    blending a tint over the background is chromatically invisible
    on that same tint (hlGold over hlGold, delta 1.000) — selection
    is carried by a 2dp outline in an audited color, checked against
    BOTH adjacencies (the composite inside, 3.35–4.11; the paper
    outside, 4.62). Compute the matrix before assigning any role.

## Profiles, notes list & presentation defaults (board run 5)
18. **A defensive filter needs BOTH bounds; parse-acceptance is not
    validity.** `parseVerseKey`'s `\d+` accepts 0, so a corrupt-store
    key `b0c0v1` passed an upper-bounds-only canon filter and computed
    global chapter −1 — a RangeError in the reference label, the exact
    crash the filter existed to prevent (Maren's catch at verify).
    Any code turning a parsed key back into an index checks chapter
    ≥ 1 and verse ≥ 1 as well, and the regression case for the input
    that motivated the guard ships in the same package.
19. **Profiles are a store concern, not a screen concern.** Run 5
    extended `UserData` (names map, sequence-allocated ids, resolved
    active id) and the reader changed exactly one field; home stayed
    read-only. The active id RESOLVES in the model — stored choice,
    else default, else first profile — so a stale stored id can
    never strand a screen, and the resolved value self-heals on the
    next save. Document v2 defaulted its new fields on load, so run
    4's shipped data carried over with no destructive migration.
20. **Presentation defaults are traps; set every surface explicitly.**
    Petra's run-5 gate: the theme's input fill is dark-tuned
    (surfaceHigh — wrong on paper sheets AND wrong level inside
    surfaceHigh dialogs), the Material dialog default surface is the
    wrong elevation and its 28dp corner is off the closed radius
    scale, and stock dialog/sheet entrances ignore
    `MediaQuery.disableAnimations`. Every new dialog or sheet sets
    its background, tint, radius, field decoration, and
    reduced-motion behavior explicitly — each guarded default fails
    silently in code review and only surfaces on the phone.

## Scroll model & data safety (board run 6)
21. **Measure text the way the renderer does — ambient style
    included.** Run 6's offset model derives every text height from
    `TextPainter`, but raw role styles ran **404dp short** over the
    full Bible list: a `Text` renders its style MERGED with the
    ambient `DefaultTextStyle` (the theme's bodyMedium carries a
    1.43 height multiplier), so the model must merge the same
    ambient style, read live from a context INSIDE the Scaffold
    (the scrollable's `storageContext` — the State's own context
    sits above the Scaffold and measures wrong). No multiplier is
    hard-coded; the merge is derivation, and it is ground-truthed
    three ways: predicted extent vs `maxScrollExtent`, rendered
    landings vs section keys, and an `ensureVisible` cross-check
    (all ≤0.5dp, extents exact, at two widths and text scale 1.3).
    An offset model that agrees only with itself proves nothing.
22. **Validation is a gate in front of the parser, never the parser
    itself.** The defensive loader (lessons #18/#19) silently drops
    malformed entries — correct for loading your own data, wrong
    as an import check. Import runs a pure shape validator with
    named error classes (not JSON / not a backup document / newer
    version / parses to nothing) that never writes; an empty parse
    is rejected, not installed behind a counts dialog; the confirm
    dialog's counts come from the exact model instance to be
    installed, counted by one method on both sides. "A malformed
    file changes nothing" is structural, and tested as such (the
    stored string stays byte-untouched across 8 malformed inputs).
23. **A binding spec that isn't in the brief doesn't exist — stop,
    and persist specs as files.** Run 6's first build dispatch
    referenced Petra's spec "appended verbatim" but the text never
    arrived; Maren stopped with zero files changed rather than
    inventing copy and coverage, and the run only proceeded once
    the spec was both embedded in the brief AND saved to
    `team/memory/decisions/` (the run-6 spec record). A coordinator
    who improvises across a missing attachment manufactures
    unverifiable work; a specialist who stops costs one dispatch.

## Reader flow, semantics & landings (board run 7)
24. **Verify the mechanism from the primary artifact before
    building on an interpretation.** Run 7's flow brief read the
    founder's walkthrough video as a continuous reader and overruled
    the research desk's documented finding (Gospel Library =
    swipe-to-change-chapter, paged). The founder corrected it
    himself mid-build ("I was swiping between sides"); the cost was
    a parked stream reader (35f62de), a full spec amendment, and a
    rebuild. A researched, sourced finding outranks a brief's
    impression of a video — where they conflict, surface the
    conflict before building, not after.
25. **A tooltip IS the semantics label, and a semantics
    requirement is only real with a semantics-tree assertion.**
    The Screens close button's tooltip satisfied the visual spec
    while assistive tech heard no place name. The fix needed
    `Semantics(container: true)` because a plain wrapper's label
    merges upward into the row's node — mutation-verified both
    ways at Petra's re-gate: removing the container, or the place
    from the label, each fails the `find.bySemanticsLabel`
    assertion (§13 item 22 / §6.3, adee5aa).
26. **Land on final geometry: state first, measure second.**
    The selected verse block grows 4.0dp when selected (the border
    contributes through padding), so a landing that scrolls before
    applying selection lands 2dp off the mechanism's own
    alignment — §5.8's order (select/flash, then `ensureVisible`
    against final geometry) is the rule. Companion: a landing path
    that mutates no state (a same-chapter jump) schedules no
    frame — it must `scheduleFrame()` itself or it hangs until an
    unrelated invalidation (7b277bc).

## Handoffs, briefs & gates (board run 8)
27. **A child agent's report is a claim, not an artifact — verify
    it against the repo before dispatching dependent work.** Run 8
    received a detailed "build complete" report (commit hashes,
    test counts, file paths) for UI that was never built; the
    builder had in fact stopped, correctly, on a spec conflict.
    Petra's gate caught it by checking `git cat-file` and file
    existence. Rule: hashes resolve, files exist, and the suite
    count is re-derivable — or the report is unverified and
    nothing downstream ships on it.
28. **A brief that paraphrases a spec loses to the filed spec.**
    The first UI dispatch brief summarized Petra's spec from a
    handoff summary and invented tokens, heights, surfaces, and
    an API that do not exist; the builder stopped rather than
    improvise (lesson 23 discipline working as designed). Briefs
    quote the spec's own names and strings or point at the file —
    a summary of a summary is where fidelity goes to die.
29. **Deviation reports are written from `git diff`, not from
    memory of building.** At the re-gate, three declared
    deviations (D1/D4/D7) described code that was not the code —
    in each case the code conformed and the declaration did not.
    Petra ruled the code (lesson 24), but a declaration that
    misdescribes the diff costs the gate a verification pass it
    should not need.

30. **A slot can be full-width while its content is not — assert
    geometry from rendered positions.** The tab bar's indicator
    centered perfectly on its column (Positioned left/right inside
    a full-width Stack) while the icon+label stack hugged the
    column's left edge (the Stack's non-positioned child
    shrink-wrapped under its default topStart alignment). Both
    facts were true at once, and only the founder's screenshot
    showed the split. The fix made the content span the slot and
    center in it; the regression test asserts icon centers,
    spacing, and the indicator center from `getCenter` at phone
    width and text scale 1.3 — and was mutation-verified against
    the pre-fix tree (it fails there). Alignment bugs are
    geometry claims: test coordinates, not widget properties.
31. **Bounded by construction beats tuned-down.** The ambient
    arc web blew out twice on additive blending; lowering alpha
    would only have moved the blowout. The fix changed the model:
    one gold token under srcOver, whose accumulation converges to
    the token and cannot exceed it (brightest possible ambient
    pixel = gold #B8860B, luminance 0.273; measured after: max
    0.216, mean 0.103, 0% above 0.9, vs before: mean 0.593, 59.6%
    above 0.9). Evidence for a rendering fix is a before/after
    capture at the exact production parameters plus pixel stats,
    regenerated by a tool in the repo — not an eyeballed screenshot.
32. **A link's label must survive the destination's actual
    coverage — and routing follows data, never a proxy cutoff.**
    Gospel Library's own archive bottoms out at 1971–1979, so the
    conference-level fallback was a dead end for the pre-1971
    talks it served. The founder's correction routed by each
    talk's recorded links (per-talk Gospel Library → its own
    Citation Index page → residual conference link → no-link
    caption), with no year cutoff anywhere: the year correlates
    with the missing links, but the data is the rule. New asset
    fields come from the source's own published link structure
    (the Index's getTalk ids and its frontend's resolution of
    them), documented at the point of harvest.

33. **Probe the real event path before rewriting the handler —
    and never dispose a controller from a route future.** The
    Item 4 audit drove system back through `handlePopRoute()`
    from eight states before touching code: the run-7 ladder was
    already correct at every rung except one modal, whose dialog
    threw "TextEditingController used after being disposed" on
    EVERY dismissal (back, barrier, Cancel — all probed). The
    future returned by showDialog/showModalBottomSheet completes
    while the route's exit transition still builds the field, so
    `whenComplete(controller.dispose)` is always a lifetime bug;
    a dialog/sheet owns its controller in its State and disposes
    it in `dispose()`, when the subtree unmounts. Rewriting the
    ladder on suspicion would have churned correct code and
    missed the actual escape.

34. **Verify a desk's summary numbers against the artifact on
    disk before integration trusts them.** The run-9 Jewish desk's
    summary report quoted link/work/byte counts that described no
    artifact the pipeline produced; the pipeline README's own run
    counts were the accurate record of the faithful output.
    Summaries are narration; the file on disk and the pipeline's
    recorded run stats are evidence. Integration re-derives every
    headline count from the artifact itself before building on it.

35. **Never write a placeholder over a path a pipeline owns.**
    Coordinator placeholder assets (written so the tree would
    analyze) overwrote the Catholic desk's real webc.json and
    deuterocanon.json outputs. Both were recovered only because
    the pipeline's cached sources were intact and the build was
    deterministic. If a stub is unavoidable, put it on a path no
    pipeline emits, or mark it so loudly that overwriting real
    output is impossible to miss.

36. **A dataset's faithful size can be unshippable — narrow at
    the pipeline, and disclose the truncation in-product.** The
    faithful Sefaria links output was 174 MB. It shipped at
    4.8 MB gzipped only after pipeline-level narrowing with
    recorded reasons (canonical work titles, the Reference
    category excluded because lexicons link by word occurrence
    rather than engagement, a per-verse cap of 25 works with each
    capped verse's full total recorded). The cap is disclosed in
    the product itself ("See all N links on Sefaria"), never
    silent. Narrowing decided in app code or by dropping files
    would have hidden the cut; narrowing in the pipeline keeps
    it auditable and rebuildable.

37. **Control counts are a layout budget at 360dp.** Four
    segmented translation buttons (KJV/WEB/JPS/Hebrew) overflowed
    the reader top bar by 48px — found by test, not by eye. The
    rule now: three or fewer options keep the segmented toggle;
    more than three switch to a chip showing the current choice
    plus a popup menu. Every new option added to a fixed bar is
    a layout cost that must be measured at the narrowest width,
    not assumed.

38. **A setter that kicks off loads must await them when its
    callers read the loaded state.** Run 8's setConferenceEnabled
    await contract carried into run 9's setTradition: returning
    before the tradition layer loads land races every caller
    that reads the layer immediately after the switch. The
    failed-load retry test proved the race. Kick-and-forget is
    for fire-and-forget call sites only; a state switch other
    code observes is a future that completes when the state is
    actually usable.

## Selection, per-translation data & baselines (board run 10)

39. **An always-on `SelectableText` inside a horizontal pager
    steals the page turn.** On Android its
    `TapAndHorizontalDragGestureRecognizer` wins the arena eagerly
    on drag, claiming horizontal swipes that start on text —
    most of the page — before the pager's recognizer can. Run 10
    proved it with the shipped suite: R-T8, R-T9 and TOOL-3
    failed under the always-on construction and passed the hour
    the text became a MODE — plain `Text.rich` at rest,
    `SelectableText` only for the verse in selection mode,
    entered by long-press. Rule: in paged readers, text
    selection is a mode you enter, never a property the text
    always carries; and the mode's presence must be invisible
    to every shipped gesture outside it.
40. **When the model changes, a test's scenario may be the thing
    that was superseded — re-seed the scenario, don't re-assert
    the claim.** Run 10's per-translation ruling voided a
    shipped My Notes test that asserted two notes visible in
    one view (they now belong to different translation sets).
    The faithful translation re-seeded the fixture as a v3
    document with the note in the set the scenario writes, the
    matching active translation, and the matching tradition —
    and asserted the other set's note is NOT in the view. A
    test translated by find-and-replace on API names alone
    would have kept asserting the old product.
41. **A red test is a regression only after a same-environment
    HEAD baseline says so.** Run 10's local suite showed 9
    failures; a HEAD worktree run in the same environment
    showed the conference dispose race failing at HEAD too
    (241/242, CI green). The remaining 8 were mine and got
    fixed; the race was reported as pre-existing with its
    baseline numbers attached. Rule: before owning a failure,
    run the failing file on the untouched tree in the same
    environment — and never ship a "suite green" claim that
    hides a baseline failure inside it.

## Ambient color & raster bounds (arch-ambient package, Oct 15, 2026)

42. **Clamp each stroke's luminance and convex compositing bounds
    the whole field — in full color.** The fix round bounded the
    ambient web by construction with ONE color (lesson 31). The
    founder then asked for the original's rainbow back, dimmer:
    the same construction generalizes. srcOver over black is a
    convex combination of the stroke colors, and luminance of a
    convex combination cannot exceed the brightest stroke's — so
    clamping every distance-sweep color to the cap
    (`ambientLuminanceCap` 0.216) bounds every pixel, whatever
    hues stack. Measured at Home parameters: mean 0.079974,
    p99 0.173455, max 0.213268, 0% above 0.9 — inside the gold
    render's envelope (0.103 / 0.196 / 0.216), with the full
    palette restored. BUT the float bound is not the raster
    bound: 8-bit premultiplied rounding across thousands of
    draws drifted 31 of 420,000 pixels +0.0052 past an exact-cap
    target. The clamp therefore targets cap − guard
    (`_ambientRasterGuard` 0.008), the guard sized from the
    MEASURED drift, never guessed; the gate corroborated the
    same 31-pixel population sitting over the target and zero
    over the cap. Rule: bound by construction, then measure the
    raster's drift against the bound and guard for the drift
    you measured.

43. **A new always-visible control is a layout-budget change
    (reader theme package, Oct 15, 2026).** Adding one 48dp
    button to the reader top bar overflowed it by 8.5px at the
    largest translation count at scale 1.0 and by 12px with two
    options at scale 2.0 — invisible at the default configuration
    the builder tests first. Measure the bar across the full
    control-count × text-scale matrix BEFORE and AFTER adding a
    control (a probe test that prints sizes, run once), and pay
    for the new control out of the bar's own budget: the fix
    tightened the segmented toggle's segment padding 12→6dp
    and let the toggle take its existing chip form at measured
    thresholds (3 options from scale 1.3, any options from 1.6).
    Rule: every control carries a price in the 360dp budget
    (lesson 37 prices counts; this prices the bar itself);
    never let a title or label silently absorb it below its
    legible width (the 3-option toggle measured 204.5dp under
    test metrics, leaving the chapter title 20dp).

44. **Host-provided vs stored values resolve at build time,
    from separate fields (reader theme package, Oct 15, 2026).**
    The deuterocanon reader held its theme in one field that
    both the shell (via widget parameter) and its own async
    stored-preference load wrote: the stored Dark landed after
    the shell's Paper and the reader rendered Dark despite the
    explicit choice — the run 9 Catholic-navigation bug's shape
    in a new field. Precedence host > stored > default must be
    a GETTER over separate fields (`_local ?? widget.x ??
    _stored ?? default`), never an assignment race. Any widget
    that both receives a value and can load one has this bug
    until the fields are split.

45. **Re-parameterizing a widget breaks its const call sites
    (reader theme package, Oct 15, 2026).** Adding a required
    palette parameter to the note editors invalidated `const`
    constructor calls three files away; the analyzer names
    them, but the cheap pre-check is a grep for `const <Widget>`
    before the first compile. Rule: when a shared widget gains
    a parameter, grep its const call sites in the same edit.## Home sections, schedules & shared-tree landings (board run 11)

46. **Verify an arithmetic rule against every instance's numbers
    before pinning it.** Run 11's brief stated plan schedules as
    "consecutive day chunks (ceil division)" beside fixed day
    counts — but a fixed chunk of ceil(T/D) exhausts Psalms &
    Proverbs (181 chapters / 60 days) on day 46 and the Whole
    Bible (1,189 / 365) on day 298, leaving 14 and 67 empty days
    that contradict the plans' own counts. Petra caught it at
    SPEC time by computing the instances, not at build time.
    The pinned rule is base/remainder (base = T ~/ D; the first
    T % D days take one extra chapter; day sizes differ by ≤ 1;
    no empty days). A rule and its totals in the same brief are
    a claim about every instance: compute the extremes before
    the spec files.
47. **In a shared working tree, a commit's file list is part of
    its claim.** Run 11's implementation (17 files, +4,388)
    landed inside the arch-ambient package's records commit
    (79992d8) because sibling packages shared one tree and one
    staging area; the run's own commits (941a150) carry only its
    fix. Provenance survived because the coordinator re-derived
    the payload from `git show --stat` and CI at HEAD before
    sign-off. Before pushing, diff-stat every landing commit
    against the package's filed file list; swept files are
    declared in the ship record, never discovered by the next
    desk.
48. **Fixed-geometry decorative surfaces are a text budget:
    clamp scale inside the art, never the words.** The plan
    cover is exactly 112×144 by spec §10, but ambient-scaled
    text (lesson 21's 1.43 height multiplier) needs ~149dp of
    its 118dp inner height at text scale 2.0 — the spec's
    geometry and its own no-overflow assertion were
    incompatible. The ratified build (gate D-1) clamps text
    scale ≤ 1.0 INSIDE the cover only; the same words render at
    full scale as the card's title and caption outside it. A
    decorative surface may cap its own typography; the
    information it carries must exist unclamped one level up.
## Live search & verification hygiene (search fix package)

49. **Results derived from current state at build cannot go
    stale; results cached per query can.** The Library live
    search is a pure function of the field's current text +
    the loaded datasets + the layer states, re-derived
    synchronously on every build — no debounce, no stored
    result list, no submit step. The per-keystroke tests pin
    the property (Job matches "jo", is gone at "joh", no
    submit anywhere). Rule: when freshness is the feature,
    make staleness structurally impossible instead of
    managing it with timers and invalidation.
50. **A fixture written from memory of another dataset's
    shape parses to empty and impersonates a product bug.**
    DeuterocanonData.parse drops a malformed book whole (by
    design); a fixture with invented minified keys therefore
    yielded zero books, and two model tests failed looking
    exactly like a search-model defect. The model was right;
    the fixture was fiction. Rule: copy fixture shapes from
    a test that parses the same asset, never from the shape
    of a different dataset.
51. **Verify worktrees live under ~/workspace, never /tmp.**
    A /tmp worktree was reaped mid-package; its test runs
    died silently and one "result" was a grep pipeline
    buffering a corpse. The ~/workspace replacement survived
    the whole package. Rule: any tree a verification claim
    rests on lives in durable storage, and a long test run
    writes its log to that same storage.
52. **Spec the pause matrix before building any
    self-running UI.** The ambient stage needed six pause
    conditions (tab invisible, app backgrounded, route
    covering Home, any descendant scrolling, pointer held,
    reduced motion) and every one was cheap because it was
    specced first: a Ticker (muted by TickerMode under
    covering routes, dead with the State) plus plain flags
    for tab/lifecycle/scroll/pointer. One framework fact
    cost a spec correction: a RouteObserver asserts
    `observer.navigator == null`, so one observer cannot
    serve three navigators — it lives on the Home
    navigator only.
53. **Write the lesson-40 translation register into the
    spec, then let the suite correct it.** The register
    said shell STORE-3 would be "kept as-is"; the suite
    proved its Home assertion landmarked the deleted
    panel's title, not Continue reading. The register is a
    hypothesis — suite evidence outranks it, the register
    gets amended with the evidence cited, and no shipped
    assertion is ever dropped silently.
54. **The staged deliverable is the arm64-v8a split — and this
    app's weight is data, not ABIs (arm64 deliverable package,
    Oct 15, 2026).** CI has built `flutter build apk --release
    --split-per-abi` and staged `app-arm64-v8a-release.apk` all
    along; zip inspection of the staged ambient build proves
    `lib/` carries arm64-v8a ONLY (libapp, libflutter,
    libdartjni, libdatastore_shared_counter) — there was never
    a universal APK in the ship path, whatever the ship
    records called it. The 32,076,557 bytes are bundled data,
    measured from the zip listing: cross-reference data.json
    8.5MB, the five translation texts ~24MB, sefaria.json.gz
    4.8MB, conference.json 2.3MB (uncompressed), against
    ~17.5MB of arm64 native libs. Rule: every package stages
    its founder deliverable as the arm64-v8a split APK under
    the package name with the `_arm64_` marker, and every
    ship report states the staged file's ABI contents from a
    zip inspection plus its exact byte size — never an assumed
    "universal." A size claim is a measurement (lesson 27's
    discipline applied to release engineering): Tabs' smaller
    chat-safe files come from their release split builds, and
    Woven Word already ships that form; no ABI savings remain
    to harvest here.
55. **A zip listing has two size columns; quote the compressed
    one — and a baseline that passes retires the flake defence
    (data diet package, Oct 15, 2026).** (a) The package was
    briefed off a table of UNCOMPRESSED asset sizes (24 MB of
    texts, 8.5 MB of cross-references), but the APK zip already
    deflates plain JSON to roughly gzip size: the eight datasets
    sat in the shipped file at 8,643,781 bytes, so pre-gzipping
    at level 9 saved only the level-9 delta (~101–176 KB at the
    APK level) against the source tree's 24,093,479. Any size
    table drawn from `unzip -l` is the Length column lying by
    omission; measure `-lv`'s compressed column or the staged
    file itself (lesson 54's rule, enforced one level deeper).
    (b) The package's local suite failed 3 conference_shell
    tests in 3/3 full runs; the coordinator's same-environment
    pristine-HEAD baseline ran 438/438 GREEN, which retired the
    lesson-41 pre-existing-flake defence and forced the real
    read: the CI log's stack named a latent lifetime bug —
    ShellController async loaders notifying after dispose —
    that the package's added load latency had pushed across
    the teardown line (CI 38819000110 failed identically;
    the fix is a `_disposed` guard after every await in the
    controller's load continuations, after which the identical
    tree runs 446/446 twice). A red delta against a green
    baseline is a regression until the mechanism is named;
    "the file is flaky" is a claim that needs its own baseline
    evidence, every time.
56. **The website is a pipeline output, not a folder — ask the
    server what it publishes before changing anything (Pages
    deploy package, Oct 15, 2026).** Pages served the repo root
    (legacy, branch `main`, path `/`) for the entire Flutter
    era, so the public site stayed the v1 web app while eleven
    board runs shipped to the phone — one `gh api …/pages` call
    named the actual state (build_type legacy, source main /)
    before anything was touched. The fix was switching the
    publisher, not copying files: build_type → workflow, the CI
    web job builds with `--base-href=/woven-word/` (a project
    page lives under its repo path; the placeholder in
    flutter/web/index.html proves nothing — the BUILT
    index.html was inspected and carries the base), and a
    `pages` job deploys the artifact on every app-changing
    push. v1 was preserved by leaving its files untouched at
    the root and flipping the publisher away from them;
    rollback is the same setting reversed. Rule: a served
    surface's source of truth is the host's configuration,
    read live — never the repo layout you assume it serves.
57. **Reduced motion is a construction swap, not a zero
    duration (reader arch package, Oct 15, 2026).** Setting
    an AnimatedSize's duration to zero under reduced motion
    threw "RenderAnimatedSize was mutated in its own
    performLayout implementation" — the size controller
    notifies during layout and re-dirties its own render
    object. The design law's "reduced motion renders final
    states" is a TREE decision: under
    `MediaQuery.disableAnimations` the animated widget
    leaves the tree and the final child renders directly —
    the `WwPageRoute` instant-swap pattern at widget scale.
    It was caught because the reduced-motion toggle was a
    named widget test (ARCH-11), not a manual check: every
    new animated surface ships a reduced-motion test in the
    same package, or the construction ships unverified.
 (Reader arch (records): spec, Petra gate PASS, lesson 56, payroll accrual)
58. **KJV punctuation cannot proxy complete sense (verse-of-day
    quotable package, Oct 15, 2026).** A "must end in terminal
    punctuation" filter was the obvious mechanical test for
    fragments — and measurement killed it: only 83.4% of the
    verses cited by ≥ 20 conference talks end in `.?!`; Matthew
    28:19, John 11:25 and Matthew 7:7 all end in colons. The KJV's
    colons close complete periodic sayings. Any text-shape proxy
    for a judgment property gets validated against a ground-truth
    set (here, citation frequency) before it is adopted, and the
    rejected candidates are recorded in the spec so nobody revives
    them.
59. **Floors beat rank cuts in tie-dense distributions, and the
    signal must be the property itself (verse-of-day quotable
    package, Oct 15, 2026).** The shipped pool ranked by
    cross-reference connections: it admitted hub verses nobody
    quotes (Daniel 9:24: 133 connections, cited by 0 talks) and
    only 49 of its 365 survive a quotability rule. The replacement
    ranks by the property the founder named — citation frequency,
    verses speakers demonstrably reach for — and states an
    eligibility floor (≥ 25 distinct talks) instead of cutting at
    a round size: the citation band is tie-dense at 365 (the cut
    lands at 27 and excludes "Jesus wept.", 25 talks). Pool sizes
    are outcomes of a stated standard (410 core / 483 Jewish),
    never targets to pad or truncate toward.
60. **Prove audit coverage against the shipped rule's candidate
    set, not the analysis file (verse-of-day quotable package,
    Oct 15, 2026).** The curatorial read ran over ranked files
    from an early analysis pass whose citation counts were
    un-deduped (John 3:16 read 241; the shipped rule counts 167
    distinct talks). The pass was only trusted after a
    set-theoretic check: every candidate at the shipped floors
    (504 core, 505 Jewish) appeared in the read set — the counts
    differed, the candidate universe did not. When analysis and
    implementation derive the same set two ways, reconcile the
    sets explicitly before building on either.
61. **Store progress on the smallest unit; derive schedules, never
    store them (study plans v2 package, Oct 15, 2026).** Plan
    progress lives on chapters (startedOn + a done set of chapter
    indices); day schedules are a pure function re-derived on every
    load. Rebalancing every built-in's pacing therefore migrated
    every user's check marks with zero migration code and zero
    loss — percent and current day recompute against the new
    derivation. A stored schedule strands progress the first time
    pacing changes.
62. **A backup that omits a store the same package creates breaks
    the file's promise (study plans v2 package, Oct 15, 2026).**
    When a feature creates user content, its definitions join the
    backup export/import in the SAME package, behind the strict
    validator: a malformed member rejects the whole import and
    writes nothing, and backups predating the member import as
    before, leaving the new store untouched. Custom plan
    definitions scoped to on-device only would have been silently
    destroyed by the first backup restore.
63. **Verify an arithmetic superlative against every instance, not
    the famous one (study plans v2 package, Oct 15, 2026).** The
    producer brief asserted the heaviest non-Psalm-119 day as 80
    verses; the gate's independent recomputation over the full
    corpus found Numbers 7 alone at 89, 1 Chronicles 6 at 81,
    Luke 1 at 80, and the heaviest multi-chapter day at 71. Any
    largest/smallest/first claim that ships in a spec gets
    recomputed over the whole dataset, never spot-checked against
    the well-known case.
64. **A CI job that fails in seconds with zero steps is
    infrastructure, not code (study plans v2 package, Oct 15,
    2026).** The integrated branch run showed pages: failure —
    0 steps, 2 seconds — while android/web/ios passed: the
    github-pages environment blocks branch deployments. Before
    treating a red job as a code failure, check its step count
    and duration, and compare against a known-good run of the
    same workflow (main's runs deploy pages with 6 steps).
