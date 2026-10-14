import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/scripture_text.dart';
import '../theme/ww_theme.dart';

/// Reader screen: one chapter on cream paper, in KJV or WEB.
///
/// Mirrors the web v1 reading view: a verse's connections are
/// bidirectional, the gold dot marks any verse with at least one
/// connection, tapping a verse opens its connections sheet (its own
/// text first, then each connection as a reference label plus the
/// referenced verse's text in the active translation), and tapping a
/// connection jumps to that chapter and flashes the target verse.
/// No highlight or note UI here — those are later packages.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.data,
    required this.chapter,
    this.verse,
  });

  final BibleData data;
  final int chapter;
  final int? verse;

  /// SharedPreferences key for the active translation (the reader's
  /// only persistence in this package).
  static const translationKey = 'ww_translation';

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  /// How long a jumped-to verse stays selected (web v1: ~2.6s).
  static const _flashDuration = Duration(milliseconds: 2600);

  late int _chapter;
  int? _selectedVerse;
  WwTranslation _translation = WwTranslation.kjv;

  ScriptureText? _texts;
  Object? _error;

  final _scrollCtl = ScrollController();
  final _verseKeys = <int, GlobalKey>{};
  Timer? _flashTimer;

  /// In-reader back history (research desk, board run 3 — Gospel
  /// Library's guide: back returns you to where you came from).
  /// Cross-reference study is a chain, so connection jumps and
  /// prev/next chapter moves push the current (chapter, verse)
  /// position here; back — top bar or Android system back — restores
  /// the last pushed position first and only pops the route when
  /// this stack is empty.
  final _history = <(int, int?)>[];

  (int, int?) get _position => (_chapter, _selectedVerse);

  void _pushHistory() {
    final current = _position;
    if (_history.isEmpty || _history.last != current) {
      _history.add(current);
    }
  }

  /// Back handling shared by the top-bar button and [PopScope].
  void _handleBack() {
    if (_history.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final (ch, v) = _history.removeLast();
    _flashTimer?.cancel();
    final chapterChanged = ch != _chapter;
    setState(() {
      _chapter = ch;
      _selectedVerse = v;
      if (chapterChanged) _verseKeys.clear();
    });
    if (v != null) {
      _flashToVerse(v);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtl.hasClients) _scrollCtl.jumpTo(0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _chapter = widget.chapter;
    _load();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _scrollCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var translation = WwTranslation.kjv;
      try {
        final prefs = await SharedPreferences.getInstance();
        translation = WwTranslation.fromStored(
          prefs.getString(ReaderScreen.translationKey),
        );
      } catch (_) {
        // Persistence is a convenience; the default stands.
      }
      final texts = await ScriptureText.load();
      if (!mounted) return;
      setState(() {
        _texts = texts;
        _translation = translation;
        _error = null;
      });
      final target = widget.verse;
      if (target != null) _flashToVerse(target);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _texts = null;
      _error = null;
    });
    await _load();
  }

  Future<void> _setTranslation(WwTranslation t) async {
    if (t == _translation) return;
    setState(() => _translation = t);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ReaderScreen.translationKey, t.label);
    } catch (_) {
      // A failed write only loses the preference, never the session.
    }
  }

  GlobalKey _keyForVerse(int v) => _verseKeys.putIfAbsent(v, () => GlobalKey());

  /// Selects [v], scrolls it into view, and — unless reduced motion —
  /// clears the selection after the flash duration. Reduced motion
  /// scrolls instantly and leaves the verse selected.
  void _flashToVerse(int v) {
    _flashTimer?.cancel();
    if (_selectedVerse != v) setState(() => _selectedVerse = v);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keyForVerse(v).currentContext;
      if (ctx == null) return;
      final reduced = WwMotion.reduced(ctx);
      Scrollable.ensureVisible(
        ctx,
        duration: reduced ? Duration.zero : WwMotion.push,
        curve: Curves.easeOut,
        alignment: 0.5,
      );
      if (reduced) return;
      _flashTimer = Timer(_flashDuration, () {
        if (mounted && _selectedVerse == v) {
          setState(() => _selectedVerse = null);
        }
      });
    });
  }

  /// Jumps the reader to another chapter + verse (a connections-sheet
  /// row tap): swaps the chapter in place when it differs, then
  /// scrolls to and flashes the target verse.
  void _navigateTo(int ch, int v) {
    if ((ch, v) != _position) _pushHistory();
    _flashTimer?.cancel();
    final chapterChanged = ch != _chapter;
    setState(() {
      _chapter = ch;
      _selectedVerse = v;
      if (chapterChanged) _verseKeys.clear();
    });
    _flashToVerse(v);
  }

  void _goToChapter(int ch) {
    if (ch < 0 || ch >= widget.data.totalChapters || ch == _chapter) return;
    _pushHistory();
    _flashTimer?.cancel();
    setState(() {
      _chapter = ch;
      _selectedVerse = null;
      _verseKeys.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollCtl.hasClients) _scrollCtl.jumpTo(0);
    });
  }

  void _onVerseTap(int v) {
    _flashTimer?.cancel();
    setState(() => _selectedVerse = v);
    _showConnections(v);
  }

  void _showConnections(int v) {
    final data = widget.data;
    final texts = _texts!;
    final translation = _translation;
    final ch = _chapter;
    final conns = data.verseConnections(ch, v);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WwColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WwRadius.sheet),
        ),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.all(WwSpace.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.refName(ch, v), style: WwType.sheetRefTitle),
                const SizedBox(height: 8),
                Text(
                  texts.verseText(translation, data, ch, v),
                  style: WwType.readerSheetVerse,
                ),
                const SizedBox(height: 12),
                // Names what a verse tap means, so first-time users
                // learn it instantly (research desk, board run 3).
                const Text('Connections', style: WwType.refLabel),
                const SizedBox(height: 8),
                if (conns.isEmpty)
                  const Text(
                    'No cross references are recorded for this verse.',
                    style: WwType.captionOnPaper,
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: conns.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: WwColors.line),
                      itemBuilder: (_, i) {
                        final tc = conns[i][0];
                        final tv = conns[i][1];
                        return InkWell(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _navigateTo(tc, tv);
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: WwSpace.minTarget,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data.refName(tc, tv),
                                  style: WwType.refLabel,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  // Snippet resolution: the entry's
                                  // target chapter + verse, read in
                                  // the ACTIVE translation through
                                  // ScriptureText (which clamps to
                                  // that text's own chapter length).
                                  texts.verseText(translation, data, tc, tv),
                                  style: WwType.snippet,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Android system back follows the same rule as the top-bar back
    // button: pop the in-reader history first, pop the route only
    // when it is empty (canPop tracks the stack, rebuilt on setState).
    return PopScope(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    final data = widget.data;
    if (_error != null) {
      return Scaffold(
        backgroundColor: WwColors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(data, showToggle: false),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'The text could not be loaded.',
                        style: WwType.bodyOnPaper,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _retry,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, WwSpace.minTarget),
                        ),
                        child: Text(
                          'Try again',
                          style: WwType.paperButtonLabelGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final texts = _texts;
    if (texts == null) {
      return Scaffold(
        backgroundColor: WwColors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(data, showToggle: false),
              const Expanded(
                child: Center(
                  child: Text(
                    'Loading the text…',
                    style: WwType.captionOnPaper,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: WwColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(data, showToggle: true),
            Expanded(child: _chapterBody(data, texts)),
            _bottomBar(data),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BibleData data, {required bool showToggle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      decoration: const BoxDecoration(
        color: WwColors.paper,
        border: Border(bottom: BorderSide(color: WwColors.line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back, color: WwColors.ink),
            constraints: const BoxConstraints(
              minWidth: WwSpace.minTarget,
              minHeight: WwSpace.minTarget,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.chapterName(_chapter),
              style: WwType.readerTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showToggle) ...[const SizedBox(width: 8), _translationToggle()],
        ],
      ),
    );
  }

  Widget _translationToggle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: WwColors.line),
        borderRadius: BorderRadius.circular(WwRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in WwTranslation.values)
            Material(
              color: t == _translation
                  ? WwColors.goldBright
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(WwRadius.chip),
              child: InkWell(
                borderRadius: BorderRadius.circular(WwRadius.chip),
                onTap: () => _setTranslation(t),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: WwSpace.minTarget,
                    minHeight: WwSpace.minTarget,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    t.label,
                    style: t == _translation
                        ? WwType.goldButtonLabel
                        : WwType.translationUnselected,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Horizontal swipe on the reading body: a SECONDARY prev/next
  /// chapter gesture (research desk, board run 3). The labeled
  /// bottom-bar buttons stay the primary affordance; a fast enough
  /// horizontal drag end (velocity past the threshold) mirrors them,
  /// including the history push inside [_goToChapter].
  void _onSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null) return;
    const threshold = 300.0;
    if (velocity < -threshold) {
      _goToChapter(_chapter + 1); // swipe left: next chapter
    } else if (velocity > threshold) {
      _goToChapter(_chapter - 1); // swipe right: previous chapter
    }
  }

  Widget _chapterBody(BibleData data, ScriptureText texts) {
    final verses = texts.chapterVerses(_translation, data, _chapter);
    return GestureDetector(
      onHorizontalDragEnd: _onSwipeEnd,
      child: SingleChildScrollView(
        controller: _scrollCtl,
        padding: const EdgeInsets.fromLTRB(
          WwSpace.screenMargin,
          16,
          WwSpace.screenMargin,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < verses.length; i++)
              _verseBlock(data, i + 1, verses[i]),
          ],
        ),
      ),
    );
  }

  Widget _verseBlock(BibleData data, int v, String text) {
    final selected = v == _selectedVerse;
    final hasConns = data.verseHasConnections(_chapter, v);
    return Material(
      // Selected highlight: hlGold at ~45% over paper (#FBF0C6
      // composited). On it, goldTextOnPaper fails contrast (4.11:1),
      // so the verse number switches to the ink role when selected —
      // see WwType.verseNumberSelected.
      color: selected
          ? WwColors.hlGold.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        key: _keyForVerse(v),
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => _onVerseTap(v),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Text(
                      '$v',
                      textAlign: TextAlign.center,
                      style: selected
                          ? WwType.verseNumberSelected
                          : WwType.verseNumber,
                    ),
                    if (hasConns) ...[
                      const SizedBox(height: 4),
                      // The dot's contrast in both states: on
                      // paper the DARK gold token passes at 3.20:1,
                      // but on the selected-verse background
                      // (hlGold at 45% over paper = #FBF0C6) it
                      // falls to 2.85:1, below the 3:1
                      // meaningful-icon threshold — so when
                      // selected the dot switches to
                      // goldTextOnPaper (4.11:1 on #FBF0C6),
                      // mirroring the verse-number pattern.
                      // Never goldBright on cream (research desk
                      // note, board run 3; Petra High-1).
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: selected
                              ? WwColors.goldTextOnPaper
                              : WwColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: WwType.readerBody)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BibleData data) {
    final hasPrev = _chapter > 0;
    final hasNext = _chapter < data.totalChapters - 1;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WwSpace.screenMargin,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: WwColors.paper,
        border: Border(top: BorderSide(color: WwColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _chapterButton(
              label: hasPrev ? data.chapterName(_chapter - 1) : null,
              isPrev: true,
              onTap: hasPrev ? () => _goToChapter(_chapter - 1) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _chapterButton(
              label: hasNext ? data.chapterName(_chapter + 1) : null,
              isPrev: false,
              onTap: hasNext ? () => _goToChapter(_chapter + 1) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chapterButton({
    required String? label,
    required bool isPrev,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final color = enabled ? WwColors.ink : WwColors.mutedOnPaper;
    final text = Text(
      label ?? (isPrev ? 'Previous' : 'Next'),
      style: enabled
          ? WwType.paperButtonLabel
          : WwType.paperButtonLabelDisabled,
      overflow: TextOverflow.ellipsis,
    );
    final icon = Icon(
      isPrev ? Icons.chevron_left : Icons.chevron_right,
      size: 20,
      color: color,
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(WwRadius.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.chip),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: isPrev
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: isPrev
                ? [icon, const SizedBox(width: 6), Flexible(child: text)]
                : [Flexible(child: text), const SizedBox(width: 6), icon],
          ),
        ),
      ),
    );
  }
}
