import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/screen_state.dart';
import '../data/scripture_text.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import '../widgets/reader_layout.dart';

/// Host services the reader needs from the shell (Petra spec §7.4,
/// §4.4, §6.4). The shell implements this; the reader never reaches
/// for a navigator above its own tab.
abstract class ReaderHost {
  /// The one open-chapter procedure (§7.4). With [inNewScreen],
  /// returns true when a new screen was created; at the cap it
  /// performs the same-screen jump itself and returns false.
  bool openChapter(int ch, {int? verse, bool inNewScreen = false});

  /// Back rung 2: pop the reader route to the Screens list.
  void readerBackFallback();

  /// A §6.4 write point has been reached: persist the screen set.
  void persistScreens();

  /// A §2.2 selection event (explicit action / history landing).
  void recordSelection(int ch);

  /// Breadcrumb: leave to browse at the Library root.
  void breadcrumbLibrary();

  /// Breadcrumb: leave to browse at [bookIndex]'s testament grid.
  void breadcrumbTestament(int bookIndex);

  /// Breadcrumb action: switch to Library and focus its search.
  void jumpToReference();
}

/// The reader: one screen's view of one book — every chapter of the
/// book in one continuous vertical stream (board run 7 part B, §4),
/// with the verse-action toolbar anchored at the tapped verse (§5).
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.data,
    required this.screen,
    required this.host,
    this.textsLoader,
  });

  final BibleData data;
  final ReadingScreen screen;
  final ReaderHost host;

  /// Loads both scripture texts; defaults to [ScriptureText.load].
  /// Tests inject a fake through this seam (§12).
  final Future<ScriptureText> Function()? textsLoader;

  static const translationKey = 'ww_translation';

  @override
  State<ReaderScreen> createState() => ReaderScreenState();
}

enum _LandingKind { verse, chapter, restore }

class _PendingLanding {
  const _PendingLanding(this.kind, this.chapter, [this.verse]);
  final _LandingKind kind;
  final int chapter;
  final int? verse;
}

class ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  static const _flashDuration = Duration(milliseconds: 2600);

  late ReadingScreen _screen;
  ScriptureText? _texts;
  Object? _error;
  WwTranslation _translation = WwTranslation.kjv;

  UserDataStore? _userStore;
  UserData _userData = UserData();
  String _profileId = UserData.defaultProfileId;

  final _scrollCtl = ScrollController();
  final _verseKeys = <String, GlobalKey>{};
  Timer? _flashTimer;

  ReaderStreamLayout? _layout;
  String? _layoutKey;
  _PendingLanding? _pending;

  int _chapterAtTop = 0;
  int? _selectedChapter;
  int? _selectedVerse;

  // Chrome hide-on-scroll (§4.5).
  bool _chromeVisible = true;
  double _lastOffset = 0;
  double _cumDown = 0;

  // Verse toolbar (§5).
  int? _toolbarChapter;
  int? _toolbarVerse;
  bool _toolbarEditing = false;
  final _noteCtl = TextEditingController();
  final _cardKey = GlobalKey();
  Offset? _toolbarPos;
  double _toolbarRaiseOffset = 0;
  bool _sheetOpen = false;

  int get chapterAtTop => _chapterAtTop;
  ReadingScreen get screen => _screen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screen = widget.screen;
    _chapterAtTop = _screen.globalChapter;
    _pending = const _PendingLanding(_LandingKind.restore, 0);
    _scrollCtl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // §6.4 write point: the reader's dispose.
    widget.host.persistScreens();
    _flashTimer?.cancel();
    _scrollCtl.removeListener(_onScroll);
    _scrollCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // §6.4 write point: app pause.
    if (state == AppLifecycleState.paused) widget.host.persistScreens();
  }

  // ---------------------------------------------------------------- load

  Future<void> _load() async {
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        _translation = WwTranslation.fromStored(
          prefs.getString(ReaderScreen.translationKey),
        );
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        _userStore = await UserDataStore.load(prefs);
        _userData = _userStore!.data;
        _profileId = _userData.activeProfileId;
      } catch (_) {
        _userStore = null;
        _userData = UserData();
        _profileId = UserData.defaultProfileId;
      }
      final texts = await (widget.textsLoader ?? ScriptureText.load)();
      if (!mounted) return;
      setState(() {
        _texts = texts;
        _error = null;
      });
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
    // §4.7: rebuild the model and re-anchor at the current
    // chapter's heading in the new model; offsets never transfer.
    setState(() {
      _translation = t;
      _layout = null;
      _layoutKey = null;
      _pending = _PendingLanding(_LandingKind.chapter, _chapterAtTop);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ReaderScreen.translationKey, t.label);
    } catch (_) {}
  }

  // ------------------------------------------------------------ user data

  String _verseKeyFor(int ch, int v) {
    final chapter = widget.data.chapters[ch];
    return verseKey(chapter.b, chapter.c, v);
  }

  HlColor? _highlightFor(int ch, int v) =>
      _userData.highlight(_profileId, _verseKeyFor(ch, v));

  String? _noteFor(int ch, int v) =>
      _userData.note(_profileId, _verseKeyFor(ch, v));

  Color _tintFor(HlColor color) => switch (color) {
    HlColor.gold => WwColors.hlGold,
    HlColor.green => WwColors.hlGreen,
    HlColor.blue => WwColors.hlBlue,
    HlColor.pink => WwColors.hlPink,
    HlColor.purple => WwColors.hlPurple,
  };

  Future<void> _persistUserData() async {
    final store = _userStore;
    if (store == null) return;
    try {
      await store.save();
    } catch (_) {}
  }

  void _applyHighlight(String key, HlColor? color) {
    setState(() => _userData.setHighlight(_profileId, key, color));
    _persistUserData();
  }

  void _applyNote(String key, String text) {
    setState(() => _userData.setNote(_profileId, key, text));
    _persistUserData();
  }

  // ------------------------------------------------------------- landings

  /// Shell entry point: land on (chapter, verse?) in the current
  /// screen, flashing a verse target (§5.8). Replaces any restore.
  void landTo(int ch, int? verse) {
    // Stream swap (§4.7): a landing for a different book must not
    // be performed against the outgoing book's layout — invalidate
    // it so the LayoutBuilder rebuilds the target book's model and
    // re-attempts the pending landing against it.
    final book = widget.data.chapters[ch].b;
    if (_layout != null && _layout!.bookIndex != book) {
      setState(() {
        _layout = null;
        _layoutKey = null;
        _verseKeys.clear();
      });
    }
    _pending = verse != null
        ? _PendingLanding(_LandingKind.verse, ch, verse)
        : _PendingLanding(_LandingKind.chapter, ch);
    _attemptPending();
  }

  /// Shell entry point: restore the place of a newly bound screen
  /// (§6.4) — no flash, no history.
  void bindScreen(ReadingScreen screen) {
    if (identical(screen, _screen)) return;
    _flashTimer?.cancel();
    setState(() {
      _screen = screen;
      _chapterAtTop = screen.globalChapter;
      _selectedChapter = null;
      _selectedVerse = null;
      _toolbarChapter = null;
      _toolbarVerse = null;
      _toolbarPos = null;
      _verseKeys.clear();
      _layout = null;
      _layoutKey = null;
      _pending = const _PendingLanding(_LandingKind.restore, 0);
      _chromeVisible = true;
      _cumDown = 0;
    });
    _attemptPending();
  }

  String _geometrySig(double width, TextScaler scaler) =>
      '${width.toStringAsFixed(1)}|${scaler.scale(1.0)}|${_translation.label}';

  void _attemptPending() {
    final layout = _layout;
    if (layout == null || _texts == null || !mounted) return;
    if (_pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performPending();
    });
  }

  Future<void> _performPending() async {
    final pending = _pending;
    final layout = _layout;
    if (pending == null || layout == null || !_scrollCtl.hasClients) return;
    // Never consume a landing against the wrong book's model: keep
    // it pending, force the stream's layout to rebuild, and let the
    // builder re-attempt (§4.2/§4.7).
    final targetChapter = pending.kind == _LandingKind.restore
        ? _screen.globalChapter
        : pending.chapter;
    if (layout.bookIndex != widget.data.chapters[targetChapter].b) {
      setState(() {
        _layout = null;
        _layoutKey = null;
      });
      return;
    }
    _pending = null;
    final viewport = _scrollCtl.position.viewportDimension;
    final reduced = WwMotion.reduced(context);
    setState(() => _chromeVisible = true);

    Future<void> scrollTo(double target, {required bool animate}) async {
      final clamped = target
          .clamp(
            0.0,
            math.max(0.0, _scrollCtl.position.maxScrollExtent),
          )
          .toDouble();
      if (!animate || reduced) {
        _scrollCtl.jumpTo(clamped);
      } else {
        await _scrollCtl.animateTo(
          clamped,
          duration: WwMotion.push,
          curve: WwMotion.curve,
        );
      }
    }

    switch (pending.kind) {
      case _LandingKind.verse:
        final ch = pending.chapter;
        final v = pending.verse!;
        _screen.anchorVerse = v;
        // Already fully visible? Flash in place, no scroll (§5.8).
        final verseOffset = layout.offsetOfVerse(ch, v);
        final verseHeight = _verseItemHeight(layout, ch, v);
        final current = _scrollCtl.offset;
        final fullyVisible =
            verseOffset >= current - 0.5 &&
            verseOffset + verseHeight <= current + viewport + 0.5;
        if (!fullyVisible) {
          await scrollTo(
            layout.verseLandingOffset(ch, v, viewport),
            animate: true,
          );
          if (!mounted) return;
          _ensureCorrection(ch, v, alignment: 0.5);
        }
        _flash(ch, v);
      case _LandingKind.chapter:
        final ch = pending.chapter;
        _screen.anchorVerse = null;
        await scrollTo(layout.chapterLandingOffset(ch, viewport), animate: true);
        if (!mounted) return;
        _ensureCorrection(ch, null, alignment: 0.0);
        if (mounted) {
          setState(() {
            _chapterAtTop = ch;
            _selectedChapter = null;
            _selectedVerse = null;
          });
        }
      case _LandingKind.restore:
        final sig = _screen.geometrySig;
        final currentSig = _currentSig;
        if (sig != null && sig == currentSig && _screen.offset > 0) {
          final target = math.min(
            _screen.offset,
            _scrollCtl.position.maxScrollExtent,
          );
          _scrollCtl.jumpTo(target);
        } else if (_screen.anchorVerse != null) {
          await scrollTo(
            layout.verseLandingOffset(
              _screen.globalChapter,
              _screen.anchorVerse!,
              viewport,
            ),
            animate: false,
          );
        } else {
          await scrollTo(
            layout.chapterLandingOffset(_screen.globalChapter, viewport),
            animate: false,
          );
        }
        if (mounted) {
          setState(() => _chapterAtTop = _screen.globalChapter);
        }
    }
    _screen.geometrySig = _currentSig;
    widget.host.persistScreens();
  }

  double _verseItemHeight(ReaderStreamLayout layout, int ch, int v) {
    for (final item in layout.items) {
      if (item.kind == ReaderItemKind.verse &&
          item.chapter == ch &&
          item.verse == v) {
        return item.height;
      }
    }
    return WwSpace.minTarget;
  }

  String? get _currentSig {
    final layout = _layout;
    if (layout == null) return null;
    return _geometrySig(
      layout.viewportWidth,
      layout.metrics.textScaler,
    );
  }

  /// The single permitted correction pass (§4.2): after a model
  /// landing, `ensureVisible` on the now-built target.
  void _ensureCorrection(int ch, int? v, {required double alignment}) {
    final key = v != null ? _keyForVerse(ch, v) : _keyForHeading(ch);
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: Duration.zero,
      alignment: alignment,
    );
  }

  void _flash(int ch, int v) {
    _flashTimer?.cancel();
    setState(() {
      _selectedChapter = ch;
      _selectedVerse = v;
      _chapterAtTop = _layout?.chapterAtOffset(_scrollCtl.offset + 1) ??
          _chapterAtTop;
    });
    if (WwMotion.reduced(context)) return;
    _flashTimer = Timer(_flashDuration, () {
      if (mounted && _selectedVerse == v && _selectedChapter == ch) {
        setState(() {
          _selectedChapter = null;
          _selectedVerse = null;
        });
      }
    });
  }

  GlobalKey _keyForVerse(int ch, int v) =>
      _verseKeys.putIfAbsent('$ch:$v', () => GlobalKey());
  GlobalKey _keyForHeading(int ch) =>
      _verseKeys.putIfAbsent('h:$ch', () => GlobalKey());

  // --------------------------------------------------------------- scroll

  void _onScroll() {
    if (!mounted || !_scrollCtl.hasClients) return;
    final offset = _scrollCtl.offset;
    final delta = offset - _lastOffset;
    _lastOffset = offset;
    // Memory-only place update (§4.3/§6.4): no persistence here.
    _screen.offset = offset;
    if (_layout != null) _screen.geometrySig = _currentSig;

    // Toolbar dismisses on stream travel beyond 8dp (§5.1).
    if (_toolbarVerse != null &&
        (offset - _toolbarRaiseOffset).abs() > 8) {
      _dismissToolbar();
    }

    var needsSetState = false;
    final layout = _layout;
    if (layout != null) {
      final chapter = layout.chapterAtOffset(offset + 1);
      if (chapter != _chapterAtTop) {
        _chapterAtTop = chapter;
        _screen.globalChapter = chapter;
        needsSetState = true;
      }
    }
    // Chrome hide-on-scroll (§4.5); never under reduced motion.
    if (!WwMotion.reduced(context)) {
      if (delta > 0) {
        _cumDown += delta;
        if (_cumDown > 48 && _chromeVisible) {
          _chromeVisible = false;
          needsSetState = true;
        }
      } else if (delta < 0) {
        _cumDown = 0;
        if (!_chromeVisible) {
          _chromeVisible = true;
          needsSetState = true;
        }
      }
    }
    if (needsSetState && mounted) setState(() {});
  }

  // -------------------------------------------------------------- toolbar

  void _onVerseTap(int ch, int v) {
    _flashTimer?.cancel();
    if (_toolbarVerse == v && _toolbarChapter == ch) {
      _dismissToolbar();
      return;
    }
    // A verse tap is an anchor event (§4.3), never history (§7.2).
    _screen.anchorVerse = v;
    _screen.globalChapter = _chapterAtTop;
    setState(() {
      _selectedChapter = ch;
      _selectedVerse = v;
      _toolbarChapter = ch;
      _toolbarVerse = v;
      _toolbarEditing = false;
      _toolbarPos = null;
      _chromeVisible = true;
      _cumDown = 0;
    });
    _toolbarRaiseOffset = _scrollCtl.hasClients ? _scrollCtl.offset : 0;
    _measureToolbar(ch, v);
  }

  /// Placement by rendered sizes only (§5.1): measure the verse's
  /// rendered rect and the card's rendered size post-frame, then
  /// apply below / above / docked in that order.
  void _measureToolbar(int ch, int v) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _toolbarVerse != v || _toolbarChapter != ch) return;
      final cardCtx = _cardKey.currentContext;
      final verseCtx = _keyForVerse(ch, v).currentContext;
      final stackCtx = context;
      if (cardCtx == null || verseCtx == null) return;
      final cardBox = cardCtx.findRenderObject() as RenderBox?;
      final verseBox = verseCtx.findRenderObject() as RenderBox?;
      final stackBox = stackCtx.findRenderObject() as RenderBox?;
      if (cardBox == null || verseBox == null || stackBox == null) return;
      final viewport = stackBox.size;
      final verseTopGlobal = verseBox.localToGlobal(Offset.zero);
      final stackTopGlobal = stackBox.localToGlobal(Offset.zero);
      final verseTop = verseTopGlobal.dy - stackTopGlobal.dy;
      final verseBottom = verseTop + verseBox.size.height;
      final cardH = cardBox.size.height;
      double top;
      if (verseBottom + 8 + cardH <= viewport.height) {
        top = verseBottom + 8;
      } else if (verseTop - 8 - cardH >= 0) {
        top = verseTop - 8 - cardH;
      } else {
        top = viewport.height - 8 - cardH;
        // Docked: scroll the minimum so the verse's top reaches
        // the viewport top, keeping its number and first lines
        // above the card.
        final layout = _layout;
        if (layout != null && _scrollCtl.hasClients) {
          final target = layout
              .offsetOfVerse(ch, v)
              .clamp(0.0, _scrollCtl.position.maxScrollExtent);
          if (WwMotion.reduced(context)) {
            _scrollCtl.jumpTo(target);
          } else {
            _scrollCtl.animateTo(
              target,
              duration: WwMotion.push,
              curve: WwMotion.curve,
            );
          }
          _toolbarRaiseOffset = target;
        }
      }
      if (mounted) setState(() => _toolbarPos = Offset(16, top));
    });
  }

  void _dismissToolbar() {
    if (_toolbarVerse == null) return;
    setState(() {
      if (_selectedChapter == _toolbarChapter &&
          _selectedVerse == _toolbarVerse) {
        _selectedChapter = null;
        _selectedVerse = null;
      }
      _toolbarChapter = null;
      _toolbarVerse = null;
      _toolbarEditing = false;
      _toolbarPos = null;
    });
  }

  // ----------------------------------------------------------------- back

  /// Back rungs 0b/0c/0d/1 (§7.1). Returns true when a rung fired.
  bool handlePriorityBack() {
    if (_toolbarEditing) {
      setState(() => _toolbarEditing = false);
      return true;
    }
    if (_sheetOpen) {
      Navigator.of(context).pop();
      return true;
    }
    if (_toolbarVerse != null) {
      _dismissToolbar();
      return true;
    }
    final history = _screen.history;
    if (history.isNotEmpty) {
      final (ch, v) = history.removeLast();
      // Stream swap first if the entry's book differs (§7.1 rung 1).
      final book = widget.data.chapters[ch].b;
      if (book != _screen.bookIndex) {
        _screen.bookIndex = book;
        _layout = null;
        _layoutKey = null;
        _verseKeys.clear();
      }
      _screen.globalChapter = ch;
      _chapterAtTop = ch;
      widget.host.recordSelection(ch);
      landTo(ch, v);
      setState(() {});
      return true;
    }
    return false;
  }

  void _handleBack() {
    if (!handlePriorityBack()) widget.host.readerBackFallback();
  }

  // -------------------------------------------------------- connections

  void _openConnections(int ch, int v) {
    _dismissToolbar();
    _sheetOpen = true;
    final data = widget.data;
    final texts = _texts!;
    final translation = _translation;
    final conns = data.verseConnections(ch, v);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WwColors.paper,
      isScrollControlled: true,
      sheetAnimationStyle: wwSheetAnimationStyle(context),
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
                        return Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  widget.host.openChapter(tc, verse: tv);
                                },
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: WwSpace.minTarget,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        data.refName(tc, tv),
                                        style: WwType.refLabel,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        texts.verseText(
                                          translation,
                                          data,
                                          tc,
                                          tv,
                                        ),
                                        style: WwType.snippet,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Open ${data.refName(tc, tv)} in new screen',
                              onPressed: () async {
                                Navigator.of(sheetContext).pop();
                                final created = widget.host.openChapter(
                                  tc,
                                  verse: tv,
                                  inNewScreen: true,
                                );
                                if (!created && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: WwColors.surfaceHigh,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          WwRadius.chip,
                                        ),
                                      ),
                                      content: const Text(
                                        'Screen limit reached — opened here instead.',
                                        style: WwType.bodyOnDark,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.open_in_new,
                                size: 18,
                                color: WwColors.goldTextOnPaper,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: WwSpace.minTarget,
                                minHeight: WwSpace.minTarget,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _sheetOpen = false;
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
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
                        child: const Text(
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
                  child: Text('Loading the text…', style: WwType.captionOnPaper),
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
            _animatedTopBar(data),
            Expanded(
              child: Stack(
                children: [
                  _streamBody(data, texts),
                  if (_toolbarVerse != null) _toolbarOverlay(data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedTopBar(BibleData data) {
    return AnimatedContainer(
      key: const ValueKey('readerTopBar'),
      duration: WwMotion.reduced(context)
          ? Duration.zero
          : WwMotion.expand,
      curve: WwMotion.curveInOut,
      height: _chromeVisible ? 49 : 0,
      child: ClipRect(
        child: OverflowBox(
          minHeight: 49,
          maxHeight: 49,
          alignment: Alignment.topCenter,
          child: _topBar(data, showToggle: _texts != null),
        ),
      ),
    );
  }

  Widget _topBar(BibleData data, {required bool showToggle}) {
    final bookIndex = widget.data.chapters[_chapterAtTop].b;
    final testament = bookIndex < 39 ? 'Old Testament' : 'New Testament';
    final bookName = widget.data.books[bookIndex].name;
    return Container(
      height: 49,
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
            child: PopupMenuButton<String>(
              color: WwColors.paper,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WwRadius.chip),
              ),
              tooltip: 'Breadcrumb',
              onSelected: (value) {
                if (value == 'library') {
                  widget.host.breadcrumbLibrary();
                } else if (value == 'testament') {
                  widget.host.breadcrumbTestament(bookIndex);
                } else if (value == 'jump') {
                  widget.host.jumpToReference();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'library', height: 48, child: Text('Library', style: WwType.bodyOnPaper)),
                PopupMenuItem(value: 'testament', height: 48, child: Text(testament, style: WwType.bodyOnPaper)),
                PopupMenuItem(
                  value: 'book',
                  height: 48,
                  enabled: false,
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 20, color: WwColors.mutedOnPaper),
                      const SizedBox(width: 8),
                      Text(bookName, style: WwType.bodyOnPaper.copyWith(color: WwColors.mutedOnPaper)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'jump', height: 48, child: Text('Jump to reference…', style: WwType.bodyOnPaper)),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.chapterName(_chapterAtTop),
                        style: WwType.readerTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: WwColors.mutedOnPaper,
                    ),
                  ],
                ),
              ),
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

  Widget _streamBody(BibleData data, ScriptureText texts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bookIndex = _screen.bookIndex ?? data.chapters[_chapterAtTop].b;
        final key =
            '$bookIndex|${_translation.label}|${constraints.maxWidth}|'
            '${MediaQuery.textScalerOf(context)}';
        if (_layout == null || _layoutKey != key) {
          _layout = ReaderStreamLayout(
            data: data,
            texts: texts,
            translation: _translation,
            bookIndex: bookIndex,
            viewportWidth: constraints.maxWidth,
            textScaler: MediaQuery.textScalerOf(context),
            ambientStyle: DefaultTextStyle.of(context).style,
          );
          _layoutKey = key;
          _attemptPending();
        }
        final layout = _layout!;
        return ListView.builder(
          controller: _scrollCtl,
          padding: EdgeInsets.zero,
          itemCount: layout.items.length,
          itemExtentBuilder: (index, _) => layout.items[index].height,
          itemBuilder: (context, index) {
            final item = layout.items[index];
            return SizedBox(
              height: item.height,
              child: switch (item.kind) {
                ReaderItemKind.heading => _headingBlock(data, layout, item),
                ReaderItemKind.verse => _verseBlock(
                  data,
                  item.chapter,
                  item.verse!,
                  texts.verseText(
                    _translation,
                    data,
                    item.chapter,
                    item.verse!,
                  ),
                ),
                ReaderItemKind.endOfBook => _endBlock(data, layout),
              },
            );
          },
        );
      },
    );
  }

  Widget _headingBlock(
    BibleData data,
    ReaderStreamLayout layout,
    ReaderItem item,
  ) {
    final ch = item.chapter;
    final book = data.chapters[ch].b;
    final isFirst = ch == data.books[book].start;
    final isLast = ch == data.books[book].start + data.books[book].chapters - 1;
    final c = data.chapters[ch];
    return GestureDetector(
      onTap: _dismissToolbar,
      child: Container(
        key: _keyForHeading(ch),
        color: WwColors.paper,
        padding: EdgeInsets.fromLTRB(16, isFirst ? 16 : 24, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.chapterName(ch), style: WwType.readerTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${c.v} verses · ${data.chapterConnCount[ch]} connections',
                    style: WwType.captionOnPaper,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Previous chapter',
              onPressed: isFirst
                  ? null
                  : () => _scrollToHeading(layout, ch - 1),
              icon: Icon(
                Icons.expand_less,
                size: 20,
                color: isFirst ? WwColors.mutedOnPaper : WwColors.ink,
              ),
              constraints: const BoxConstraints(
                minWidth: WwSpace.minTarget,
                minHeight: WwSpace.minTarget,
              ),
            ),
            IconButton(
              tooltip: 'Next chapter',
              onPressed: isLast ? null : () => _scrollToHeading(layout, ch + 1),
              icon: Icon(
                Icons.expand_more,
                size: 20,
                color: isLast ? WwColors.mutedOnPaper : WwColors.ink,
              ),
              constraints: const BoxConstraints(
                minWidth: WwSpace.minTarget,
                minHeight: WwSpace.minTarget,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToHeading(ReaderStreamLayout layout, int ch) {
    // §4.6: a scroll aid — no history, no selection, no flash.
    if (!_scrollCtl.hasClients) return;
    setState(() => _chromeVisible = true);
    final target = layout.chapterLandingOffset(
      ch,
      _scrollCtl.position.viewportDimension,
    );
    if (WwMotion.reduced(context)) {
      _scrollCtl.jumpTo(target);
    } else {
      _scrollCtl.animateTo(target, duration: WwMotion.push, curve: WwMotion.curve);
    }
  }

  Widget _endBlock(BibleData data, ReaderStreamLayout layout) {
    final book = layout.book;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('End of ${book.name}', style: WwType.sheetRefTitle),
          if (layout.hasNextBook) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final next = data.books[layout.bookIndex + 1];
                widget.host.openChapter(next.start);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WwColors.goldBright,
                foregroundColor: WwColors.onGold,
                minimumSize: const Size.fromHeight(WwSpace.minTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(WwRadius.chip),
                ),
              ),
              child: Text(
                'Open ${data.books[layout.bookIndex + 1].name} 1',
                style: WwType.goldButtonLabel,
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              'The last book of the Bible.',
              style: WwType.captionOnPaper,
            ),
          ],
        ],
      ),
    );
  }

  Widget _verseBlock(BibleData data, int ch, int v, String text) {
    final selected = v == _selectedVerse && ch == _selectedChapter;
    final hasConns = data.verseHasConnections(ch, v);
    final highlight = _highlightFor(ch, v);
    final tint = highlight == null ? null : _tintFor(highlight);
    final hasNote = _noteFor(ch, v) != null;
    final background = selected
        ? Color.alphaBlend(
            WwColors.hlGold.withValues(alpha: 0.45),
            tint ?? WwColors.paper,
          )
        : (tint ?? Colors.transparent);
    final restingPlain = !selected && highlight == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(WwRadius.row),
        child: InkWell(
          key: _keyForVerse(ch, v),
          borderRadius: BorderRadius.circular(WwRadius.row),
          onTap: () => _onVerseTap(ch, v),
          child: Container(
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WwRadius.row),
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
                        style: restingPlain
                            ? WwType.verseNumber
                            : WwType.verseNumberInk,
                      ),
                      if (hasConns) ...[
                        const SizedBox(height: 4),
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
      ),
    );
  }

  // --------------------------------------------------------------- toolbar

  Widget _toolbarOverlay(BibleData data) {
    final ch = _toolbarChapter!;
    final v = _toolbarVerse!;
    final pos = _toolbarPos ?? const Offset(16, 64);
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final width = math.min(
      MediaQuery.sizeOf(context).width - 32,
      400.0,
    );
    final Widget card = Container(
      key: _cardKey,
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WwColors.paper,
        borderRadius: BorderRadius.circular(WwRadius.sheet),
        border: Border.all(color: WwColors.mutedOnPaper),
      ),
      child: _toolbarEditing
          ? _noteEditorView(data, ch, v)
          : _toolbarActionsView(data, ch, v),
    );
    if (_toolbarEditing && keyboard > 0) {
      return Positioned(
        left: pos.dx,
        bottom: keyboard + 8,
        child: card,
      );
    }
    return Positioned(left: pos.dx, top: pos.dy, child: card);
  }

  Widget _toolbarActionsView(BibleData data, int ch, int v) {
    final key = _verseKeyFor(ch, v);
    final currentHighlight = _userData.highlight(_profileId, key);
    final currentNote = _userData.note(_profileId, key);
    final connCount = data.verseConnections(ch, v).length;
    final narrow = MediaQuery.sizeOf(context).width < 344;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(data.refName(ch, v), style: WwType.sheetRefTitle),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: _dismissToolbar,
              icon: const Icon(Icons.close, size: 20, color: WwColors.ink),
              constraints: const BoxConstraints(
                minWidth: WwSpace.minTarget,
                minHeight: WwSpace.minTarget,
              ),
            ),
          ],
        ),
        if (currentNote != null) ...[
          Text(
            currentNote,
            style: WwType.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: narrow ? 144 : null,
            child: Wrap(
              children: [
                for (final color in HlColor.values)
                  _swatch(
                    color: color,
                    active: color == currentHighlight,
                    onTap: () => _applyHighlight(
                      key,
                      color == currentHighlight ? null : color,
                    ),
                  ),
                _noneSwatch(
                  active: currentHighlight == null,
                  onTap: () => _applyHighlight(key, null),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _noteCtl.text = currentNote ?? '';
                  setState(() => _toolbarEditing = true);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, WwSpace.minTarget),
                  side: const BorderSide(color: WwColors.mutedOnPaper),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                ),
                child: Text(
                  currentNote != null ? 'Edit note' : 'Add note',
                  style: WwType.paperButtonLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _openConnections(ch, v),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, WwSpace.minTarget),
                  side: const BorderSide(color: WwColors.mutedOnPaper),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                ),
                child: Text(
                  'Connections · $connCount',
                  style: WwType.paperButtonLabel,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _noteEditorView(BibleData data, int ch, int v) {
    final key = _verseKeyFor(ch, v);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.refName(ch, v), style: WwType.sheetRefTitle),
        const SizedBox(height: 8),
        const Text('Note', style: WwType.refLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtl,
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
              borderSide: const BorderSide(color: WwColors.goldTextOnPaper),
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
              onPressed: () => setState(() => _toolbarEditing = false),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, WwSpace.minTarget),
              ),
              child: const Text('Cancel', style: WwType.paperButtonLabel),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _applyNote(key, _noteCtl.text);
                setState(() => _toolbarEditing = false);
              },
              style: TextButton.styleFrom(
                backgroundColor: WwColors.goldBright,
                minimumSize: const Size(64, WwSpace.minTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(WwRadius.chip),
                ),
              ),
              child: const Text('Save', style: WwType.goldButtonLabel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _swatch({
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

  Widget _noneSwatch({required bool active, required VoidCallback onTap}) {
    return Semantics(
      label: 'None highlight',
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
                  color: WwColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? WwColors.goldTextOnPaper : WwColors.line,
                    width: active ? 2 : 1,
                  ),
                ),
                child: const Icon(
                  Icons.do_not_disturb_alt,
                  size: 20,
                  color: WwColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
