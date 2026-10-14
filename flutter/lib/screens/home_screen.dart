import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../theme/ww_theme.dart';
import '../widgets/arc_stage.dart';

/// Home screen: the whole-Bible book/chapter list, with a compact arc
/// mini-map pinned at the top showing the current selection.
///
/// The mini-map is a display only — no pan or zoom. With nothing
/// selected it shows the full web; selecting a chapter swaps the base
/// image to bars only and the selection layer draws just that
/// chapter's arcs, so what is selected is unmistakable (founder,
/// Oct 13, 2026). Scope and jump search carry over from the retired
/// arc explorer screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _miniStage = Size(1200, 500);

  /// Resume state (research desk ADOPT, Oct 14, 2026): like Gospel
  /// Library, Logos, and Dwell, relaunching restores the user's place —
  /// the scope and selected chapter, persisted with shared_preferences.
  static const _scopeKey = 'ww_home_scope';
  static const _selectedKey = 'ww_home_selected';

  BibleData? _data;
  Object? _error;
  String _scope = 'all';
  int? _selected;

  final _searchCtl = TextEditingController();
  final _scrollCtl = ScrollController();

  final _images = <String, ui.Image>{};
  final _rendering = <String>{};
  final _bookKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _scrollCtl.dispose();
    _disposeImages();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await BibleData.load();
      if (!mounted) return;
      final restored = await _restoreState(data);
      if (!mounted) return;
      // Scope first, then selection (the restored selection is only
      // valid inside the restored scope — _restoreState checks both).
      setState(() {
        _data = data;
        _error = null;
        _scope = restored.$1;
        _selected = restored.$2;
      });
      final sel = restored.$2;
      if (sel != null) _scrollToBook(data.chapters[sel].b);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Reads the persisted scope and selection. Returns the saved scope
  /// when it is one of 'all'/'ot'/'nt' (else 'all'), and the saved
  /// selection only when it is a real chapter inside that scope's
  /// range; missing or invalid values restore as unselected.
  Future<(String, int?)> _restoreState(BibleData data) async {
    var scope = 'all';
    int? selected;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScope = prefs.getString(_scopeKey);
      if (savedScope == 'all' || savedScope == 'ot' || savedScope == 'nt') {
        scope = savedScope!;
      }
      final savedSelected = prefs.getInt(_selectedKey);
      if (savedSelected != null &&
          savedSelected >= 0 &&
          savedSelected < data.totalChapters) {
        final (lo, hi) = data.scopeRange(scope);
        if (savedSelected >= lo && savedSelected <= hi) {
          selected = savedSelected;
        }
      }
    } catch (_) {
      // Persistence is a convenience; a read failure just starts fresh.
    }
    return (scope, selected);
  }

  /// Persists the current scope and selection. Clearing the selection
  /// removes the selected key, so a relaunch starts unselected.
  Future<void> _persistState() async {
    final scope = _scope;
    final selected = _selected;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scopeKey, scope);
      if (selected == null) {
        await prefs.remove(_selectedKey);
      } else {
        await prefs.setInt(_selectedKey, selected);
      }
    } catch (_) {
      // A failed write only loses the resume point, never the session.
    }
  }

  (int, int) get _range => _data!.scopeRange(_scope);

  void _disposeImages() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
  }

  Future<void> _ensureMiniImage({
    required String key,
    required int lo,
    required int hi,
    required double band,
    required bool includeArcs,
  }) async {
    final data = _data;
    if (data == null) return;
    if (_images.containsKey(key) || _rendering.contains(key)) return;
    _rendering.add(key);
    try {
      final img = await renderArcImage(
        data: data,
        lo: lo,
        hi: hi,
        stage: _miniStage,
        density: band,
        faint: false,
        includeArcs: includeArcs,
        includeLabels: false,
      );
      _images[key] = img;
      if (mounted) setState(() {});
    } finally {
      _rendering.remove(key);
    }
  }

  void _setScope(String scope) {
    if (scope == _scope) return;
    final data = _data;
    if (data == null) return;
    _disposeImages();
    setState(() {
      _scope = scope;
      final sel = _selected;
      if (sel != null) {
        final (lo, hi) = data.scopeRange(scope);
        if (sel < lo || sel > hi) _selected = null;
      }
    });
    _persistState();
    if (_scrollCtl.hasClients) _scrollCtl.jumpTo(0);
  }

  /// Selects [ch]. Search and partner-chip jumps widen the scope to
  /// 'all' when the chapter falls outside it, and scroll the list to
  /// the chapter's book. A tap on a visible chapter chip passes
  /// [scroll] false — the chapter is already on screen.
  void _select(int ch, {required bool scroll}) {
    final data = _data;
    if (data == null) return;
    final (lo, hi) = _range;
    final needsAll = ch < lo || ch > hi;
    if (needsAll) _disposeImages();
    setState(() {
      if (needsAll) _scope = 'all';
      _selected = ch;
    });
    _persistState();
    if (scroll) _scrollToBook(data.chapters[ch].b);
  }

  void _clearSelection() {
    setState(() => _selected = null);
    _persistState();
  }

  void _scrollToBook(int bookIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _bookKeys[bookIndex]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: WwMotion.reduced(ctx) ? Duration.zero : WwMotion.push,
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    });
  }

  void _submitSearch(String raw) {
    final data = _data;
    if (data == null) return;
    final ch = data.parseSearch(raw);
    if (ch == null) return;
    _select(ch, scroll: true);
    _searchCtl.clear();
    FocusScope.of(context).unfocus();
  }

  GlobalKey _keyForBook(int bookIndex) =>
      _bookKeys.putIfAbsent(bookIndex, () => GlobalKey());

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (data != null) _tools(data),
            if (data != null) _miniMap(data),
            Expanded(child: data != null ? _scrollArea(data) : _statusArea()),
          ],
        ),
      ),
    );
  }

  Widget _statusArea() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The web could not be woven.', style: WwType.bodyOnDark),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(
                minimumSize: const Size(64, WwSpace.minTarget),
              ),
              child: Text(
                'Try again',
                style: WwType.buttonLabel.copyWith(color: WwColors.goldBright),
              ),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Woven Word', style: WwType.screenTitle),
          SizedBox(height: 12),
          Text('Weaving 344,799 connections…', style: WwType.captionOnDark),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: WwSpace.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      decoration: const BoxDecoration(
        color: WwColors.nav,
        border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: const Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Woven Word', style: WwType.appTitle),
              Text('BIBLE CROSS REFERENCES', style: WwType.appSubtitle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tools(BibleData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WwSpace.screenMargin,
        8,
        WwSpace.screenMargin,
        8,
      ),
      child: Row(
        children: [
          Container(
            height: WwSpace.minTarget,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: WwColors.surfaceHigh,
              borderRadius: BorderRadius.circular(WwRadius.input),
              border: Border.all(color: WwColors.borderDark),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _scope,
                dropdownColor: WwColors.surfaceHigh,
                style: WwType.controlLabel,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: WwColors.mutedOnDark,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Whole Bible')),
                  DropdownMenuItem(value: 'ot', child: Text('Old Testament')),
                  DropdownMenuItem(value: 'nt', child: Text('New Testament')),
                ],
                onChanged: (v) {
                  if (v != null) _setScope(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: WwSpace.minTarget,
              child: TextField(
                controller: _searchCtl,
                style: WwType.controlLabel,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                decoration: const InputDecoration(
                  hintText: 'Jump to a book or chapter: John 3, Psalms 23…',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMap(BibleData data) {
    final (lo, hi) = _range;
    return Container(
      decoration: const BoxDecoration(
        color: WwColors.stage,
        border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final band = bandFor(densityFor(w));
          final includeArcs = _selected == null;
          final key = '$lo-$hi-$band-$includeArcs';
          final img = _images[key];
          if (img == null) {
            _ensureMiniImage(
              key: key,
              lo: lo,
              hi: hi,
              band: band,
              includeArcs: includeArcs,
            );
          }
          return SizedBox(
            width: w,
            height: w * _miniStage.height / _miniStage.width,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _miniStage.width,
                height: _miniStage.height,
                child: Stack(
                  children: [
                    if (img != null)
                      RawImage(
                        image: img,
                        width: _miniStage.width,
                        height: _miniStage.height,
                        fit: BoxFit.fill,
                      ),
                    if (_selected != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: MiniSelectionPainter(
                            data: data,
                            lo: lo,
                            hi: hi,
                            stage: _miniStage,
                            selected: _selected,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scrollArea(BibleData data) {
    return CustomScrollView(
      controller: _scrollCtl,
      slivers: [
        if (_selected != null) _selectionPanel(data),
        ..._bookSlivers(data),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _selectionPanel(BibleData data) {
    final ch = _selected!;
    final c = data.chapters[ch];
    return SliverToBoxAdapter(
      child: Container(
        color: WwColors.surface,
        padding: const EdgeInsets.all(WwSpace.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(data.chapterName(ch), style: WwType.selectionTitle),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmt(c.v)} verses · '
                        '${_fmt(data.chapterConnCount[ch])} connections',
                        style: WwType.captionOnDark,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear selection',
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close, color: WwColors.navInk),
                  constraints: const BoxConstraints(
                    minWidth: WwSpace.minTarget,
                    minHeight: WwSpace.minTarget,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Connected chapters', style: WwType.captionOnDark),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in data.partnersSorted(ch))
                  _partnerChip(data, entry),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerChip(BibleData data, MapEntry<int, int> entry) {
    return Material(
      color: WwColors.surfaceHigh,
      borderRadius: BorderRadius.circular(WwRadius.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.chip),
        onTap: () => _select(entry.key, scroll: true),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.chapterName(entry.key), style: WwType.controlLabel),
              const SizedBox(width: 6),
              Text(_fmt(entry.value), style: WwType.captionOnDark),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _bookSlivers(BibleData data) {
    final start = _scope == 'nt' ? 39 : 0;
    final end = _scope == 'ot'
        ? (data.books.length < 39 ? data.books.length : 39)
        : data.books.length;
    final slivers = <Widget>[];
    for (var bi = start; bi < end; bi++) {
      if (_scope == 'all' && bi == 0) {
        slivers.add(_sectionHeader('OLD TESTAMENT'));
      }
      if (_scope == 'all' && bi == 39) {
        slivers.add(_sectionHeader('NEW TESTAMENT'));
      }
      slivers.add(SliverToBoxAdapter(child: _bookSection(data, bi)));
    }
    return slivers;
  }

  Widget _sectionHeader(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WwSpace.screenMargin,
          WwSpace.screenMargin,
          WwSpace.screenMargin,
          0,
        ),
        child: Text(label, style: WwType.appSubtitle),
      ),
    );
  }

  Widget _bookSection(BibleData data, int bi) {
    final book = data.books[bi];
    return Column(
      key: _keyForBook(bi),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WwSpace.screenMargin,
            WwSpace.screenMargin,
            WwSpace.screenMargin,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  book.name,
                  style: WwType.bodyOnDark.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                book.chapters == 1 ? '1 chapter' : '${book.chapters} chapters',
                style: WwType.captionOnDark,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 1; n <= book.chapters; n++)
                _chapterChip(book.start + n - 1, n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chapterChip(int ch, int n) {
    final selected = ch == _selected;
    return Material(
      color: selected ? WwColors.goldBright : WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => _select(ch, scroll: false),
        child: Container(
          width: WwSpace.minTarget,
          height: WwSpace.minTarget,
          alignment: Alignment.center,
          child: Text(
            '$n',
            style: selected
                ? const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WwColors.onGold,
                  )
                : WwType.bodyOnDark,
          ),
        ),
      ),
    );
  }
}
