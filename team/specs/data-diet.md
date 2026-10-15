# Data diet — bundled JSON ships gzipped (Oct 15, 2026)

## Why

The staged founder APK measured 32,076,557 bytes, and the founder's
chat downloads truncate files at random sizes (10.47 MB, then 5.37 MB
on Oct 15, 2026), while his Tabs APKs (~28 MB) arrive fine. He asked
for "APKs like that." Lesson 54 established the deliverable was
already the arm64-v8a split; this package works the remaining lever:
the bundled data.

## The measurement the package stands on (Boaz, from the zip)

The staged build's own zip listing (`unzip -lv`, compressed column)
shows where the bytes actually sit in the file:

- libflutter.so 11,747,864 (stored) + libapp.so 5,637,000 (stored)
  + small libs ≈ 17.5 MB of binaries.
- sefaria.json.gz 4,806,220 (already compressed; a level-9
  recompress of its 37,066,259 raw bytes measures 4,848,290 —
  no gain; left byte-untouched).
- The eight plain JSON assets, deflated BY THE ZIP ITSELF:
  data.json 2,107,761; webc 1,404,592; hebrew 1,355,847;
  kjv 1,232,120; web 1,220,900; jps 944,421; conference 360,716;
  confessions 17,424 — 8,643,781 total in the file.

**Honesty note, stated before the build:** the asset files' raw
sizes (32.6 MB across the eight) are NOT what the APK carries —
the APK zip already deflates plain assets to roughly gzip size.
Pre-gzipping at level 9 therefore saves only the level-9 delta
against the zip's normal deflate pass: ~101 KB at the APK level
(gz sums below minus the zip's own further ~1% squeeze on stored
gzip streams, cf. sefaria). The source tree shrinks 24,093,479
bytes; the deliverable shrinks by the small delta. Both numbers
belong in the ship record; neither is dressed up as the other.

## What shipped

- Eight assets compressed with `gzip -9 -n` (deterministic, no
  stored name/timestamp): data, kjv, web, jps, hebrew, webc,
  conference, confessions → `assets/<name>.json.gz`; the raw
  `.json` files are removed. Sefaria (already gz), deuterocanon
  (1,239 B), webc_books (4,508 B), and the app icon are untouched:
  below any meaningful size, or already compressed.
- Data layer: new `lib/data/bundled_gzip.dart` —
  `inflateBundledJson` (package:archive `GZipDecoder`, chosen over
  dart:io's `GZipCodec` so decoding is platform-uniform including
  web, where dart:io is unavailable) plus rootBundle byte loaders.
  The four loaders (scripture_text, bible_data, conference_data,
  confession_data) load bytes and inflate inside the same compute
  isolate that parses — the exact shape `SefariaData.load`
  established. Parsing code after inflation is untouched;
  failures-as-values semantics preserved (required pair throws,
  optionals return null).
- Byte-equality is proven, not spot-checked:
  `test/bundled_assets_test.dart` inflates every shipped .gz and
  asserts length + SHA-256 against the pre-change recorded values
  for all eight files; Boaz's pipeline verification and Petra's
  gate independently re-derived the same hashes from the files.
- Pipeline discipline: `tools/compress_assets.py` is the standing
  finalizer — any data pipeline run ends by re-gzipping these
  assets (verify-by-inflate + hash, idempotent, prints the byte
  table), so a future dataset rebuild cannot silently restore
  the uncompressed form.
- Load-time cost (workstation VM, min of 3, archive decoder):
  data 71 ms, kjv 21, web 31, jps 39, hebrew 58, webc 54,
  conference 16, confessions 0.2 — ~291 ms if every payload were
  inflated serially, which never happens: cold start inflates
  data + KJV/WEB (~124 ms) inside the isolate calls that already
  parse those payloads, and each layer dataset inflates lazily
  with its layer, the pattern the app already pays for Sefaria's
  37 MB. No new main-thread work; no visible cold-start change.

## Asset table (source files)

| asset | raw bytes | .gz bytes | ratio |
|---|---|---|---|
| data.json | 8,504,484 | 2,104,273 | 0.247× |
| hebrew.json | 5,426,198 | 1,317,653 | 0.243× |
| webc.json | 4,672,408 | 1,388,280 | 0.297× |
| kjv.json | 4,219,564 | 1,216,510 | 0.288× |
| web.json | 4,169,532 | 1,206,799 | 0.289× |
| jps.json | 3,276,049 | 932,709 | 0.285× |
| conference.json | 2,284,735 | 359,160 | 0.157× |
| confessions.json | 83,129 | 17,236 | 0.207× |
| **eight total** | **32,636,099** | **8,542,620** | **0.262×** |
| assets total (incl. untouched) | 37,552,363 | 13,458,884 | 0.358× |

## Follow-up lever left for a founder decision (not taken)

An LZMA-class codec (package:archive also ships an XZ decoder)
on the same payloads measures materially smaller than gzip on
this data and would take the deliverable down by roughly another
1.5–2.5 MB; it was NOT taken because the brief fixed gzip (the
Sefaria precedent) and the swap deserves its own ruling. The
archive dependency this package added makes it a small step
if the founder wants it.
