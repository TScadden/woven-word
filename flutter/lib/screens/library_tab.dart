import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../data/confession_data.dart';
import '../data/conference_data.dart';
import '../data/deuterocanon.dart';
import '../data/library_search.dart';
import '../data/tradition.dart';
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

/// The tradition layer's live state for the Library root (board
/// run 9): the generalization of [ConferenceLayerState]. The
/// shell controller implements it; standalone pumps pass null
/// and render the shipped root.
abstract class TraditionLayerState {
  WwTradition get tradition;
  ConfessionData? get confessionData;
  DeuterocanonData? get deuterocanonData;
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
    this.traditionState,
    this.onOpenTanakh,
    this.onOpenCatholicOt,
    this.onOpenConfessions,
    this.onOpenBook,
    this.onOpenDeuteroBook,
    this.onOpenDeuteroChapter,
    this.onOpenTalk,
  });

  final Future<BibleData> dataFuture;
  final void Function(bool isOT) onTestament;
  final void Function(int ch) onOpenChapter;

  /// The conference layer's live state (board run 8, §4.1). Null
  /// (standalone pumps) renders the shipped root, exactly.
  final ConferenceLayerState? conferenceState;

  /// Pushes the conference browse (§4.2). The shell provides it.
  final VoidCallback? onOpenConference;

  /// The tradition layer's live state (board run 9). Null
  /// (standalone pumps) renders the shipped root, exactly.
  final TraditionLayerState? traditionState;

  /// Pushes the Tanakh sectioned grid (Jewish tradition).
  final VoidCallback? onOpenTanakh;

  /// Pushes the Catholic Old Testament grid (core + deuterocanon
  /// books in Catholic order).
  final VoidCallback? onOpenCatholicOt;

  /// Pushes the confessions browse (Protestant tradition).
  final VoidCallback? onOpenConfessions;

  /// Live search (search fix package, spec §5): pushes one
  /// core book's chapter grid from a BOOKS result. Optional —
  /// a pump that omits it renders no core-book result rows
  /// (absent, never dead).
  final void Function(int bookIndex)? onOpenBook;

  /// Pushes one deuterocanon book's chapter grid from a BOOKS
  /// result (Catholic tradition).
  final void Function(DeuteroBook book)? onOpenDeuteroBook;

  /// Opens the deuterocanon reader at one chapter, from a
  /// CHAPTERS result or a bare-book submit.
  final void Function(DeuteroBook book, int chapterInBook)?
  onOpenDeuteroChapter;

  /// Pushes one talk's talk view from a TALKS result — the
  /// direct push, not the stack-resetting sheet path, so the
  /// search state survives underneath (§4).
  final void Function(ConferenceTalk talk)? onOpenTalk;

  @override
  State<LibraryRoot> createState() => LibraryRootState();
}

class LibraryRootState extends State<LibraryRoot> {
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollCtl = ScrollController();

  /// The search field's current text (search fix package).
  /// Results derive from it synchronously at build (§2.1), so
  /// no frame can show a previous query's results.
  String _query = '';

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

  /// The layer listenable the search surfaces rebuild on, the
  /// conference tile slot's rule (§5): the first of the two
  /// layer states that is a [Listenable]. In the shell both
  /// are the one controller.
  Listenable? get _layerListenable {
    final conference = widget.conferenceState;
    if (conference is Listenable) return conference as Listenable;
    final tradition = widget.traditionState;
    if (tradition is Listenable) return tradition as Listenable;
    return null;
  }

  bool get _conferenceOn {
    final state = widget.conferenceState;
    return state != null && state.conferenceEnabled;
  }

  /// The §3 model over the current query and layer states.
  /// The conference dataset enters only while the layer is on
  /// (the tile slot's exact conditions), so layer-off searches
  /// have no TALKS group, structurally.
  LibrarySearchResults _results(BibleData data) {
    final traditionState = widget.traditionState;
    final conferenceState = widget.conferenceState;
    return searchLibrary(
      data: data,
      tradition: traditionState?.tradition ?? WwTradition.none,
      query: _query,
      deuterocanon: traditionState?.deuterocanonData,
      conference: _conferenceOn ? conferenceState?.conferenceData : null,
    );
  }

  /// The keyboard search action (§2.6): the shipped jump,
  /// resolved through the §3 model — the first CHAPTERS
  /// result, else (for a query with no trailing number) the
  /// first BOOKS result's chapter 1. An out-of-range reference
  /// ("John 99") jumps nowhere: search never invents a chapter.
  ///
  /// A submitted jump keeps the shipped run-7 field contract:
  /// it clears the field, so the root beneath the destination
  /// is the browse view (NAV-3 pins those tiles after a
  /// search jump + re-tap). Result-row taps are the other
  /// contract — they keep the query (§4).
  void _jump(BibleData data) {
    if (_query.trim().isEmpty) return;
    final results = _results(data);
    void land(VoidCallback go) {
      _searchCtl.clear();
      setState(() => _query = '');
      go();
    }

    if (results.chapters.isNotEmpty) {
      land(() => widget.onOpenChapter(results.chapters.first));
      return;
    }
    if (results.deuteroChapters.isNotEmpty &&
        widget.onOpenDeuteroChapter != null) {
      final (book, chapterInBook) = results.deuteroChapters.first;
      land(() => widget.onOpenDeuteroChapter!(book, chapterInBook));
      return;
    }
    if (RegExp(r'\d+$').hasMatch(_query.trim())) return;
    if (results.books.isNotEmpty) {
      land(() => widget.onOpenChapter(data.books[results.books.first].start));
      return;
    }
    if (results.deuteroBooks.isNotEmpty &&
        widget.onOpenDeuteroChapter != null) {
      final book = results.deuteroBooks.first;
      land(() => widget.onOpenDeuteroChapter!(book, 1));
    }
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
                      _searchField(data),
                      const SizedBox(height: 16),
                      if (_query.trim().isEmpty) ...[
                        _tilesRegion(data),
                        _conferenceTileSlot(),
                      ] else
                        _resultsRegion(data),
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

  /// The search field (search fix package): live results on
  /// every keystroke; the keyboard search action keeps its
  /// jump meaning (§2.6). The hint names exactly the groups
  /// that can appear (§2.5), so the field rebuilds on the
  /// layer listenable alongside the results region.
  Widget _searchField(BibleData data) {
    Widget field() => SizedBox(
      height: WwSpace.minTarget,
      child: TextField(
        controller: _searchCtl,
        focusNode: _searchFocus,
        style: WwType.controlLabel,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value),
        onSubmitted: (_) => _jump(data),
        decoration: InputDecoration(
          hintText: _conferenceOn
              ? 'Search books, chapters, talks…'
              : 'Search books and chapters…',
        ),
      ),
    );
    final listenable = _layerListenable;
    if (listenable == null) return field();
    return ListenableBuilder(listenable: listenable, builder: (_, _) => field());
  }

  /// The results region (§2.3): rebuilds on the layer
  /// listenable under the tile slot's rule, so a layer or
  /// tradition change on another tab agrees with the next
  /// keystroke's results.
  Widget _resultsRegion(BibleData data) {
    final listenable = _layerListenable;
    if (listenable == null) return _resultsList(data);
    return ListenableBuilder(
      listenable: listenable,
      builder: (_, _) => _resultsList(data),
    );
  }

  Widget _resultsList(BibleData data) {
    final results = _results(data);
    if (results.isEmpty) {
      return const Text(
        'No match — try a book name and chapter, like John 3.',
        style: WwType.captionOnDark,
      );
    }
    final groups = <Widget>[];

    // BOOKS (§3.1 + §3.2): a group renders only the rows whose
    // navigation was supplied (§5 — absent, never dead).
    final bookRows = <Widget>[];
    if (widget.onOpenBook != null) {
      for (final bookIndex in results.books) {
        final book = data.books[bookIndex];
        bookRows.add(
          _searchRow(
            title: book.name,
            subtitle: book.chapters == 1
                ? '1 chapter'
                : '${book.chapters} chapters',
            semanticsLabel: 'Open book: ${book.name}',
            onTap: () => widget.onOpenBook!(bookIndex),
          ),
        );
      }
    }
    if (widget.onOpenDeuteroBook != null) {
      for (final book in results.deuteroBooks) {
        bookRows.add(
          _searchRow(
            title: book.name,
            subtitle:
                '${book.chapters == 1 ? '1 chapter' : '${book.chapters} chapters'}'
                ' · Deuterocanon',
            semanticsLabel: 'Open book: ${book.name}',
            onTap: () => widget.onOpenDeuteroBook!(book),
          ),
        );
      }
    }
    if (bookRows.isNotEmpty) {
      groups.add(_group('BOOKS', bookRows));
    }

    // CHAPTERS (§3.3): core rows ride the shipped onOpenChapter;
    // deutero rows render only with their navigation supplied.
    final chapterRows = <Widget>[];
    for (final ch in results.chapters) {
      final verses = data.chapters[ch].v;
      chapterRows.add(
        _searchRow(
          title: data.chapterName(ch),
          subtitle: verses == 1 ? '1 verse' : '$verses verses',
          semanticsLabel: 'Open chapter: ${data.chapterName(ch)}',
          onTap: () => widget.onOpenChapter(ch),
        ),
      );
    }
    if (widget.onOpenDeuteroChapter != null) {
      for (final (book, chapterInBook) in results.deuteroChapters) {
        final verses = book.verseCounts[chapterInBook - 1];
        chapterRows.add(
          _searchRow(
            title: '${book.name} $chapterInBook',
            subtitle:
                '${verses == 1 ? '1 verse' : '$verses verses'} · Deuterocanon',
            semanticsLabel: 'Open chapter: ${book.name} $chapterInBook',
            onTap: () => widget.onOpenDeuteroChapter!(book, chapterInBook),
          ),
        );
      }
    }
    if (chapterRows.isNotEmpty) {
      groups.add(_group('CHAPTERS', chapterRows));
    }

    // TALKS (§3.4).
    if (widget.onOpenTalk != null && results.talks.isNotEmpty) {
      groups.add(
        _group('TALKS', [
          for (final talk in results.talks)
            _searchRow(
              title: talk.title,
              subtitle: '${talk.speaker} · ${talk.conferenceLabel}',
              semanticsLabel: 'Open talk: ${talk.title}, by ${talk.speaker}',
              onTap: () => widget.onOpenTalk!(talk),
            ),
        ]),
      );
    }

    if (groups.isEmpty) {
      // Matches exist but no supplied navigation can open any
      // of them (a bare standalone pump): the honest line, not
      // dead rows.
      return const Text(
        'No match — try a book name and chapter, like John 3.',
        style: WwType.captionOnDark,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          groups[i],
        ],
      ],
    );
  }

  /// One results group: the shipped section header (the
  /// sectioned grids' appSubtitle eyebrow) over browse rows
  /// at the shipped 8dp row gap.
  Widget _group(String title, List<Widget> rows) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: WwType.appSubtitle),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          rows[i],
        ],
      ],
    );
  }

  /// One search result row: the shipped browse-row
  /// construction (conference browse's `browseRow`, built
  /// locally — that file imports this one for the top bar, so
  /// the construction is mirrored, not imported): Material
  /// surface + row radius + InkWell, minHeight 48, the whole
  /// row the tap target, one container semantics node with
  /// the §4 label (lesson 25).
  Widget _searchRow({
    required String title,
    required String subtitle,
    required String semanticsLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: WwType.controlLabel.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: WwType.captionOnDark),
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

  /// The canon tile region (board run 9): the tradition decides
  /// which canon the Library presents. With no tradition state
  /// (standalone pumps) or Bible only / Latter-day Saint /
  /// Protestant selected, the tiles are the shipped testament
  /// pair (Protestant adds its confessions tile below). Jewish
  /// presents the Tanakh alone; Catholic's Old Testament tile
  /// counts the union canon and opens the mixed grid. When the
  /// state object is listenable (the shell controller is), the
  /// region rebuilds on its notifications, the conference slot's
  /// rule.
  Widget _tilesRegion(BibleData data) {
    final state = widget.traditionState;
    if (state == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _testamentTile(data, isOT: true),
          const SizedBox(height: 8),
          _testamentTile(data, isOT: false),
        ],
      );
    }
    if (state is Listenable) {
      return ListenableBuilder(
        listenable: state as Listenable,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: _traditionTiles(data, state),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _traditionTiles(data, state),
    );
  }

  List<Widget> _traditionTiles(BibleData data, TraditionLayerState state) {
    switch (state.tradition) {
      case WwTradition.jewish:
        final otBooks = math.min(39, data.books.length);
        final chapters = data.books
            .take(otBooks)
            .fold(0, (sum, b) => sum + b.chapters);
        return [
          _layerTile(
            title: 'Tanakh',
            caption: '$otBooks books · $chapters chapters',
            onTap: widget.onOpenTanakh,
          ),
        ];
      case WwTradition.catholic:
        final deutero = state.deuterocanonData;
        if (deutero == null || deutero.books.isEmpty) {
          // The extra canon has not loaded (or failed): no Old
          // Testament tile at all until the union tile can render.
          // The shipped 39-book tile would undercount the canon
          // this tradition names, permanently if the load failed.
          return [_testamentTile(data, isOT: false)];
        }
        final otBooks = math.min(39, data.books.length);
        final otChapters = data.books
            .take(otBooks)
            .fold(0, (sum, b) => sum + b.chapters);
        // The union count names each book once: the Greek Esther
        // and Greek Daniel are alternate editions of core books
        // already inside the 39, so they add tiles to the grid
        // but not books or chapters to the count (46 books · 1066
        // chapters on the bundled table).
        final extra = deutero.books
            .where(
              (b) => b.slug != 'esther-greek' && b.slug != 'daniel-greek',
            )
            .toList();
        final books = otBooks + extra.length;
        final chapters =
            otChapters + extra.fold(0, (sum, b) => sum + b.chapters);
        return [
          _layerTile(
            title: 'Old Testament',
            caption: '$books books · $chapters chapters',
            onTap: widget.onOpenCatholicOt,
          ),
          const SizedBox(height: 8),
          _testamentTile(data, isOT: false),
        ];
      case WwTradition.protestant:
        final tiles = <Widget>[
          _testamentTile(data, isOT: true),
          const SizedBox(height: 8),
          _testamentTile(data, isOT: false),
        ];
        final confessions = state.confessionData;
        if (confessions != null && confessions.docs.isNotEmpty) {
          final d = confessions.docs.length;
          final s = confessions.sections.length;
          tiles.add(const SizedBox(height: 8));
          tiles.add(
            _layerTile(
              title: 'Confessions',
              caption:
                  '${d == 1 ? '1 document' : '$d documents'} · '
                  '${s == 1 ? '1 section' : '$s sections'}',
              onTap: widget.onOpenConfessions,
            ),
          );
        }
        return tiles;
      case WwTradition.none:
      case WwTradition.lds:
        return [
          _testamentTile(data, isOT: true),
          const SizedBox(height: 8),
          _testamentTile(data, isOT: false),
        ];
    }
  }

  /// A layer tile in the testament tile's construction
  /// (selectionTitle + captionOnDark, 72dp floor, chevron).
  Widget _layerTile({
    required String title,
    required String caption,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      label: '$title, $caption',
      child: ExcludeSemantics(
        child: Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: onTap,
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
                        Text(title, style: WwType.selectionTitle),
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
              breadcrumbItems: [('library', 'Library'), ('__current', title)],
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
                            child: Text('${i + 1}', style: WwType.bodyOnDark),
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
