# Ship record — Pages deploy: website serves the Flutter build

Package: Boaz (release engineering), Silas producing.
Founder direction (Oct 15, 2026): "I think we need to update the
website version to match the phone version. Don't resize it. I
want to see what this looks like on laptop."
Decision record: `team/memory/decisions/2026-10-15-pages-flutter-web-deploy.md`
Lesson: 56.

## What changed

- GitHub Pages: `build_type` legacy (source `main` `/`, serving
  the repo root = the v1 web app) → **`workflow`**, flipped via
  the Pages API immediately before the landing push.
- `.github/workflows/flutter.yml` (commit `469a83c`):
  - `web` job now builds `flutter build web --release
    --base-href=/woven-word/` (was a bare compile check whose
    step name still said Pages serves v1).
  - New `pages` job (needs `web`): download-artifact →
    configure-pages → upload-pages-artifact → deploy-pages,
    permissions pages:write + id-token:write, concurrency group
    `pages`. Every app-changing push to `main` now redeploys
    the site as a pipeline step.
- README: new "Live site" section; root files labeled the v1
  archive.
- v1 preserved: all root files untouched, in place and in git
  history; rollback = Pages source back to legacy `main` `/`.

## Pre-flight (local, worktree at origin/main 2532f4a)

- `flutter build web --release --base-href=/woven-word/` green;
  built `index.html` inspected: `<base href="/woven-word/">`.
- `build/web` contains flutter_bootstrap.js, main.dart.js,
  flutter_service_worker.js, version.json, and all eight
  gzipped datasets under `assets/assets/` (data, kjv, web,
  jps, hebrew, webc, conference, confessions .json.gz).
- Loaders are web-safe: rootBundle + package:archive
  GZipDecoder (`lib/data/bundled_gzip.dart`), no dart:io.

## Ship verification

- CI "Build Flutter app" run **38825078669** on head
  **469a83c**: **success** — jobs web ✓, android ✓, ios ✓,
  pages ✓ (deploy included).
- Pages API after the run: `build_type: workflow`,
  `status: built`, html_url https://tscadden.github.io/woven-word/.
- Live fetches from the deployed site:
  - `/woven-word/version.json` →
    `{"app_name":"woven_word","version":"1.0.0","build_number":"1","package_name":"woven_word"}`
    — a file only a Flutter web build emits; byte-identical to
    the local build's. v1 has no such file.
  - `/woven-word/flutter_bootstrap.js` → the genuine Flutter
    web loader (main.dart.js entrypoint, base-URI aware).
  - `/woven-word/assets/assets/data.json.gz` → HTTP 200,
    binary payload (text extraction n/a — the expected shape
    for a .gz at exactly the path rootBundle requests).
  - The root URL returns HTTP 200; its body is the Flutter
    shell (script-only, no extractable text), as built.
- Remaining visual confirmation: a rendered screenshot of the
  live site at laptop width (founder asked to see it; taken
  from Rusty's browser, not CI).

## Standing rule landed with this package

Website refresh is part of shipping: a package that changes
the app is not fully shipped until the "Build Flutter app" run
on the landed tree is green including its `pages` job
(decision record + lesson 56). Founder deliverable unchanged:
Android arm64 APK only; the website is a publication channel.

Payroll: none (release infrastructure).
