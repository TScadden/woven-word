# Decision: The website serves the Flutter build, deployed by CI (2026-10-15)

Founder, Oct 15, 2026: "I think we need to update the website version
to match the phone version. Don't resize it. I want to see what this
looks like on laptop."

## Before

GitHub Pages was configured `legacy`, source = branch `main`, path
`/` — it served the repo root, which is the original v1 web app
(`index.html`, `app.js`, `data.json`, …). The Flutter web target was
only a CI compile check (the flutter.yml web job said so in its own
step name), so the public site stayed v1 through every board run.

## After

- Pages `build_type` is `workflow`. The `web` job in
  `.github/workflows/flutter.yml` builds
  `flutter build web --release --base-href=/woven-word/` (a project
  page lives under `/woven-word/`; the built `index.html` was
  inspected and carries `<base href="/woven-word/">`), and a new
  `pages` job deploys that artifact via configure-pages /
  upload-pages-artifact / deploy-pages on every app-changing push
  to `main`. No manual copies: the deploy is a pipeline step.
- The app renders at the browser's full viewport, as Flutter web
  does — no phone-width resizing or reframing (founder's words).
- Post-data-diet assets are web-safe by construction and verified
  in the built output: the eight `*.json.gz` datasets sit in
  `build/web/assets/assets/` and the loaders inflate them with
  package:archive's GZipDecoder via rootBundle (no dart:io).

## v1 preservation

The v1 web app is NOT deleted. Its files remain untouched at the
repo root (`index.html`, `app.js`, `build_data.py`, `data.json`,
`kjv.json`, `kjv_raw.json`, `web.json`, `eng-web_vpl.txt`,
`web_vpl.zip`, `manifest.json`, `icon-512.png`,
`cross_references.txt`), in git history and in place; the README
now labels them the v1 archive. Rolling the site back to v1 is
one Pages setting: source back to legacy `main` `/`.

## Ship-checklist change (standing)

A package that changes the app is not fully shipped until the
"Build Flutter app" run on the landed tree is green INCLUDING its
`pages` job — the website refresh is part of shipping, verified
from the run, not assumed from the push. This sits alongside the
Android-only deliverable rule
(`2026-10-15-android-deliverable-only.md`): the founder still
receives only the Android arm64 APK file; the website is a
publication channel, never a deliverable, and iOS stays a CI
compile check until he asks for it.

Payroll: none — release infrastructure, per the fix-package
precedent.
