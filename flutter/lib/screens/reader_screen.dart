import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/scripture_text.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';

/// Reader screen: one chapter on cream paper, in KJV or WEB.
///
/// Mirrors the web v1 reading view: a verse's connections are
/// bidirectional, the gold dot marks any verse with at least one
/// connection, tapping a verse opens its connections sheet (its own
/// text first, then each connection as a reference label plus the
/// referenced verse's text in the active translation), and tapping a
/// connection jumps to that chapter and flashes the target verse.
/// Verses can also carry a per-profile highlight and a plain-text
/// note (board run 4), applied from the connections sheet and
/// persisted on-device through [UserDataStore]; the verse block
/// renders the highlight tint, and a notes icon marks noted verses.
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

  /// Per-profile highlights and notes for this session. The active
  /// profile is [UserData.defaultProfileId] until profiles land
  /// (board run 5). A failed store load leaves an empty in-memory
  /// model, so persistence never blocks reading.
  UserDataStore? _userStore;
  UserData _userData = UserData();

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
      try {
        final prefs = await SharedPreferences.getInstance();
        _userStore = await UserDataStore.load(prefs);
        _userData = _userStore!.data;
      } catch (_) {
        // Persistence failure never blocks reading: the session
        // keeps an empty in-memory model.
        _userStore = null;
        _userData = UserData();
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

  /// Canonical verse key for (chapter, verse) in the active
  /// profile's data: the chapter's book index and chapter-in-book
  /// from [BibleData], never the global chapter index.
  String _verseKeyFor(int ch, int v) {
    final chapter = widget.data.chapters[ch];
    return verseKey(chapter.b, chapter.c, v);
  }

  HlColor? _highlightFor(int ch, int v) =>
      _userData.highlight(UserData.defaultProfileId, _verseKeyFor(ch, v));

  String? _noteFor(int ch, int v) =>
      _userData.note(UserData.defaultProfileId, _verseKeyFor(ch, v));

  /// The theme tint a highlight color renders in (full opacity).
  Color _tintFor(HlColor color) => switch (color) {
    HlColor.gold => WwColors.hlGold,
    HlColor.green => WwColors.hlGreen,
    HlColor.blue => WwColors.hlBlue,
    HlColor.pink => WwColors.hlPink,
    HlColor.purple => WwColors.hlPurple,
  };

  /// Persists the user-data model after a mutation. Fire-and-forget
  /// with a catch: the session state is already updated, so a failed
  /// write only loses persistence, never the visible change.
  Future<void> _persistUserData() async {
    final store = _userStore;
    if (store == null) return;
    try {
      await store.save();
    } catch (_) {
      // Session state already carries the change.
    }
  }

  void _applyHighlight(String key, HlColor? color) {
    setState(
      () => _userData.setHighlight(UserData.defaultProfileId, key, color),
    );
    _persistUserData();
  }

  void _applyNote(String key, String text) {
    setState(() => _userData.setNote(UserData.defaultProfileId, key, text));
    _persistUserData();
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
    final key = _verseKeyFor(ch, v);
    var editingNote = false;
    final noteController = TextEditingController();
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
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final currentHighlight = _userData.highlight(
              UserData.defaultProfileId,
              key,
            );
            final currentNote = _userData.note(UserData.defaultProfileId, key);
            final Widget sheetBody;
            if (editingNote) {
              // Note editor: an in-sheet swap (instant, no fade) of
              // the sheet's main view. A single body field, no title,
              // an explicit Save; saving empty removes the note
              // (UserData.setNote semantics).
              sheetBody = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.refName(ch, v), style: WwType.sheetRefTitle),
                  const SizedBox(height: 8),
                  const Text('Note', style: WwType.refLabel),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    style: WwType.bodyOnPaper,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: WwColors.paper,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      // Local to this sheet (Petra Flag C): the app
                      // theme's focused border is goldBright, which
                      // is prohibited on paper (1.89:1), so the field
                      // carries its own borders — line idle,
                      // goldTextOnPaper focused — and never inherits
                      // the theme's InputDecorationTheme here.
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(WwRadius.input),
                        borderSide: const BorderSide(color: WwColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(WwRadius.input),
                        borderSide: const BorderSide(color: WwColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(WwRadius.input),
                        borderSide: const BorderSide(
                          color: WwColors.goldTextOnPaper,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Saving an empty note removes it.',
                    style: WwType.captionOnPaper,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => editingNote = false),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, WwSpace.minTarget),
                        ),
                        child: const Text(
                          'Cancel',
                          style: WwType.paperButtonLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          _applyNote(key, noteController.text);
                          setSheetState(() => editingNote = false);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: WwColors.goldBright,
                          minimumSize: const Size(64, WwSpace.minTarget),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(WwRadius.chip),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: WwType.goldButtonLabel,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              sheetBody = Column(
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
                  const SizedBox(height: 16),
                  const Text('Highlight', style: WwType.refLabel),
                  const SizedBox(height: 8),
                  // Filled-circle palette row: one tap applies
                  // instantly (no Save for highlights); tapping the
                  // active swatch again removes the highlight.
                  Row(
                    children: [
                      for (final color in HlColor.values)
                        _highlightSwatch(
                          color: color,
                          active: color == currentHighlight,
                          onTap: () {
                            _applyHighlight(
                              key,
                              color == currentHighlight ? null : color,
                            );
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                  if (currentHighlight != null)
                    TextButton(
                      onPressed: () {
                        _applyHighlight(key, null);
                        setSheetState(() {});
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, WwSpace.minTarget),
                      ),
                      child: const Text(
                        'Remove highlight',
                        style: WwType.paperButtonLabel,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Note', style: WwType.refLabel),
                  const SizedBox(height: 8),
                  if (currentNote != null) ...[
                    Text(currentNote, style: WwType.snippet),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        noteController.text = currentNote;
                        setSheetState(() => editingNote = true);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, WwSpace.minTarget),
                      ),
                      child: const Text(
                        'Edit note',
                        style: WwType.paperButtonLabelGold,
                      ),
                    ),
                  ] else
                    TextButton(
                      onPressed: () {
                        noteController.text = '';
                        setSheetState(() => editingNote = true);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, WwSpace.minTarget),
                      ),
                      child: const Text(
                        'Add note',
                        style: WwType.paperButtonLabelGold,
                      ),
                    ),
                ],
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                child: sheetBody,
              ),
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  /// One highlight swatch in the verse sheet: a 48dp target holding
  /// a filled circle in the exact tint the verse renders in, with a
  /// line border. The active swatch carries an ink checkmark
  /// centered on it and a 2dp goldTextOnPaper ring around it.
  Widget _highlightSwatch({
    required HlColor color,
    required bool active,
    required VoidCallback onTap,
  }) {
    final name = switch (color) {
      HlColor.gold => 'Gold',
      HlColor.green => 'Green',
      HlColor.blue => 'Blue',
      HlColor.pink => 'Pink',
      HlColor.purple => 'Purple',
    };
    return Semantics(
      label: '$name highlight',
      button: true,
      selected: active,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: WwSpace.minTarget,
            height: WwSpace.minTarget,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _tintFor(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? WwColors.goldTextOnPaper : WwColors.line,
                    width: active ? 2 : 1,
                  ),
                ),
                child: active
                    ? const Icon(Icons.check, size: 20, color: WwColors.ink)
                    : null,
              ),
            ),
          ),
        ),
      ),
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
    final highlight = _highlightFor(_chapter, v);
    final tint = highlight == null ? null : _tintFor(highlight);
    final hasNote = _noteFor(_chapter, v) != null;
    // Effective background (Petra, board run 4 — lesson 16: every
    // element, every state): resting is the verse's highlight tint
    // at FULL opacity, or transparent when unhighlighted; selected
    // composites hlGold at 45% alpha over the tint (or over paper
    // when unhighlighted, which still computes #FBF0C6), opaque.
    final background = selected
        ? Color.alphaBlend(
            WwColors.hlGold.withValues(alpha: 0.45),
            tint ?? WwColors.paper,
          )
        : (tint ?? Colors.transparent);
    // The resting plain state is the only one where the number and
    // the dot keep their paper roles; selected or highlighted, both
    // switch (see the number role and the dot comment below).
    final restingPlain = !selected && highlight == null;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        key: _keyForVerse(v),
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => _onVerseTap(v),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WwRadius.row),
            // Selected outline (producer decision resolving Petra
            // Flag A, board run 4): the selection delta on an
            // hlGold-highlighted verse is 1.000 — chromatically
            // invisible — so EVERY selected block carries this 2dp
            // border in goldTextOnPaper at the row radius.
            // goldTextOnPaper computes 3.35–4.11 on all selected
            // composites and 4.62 against the surrounding paper.
            border: selected
                ? Border.all(color: WwColors.goldTextOnPaper, width: 2)
                : null,
          ),
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
                      // Verse number: goldTextOnPaper (WwType
                      // .verseNumber) ONLY when not selected AND
                      // no highlight; otherwise the ink role —
                      // goldTextOnPaper computes 3.22–4.11 on the
                      // non-paper surfaces, under the 4.5 floor,
                      // while ink computes 11.92–17.12 there
                      // (Petra's run-4 audit, WwType.verseNumberInk).
                      style: restingPlain
                          ? WwType.verseNumber
                          : WwType.verseNumberInk,
                    ),
                    if (hasConns) ...[
                      const SizedBox(height: 4),
                      // The dot's three-condition rule (Petra,
                      // board run 4): gold ONLY when not selected
                      // AND no highlight — gold passes at 3.20 on
                      // rest/paper only and falls to 2.23–2.85 on
                      // every other surface (selected composites
                      // and highlight tints), below the 3.0
                      // meaningful-icon floor. In every other
                      // state the dot is goldTextOnPaper, which
                      // computes 3.22–4.11 on all non-paper
                      // surfaces. Never goldBright on cream.
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: restingPlain
                              ? WwColors.gold
                              : WwColors.goldTextOnPaper,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (hasNote) ...[
                      const SizedBox(height: 4),
                      // Note indicator: goldTextOnPaper on ALL
                      // surfaces, no state switch (Petra, board
                      // run 4) — its minimum computed ratio is
                      // 3.22 on rest/hlPurple, over the 3.0 icon
                      // floor; ink was rejected because it would
                      // collapse into the body content beside it.
                      // No alpha on this audited element (Petra
                      // Flag B).
                      const Icon(
                        Icons.notes,
                        size: 16,
                        color: WwColors.goldTextOnPaper,
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
