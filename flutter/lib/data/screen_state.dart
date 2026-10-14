import 'dart:convert';

import 'bible_data.dart';

/// Board run 7 part B, Petra spec §6 as amended by Amendment A:
/// a screen is one held reading place — a bound book (or unbound),
/// its current chapter page, an optional verse anchor, and its own
/// in-reader history (session-only, never persisted).
///
/// A place is a chapter page + verse anchor ONLY. There is no
/// scroll-offset field and no geometry signature: both existed to
/// restore a position inside a continuous stream, and the paged
/// reader (§4) has no stream. In-page scroll position is
/// session-only and is never persisted (§6.4 as amended).
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
  });

  final int id;

  /// The bound book's index, or null when unbound.
  int? bookIndex;

  /// Global chapter index of the held place — its chapter PAGE
  /// (§4.3: the pager's reported current page, never derived from
  /// a scroll offset).
  int globalChapter;

  /// The last verse explicitly landed on or tapped, or null when
  /// the place is a whole chapter (§4.3).
  int? anchorVerse;

  /// In-reader history of places left, (globalChapter, verse?)
  /// (§7.2). Session-only.
  final List<(int, int?)> history = [];

  bool get bound => bookIndex != null;

  /// The current place as a history entry.
  (int, int?) get place => (globalChapter, anchorVerse);

  Map<String, dynamic> toJson() => {
    'book': bookIndex,
    'chapter': globalChapter,
    'anchor': anchorVerse,
  };
}

/// Serializes the screen set (§6.4 as amended: chapter page +
/// verse anchor only — no offset, no geometry signature).
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
///
/// Documents written by the retired stream shape may carry
/// `offset` / `sig` fields: they are ignored, never applied — an
/// offset from the stream shape landing in the paged reader is a
/// Blocker (§6.4 as amended; STORE-3's legacy-shape case).
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
    // NOTE: any 'offset' / 'sig' keys in a legacy stream-shaped
    // entry are deliberately not read (§6.4 as amended).
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
