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
