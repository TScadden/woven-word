#!/usr/bin/env python3
"""Compress bundled data assets to .json.gz -- the standing finalizer.

Why: APK size discipline (data-diet package, Oct 15 2026). The bundled
JSON datasets are large and highly compressible (roughly 3-4x), so the
app ships them gzipped instead of raw. Any data pipeline run that
regenerates these assets must end with this script, so raw .json files
never creep back into flutter/assets/ and bloat the APK again.

Loaders expect .json.gz: lib/data/bundled_gzip.dart inflates the bundled
gzip assets at load time, so the .json.gz files written here are the
canonical on-disk form the app reads.

Behaviour:
  For each of the 8 asset names below:
    * If flutter/assets/<name>.json exists, write
      flutter/assets/<name>.json.gz via Python gzip (compresslevel=9,
      mtime=0, no stored filename -- deterministic output), verify by
      decompressing the .gz and comparing its SHA-256 to the source,
      then remove the raw .json. The raw file is never removed unless
      verification passes.
    * If only the .gz exists, verify that it inflates and report its
      size (no changes made).
  Prints a before/after byte table.

Idempotent: a second run changes nothing -- with no raw .json present
it only verifies the existing .gz files and reports them.
"""

from __future__ import annotations

import gzip
import hashlib
import sys
from pathlib import Path

# The 8 compressible bundled datasets (base names, without extension).
ASSET_NAMES = [
    "data",
    "kjv",
    "web",
    "jps",
    "hebrew",
    "webc",
    "conference",
    "confessions",
]

# Repo root is the parent of tools/, regardless of the caller's cwd.
REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "flutter" / "assets"


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def main() -> int:
    if not ASSETS_DIR.is_dir():
        print(f"error: assets directory not found: {ASSETS_DIR}", file=sys.stderr)
        return 1

    rows = []  # (asset, before_bytes, after_bytes, status)
    failures = 0
    changes = 0

    for name in ASSET_NAMES:
        raw_path = ASSETS_DIR / f"{name}.json"
        gz_path = ASSETS_DIR / f"{name}.json.gz"

        # "Before" is what is on disk at entry: the raw file if present,
        # otherwise the already-compressed file.
        before = file_size(raw_path) if raw_path.exists() else file_size(gz_path)

        if raw_path.exists():
            source = raw_path.read_bytes()
            source_hash = sha256_hex(source)

            # Deterministic gzip: level 9, mtime 0, no stored filename.
            with open(gz_path, "wb") as fh:
                with gzip.GzipFile(
                    filename="", mode="wb", compresslevel=9, mtime=0, fileobj=fh
                ) as gz:
                    gz.write(source)

            # Verify before deleting anything: inflate and compare hashes.
            with gzip.open(gz_path, "rb") as gz:
                inflated = gz.read()
            if sha256_hex(inflated) != source_hash:
                print(
                    f"error: verification failed for {name}.json.gz "
                    f"(decompressed SHA-256 != source); raw file kept",
                    file=sys.stderr,
                )
                failures += 1
                rows.append((f"{name}.json", before, file_size(gz_path), "FAILED - kept raw"))
                continue

            raw_path.unlink()
            changes += 1
            rows.append(
                (f"{name}.json", before, file_size(gz_path), "compressed + verified, raw removed")
            )

        elif gz_path.exists():
            # Already compressed: verify it inflates, report its size.
            try:
                with gzip.open(gz_path, "rb") as gz:
                    inflated = gz.read()
            except OSError as exc:
                print(f"error: {gz_path.name} does not inflate: {exc}", file=sys.stderr)
                failures += 1
                rows.append((f"{name}.json", before, before, "FAILED - corrupt .gz"))
                continue
            rows.append(
                (
                    f"{name}.json",
                    before,
                    file_size(gz_path),
                    f"already compressed, verified (inflates to {len(inflated)} bytes)",
                )
            )

        else:
            print(f"error: neither {raw_path.name} nor {gz_path.name} found", file=sys.stderr)
            failures += 1
            rows.append((f"{name}.json", 0, 0, "MISSING"))

    # Before/after byte table.
    name_w = max(len(r[0]) for r in rows)
    print(f"{'asset':<{name_w}}  {'before':>12}  {'after (.gz)':>12}  {'ratio':>7}  status")
    print(f"{'-' * name_w}  {'-' * 12}  {'-' * 12}  {'-' * 7}  ------")
    total_before = 0
    total_after = 0
    for asset, before, after, status in rows:
        total_before += before
        total_after += after
        ratio = f"{after / before:.3f}x" if before else "-"
        print(f"{asset:<{name_w}}  {before:>12}  {after:>12}  {ratio:>7}  {status}")
    print(f"{'-' * name_w}  {'-' * 12}  {'-' * 12}  {'-' * 7}  ------")
    total_ratio = f"{total_after / total_before:.3f}x" if total_before else "-"
    print(f"{'TOTAL (8 assets)':<{name_w}}  {total_before:>12}  {total_after:>12}  {total_ratio:>7}")
    print(f"changes: {changes} file(s) compressed this run")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
