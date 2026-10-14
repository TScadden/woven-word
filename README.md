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

## Data and credits

- Cross references: [OpenBible.info](https://www.openbible.info/labs/cross-references/)
  (CC BY), built on the Treasury of Scripture Knowledge (public domain).
- Scripture texts, both public domain: King James Version, and the World
  English Bible (via [ebible.org](https://ebible.org)). Woven Word ships
  only copyright-free texts; switch translations at the top of any chapter.
- Inspiration: Chris Harrison and Christoph Römhild's Bible cross-reference
  visualization.

## Build

`data.json` and `kjv.json` are generated from the source files:

```
python3 build_data.py   # cross_references.txt -> data.json
```

Then serve the folder statically (GitHub Pages works as is).

## License

MIT for the code. Data licenses above.
