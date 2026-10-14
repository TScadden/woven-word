# Decision: Intro rethink — static first-run intro, silent launch thereafter (2026-10-14)

**Status: RATIFIED by Silas (Producer), Oct 14, 2026.** Working paper:
`2026-10-14-intro-rethink-draft.md` (Jude's research + recommendation).
Founder direction that opened this package (Oct 14, 2026): "I'm thinking
maybe we change the intro to something else. Maybe not even an animation
then swipe up. Maybe just a normal intro screen. Have the team do some
research on other apps then name a decision."

## The decision — option (c)
1. **Every launch: system splash only.** Black stage background
   (`WwColors.stage`) with the settled app icon, no in-app animation,
   dismissed at first frame. Returning users go straight to content /
   restored position. No gate, no swipe, no show.
2. **First run only:** one static intro screen — black stage, app icon,
   "Woven Word" wordmark, one plain line about the cross references, and
   a ≥48dp **Begin reading** button. Persisted `intro_seen` flag;
   user-paced, never auto-advances, never repeats. The founder's swipe-up
   becomes an accessible button.
3. **The package-1 sequence (typewriter → dust → slide) is RETIRED** —
   not refined, not kept behind a flag. Its code stays recoverable in git
   history (`4dee005`, `998c1fe`, `00335f9`).

## Research summary (Jude, Phase A — sources in the draft)
- Category: **0 of 5** leading Bible apps (YouVersion, Logos, Blue Letter
  Bible, Dwell, Gospel Library) open every launch with a timed brand
  animation. Four go straight to content; Dwell spends its brand effort
  once, on a first-run onboarding flow. Gospel Library's official guides
  state returning users resume where they left off.
- Platform guidance: Apple HIG *Launching* — launch instantly, downplay
  the launch experience, if a splash is needed put it at the start of
  onboarding. Android Developers *Splash screens* — system splash only,
  animated icon ≤1,000ms, dismiss at first frame, keeping a custom splash
  for branding produces a double splash. Material launch guidance —
  branded launch is momentary exposure while loading; avoid animation.
- Measured defect in the status quo: the current sequence runs ≈4,186ms
  unskippable on EVERY launch in front of a blank home, and the native
  layers in front of it are still white Flutter defaults (white flash →
  black stage → 4.2s show → blank home, plus Android 12+'s own splash).

## Ratification calls on Jude's open questions
1. **Retire package 1 sight-unseen: YES.** The founder reopened the
   concept; spending a verification cycle on a sequence the research,
   both platforms, and the founder all point away from buys nothing.
   Lesson #8's cost is recorded honestly below.
2. **Sequencing: build now, verify with the home package.** The build is
   unblocked in this board run (P2 has landed). Founder phone
   verification of the intro batches with the home redesign, so he
   verifies it against a real landing screen, per Jude's recommendation.

## Consequences for team memory
- Lessons #5 (ash, not confetti) and #6 (~150ms typing floor): KEPT with
  narrowed scope — verified craft knowledge governing dust/typing
  wherever they ever appear, not a mandate for an every-launch sequence.
- Lesson #9 (gate checks numbers against lessons): survives intact.
- Lesson #8: the WP1 Flutter implementation never completed founder
  phone verification; its implementation-specific feel claims stay
  unverified, permanently. Accepted.
- The five `WwColors.ash*` tokens lose their only consumer in this
  package and are removed with it — no dead tokens.
