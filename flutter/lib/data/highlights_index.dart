import 'bible_data.dart';
import 'deuterocanon.dart';
import 'scripture_text.dart';
import 'tradition.dart';
import 'user_data.dart';

/// The All Highlights index (board run 11, spec §6.1): which of
/// one profile's spans in one translation are visible under a
/// tradition, and how they group for display. Pure and
/// widget-free; the shell's Highlights count and the All
/// Highlights screen both read through here, so the caption
/// always equals the number of rows the tap reveals.

/// Whether a parsed span position names a real place in the
/// canon. Mirrors `notePositionInCanon` (my_notes_screen.dart)
/// exactly — both bounds bind (lesson 18): core books need
/// `0 <= book < books.length`, `1 <= chapter <= book.chapters`,
/// `1 <= verse <= chapters[global].v`; indices at or above
/// [DeuteroBook.bookIndexBase] defer to the deuterocanon table
/// and are out when it is null.
///
/// Re-implemented here, NOT imported from the screen file: a
/// data-layer function never imports a screen.
bool spanPositionInCanon(
  BibleData data,
  int book,
  int chapter,
  int verse, {
  DeuterocanonData? deutero,
}) {
  if (book >= DeuteroBook.bookIndexBase) {
    return deutero?.positionInCanon(book, chapter, verse) ?? false;
  }
  if (book < 0 || book >= data.books.length) return false;
  if (chapter < 1 || chapter > data.books[book].chapters) return false;
  final global = data.books[book].start + chapter - 1;
  return verse >= 1 && verse <= data.chapters[global].v;
}

/// The spans of [spans] (ONE profile's spans in ONE translation
/// set — the caller slices `ProfileData.spans[translationKey]`,
/// absent set = empty) that are visible under [tradition]: the
/// run-10 visibility rule — the key parses, its position is in
/// the canon (the deuterocanon table included), and its book is
/// in the tradition's canon. Storage is never filtered; this is
/// a view predicate only. Return order is unspecified — ordering
/// is [groupHighlights]' job; the shell's count uses only the
/// length.
List<HighlightSpan> visibleSpansForIndex({
  required BibleData data,
  required DeuterocanonData? deutero,
  required List<HighlightSpan> spans,
  required WwTradition tradition,
}) {
  return [
    for (final span in spans)
      if (_spanVisible(data, deutero, span, tradition)) span,
  ];
}

bool _spanVisible(
  BibleData data,
  DeuterocanonData? deutero,
  HighlightSpan span,
  WwTradition tradition,
) {
  final parsed = parseVerseKey(span.verseKey);
  if (parsed == null) return false;
  final (book, chapter, verse) = parsed;
  if (!spanPositionInCanon(data, book, chapter, verse, deutero: deutero)) {
    return false;
  }
  return canonContainsBook(tradition, data, book);
}

/// One display row of the All Highlights list.
class HighlightRowData {
  const HighlightRowData({
    required this.span,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.refLabel,
    required this.displayText,
  });

  final HighlightSpan span;

  /// May be >= [DeuteroBook.bookIndexBase].
  final int book;

  /// Chapter in book, 1-based.
  final int chapter;

  final int verse;
  final String refLabel;
  final String displayText;
}

/// One chapter's rows within a book group.
class HighlightChapterGroup {
  const HighlightChapterGroup({required this.chapter, required this.rows});

  final int chapter;
  final List<HighlightRowData> rows;
}

/// One book's groups: its chapters ascending.
class HighlightBookGroup {
  const HighlightBookGroup({
    required this.book,
    required this.bookName,
    required this.chapters,
  });

  final int book;
  final String bookName;
  final List<HighlightChapterGroup> chapters;
}

/// Groups the visible spans for display: books in the active
/// tradition's canon order (deuterocanon groups — Catholic only,
/// the only tradition under which they are visible — follow ALL
/// core groups, in deuterocanon table order), chapters
/// ascending within a book, rows by verse, then start offset,
/// then end, then anchor.
///
/// Display text (spec §6.1): a full-verse span shows the verse's
/// text in the active translation; any other span shows its
/// anchor when non-empty, else the verse's text. When [texts] is
/// null or a resolution is empty, the fallback is the span's
/// anchor (which may itself be '' — the row then shows its
/// reference alone, never a fabricated line).
List<HighlightBookGroup> groupHighlights({
  required BibleData data,
  required DeuterocanonData? deutero,
  required List<HighlightSpan> spans,
  required WwTradition tradition,
  required ScriptureText? texts,
  required WwTranslation translation,
}) {
  final visible = visibleSpansForIndex(
    data: data,
    deutero: deutero,
    spans: spans,
    tradition: tradition,
  );
  final byBook = <int, List<HighlightSpan>>{};
  for (final span in visible) {
    final parsed = parseVerseKey(span.verseKey)!;
    byBook.putIfAbsent(parsed.$1, () => []).add(span);
  }
  if (byBook.isEmpty) return const [];

  final view = CanonView.forTradition(tradition, data);
  final coreOrder = [
    for (final b in view.bookOrder)
      if (byBook.containsKey(b)) b,
  ];
  final deuteroOrder = [
    for (final b in byBook.keys)
      if (b >= DeuteroBook.bookIndexBase) b,
  ]..sort();

  return [
    for (final book in [...coreOrder, ...deuteroOrder])
      _bookGroup(
        data: data,
        deutero: deutero,
        view: view,
        book: book,
        bookSpans: byBook[book]!,
        texts: texts,
        translation: translation,
      ),
  ];
}

HighlightBookGroup _bookGroup({
  required BibleData data,
  required DeuterocanonData? deutero,
  required CanonView view,
  required int book,
  required List<HighlightSpan> bookSpans,
  required ScriptureText? texts,
  required WwTranslation translation,
}) {
  final isDeutero = book >= DeuteroBook.bookIndexBase;
  final bookName = isDeutero
      ? deutero!.byBookIndex(book)!.name
      : (view.nameFor(book) ?? data.books[book].name);

  final byChapter = <int, List<HighlightSpan>>{};
  for (final span in bookSpans) {
    final parsed = parseVerseKey(span.verseKey)!;
    byChapter.putIfAbsent(parsed.$2, () => []).add(span);
  }
  final chapterNumbers = byChapter.keys.toList()..sort();

  HighlightRowData rowFor(HighlightSpan span) {
    final parsed = parseVerseKey(span.verseKey)!;
    final (_, chapter, verse) = parsed;
    final String refLabel;
    String verseText;
    if (isDeutero) {
      refLabel = deutero!.refLabel(book, chapter, verse);
      final slug = deutero.byBookIndex(book)?.slug;
      verseText = (texts == null || slug == null)
          ? ''
          : texts.extraVerseText(slug, chapter, verse);
    } else {
      final global = data.books[book].start + chapter - 1;
      refLabel = data.refName(global, verse);
      verseText = texts?.verseText(translation, data, global, verse) ?? '';
    }
    final String displayText;
    if (span.isFullVerse) {
      displayText = verseText.isNotEmpty ? verseText : span.anchor;
    } else {
      displayText = span.anchor.isNotEmpty ? span.anchor : verseText;
    }
    return HighlightRowData(
      span: span,
      book: book,
      chapter: chapter,
      verse: verse,
      refLabel: refLabel,
      displayText: displayText,
    );
  }

  return HighlightBookGroup(
    book: book,
    bookName: bookName,
    chapters: [
      for (final chapter in chapterNumbers)
        HighlightChapterGroup(
          chapter: chapter,
          rows: [
            for (final span in ([...byChapter[chapter]!]..sort(_rowOrder)))
              rowFor(span),
          ],
        ),
    ],
  );
}

/// Row order within a chapter: verse ASC, then start ASC, then
/// end ASC, then anchor — full determinism.
int _rowOrder(HighlightSpan a, HighlightSpan b) {
  final pa = parseVerseKey(a.verseKey)!;
  final pb = parseVerseKey(b.verseKey)!;
  final byVerse = pa.$3.compareTo(pb.$3);
  if (byVerse != 0) return byVerse;
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  final byEnd = a.end.compareTo(b.end);
  if (byEnd != 0) return byEnd;
  return a.anchor.compareTo(b.anchor);
}
