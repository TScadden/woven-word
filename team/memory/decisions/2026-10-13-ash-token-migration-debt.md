# Tracked debt — ash palette tokens (Oct 13, 2026)

From Petra's WP1 QC gate, judgment call (a): conditional accept.

The five ash palette constants (ash[0..3] + goldTint) live as named,
centralized constants inside `_DustScene` in
`flutter/lib/screens/splash_screen.dart`. The tokens-only rule (tokens
live in `lib/theme/ww_theme.dart` only) is NOT waived.

**Binding condition:** before the next package that touches the splash
or the theme — and no later than the home-redesign package — Maren
migrates the five constants into `WwColors` and the splash references
the tokens. If the migration has not landed by then, this becomes a
Blocker at that package's gate.

Palette note: black/cream/gold is KEPT for the opening sequence
(Petra, palette owner, WP1 gate — contrast passes with wide margins on
the black stage; the ash effect is derived from #000000). Revisit
trigger: the home-redesign package, where palette gets a full token
contrast audit as its own package item.

## CLOSED — Oct 13, 2026

Maren migrated the five constants into `WwColors` in
`flutter/lib/theme/ww_theme.dart`, in a new commented group
`// Splash ash — dust dissolve palette` (lines 42–49):
`ashLight` = 0xFFC9BBA3, `ash` = 0xFFA79B84, `ashMid` = 0xFF8A8071,
`ashDeep` = 0xFF6E675C, `ashGold` = 0xFFD8C49A — hex values byte-identical
to the former local constants, order preserved.

`flutter/lib/screens/splash_screen.dart` now consumes the tokens
everywhere those colours were used: the caret particles and the rare
particle tint use `WwColors.ashGold`, and particle colour selection
indexes a const list of `WwColors.ashLight / ash / ashMid / ashDeep` in
the original order. The local constants (`_DustScene.ash` and
`_DustScene.goldTint`) are removed entirely. Zero behaviour change.

Verify (Maren, from `~/workspace/woven-word/flutter`, local SDK):
`flutter analyze` — No issues found; `flutter test` — All tests passed
(5/5); `flutter build web --release` — ✓ Built build/web.
