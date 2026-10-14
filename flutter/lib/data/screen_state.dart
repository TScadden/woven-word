import 'dart:convert';

import 'bible_data.dart';

/// Board run 7 part B, Petra spec §6: a screen is one held reading
/// place — a bound book stream (or unbound), its chapter-at-top,
/// an optional verse anchor, a scroll offset with the geometry
/// signature it was measured under, and its own in-stream history
/// (session-only, never persisted).
///
/// Screens are navigation state in shared_preferences under
/// `ww_screens_v1`. They are never part of [UserData] and never
/// exported in a backup (§6.2); `UserData.version` does not move.

/// The binding screen cap (§0.1 overrule).
const int wwMaxScreens = 5;

class ReadingScreen {
  ReadingScreen({
    required this.id,
    this.bookIndex,
    this.globalChapter = 0,
    this.anchorVerse,
    this.offset = 0,
    this.geometrySig,
  });

  final int id;

  /// The bound book's index, or null when unbound.
  int? bookIndex;

  /// Chapter-at-top (global chapter index) of the held place.
  int globalChapter;

  /// The last verse explicitly landed on or tapped, or null.
  int? anchorVerse;

  /// Scroll offset in the bound book's stream, valid only under
  /// [geometrySig] (§6.4).
  double offset;
  String? geometrySig;

  /// In-stream history of places left, (globalChapter, verse?)
  /// (§7.2). Session-only.
  final List<(int, int?)> history = [];

  bool get bound => bookIndex != null;

  /// The current place as a history entry.
  (int, int?) get place => (globalChapter, anchorVerse);

  Map<String, dynamic> toJson() => {
    'book': bookIndex,
    'chapter': globalChapter,
    'anchor': anchorVerse,
    'offset': offset,
    'sig': geometrySig,
  };
}

/// Serializes the screen set (§6.4).
String serializeWwScreens(List<ReadingScreen> screens, int activeIndex) =>
    jsonEncode({
      'active': activeIndex,
      'screens': [for (final s in screens) s.toJson()],
    });

/// Defensive parse of the `ww_screens_v1` document (§6.4, lessons
/// #18/#19): entries failing shape or canon checks are dropped, an
/// out-of-range active index resolves to the first screen, and an
/// empty parse yields the default set — one screen bound to
/// [fallbackChapter] (the persisted Home selection's chapter) when
/// one exists, else Genesis 1 (global chapter 0).
(List<ReadingScreen>, int) parseWwScreens(
  String? raw,
  BibleData data, {
  int? fallbackChapter,
}) {
  (List<ReadingScreen>, int) fallback() {
    final ch =
        (fallbackChapter != null &&
            fallbackChapter >= 0 &&
            fallbackChapter < data.totalChapters)
        ? fallbackChapter
        : 0;
    return (
      [
        ReadingScreen(
          id: 1,
          bookIndex: data.chapters[ch].b,
          globalChapter: ch,
        ),
      ],
      0,
    );
  }

  if (raw == null) return fallback();
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return fallback();
  }
  if (decoded is! Map) return fallback();
  final rawScreens = decoded['screens'];
  if (rawScreens is! List) return fallback();
  final screens = <ReadingScreen>[];
  var nextId = 1;
  for (final entry in rawScreens) {
    if (entry is! Map) continue;
    final book = entry['book'];
    final chapter = entry['chapter'];
    final anchor = entry['anchor'];
    final offset = entry['offset'];
    final sig = entry['sig'];
    if (book != null && book is! int) continue;
    if (chapter is! int) continue;
    if (chapter < 0 || chapter >= data.totalChapters) continue;
    // A bound entry's chapter must belong to its book.
    if (book != null) {
      if (book < 0 || book >= data.books.length) continue;
      if (data.chapters[chapter].b != book) continue;
    }
    if (anchor != null && (anchor is! int || anchor < 1)) continue;
    if (screens.length >= wwMaxScreens) continue;
    screens.add(
      ReadingScreen(
        id: nextId++,
        bookIndex: book,
        globalChapter: chapter,
        anchorVerse: anchor,
        offset: offset is num ? offset.toDouble() : 0,
        geometrySig: sig is String ? sig : null,
      ),
    );
  }
  if (screens.isEmpty) return fallback();
  var active = 0;
  final rawActive = decoded['active'];
  if (rawActive is int && rawActive >= 0 && rawActive < screens.length) {
    active = rawActive;
  }
  return (screens, active);
}
