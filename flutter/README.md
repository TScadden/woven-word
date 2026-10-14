# woven_word

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Woven Word (Flutter)

One codebase for Android, iOS, and web, succeeding the web v1 at the
repo root (which stays live on Pages until this reaches parity).

Screens land one at a time, each verified by Tyson on his phone:
(a) arc web home — pan/zoom stage, density-aware arcs, scope + search;
(b) chapter connection sheet; (c) reader with KJV / WEB toggle;
(d) verse sheet; (e) profiles + My Notes.

Design system: `lib/theme/ww_theme.dart`, built on the Tabs
design-audit rules with Woven Word tokens (black stage, cream paper,
gold). CI: `.github/workflows/flutter.yml` builds the Android APK to
the `flutter-apk-latest` release and compile-checks web + iOS.
