import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/bible_data.dart';
import '../theme/ww_theme.dart';

/// Exact layout model for the home screen's scroll content (board
/// run 6, Petra spec part 1).
///
/// The home list is a lazy [CustomScrollView]: a book section that
/// has never been built has no rendered position, so `ensureVisible`
/// cannot jump to it (LESSONS #14). This model computes every book
/// section's offset — and the total content extent — as a pure
/// function of the loaded [BibleData], the current scope, the
/// post-jump selection panel (if any), the viewport width, and the
/// ambient text scaler, so a jump can be an `animateTo` to a known
/// offset even on a cold jump to a never-built book.
///
/// Exactness discipline (spec §1.2/§1.3): every constant below is a
/// literal from `home_screen.dart`'s widget tree (cited inline), and
/// every text-dependent height/width is derived with [TextPainter]
/// using the widget's exact [TextStyle] and the ambient
/// [TextScaler] — the same metrics the renderer uses. No estimated
/// line heights, no per-character tables.

/// Text measurements derived from the framework's own text layout.
///
/// A `Text` widget does not render its style raw: with the style's
/// default `inherit: true` it renders the ambient
/// [DefaultTextStyle] merged with its own style (the theme's
/// bodyMedium — Roboto at a 1.43 height multiplier — supplies the
/// line height and letter spacing the WwType roles leave unset).
/// The painter merges the same ambient style, so model and
/// renderer measure the identical effective style.
class TextMetrics {
  TextMetrics(this.textScaler, this.ambientStyle);

  final TextScaler textScaler;
  final TextStyle ambientStyle;

  TextPainter _painter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: ambientStyle.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  );

  /// The single-run width of [text] in [style], unconstrained.
  double width(String text, TextStyle style) {
    final painter = _painter(text, style)..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  /// The laid-out height of [text] in [style]; when [maxWidth] is
  /// given the text wraps at that width exactly as the widget does.
  double height(String text, TextStyle style, {double? maxWidth}) {
    final painter = _painter(text, style)
      ..layout(minWidth: 0, maxWidth: maxWidth ?? double.infinity);
    final result = painter.height;
    painter.dispose();
    return result;
  }
}

/// The selection panel's text inputs, in the exact strings the panel
/// renders: its title, its verses/connections caption, and each
/// partner chip's (chapter name, formatted count) label pair.
class HomePanelData {
  const HomePanelData({
    required this.title,
    required this.caption,
    required this.partners,
  });

  final String title;
  final String caption;
  final List<(String, String)> partners;
}

/// Thousands-separated count formatting, mirroring `HomeScreen._fmt`
/// (the strings the selection panel actually renders).
String _fmtCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Builds the [HomePanelData] for [ch] from the same values and
/// formatting the selection panel's build path uses.
HomePanelData homePanelData(BibleData data, int ch) {
  final c = data.chapters[ch];
  return HomePanelData(
    title: data.chapterName(ch),
    caption:
        '${_fmtCount(c.v)} verses · '
        '${_fmtCount(data.chapterConnCount[ch])} connections',
    partners: [
      for (final entry in data.partnersSorted(ch))
        (data.chapterName(entry.key), _fmtCount(entry.value)),
    ],
  );
}

/// The offset model over one (data, scope, panel, width, scaler)
/// state. Construct it from the POST-jump state: a jump's own state
/// change (selection set, scope widened) is applied first, then the
/// model describes the layout that state produces (spec §1.2).
class HomeLayout {
  HomeLayout({
    required this.data,
    required this.scope,
    required this.viewportWidth,
    required TextScaler textScaler,
    required TextStyle ambientStyle,
    this.panel,
  }) : metrics = TextMetrics(textScaler, ambientStyle);

  final BibleData data;
  final String scope;
  final double viewportWidth;
  final HomePanelData? panel;
  final TextMetrics metrics;

  /// Book index range in scope order — mirrors `_bookSlivers`:
  /// 'nt' starts at book 39; 'ot' ends before book 39 (clamped to
  /// the book count); 'all' covers every book.
  (int, int) get _bookRange {
    final start = scope == 'nt' ? 39 : 0;
    final end = scope == 'ot'
        ? (data.books.length < 39 ? data.books.length : 39)
        : data.books.length;
    return (start, end);
  }

  /// Width inside the scroll view's horizontal padding: book
  /// sections and the selection panel both inset their content by
  /// `WwSpace.screenMargin` (16) on each side.
  double get _contentWidth => viewportWidth - WwSpace.screenMargin * 2;

  /// Height of the selection panel, from its construction in
  /// `_selectionPanel`: 16 top padding + title row + 12 gap + 48
  /// Read button + 12 gap + 'Connected chapters' caption + 8 gap +
  /// partner Wrap + 16 bottom padding (spec §1.2.1).
  double get panelHeight {
    final panel = this.panel;
    if (panel == null) return 0;
    // Title row: an Expanded column (title over caption, 2dp gap)
    // beside the 48dp clear IconButton; the row is as tall as the
    // taller side. The column's width is the content width minus
    // the button's 48.
    final columnWidth = _contentWidth - WwSpace.minTarget;
    final columnHeight =
        metrics.height(panel.title, WwType.selectionTitle, maxWidth: columnWidth) +
        2 +
        metrics.height(panel.caption, WwType.captionOnDark, maxWidth: columnWidth);
    final titleRowHeight = math.max(columnHeight, WwSpace.minTarget);
    final captionHeight = metrics.height(
      'Connected chapters',
      WwType.captionOnDark,
      maxWidth: _contentWidth,
    );
    return WwSpace.screenMargin +
        titleRowHeight +
        12 +
        WwSpace.minTarget +
        12 +
        captionHeight +
        8 +
        _partnerWrapHeight(panel) +
        WwSpace.screenMargin;
  }

  /// Height of the partner-chips Wrap: chips laid greedily into
  /// rows of [_contentWidth], spacing/runSpacing 8 (the Wrap's
  /// literals in `_selectionPanel`). A row is as tall as its
  /// tallest chip; rows are separated by the 8dp runSpacing.
  double _partnerWrapHeight(HomePanelData panel) {
    var total = 0.0;
    var rowWidth = 0.0;
    var rowHeight = 0.0;
    var inRow = false;
    for (final partner in panel.partners) {
      final chipWidth = _partnerChipWidth(partner);
      final chipHeight = _partnerChipHeight(partner);
      if (!inRow) {
        rowWidth = chipWidth;
        rowHeight = chipHeight;
        total = chipHeight;
        inRow = true;
      } else if (rowWidth + 8 + chipWidth <= _contentWidth) {
        rowWidth += 8 + chipWidth;
        if (chipHeight > rowHeight) {
          total += chipHeight - rowHeight;
          rowHeight = chipHeight;
        }
      } else {
        total += 8 + chipHeight;
        rowWidth = chipWidth;
        rowHeight = chipHeight;
      }
    }
    return total;
  }

  /// One partner chip's width, from `_partnerChip`: horizontal
  /// padding 12 + name (`controlLabel`) + 6 gap + count
  /// (`captionOnDark`) + horizontal padding 12.
  double _partnerChipWidth((String, String) partner) =>
      12 +
      metrics.width(partner.$1, WwType.controlLabel) +
      6 +
      metrics.width(partner.$2, WwType.captionOnDark) +
      12;

  /// One partner chip's height: `minHeight` 48, vertical padding
  /// 8 + 8 around the taller of its two single-line texts.
  double _partnerChipHeight((String, String) partner) => math.max(
    WwSpace.minTarget,
    8 +
        math.max(
          metrics.height(partner.$1, WwType.controlLabel),
          metrics.height(partner.$2, WwType.captionOnDark),
        ) +
        8,
  );

  /// Height of a section header (`_sectionHeader`): 16 top padding
  /// + the `appSubtitle` line. Bottom padding is 0.
  double _sectionHeaderHeight(String label) =>
      WwSpace.screenMargin +
      metrics.height(label, WwType.appSubtitle, maxWidth: _contentWidth);

  /// Height of one book section (`_bookSection`): header block
  /// (16 top padding + header row + 8 bottom padding) + the chapter
  /// grid's Wrap height.
  double bookSectionHeight(int bookIndex) {
    final book = data.books[bookIndex];
    // Header row: Expanded book name (bodyOnDark w600 — the build
    // path's copyWith weight) beside the chapter-count caption.
    final countLabel = book.chapters == 1
        ? '1 chapter'
        : '${book.chapters} chapters';
    final captionHeight = metrics.height(countLabel, WwType.captionOnDark);
    final captionWidth = metrics.width(countLabel, WwType.captionOnDark);
    final nameHeight = metrics.height(
      book.name,
      WwType.bodyOnDark.copyWith(fontWeight: FontWeight.w600),
      maxWidth: _contentWidth - captionWidth,
    );
    final headerHeight =
        WwSpace.screenMargin + math.max(nameHeight, captionHeight) + 8;
    // Chapter grid: 48×48 chips, Wrap spacing/runSpacing 8, inside
    // 16dp horizontal padding (spec §1.2.3 formula).
    final perRow = ((viewportWidth - 32 + 8) / (48 + 8)).floor();
    final rows = (book.chapters + perRow - 1) ~/ perRow;
    final gridHeight = rows * 48.0 + (rows - 1) * 8.0;
    return headerHeight + gridHeight;
  }

  /// Whether a section header precedes [bookIndex] in this scope —
  /// in scope 'all' only: OT before book 0, NT before book 39
  /// (`_bookSlivers`).
  double _headerBefore(int bookIndex) {
    if (scope != 'all') return 0;
    if (bookIndex == 0) return _sectionHeaderHeight('OLD TESTAMENT');
    if (bookIndex == 39) return _sectionHeaderHeight('NEW TESTAMENT');
    return 0;
  }

  /// The offset of the top edge of [bookIndex]'s section Column
  /// (including its 16dp top padding) within the scroll content:
  /// the selection panel, then every preceding in-scope section
  /// header and book section in render order.
  double offsetOfBook(int bookIndex) {
    final (start, end) = _bookRange;
    var offset = panelHeight;
    for (var bi = start; bi < end; bi++) {
      offset += _headerBefore(bi);
      if (bi == bookIndex) return offset;
      offset += bookSectionHeight(bi);
    }
    return offset;
  }

  /// The total height of the scroll content: panel + every in-scope
  /// section header and book section + the trailing 24 spacer
  /// (`_scrollArea`'s final sliver). The scrollable extent is this
  /// minus the scroll viewport's height.
  double get totalExtent {
    final (start, end) = _bookRange;
    var total = panelHeight;
    for (var bi = start; bi < end; bi++) {
      total += _headerBefore(bi);
      total += bookSectionHeight(bi);
    }
    return total + 24;
  }
}
