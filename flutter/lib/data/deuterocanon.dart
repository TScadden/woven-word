import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The deuterocanon (board run 9, Catholic tradition): the books
/// of the 73-book canon that sit outside the 66-book woven core —
/// Tobit, Judith, Wisdom, Sirach, Baruch, 1 and 2 Maccabees, plus
/// any additions books the bundled text edition carries as books
/// of their own. Parsed from `assets/deuterocanon.json`, which
/// the Catholic pipeline derives from the WEB Catholic Edition
/// text itself (see tools/catholic/README.md).
///
/// These books have their own reader and their own chapter space.
/// Highlights and notes key them with reserved book indices
/// ([DeuteroBook.bookIndexBase] + ordinal) in the existing
/// `b{book}c{chapter}v{verse}` key format, bounds-checked here —
/// never against the core canon (lesson 18, both bounds).
///
/// The woven web carries no cross-reference data for these
/// chapters (the OpenBible/TSK set is the 66-book canon); every
/// surface that presents them says so.
class DeuteroBook {
  const DeuteroBook({
    required this.ordinal,
    required this.slug,
    required this.name,
    required this.abbr,
    required this.verseCounts,
  });

  /// Position in the bundled table (0-based).
  final int ordinal;

  /// Stable slug (e.g. "tobit"); also the key ScriptureText uses
  /// for this book's WEB Catholic Edition text.
  final String slug;

  final String name;
  final String abbr;

  /// Verse count per chapter, chapter 1 first.
  final List<int> verseCounts;

  /// The first reserved book index for deuterocanon keys.
  static const int bookIndexBase = 1000;

  /// This book's index in the verse-key space.
  int get bookIndex => bookIndexBase + ordinal;

  int get chapters => verseCounts.length;
}

/// The bundled deuterocanon table plus its canon checks.
class DeuterocanonData {
  DeuterocanonData._(this._books);

  final List<DeuteroBook> _books;

  List<DeuteroBook> get books => List.unmodifiable(_books);

  int get totalChapters => _books.fold(0, (sum, b) => sum + b.chapters);

  DeuteroBook? bySlug(String slug) {
    for (final b in _books) {
      if (b.slug == slug) return b;
    }
    return null;
  }

  /// The book a verse-key book index names, or null when the
  /// index is not a deuterocanon index.
  DeuteroBook? byBookIndex(int bookIndex) {
    final ordinal = bookIndex - DeuteroBook.bookIndexBase;
    if (ordinal < 0 || ordinal >= _books.length) return null;
    return _books[ordinal];
  }

  static bool isDeuteroBookIndex(int bookIndex) =>
      bookIndex >= DeuteroBook.bookIndexBase;

  /// Whether (bookIndex, chapterInBook, verse) names a real
  /// deuterocanon verse. Both bounds bind, exactly like the core
  /// canon check in My Notes.
  bool positionInCanon(int bookIndex, int chapterInBook, int verse) {
    final book = byBookIndex(bookIndex);
    if (book == null) return false;
    if (chapterInBook < 1 || chapterInBook > book.chapters) return false;
    return verse >= 1 && verse <= book.verseCounts[chapterInBook - 1];
  }

  /// "Tobit 3:5" for a deuterocanon position.
  String refLabel(int bookIndex, int chapterInBook, int verse) {
    final book = byBookIndex(bookIndex);
    if (book == null) return 'Chapter $chapterInBook:$verse';
    return '${book.name} $chapterInBook:$verse';
  }

  /// Pure parse of the bundled shape (testable without the
  /// asset bundle). Malformed books are dropped, never thrown.
  static DeuterocanonData parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final books = <DeuteroBook>[];
    final rawBooks = json['books'];
    if (rawBooks is List) {
      for (final raw in rawBooks) {
        if (raw is! Map) continue;
        final counts = raw['verseCounts'];
        if (counts is! List || counts.isEmpty) continue;
        // A book whose stated chapter count disagrees with its
        // verse-count table is malformed: dropped whole, never
        // half-kept (its ordinal would shift every later book).
        final stated = raw['chapters'];
        if (stated is num && stated.toInt() != counts.length) continue;
        books.add(
          DeuteroBook(
            ordinal: books.length,
            slug: raw['slug'] as String,
            name: raw['name'] as String,
            abbr: raw['abbr'] as String,
            verseCounts: [for (final n in counts) (n as num).toInt()],
          ),
        );
      }
    }
    return DeuterocanonData._(books);
  }

  /// Loads and parses assets/deuterocanon.json off the UI thread.
  static Future<DeuterocanonData> load() async {
    final source = await rootBundle.loadString('assets/deuterocanon.json');
    return compute(DeuterocanonData.parse, source);
  }
}
