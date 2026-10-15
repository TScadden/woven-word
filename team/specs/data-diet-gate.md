# Data diet — Petra gate: PASS (Oct 15, 2026)

Read-only gate on the package tree (base af83aae + both desks'
work). No code edited by the gate. Every claim re-derived from
the artifact, none taken from the desks' reports.

## Claims

1. **Eight assets gzipped; loaders inflate in the parse
   isolates — VERIFIED.** Disk state exact (8 plain .json gone,
   8 .json.gz present, sefaria/deuterocanon/webc_books/icon
   untouched). Loaders resolve the .gz paths; parse logic after
   inflation untouched; failures-as-values preserved (required
   pair throws, optionals null); the only lib importer of the
   new bundled_gzip helper is the four data loaders.
2. **Byte equality — VERIFIED independently.** The gate
   re-inflated all eight files itself: every length and SHA-256
   matches the recorded pre-change table exactly. The shipped
   equality suite passes 8/8 in the gate's own run and fails
   under mutation (one flipped content byte → exactly that
   asset's test fails).
3. **Totals — VERIFIED.** Eight raw 32,636,099 → gz 8,542,620;
   assets total 37,552,363 → 13,458,884.
4. **Diff discipline — VERIFIED.** Zero diff in screens (at
   gate time), theme, tokens, or any visual file; zero diff in
   stores/user data; pubspec carries exactly the archive
   dependency + the eight asset swaps. PARSE-IDENTICAL: each
   loader's parse output on a fixed fixture is deep-equal
   pre/post package.
5. **Measurement honesty — VERIFIED.** From the staged ambient
   APK's own zip listing: the eight assets sit in today's file
   at 8,643,781 bytes total (the zip deflated them), so the
   APK-level saving of pre-gzipping is the level-9 delta
   (~101–176 KB), NOT the source tree's 24,093,479. The spec
   states both numbers; the ship record must too.

## Notes (non-blocking)

- `tools/compress_assets.py` output is byte-identical to CLI
  `gzip -9 -n`; its idempotence and hash verification check out.
- Web build verified green with the .gz assets in build output;
  the archive decoder keeps web runtime decoding working
  (dart:io would not).
- The gate predates the fix round (ShellController disposed
  guards). That change is non-visual, outside every claim
  above, and is verified by the suite record in the ship
  report; this PASS stands for the package's substance.

**Verdict: PASS, no fix items.**
