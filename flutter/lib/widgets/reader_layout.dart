import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/bible_data.dart';
import '../data/scripture_text.dart';
import '../theme/ww_theme.dart';

/// Text measurements derived from the framework's own text layout
/// (lesson 21): a `Text` renders its style MERGED with the ambient
/// [DefaultTextStyle], so every painter here merges the same ambient
/// style, read live from a context inside the reader's Scaffold.
class TextMetrics {
  TextMetrics(this.textScaler, this.ambientStyle);

  final TextScaler textScaler;
  final TextStyle ambientStyle;

  TextPainter _painter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: ambientStyle.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  );

  double height(String text, TextStyle style, {double? maxWidth}) {
    final painter = _painter(text, style)
      ..layout(minWidth: 0, maxWidth: maxWidth ?? double.infinity);
    final result = painter.height;
    painter.dispose();
    return result;
  }
}

enum ReaderItemKind { heading, verse, endOfBook }

/// One item of a book's continuous stream (§4.1): a chapter heading
/// block, one verse block, or the end-of-book block.
class ReaderItem {
  const ReaderItem({
    required this.kind,
    required this.chapter,
    required this.verse,
    required this.offset,
    required this.height,
  });

  final ReaderItemKind kind;

  /// Global chapter index (heading/verse items; the book's last
  /// chapter for the end-of-book item).
  final int chapter;

  /// 1-based verse number for verse items, else null.
  final int? verse;

  /// Offset of this item's top edge within the stream content.
  final double offset;

  /// The item's exact rendered height.
  final double height;
}

/// The reader's offset model (Petra spec §4.2, lesson 21 discipline).
///
/// Derived — never estimated — from the active translation's actual
/// verse strings, the viewport width, the ambient text scaler, and
/// the ambient [DefaultTextStyle] inside the reader's Scaffold.
/// Every literal traces to §4.1 / the verse block construction:
///  * list margins 16 each side (the list's horizontal padding);
///  * verse block horizontal padding 8 + 8, vertical padding 8 + 8,
///    number column 24 + 8 gap, block minimum height 48;
///  * heading block: top gap 24 (first chapter 16), title in
///    `readerTitle`, 4 gap, caption in `captionOnPaper`, 12 bottom;
///  * end-of-book block: 24 gap, title in `sheetRefTitle`, then
///    either 12 + a 48-minimum button or the Revelation caption;
///  * trailing 24 after the end-of-book block.
class ReaderStreamLayout {
  ReaderStreamLayout({
    required this.data,
    required this.texts,
    required this.translation,
    required this.bookIndex,
    required this.viewportWidth,
    required TextScaler textScaler,
    required TextStyle ambientStyle,
  }) : metrics = TextMetrics(textScaler, ambientStyle) {
    _build();
  }

  final BibleData data;
  final ScriptureText texts;
  final WwTranslation translation;
  final int bookIndex;
  final double viewportWidth;
  final TextMetrics metrics;

  final List<ReaderItem> items = [];
  final List<int> _chapterGlobals = [];
  final Map<int, double> _chapterOffsets = {};
  final Map<int, List<double>> _verseOffsets = {};
  double _extent = 0;

  /// Global chapter indices of this book, in order.
  List<int> get chaptersOfBook => List.unmodifiable(_chapterGlobals);

  Book get book => data.books[bookIndex];

  bool get hasNextBook => bookIndex + 1 < data.books.length;

  /// Verse text width: viewport − 32 list margins − 16 block
  /// horizontal padding − 32 number column and gap (§4.2).
  double get _verseTextWidth => viewportWidth - 32 - 16 - 32;

  String _captionFor(int globalChapter) {
    final c = data.chapters[globalChapter];
    return '${c.v} verses · ${data.chapterConnCount[globalChapter]} '
        'connections';
  }

  double _headingHeight(int globalChapter, {required bool first}) {
    final titleH = metrics.height(
      data.chapterName(globalChapter),
      WwType.readerTitle,
      maxWidth: viewportWidth - 32 - 96,
    );
    final captionH = metrics.height(
      _captionFor(globalChapter),
      WwType.captionOnPaper,
      // The caption renders in the title column, beside the 96dp
      // of prev/next targets — its real text width (§4.2).
      maxWidth: viewportWidth - 32 - 96,
    );
    // The heading row is the taller of the title+caption column and
    // the 48dp prev/next targets (§4.1/§4.6).
    final columnH = titleH + 4 + captionH;
    final rowH = math.max(columnH, WwSpace.minTarget);
    return (first ? 16.0 : 24.0) + rowH + 12;
  }

  double _verseHeight(int globalChapter, String text) {
    final textH = metrics.height(
      text,
      WwType.readerBody,
      maxWidth: _verseTextWidth,
    );
    return math.max(WwSpace.minTarget, 16 + textH);
  }

  double _endHeight() {
    final titleH = metrics.height(
      'End of ${book.name}',
      WwType.sheetRefTitle,
      maxWidth: viewportWidth - 32,
    );
    if (hasNextBook) return 24 + titleH + 12 + WwSpace.minTarget;
    final captionH = metrics.height(
      'The last book of the Bible.',
      WwType.captionOnPaper,
      maxWidth: viewportWidth - 32,
    );
    return 24 + titleH + 4 + captionH;
  }

  void _build() {
    final b = book;
    var offset = 0.0;
    for (var ci = 0; ci < b.chapters; ci++) {
      final global = b.start + ci;
      _chapterGlobals.add(global);
      final headingH = _headingHeight(global, first: ci == 0);
      _chapterOffsets[global] = offset;
      items.add(
        ReaderItem(
          kind: ReaderItemKind.heading,
          chapter: global,
          verse: null,
          offset: offset,
          height: headingH,
        ),
      );
      offset += headingH;
      final verses = texts.chapterVerses(translation, data, global);
      final verseOffsets = <double>[];
      for (var vi = 0; vi < verses.length; vi++) {
        final h = _verseHeight(global, verses[vi]);
        verseOffsets.add(offset);
        items.add(
          ReaderItem(
            kind: ReaderItemKind.verse,
            chapter: global,
            verse: vi + 1,
            offset: offset,
            height: h,
          ),
        );
        offset += h;
      }
      _verseOffsets[global] = verseOffsets;
    }
    final endH = _endHeight();
    items.add(
      ReaderItem(
        kind: ReaderItemKind.endOfBook,
        chapter: _chapterGlobals.last,
        verse: null,
        offset: offset,
        height: endH,
      ),
    );
    offset += endH;
    _extent = offset + 24;
  }

  /// Total height of the stream content, trailing padding included.
  double get streamExtent => _extent;

  /// Offset of a chapter's heading block top.
  double offsetOfChapter(int globalChapter) =>
      _chapterOffsets[globalChapter] ?? 0;

  /// Offset of a verse block's top.
  double offsetOfVerse(int globalChapter, int verse) {
    final list = _verseOffsets[globalChapter];
    if (list == null || list.isEmpty) return offsetOfChapter(globalChapter);
    return list[(verse.clamp(1, list.length)) - 1];
  }

  /// The chapter whose range contains [offset] (§4.3): ranges run
  /// from a heading block's first pixel to the next heading's first
  /// pixel; the end-of-book block belongs to the last chapter.
  int chapterAtOffset(double offset) {
    var result = _chapterGlobals.first;
    for (final global in _chapterGlobals) {
      if (_chapterOffsets[global]! <= offset) {
        result = global;
      } else {
        break;
      }
    }
    return result;
  }

  /// Scroll offset that lands a chapter heading at the viewport top
  /// (alignment 0.0), clamped to the scrollable range.
  double chapterLandingOffset(int globalChapter, double viewportHeight) {
    final maxOffset = math.max(0.0, _extent - viewportHeight);
    return offsetOfChapter(globalChapter).clamp(0.0, maxOffset);
  }

  /// Scroll offset that lands a verse block's top at 0.5 of the
  /// viewport (the shipped `ensureVisible` alignment, §4.2),
  /// clamped to the scrollable range.
  double verseLandingOffset(
    int globalChapter,
    int verse,
    double viewportHeight,
  ) {
    final maxOffset = math.max(0.0, _extent - viewportHeight);
    return (offsetOfVerse(globalChapter, verse) - viewportHeight * 0.5)
        .clamp(0.0, maxOffset);
  }
}
