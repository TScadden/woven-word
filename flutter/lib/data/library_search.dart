import 'bible_data.dart';
import 'conference_data.dart';
import 'deuterocanon.dart';
import 'tradition.dart';

/// Library live search (search fix package, spec §3): a pure
/// function from the field's current text + the loaded datasets
/// to the grouped results the Library root renders. Results are
/// derived synchronously at build, so a frame can never show a
/// previous query's results and no submit step exists.
///
/// Groups, in render order: BOOKS (the tradition's presented
/// books, then the deuterocanon under Catholic), CHAPTERS (the
/// reference the query names), TALKS (the conference layer's,
/// only when a [ConferenceData] is supplied — the caller passes
/// one only while the layer is on, so a null input is the off
/// state, structurally). Translations are never an input.
class LibrarySearchResults {
  const LibrarySearchResults({
    required this.books,
    required this.deuteroBooks,
    required this.chapters,
    required this.deuteroChapters,
    required this.talks,
  });

  /// Core book indices that match, in the tradition's
  /// presentation order ([CanonView.bookOrder]).
  final List<int> books;

  /// Deuterocanon books that match, in bundled table order.
  /// Non-empty only under the Catholic tradition with the
  /// table loaded.
  final List<DeuteroBook> deuteroBooks;

  /// Global chapter indices the query's reference names, in
  /// canon order.
  final List<int> chapters;

  /// (book, chapterInBook) deuterocanon references the query
  /// names, in table order.
  final List<(DeuteroBook, int)> deuteroChapters;

  /// Talks whose title or speaker matches, newest first
  /// (ConferenceData's shared talk order).
  final List<ConferenceTalk> talks;

  bool get isEmpty =>
      books.isEmpty &&
      deuteroBooks.isEmpty &&
      chapters.isEmpty &&
      deuteroChapters.isEmpty &&
      talks.isEmpty;
}

String _squash(String s) => s.replaceAll(RegExp(r'\s'), '');

/// Newest-first talk order, ConferenceData's one shared sort
/// (year descending, October before April within a year, then
/// dataset order — ids are bundled-table indices).
int _newestFirst(ConferenceTalk a, ConferenceTalk b) {
  final byYear = b.year.compareTo(a.year);
  if (byYear != 0) return byYear;
  final rankA = a.session == 'O' ? 1 : 0;
  final rankB = b.session == 'O' ? 1 : 0;
  final bySession = rankB.compareTo(rankA);
  if (bySession != 0) return bySession;
  return a.id.compareTo(b.id);
}

/// The Library search over [data]'s canon as [tradition]
/// presents it. [query] is the field's raw text; a blank query
/// yields empty groups (the root renders its browse instead).
LibrarySearchResults searchLibrary({
  required BibleData data,
  required WwTradition tradition,
  required String query,
  DeuterocanonData? deuterocanon,
  ConferenceData? conference,
}) {
  const empty = LibrarySearchResults(
    books: [],
    deuteroBooks: [],
    chapters: [],
    deuteroChapters: [],
    talks: [],
  );
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return empty;
  final qSquashed = _squash(q);

  final view = CanonView.forTradition(tradition, data);

  // §3.1 BOOKS, core: name contains, or the squashed
  // abbreviation starts with the squashed query — in the
  // tradition's presentation order.
  final books = <int>[];
  for (final bookIndex in view.bookOrder) {
    final name = view.nameFor(bookIndex)!;
    final book = data.books[bookIndex];
    if (name.toLowerCase().contains(q) ||
        _squash(book.abbr.toLowerCase()).startsWith(qSquashed)) {
      books.add(bookIndex);
    }
  }

  // §3.2 BOOKS, deuterocanon: Catholic only, table loaded.
  final deuteroBooks = <DeuteroBook>[];
  final deuteroActive =
      tradition == WwTradition.catholic && deuterocanon != null;
  if (deuteroActive) {
    for (final book in deuterocanon.books) {
      if (book.name.toLowerCase().contains(q) ||
          _squash(book.abbr.toLowerCase()).startsWith(qSquashed)) {
        deuteroBooks.add(book);
      }
    }
  }

  // §3.3 CHAPTERS: parseSearch's grammar and book rule, but
  // every match contributes and an out-of-range number
  // contributes nothing — search never clamps a reference
  // into a chapter that does not exist.
  final chapters = <int>[];
  final deuteroChapters = <(DeuteroBook, int)>[];
  final m = RegExp(r'^(.*?)\s+(\d+)$').firstMatch(q);
  if (m != null) {
    final bookPart = m.group(1)!;
    final chapNum = int.parse(m.group(2)!);
    final bookPartSquashed = _squash(bookPart);
    bool refMatches(String name, String abbr) =>
        name.toLowerCase().startsWith(bookPart) ||
        _squash(abbr.toLowerCase()) == bookPartSquashed;
    for (final bookIndex in view.bookOrder) {
      final book = data.books[bookIndex];
      if (!refMatches(view.nameFor(bookIndex)!, book.abbr)) continue;
      if (chapNum >= 1 && chapNum <= book.chapters) {
        chapters.add(book.start + chapNum - 1);
      }
    }
    if (deuteroActive) {
      for (final book in deuterocanon.books) {
        if (!refMatches(book.name, book.abbr)) continue;
        if (chapNum >= 1 && chapNum <= book.chapters) {
          deuteroChapters.add((book, chapNum));
        }
      }
    }
  }

  // §3.4 TALKS: title or speaker contains the query, newest
  // first. A null [conference] is the layer-off state.
  final talks = <ConferenceTalk>[];
  if (conference != null) {
    for (final talk in conference.talks) {
      if (talk.title.toLowerCase().contains(q) ||
          talk.speaker.toLowerCase().contains(q)) {
        talks.add(talk);
      }
    }
    talks.sort(_newestFirst);
  }

  return LibrarySearchResults(
    books: books,
    deuteroBooks: deuteroBooks,
    chapters: chapters,
    deuteroChapters: deuteroChapters,
    talks: talks,
  );
}
