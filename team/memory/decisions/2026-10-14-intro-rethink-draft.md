# DRAFT Decision — Intro / Launch Treatment Rethink (P3, Phase A)

- **Status: DRAFT — not ratified.** Written by Jude (Motion Designer),
  2026-10-14, for Silas to ratify or amend. No app code was changed for
  this draft. The build phase starts only on Silas's go-ahead, after the
  P2 token package lands.
- **Founder direction (Oct 14, 2026):** the intro may change entirely;
  maybe not an animation followed by a swipe up at all; maybe just a
  normal intro screen; the team is to research other apps and name a
  decision.
- **Question decided here:** what does a user see between tapping the
  Woven Word icon and being able to read scripture — on first run, and
  on every later launch?

---

## 1. Where we start: the package-1 sequence, measured from code

Source: `flutter/lib/screens/splash_screen.dart` at HEAD (commits
`4dee005`, `998c1fe`, `00335f9`).

| Phase | Duration |
|---|---|
| Typewriter, "Woven Word", seeded schedule (sum stated in code) | 1,516 ms |
| Hold | 320 ms |
| Dust erosion (48 strips, up to ~3,000 ash particles) | 1,850 ms |
| Home slides up | 500 ms |
| **Total, every launch, before Home is settled** | **≈ 4,186 ms** |

Facts that matter for the decision:

- It runs on **every** launch, not just the first. There is no
  first-run / returning-user distinction and no skip.
- It **gates content**: Home does not exist for the user until the
  sequence finishes. The content it gates is, today, a blank
  `HomeScreen` (founder direction, Oct 13) — 4.2 seconds of motion to
  arrive at an empty screen.
- Its durations (1,850 / 500 / 320 ms, 530 ms caret blink) sit outside
  the design-audit allowed duration set (§8: {220, 300, 350, 400, 450,
  650, 900, 1100} plus named exceptions). It predates the audit
  adaptation and was never reconciled to it.
- Reduced motion is the one part already audit-clean: with
  `MediaQuery.disableAnimations` the gate jumps straight to Home.
- **There is a launch seam in front of it.** The native layers are
  still Flutter defaults: Android `launch_background.xml` is a white
  layer-list and the iOS `LaunchScreen.storyboard` is a white screen
  with the stock LaunchImage. On Android 12+ the system also imposes
  its own splash (icon on the theme window background). So the real
  launch today is: white / system flash → black stage → typewriter →
  dust → slide → blank home. Two splashes, opposite colours, then a
  timed show.

---

## 2. Research

Method note, stated plainly: none of the five reference apps publishes
its splash duration, and I could not establish exact launch timings
from public sources for any of them. Where a timing cannot be
established I say so. What public sources *do* establish is what the
documented first screen is, what a first run asks for, and whether any
timed brand animation is part of the described experience at all. In
every category case below, the documented opening is content or an
account step — never a timed animation the user watches.

### 2.1 The category

**YouVersion (Bible App, Life.Church)**
- Documented opening is a content Home feed: Verse of the Day, plans,
  and a home feed of friends' bookmarks/highlights (YouVersion blog;
  Google Play listing).
- No timed wordmark/brand animation is documented anywhere I could
  find. Exact splash behaviour and duration: **not established**.
- First-run vs returning: the app's described experience is the Home
  feed in both cases; account creation is tied to social/plan
  features, not presented as a launch gate in the sources found.

**Logos (Faithlife)**
- The official "Getting Started with the Logos Mobile App" walkthrough
  orients the user to where tools and resources live — it teaches the
  app's workspace, not a launch show (Logos User Ed, YouTube; Logos
  support / help centre).
- The one real first-run gate is **sign-in**: Logos is an account
  library product, and its getting-started material is built around
  logging in with the same account used elsewhere so the library syncs
  (logos.com get-started pages). That is an account gate, not a brand
  moment.
- A splash + "preparing your library" sequence is attested for Logos
  **desktop** in support forums — desktop evidence, not mobile, and I
  am not counting it as a mobile finding. Mobile splash duration:
  **not established**.

**Blue Letter Bible**
- Store listing and support pages describe a study tool that starts
  from a passage/search: 15+ Bibles, interlinear, lexicon,
  Treasury of Scripture Knowledge cross-references (Google Play
  listing; blb.org app support).
- No onboarding or brand animation is documented. Exact splash
  behaviour and duration: **not established**.

**Dwell (audio Bible)**
- The category's clear exception, and it proves where brand treatment
  actually lives: Dwell's *first run* is a designed onboarding and
  trial flow — personalisation (voice, version, music) and a 7-day
  trial / subscription offer (dwellapp.io; store listings).
- Returning use is described in reviews as straight to listening
  content organised in tabs: Plans, Passages, Playlists, Library
  (Christian Chronicle review). The brand moment is a first-run
  onboarding, not an every-launch animation. Launch splash duration:
  **not established**.

**Gospel Library (Church of Jesus Christ)**
- The strongest documentary evidence in the set. The official user
  guides (iOS and Android, churchofjesuschrist.org) state that the
  first time you open the app you see the Home section, with its
  bottom bar, quick links to the scriptures and the current
  *Come, Follow Me* lesson, and a daily verse.
- Returning behaviour is also documented: the app remembers where you
  were so you can pick up where you left off.
- Sign-in is **not** a launch gate: it lives in Settings, is optional,
  and exists to sync annotations. No brand animation is mentioned in
  the guide at all. Splash duration: **not established** — and the
  guide's silence, for an otherwise step-by-step document, is itself
  the finding: the opening is Home.

**Category verdict:** 0 of 5 documented apps open every launch with a
timed brand animation. 4 of 5 go to content. The 1 exception (Dwell)
spends its brand effort once, on first-run onboarding. Woven Word's
current sequence is not the category norm; it is outside it.

### 2.2 Outside the category

- **Gmail on Android 12+ (Google's own example).** Android's splash
  documentation and 9to5Google's coverage show an animated icon that
  plays *while the app loads*, with the inbox arriving as the
  animation completes. The animation covers real load time; it does
  not add time after it. (Sources: Android Developers, *Splash
  screens*; 9to5Google, Android 12 animated splash gallery.)
- **Netflix "tudum".** Mobbin's launch-screen reference cites it as
  the good version of a motion logo: brief, subtle, a media brand
  whose sound/mark is the product's own signature. It is the famous
  exception, and it is seconds-shorter than our sequence and attached
  to playback, not to a tool the user opens repeatedly to look
  something up. (Source: Mobbin, *Launch Screen UI Design* glossary.)
- **(Not Boring) Weather.** Same Mobbin reference: a launch animation
  lasting ~8 seconds exists — and it is **skippable**, which Mobbin
  notes is extremely rare in practice. Long is only defensible when
  the user can leave it. Ours cannot be skipped.
- **Google Play Instant guidance (Android Developers).** For instant
  launches Google instructs developers not to create additional
  splash screens of their own, because the system launch experience
  already carries branding, title, and icon, and an added one reads as
  redundant.

### 2.3 Platform guidance

**Apple — Human Interface Guidelines, *Launching***
(developer.apple.com/design/human-interface-guidelines/launching;
the direct fetch failed in this session, so this section summarises
the HIG text as reproduced in the HIG reference mirrors returned by
search — the substance is consistent across all of them.)

- Launch should feel instant; people may not want to wait more than a
  couple of seconds.
- Downplay the launch experience. A launch screen is not onboarding,
  not a splash screen, and not an opportunity for artistic expression.
- Design the launch screen to be nearly identical to the app's first
  screen; if the app opens on a solid colour, the launch screen
  should be only that solid colour.
- Avoid text on the launch screen; do not include logos or other
  branding unless they are a fixed part of the first screen; do not
  advertise.
- If a splash screen is needed, put it at the **beginning of the
  onboar
...[truncated 7381 chars]