# Data diet — ship record (Oct 15, 2026)

**Shipped.** The eight bundled JSON datasets now ship gzipped
and inflate in the data layer; behavior is byte-identical
(proven, below). The deliverable is 31,953,485 bytes — and this
record leads with the honest number: **the APK shrank by
123,072 bytes, not by the source tree's 24,093,479**, because
the APK zip already deflated the plain assets (see the spec's
measurement section; lesson 55a). The founder's truncation
problem is a transport problem at any size in this range; the
release channel remains the verified route, and the XZ lever
(~2.1–2.3 MB more, measured per-file at xz -9e) is recorded in
the spec for a founder ruling.

## Deliverable

- APK: `build-data-diet/woven_word_data_diet_arm64_20261015.apk`
  — **31,953,485 bytes** (was 32,076,557; Δ −123,072), from CI
  run 38820853425's artifact, SHA-256
  3e2c7cfaf300dea9254123115872b586314b602e1cb256bc09a55ae04d441ecf.
- ABI (zip inspection): arm64-v8a ONLY (libapp, libflutter,
  libdartjni, libdatastore_shared_counter). The `_arm64_`
  marker per lesson 54.
- Signer: V2 certificate SHA-256
  `05d5a45cf52fd141a54e2ecfd00472a568c9c0bdffd0458e44ba52bfe4b5be11`
  from the CI print step — the pinned fingerprint.
- Release: uploaded to `flutter-apk-latest` as
  `woven_word_data_diet_arm64_20261015.apk`, listed size
  31,953,485 — matches the staged file.

## Asset table (measured)

Source files (Boaz; gate re-derived):

| asset | raw | .gz | ratio |
|---|---|---|---|
| data.json | 8,504,484 | 2,104,273 | 0.247× |
| hebrew.json | 5,426,198 | 1,317,653 | 0.243× |
| webc.json | 4,672,408 | 1,388,280 | 0.297× |
| kjv.json | 4,219,564 | 1,216,510 | 0.288× |
| web.json | 4,169,532 | 1,206,799 | 0.289× |
| jps.json | 3,276,049 | 932,709 | 0.285× |
| conference.json | 2,284,735 | 359,160 | 0.157× |
| confessions.json | 83,129 | 17,236 | 0.207× |
| **total (8)** | **32,636,099** | **8,542,620** | **0.262×** |

In the APK (zip compressed column): the eight sat at 8,643,781
bytes before, 8,520,370 after. Assets total in the source tree:
37,552,363 → 13,458,884. Sefaria untouched (its level-9
recompress measures 4,848,290 vs the shipped 4,848,303 — no
gain); deuterocanon and webc_books untouched (below meaningful
size).

## Byte equality & behavior

- `test/bundled_assets_test.dart`: each shipped .gz inflates
  to exactly the recorded pre-change length + SHA-256 (8/8;
  gate mutation-verified — one flipped byte fails exactly one
  asset's test).
- Loaders parse deep-equal on fixed fixtures pre/post (gate);
  parsing code after inflation is untouched; required-pair
  throws / optionals-null semantics preserved. All existing
  data behavior (verse lookups, the 3 John clamp, search,
  plans, verse of the day, conference browse) rides the
  unchanged parsers over identical bytes.
- Load time (workstation VM, archive decoder, min of 3): data
  71 ms, kjv 21, web 31, jps 39, hebrew 58, webc 54,
  conference 16, confessions 0.2 — all inside the compute
  isolates that already parse these payloads; nothing new on
  the main thread, cold start structurally unchanged (spec).

## Verification & the fix round

- Desks: analyze clean; Petra gate PASS (data-diet-gate.md).
- First landing (45930af): local suite 443+3 in 3/3 runs —
  conference_shell dispose-race tests. The coordinator's
  same-environment pristine-HEAD baseline ran **438/438
  green**, retiring the flake defence; CI 38819000110 failed
  identically, and its log named the mechanism: *"A
  ShellController was used after being disposed"* from
  `ensureDeuteroLoaded`'s continuation — a latent lifetime bug
  the package's added load latency pushed across teardown.
- Fix (a5b1748): a `_disposed` flag
  set first in `ShellController.dispose()`, checked after
  every await in the controller's load continuations (36
  guard checks, one file, +58/−5) — written from the stack + a
  line-by-line audit; live behavior unchanged (no test
  modified). After the fix: local suite **446/446 twice**
  (438 shipped + 8 equality), conference_shell standalone
  10/10, parity harness 72/72 on the data layer.
- **Final CI: run 38820853425 — SUCCESS** (android, web, iOS)
  on head a5b1748.

## Commits

20c1c55 assets · 3fef873 app · 45930af tests · a5b1748 fix ·
this records commit (spec, gate, report, lesson 55).

## Payroll

No feature fee: a delivery fix of shipped features, per the
ledger's standing precedent for fix packages. The
use-after-dispose repair ships inside this package as part of
the fix round, not as a separate feature.
