# Woven Word

Every connection in the Bible, woven into one web — and readable.

Woven Word takes the famous arc picture of Bible cross references and makes it
something you can explore and read:

- **The Web** — all 344,799 cross references drawn as arcs over the 1,189
  chapters of the Bible, Genesis to Revelation. Colors run by distance, the
  way the classic visualization does: near connections glow blue and purple,
  far ones sweep gold and red.
- **Tap any chapter** — its arcs light up, with its strongest partner chapters
  listed. Tap one to travel the thread.
- **Read it like Gospel Library** — a clean serif reading view. Verses with
  connections carry a small marker; tap any verse to open its connections and
  jump straight to the connected passage, text included.
- **Your study, on your device** — create local profiles (no account, no
  server), highlight verses in five colors, and attach notes. Everything is
  stored in your browser's local storage, per profile.

## Live site

[tscadden.github.io/woven-word](https://tscadden.github.io/woven-word/) serves
the **Flutter app** (the same build as the phone app), deployed by GitHub
Actions: every app-changing push to `main` rebuilds the web target from
`flutter/` and publishes it to GitHub Pages (the `pages` job in
`.github/workflows/flutter.yml`).

The files at this repo's root (`index.html`, `app.js`, `data.json`,
`kjv.json`, `web.json`, `manifest.json`, `icon-512.png`) are the **original
v1 web app**, preserved in place for the record. They are no longer served;
the v1 build steps below apply to that archive only.

## Data and credits

- Cross references: [OpenBible.info](https://www.openbible.info/labs/cross-references/)
  (CC BY), built on the Treasury of Scripture Knowledge (public domain).
- Scripture texts, both public domain: King James Version, and the World
  English Bible (via [ebible.org](https://ebible.org)). Woven Word ships
  only copyright-free texts; switch translations at the top of any chapter.
- Inspiration: Chris Harrison and Christoph Römhild's Bible cross-reference
  visualization.

## Build (v1 archive)

`data.json` and `kjv.json` are generated from the source files:

```
python3 build_data.py   # cross_references.txt -> data.json
```

Then serve the folder statically. (This reproduces the archived v1 app;
the current app builds from `flutter/` — `flutter build web --release
--base-href=/woven-word/` is exactly what CI deploys.)

## License

MIT for the code. Data licenses above.
