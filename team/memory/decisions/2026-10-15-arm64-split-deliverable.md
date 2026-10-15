# Process: staged deliverable is the arm64-v8a split APK (2026-10-15)

Context: the founder's chat downloads truncated the 32,076,557-byte
staged build at random sizes (10.47 MB, then 5.37 MB — at 5.37 MB
Android no longer recognizes the file as a package and offers an
"Open with" chooser instead of the installer). He asked for APKs
"like the Tabs side chat," whose files have never had this problem;
the Tabs recipe is release builds with `--split-per-abi`, delivering
the arm64-v8a APK only.

Finding (Boaz, measured Oct 15, 2026): Woven Word's CI already
builds `--split-per-abi` and stages `app-arm64-v8a-release.apk`.
Zip inspection of the staged ambient-arch build (from CI run
38810752884, SHA-256 67600a98…, byte-identical to the CI artifact)
shows `lib/` contains arm64-v8a only. The 32 MB is bundled data —
cross references, five translation texts, the Sefaria index, the
conference index — not other architectures. The split therefore
changes no bytes for this app; the deliverable was already arm64.

Process change, effective immediately:
- The staged founder deliverable is the arm64-v8a split release
  APK from the green CI run, staged under the package name with
  the `_arm64_` marker (e.g.
  `woven_word_arch_ambient_home_arm64_20261015.apk`).
- The same file is uploaded to the `flutter-apk-latest` release
  as a backup-channel asset and its size verified against the
  staged file.
- Every ship report states the staged file's exact byte size,
  its ABI contents from zip inspection, and its signer SHA-256
  against the pinned fingerprint — measured, never assumed.

Recorded as lesson 54 in team/memory/LESSONS.md.
