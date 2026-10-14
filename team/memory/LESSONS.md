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
