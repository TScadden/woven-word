import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../data/conference_data.dart';
import '../theme/ww_theme.dart';

/// A live view of the General Conference layer's state for the
/// Library root (board run 8, spec §4.1). The shell's controller
/// implements this; the root reads through the getters at render
/// time (and rebuilds on the controller's notifications when it
/// is also a [Listenable]), so a toggle flipped on another tab
/// agrees with the next Library render (§1.1) without the root
/// holding a stale snapshot.
abstract class ConferenceLayerState {
  bool get conferenceEnabled;
  ConferenceData? get conferenceData;
}

/// Text measurements derived from the framework's own text layout
/// (lesson 21): a `Text` renders its style MERGED with the ambient
/// [DefaultTextStyle], so this painter merges the same ambient
/// style. Its one consumer is the §3.2.1 book-tile height
/// derivation below. (It lived in the retired reader offset model
/// until Amendment A deleted that file; the tile derivation is
/// reader-model-independent and keeps the helper.)
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

/// Library tab (board run 7 part B, §3): drill-down —
/// root (search + testament tiles) → book tile grid → chapter
/// number grid → reader (entered through the Screens mechanism).

/// A dark top bar in the shipped sub-screen pattern, with the
/// title as a breadcrumb button when [onBreadcrumb] items exist
/// (§3.5).
Widget libraryTopBar({
  required String title,
  VoidCallback? onBack,
  List<(String, String)>? breadcrumbItems,
  void Function(String value)? onBreadcrumb,
  bool currentIsTestament = false,
}) {
  return Container(
    constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
    padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
    decoration: const BoxDecoration(
      color: WwColors.nav,
      border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
    ),
    child: Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: WwColors.navInk),
            constraints: const BoxConstraints(
              minWidth: WwSpace.minTarget,
              minHeight: WwSpace.minTarget,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: breadcrumbItems == null
              ? Text(
                  title,
                  style: WwType.screenTitle,
                  overflow: TextOverflow.ellipsis,
                )
              : PopupMenuButton<String>(
                  color: WwColors.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                  tooltip: 'Breadcrumb',
                  onSelected: onBreadcrumb,
                  itemBuilder: (_) => [
                    for (final (value, label) in breadcrumbItems)
                      PopupMenuItem(
                        value: value == '__current' ? null : value,
                        height: 48,
                        enabled: value != '__current',
                        child: value == '__current'
                            ? Row(
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 20,
                                    color: WwColors.mutedOnDark,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: WwType.controlLabel.copyWith(
                                      color: WwColors.mutedOnDark,
                                    ),
                                  ),
                                ],
                              )
                            : Text(label, style: WwType.controlLabel),
                      ),
                  ],
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: WwSpace.minTarget,
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: WwType.screenTitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: WwColors.mutedOnDark,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

class LibraryRoot extends StatefulWidget {
  const LibraryRoot({
    super.key,
    required this.dataFuture,
    required this.onTestament,
    required this.onOpenChapter,
    this.conferenceState,
    this.onOpenConference,
  });

  final Future<BibleData> dataFuture;
  final void Function(bool isOT) onTestament;
  final void Function(int ch) onOpenChapter;

  /// The conference layer's live state (board run 8, §4.1). Null
  /// (standalone pumps) renders the shipped root, exactly.
  final ConferenceLayerState? conferenceState;

  /// Pushes the conference browse (§4.2). The shell provides it.
  final VoidCallback? onOpenConference;

  @override
  State<LibraryRoot> createState() => LibraryRootState();
}

class LibraryRootState extends State<LibraryRoot> {
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtl = ScrollController();
  bool _noMatch = false;

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  void focusSearch() {
    _searchFocus.requestFocus();
  }

  void scrollToTop() {
    if (!_scrollCtl.hasClients) return;
    if (WwMotion.reduced(context)) {
      _scrollCtl.jumpTo(0);
    } else {
      _scrollCtl.animateTo(0, duration: WwMotion.push, curve: WwMotion.curve);
    }
  }

  void _submit(BibleData data, String raw) {
    final ch = data.parseSearch(raw);
    if (ch == null) {
      setState(() => _noMatch = true);
      return;
    }
    setState(() => _noMatch = false);
    _searchCtl.clear();
    widget.onOpenChapter(ch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(title: 'Library'),
            Expanded(
              child: FutureBuilder<BibleData>(
                future: widget.dataFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) {
                    return const Center(
                      child: Text(
                        'Loading the library…',
                        style: WwType.captionOnDark,
                      ),
                    );
                  }
                  return ListView(
                    controller: _scrollCtl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: WwSpace.screenMargin,
                    ),
                    children: [
                      const SizedBox(height: 8),
                      SizedBox(
                        height: WwSpace.minTarget,
                        child: TextField(
                          controller: _searchCtl,
                          focusNode: _searchFocus,
                          style: WwType.controlLabel,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) {
                            if (_noMatch) setState(() => _noMatch = false);
                          },
                          onSubmitted: (raw) => _submit(data, raw),
                          decoration: const InputDecoration(
                            hintText:
                                'Jump to a book or chapter: John 3, Psalms 23…',
                          ),
                        ),
                      ),
                      if (_noMatch) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'No match — try a book name and chapter, like John 3.',
                          style: WwType.captionOnDark,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _testamentTile(data, isOT: true),
                      const SizedBox(height: 8),
                      _testamentTile(data, isOT: false),
                      _conferenceTileSlot(),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _testamentTile(BibleData data, {required bool isOT}) {
    // Counts are data, computed from the loaded canon (§3.1).
    final bookCount = isOT
        ? math.min(39, data.books.length)
        : math.max(0, data.books.length - 39);
    final chapterCount = isOT
        ? data.books
              .take(math.min(39, data.books.length))
              .fold(0, (sum, b) => sum + b.chapters)
        : data.books
              .skip(math.min(39, data.books.length))
              .fold(0, (sum, b) => sum + b.chapters);
    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => widget.onTestament(isOT),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(WwSpace.screenMargin),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOT ? 'Old Testament' : 'New Testament',
                      style: WwType.selectionTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$bookCount books · $chapterCount chapters',
                      style: WwType.captionOnDark,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: WwColors.mutedOnDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The conference tile's slot (board run 8, §4.1): when the
  /// layer is OFF — or no state was supplied — this is nothing
  /// at all (absent, not disabled, §1.1). When the state object
  /// is listenable (the shell controller is), the slot rebuilds
  /// on its notifications so a toggle flipped elsewhere agrees
  /// with this render.
  Widget _conferenceTileSlot() {
    final state = widget.conferenceState;
    if (state == null) return const SizedBox.shrink();
    if (state is Listenable) {
      return ListenableBuilder(
        listenable: state as Listenable,
        builder: (context, _) => _conferenceTile(state),
      );
    }
    return _conferenceTile(state);
  }

  /// The General Conference tile (§4.1): built exactly like a
  /// testament tile, below the New Testament tile with the
  /// shipped 8dp inter-tile gap, its caption counted from the
  /// loaded dataset at render time — conferences present in the
  /// browse and the talks it lists (talks with at least one
  /// Bible citation, per [ConferenceData.conferences]). No
  /// coverage or year-range copy appears here (Flag F-6).
  /// Dataset-empty rule: with zero conferences the tile does
  /// not render — a tile into an empty browse is a dead control.
  Widget _conferenceTile(ConferenceLayerState state) {
    if (!state.conferenceEnabled) return const SizedBox.shrink();
    final conferenceData = state.conferenceData;
    if (conferenceData == null) return const SizedBox.shrink();
    final conferences = conferenceData.conferences();
    if (conferences.isEmpty) return const SizedBox.shrink();
    final n = conferences.length;
    var m = 0;
    for (final conference in conferences) {
      m += conference.$3;
    }
    final caption =
        '${n == 1 ? '1 conference' : '$n conferences'} · '
        '${m == 1 ? '1 talk' : '$m talks'}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Semantics(
          container: true,
          button: true,
          label:
              'General Conference, '
              '${n == 1 ? '1 conference' : '$n conferences'}, '
              '${m == 1 ? '1 talk' : '$m talks'}',
          child: ExcludeSemantics(
            child: Material(
              color: WwColors.surface,
              borderRadius: BorderRadius.circular(WwRadius.row),
              child: InkWell(
                borderRadius: BorderRadius.circular(WwRadius.row),
                onTap: widget.onOpenConference,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(WwSpace.screenMargin),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'General Conference',
                              style: WwType.selectionTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(caption, style: WwType.captionOnDark),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: WwColors.mutedOnDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The testament book tile grid (§3.2): 2 columns, tile height
/// derived by the §3.2.1 formula at layout time.
class BookGrid extends StatelessWidget {
  const BookGrid({
    super.key,
    required this.data,
    required this.isOT,
    required this.onOpenBook,
    required this.onBack,
    required this.onBreadcrumbRoot,
  });

  final BibleData data;
  final bool isOT;
  final void Function(int bookIndex) onOpenBook;
  final VoidCallback onBack;
  final VoidCallback onBreadcrumbRoot;

  @override
  Widget build(BuildContext context) {
    final start = isOT ? 0 : math.min(39, data.books.length);
    final end = isOT ? math.min(39, data.books.length) : data.books.length;
    final indices = [for (var i = start; i < end; i++) i];
    final title = isOT ? 'Old Testament' : 'New Testament';
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: title,
              onBack: onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('__current', title),
              ],
              onBreadcrumb: (value) {
                if (value == 'library') onBreadcrumbRoot();
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 32 - 8) / 2;
                  final innerWidth = tileWidth - 24;
                  final metrics = TextMetrics(
                    MediaQuery.textScalerOf(context),
                    DefaultTextStyle.of(context).style,
                  );
                  var nameHeight = 0.0;
                  for (final i in indices) {
                    final h = metrics.height(
                      data.books[i].name,
                      WwType.bookTileTitle,
                      maxWidth: innerWidth,
                    );
                    if (h > nameHeight) nameHeight = h;
                  }
                  final captionHeight = metrics.height(
                    '50 chapters',
                    WwType.captionOnDark,
                    maxWidth: innerWidth,
                  );
                  // §3.2.1: 12 + tallest name + 4 + caption + 12.
                  final tileHeight = 12 + nameHeight + 4 + captionHeight + 12;
                  return GridView.builder(
                    padding: const EdgeInsets.all(WwSpace.screenMargin),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: tileWidth / tileHeight,
                    ),
                    itemCount: indices.length,
                    itemBuilder: (context, i) {
                      final book = data.books[indices[i]];
                      return Material(
                        color: WwColors.surface,
                        borderRadius: BorderRadius.circular(WwRadius.row),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(WwRadius.row),
                          onTap: () => onOpenBook(indices[i]),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(book.name, style: WwType.bookTileTitle),
                                const SizedBox(height: 4),
                                Text(
                                  book.chapters == 1
                                      ? '1 chapter'
                                      : '${book.chapters} chapters',
                                  style: WwType.captionOnDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One book's chapter number grid (§3.3): numbers only, shipped
/// chip construction, derived column count.
class ChapterGrid extends StatelessWidget {
  const ChapterGrid({
    super.key,
    required this.data,
    required this.bookIndex,
    required this.onOpenChapter,
    required this.onBack,
    required this.onBreadcrumb,
  });

  final BibleData data;
  final int bookIndex;
  final void Function(int ch) onOpenChapter;
  final VoidCallback onBack;

  /// Breadcrumb selections: 'library' or 'testament'.
  final void Function(String value) onBreadcrumb;

  @override
  Widget build(BuildContext context) {
    final book = data.books[bookIndex];
    final testament = bookIndex < 39 ? 'Old Testament' : 'New Testament';
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: book.name,
              onBack: onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('testament', testament),
                ('__current', book.name),
              ],
              onBreadcrumb: onBreadcrumb,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth - 32;
                  final columns = math.max(
                    1,
                    ((contentWidth + 8) / 56).floor(),
                  );
                  return GridView.builder(
                    padding: const EdgeInsets.all(WwSpace.screenMargin),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: book.chapters,
                    itemBuilder: (context, i) {
                      return Material(
                        color: WwColors.surface,
                        borderRadius: BorderRadius.circular(WwRadius.row),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(WwRadius.row),
                          onTap: () => onOpenChapter(book.start + i),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: WwType.bodyOnDark,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
