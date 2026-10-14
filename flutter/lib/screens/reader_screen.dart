import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/conference_data.dart';
import '../data/screen_state.dart';
import '../data/scripture_text.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';

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

  /// A §2.2 selection event (explicit action / history landing /
  /// page turn).
  void recordSelection(int ch);

  /// Breadcrumb: leave to browse at the Library root.
  void breadcrumbLibrary();

  /// Breadcrumb: leave to browse at [bookIndex]'s testament grid.
  void breadcrumbTestament(int bookIndex);

  /// Breadcrumb action: switch to Library and focus its search.
  void jumpToReference();
}

/// Conference layer services the reader's connections sheet
/// needs (board run 8, spec §3). The shell implements this
/// alongside [ReaderHost]; a host that does not (the standalone
/// reader test harness) leaves the sheet exactly as shipped —
/// the layer OFF contract (§1.1) by construction.
abstract class ConferenceHost {
  /// Whether the General Conference layer is enabled.
  bool get conferenceEnabled;

  /// The loaded conference dataset, or null while unloaded.
  ConferenceData? get conferenceData;

  /// Opens [talk]'s talk view on the Library stack, with the
  /// conferences list and that conference's talks list beneath
  /// it, so Back unwinds the browse (§3.3, §4.5).
  void openConferenceTalk(ConferenceTalk talk);
}

/// The reader: one screen's view of one book, PAGED (board run 7
/// part B, §4 as amended by Amendment A) — one whole chapter per
/// page, a horizontal swipe (or the §4.6 label-block buttons) turns
/// the page, in-page scroll stops at the chapter's end. There is no
/// continuous cross-chapter stream and no offset model anywhere in
/// this reader: verse landing is the shipped `GlobalKey` +
/// `Scrollable.ensureVisible` mechanism at chapter scope (§4.2),
/// on pages that build all their verses eagerly (§4.1).
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

  // Pager state (§4.1/§4.3). [_currentChapter] is the single
  // current-chapter truth: the pager's reported current page,
  // mapped to its chapter. In-page scroll never writes it.
  late PageController _pageCtl;
  int _bookIndex = 0;
  int _currentChapter = 0;
  final _pageControllers = <int, ScrollController>{};
  final _verseKeys = <String, GlobalKey>{};
  Timer? _flashTimer;

  _PendingLanding? _pending;
  int _pendingAttempts = 0;

  int? _selectedChapter;
  int? _selectedVerse;

  // Verse toolbar (§5).
  int? _toolbarChapter;
  int? _toolbarVerse;
  bool _toolbarEditing = false;
  final _noteCtl = TextEditingController();
  final _cardKey = GlobalKey();
  final _stackKey = GlobalKey();
  Offset? _toolbarPos;
  double _toolbarRaiseOffset = 0;
  bool _toolbarScrollGuard = false;
  bool _sheetOpen = false;

  // ---- test seams (§12): rendered-state accessors, no model ----
  int get currentChapter => _currentChapter;
  ReadingScreen get screen => _screen;
  PageController get pageController => _pageCtl;
  ScrollController? scrollControllerFor(int ch) => _pageControllers[ch];
  BuildContext? verseContext(int ch, int v) =>
      _verseKeys['$ch:$v']?.currentContext;

  /// R-T4's cross-check: repeat the §4.2 landing call on the
  /// already-landed verse and report how far the page moved.
  Future<void> debugEnsureVisible(int ch, int v) {
    final ctx = verseContext(ch, v);
    if (ctx == null) return Future.value();
    return Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: Duration.zero,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screen = widget.screen;
    _bookIndex =
        _screen.bookIndex ?? widget.data.chapters[_screen.globalChapter].b;
    _currentChapter = _screen.globalChapter;
    _pageCtl = _newPageController(_currentChapter);
    _pending = _PendingLanding(_LandingKind.restore, _currentChapter);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // §6.4 write point: the reader's dispose.
    widget.host.persistScreens();
    _flashTimer?.cancel();
    _pageCtl.dispose();
    for (final ctl in _pageControllers.values) {
      ctl.dispose();
    }
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // §6.4 write point: app pause.
    if (state == AppLifecycleState.paused) widget.host.persistScreens();
  }

  PageController _newPageController(int globalChapter) {
    final book = widget.data.books[widget.data.chapters[globalChapter].b];
    return PageController(
      initialPage: globalChapter - book.start,
    );
  }

  void _replacePageController(int globalChapter) {
    final old = _pageCtl;
    _pageCtl = _newPageController(globalChapter);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  ScrollController _controllerFor(int ch) {
    return _pageControllers.putIfAbsent(ch, () {
      final ctl = ScrollController();
      ctl.addListener(() {
        // Toolbar dismisses on in-page travel beyond 8dp (§5.1).
        // Programmatic docked scrolls (§5.1 rule 3) are guarded.
        if (_toolbarScrollGuard) return;
        if (_toolbarVerse != null &&
            _toolbarChapter == ch &&
            ch == _currentChapter &&
            ctl.hasClients &&
            (ctl.offset - _toolbarRaiseOffset).abs() > 8) {
          _dismissToolbar();
        }
      });
      return ctl;
    });
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
      _attemptPending();
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
    // §4.7 (paged): the pager stays on the same chapter page; the
    // page's content rebuilds from the new translation. A held
    // verse anchor re-anchors in-page (§4.2, no flash); otherwise
    // the page returns to its top. No offset transfers anywhere.
    setState(() => _translation = t);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ReaderScreen.translationKey, t.label);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = _screen.anchorVerse;
      final ctx = anchor != null
          ? verseContext(_currentChapter, anchor)
          : null;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: WwMotion.reduced(context)
              ? Duration.zero
              : WwMotion.push,
          curve: WwMotion.curve,
        );
      } else {
        final ctl = _pageControllers[_currentChapter];
        if (ctl != null && ctl.hasClients && ctl.offset != 0) {
          ctl.jumpTo(0);
        }
      }
    });
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
  /// screen (§7.4 step 4, §5.8). Verse targets flash; chapter
  /// targets land on the page top.
  void landTo(int ch, int? verse) {
    _pending = verse != null
        ? _PendingLanding(_LandingKind.verse, ch, verse)
        : _PendingLanding(_LandingKind.chapter, ch);
    _pendingAttempts = 0;
    final book = widget.data.chapters[ch].b;
    if (book != _bookIndex) {
      _swapToBook(book, ch);
    } else if (ch != _currentChapter) {
      _setPageDirect(ch);
    }
    _attemptPending();
  }

  /// Shell entry point: restore the place of a newly bound screen
  /// (§6.4) — no flash, no history.
  void bindScreen(ReadingScreen screen) {
    if (identical(screen, _screen)) return;
    _flashTimer?.cancel();
    setState(() {
      _screen = screen;
      _bookIndex =
          screen.bookIndex ?? widget.data.chapters[screen.globalChapter].b;
      _currentChapter = screen.globalChapter;
      _selectedChapter = null;
      _selectedVerse = null;
      _toolbarChapter = null;
      _toolbarVerse = null;
      _toolbarEditing = false;
      _toolbarPos = null;
      _verseKeys.clear();
      _disposePageControllersDeferred();
      _replacePageController(_currentChapter);
      _pending = _PendingLanding(_LandingKind.restore, _currentChapter);
      _pendingAttempts = 0;
    });
    // Same-book rebind: the pager's scroll position survives a
    // controller swap, so set it directly to the bound page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageCtl.hasClients) return;
      final book = widget.data.books[_bookIndex];
      final idx = _currentChapter - book.start;
      if (_pageCtl.page?.round() != idx) _pageCtl.jumpToPage(idx);
    });
    _attemptPending();
  }

  /// Page scroll controllers are still attached to the outgoing
  /// pages during a setState; dispose them after the frame that
  /// unmounts those pages.
  void _disposePageControllersDeferred() {
    final stale = _pageControllers.values.toList();
    _pageControllers.clear();
    if (stale.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final ctl in stale) {
        ctl.dispose();
      }
    });
  }

  /// Page-set swap (§4.7): the pager is rebuilt for the new book
  /// with the target chapter as its initial page. No turn across
  /// the seam ever happens.
  void _swapToBook(int book, int ch) {
    setState(() {
      _bookIndex = book;
      _screen.bookIndex = book;
      _currentChapter = ch;
      _screen.globalChapter = ch;
      _selectedChapter = null;
      _selectedVerse = null;
      _toolbarChapter = null;
      _toolbarVerse = null;
      _toolbarEditing = false;
      _toolbarPos = null;
      _verseKeys.clear();
      _disposePageControllersDeferred();
      _replacePageController(ch);
    });
  }

  /// Commanded arrival on a page of the same book (§4.2 step 1):
  /// the pager is set directly to the target page — it never
  /// animates or flips through intermediate chapters.
  void _setPageDirect(int ch) {
    setState(() {
      _currentChapter = ch;
      _screen.globalChapter = ch;
    });
    final book = widget.data.books[_bookIndex];
    final idx = ch - book.start;
    if (_pageCtl.hasClients) {
      _pageCtl.jumpToPage(idx);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtl.hasClients) _pageCtl.jumpToPage(idx);
      });
    }
  }

  void _attemptPending() {
    if (_pending == null || _texts == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performPending();
    });
    // A same-chapter landing changes no widget state, so nothing
    // else schedules the frame this callback waits for — schedule
    // it, or the landing starves until an unrelated invalidation.
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _performPending() async {
    final pending = _pending;
    if (pending == null || _texts == null || !mounted) return;
    final target = pending.kind == _LandingKind.restore
        ? _screen.globalChapter
        : pending.chapter;
    // The target page must be the current page before any in-page
    // landing is attempted (§4.2 step 1 before step 2).
    if (target != _currentChapter) {
      final book = widget.data.chapters[target].b;
      if (book != _bookIndex) {
        _swapToBook(book, target);
      } else {
        _setPageDirect(target);
      }
      _attemptPending();
      return;
    }
    final verse = pending.kind == _LandingKind.chapter
        ? null
        : (pending.kind == _LandingKind.verse
              ? pending.verse
              : _screen.anchorVerse);
    if (verse == null) {
      // Chapter / anchorless-restore landing: the page opens at
      // its top — offset 0 by construction (§4.2).
      _pending = null;
      _screen.anchorVerse = null;
      final ctl = _pageControllers[target];
      if (ctl != null && ctl.hasClients && ctl.offset != 0) {
        ctl.jumpTo(0);
      }
      if (pending.kind != _LandingKind.restore) {
        widget.host.persistScreens();
      }
      return;
    }
    final ctx = verseContext(target, verse);
    if (ctx == null) {
      // The page builds eagerly, but its first frame may not have
      // run yet after a swap/jump; retry on the next frame.
      if (++_pendingAttempts <= 10) _attemptPending();
      return;
    }
    _pending = null;
    final isRestore = pending.kind == _LandingKind.restore;
    if (!isRestore) _screen.anchorVerse = verse;
    if (!isRestore && pending.kind == _LandingKind.verse) {
      // §5.8's shipped order: SELECT, then the ensureVisible
      // landing. The selection must render first because the
      // selected construction changes the verse block's height
      // (its 2dp outline adds to the block's effective padding):
      // a scroll computed against the unselected geometry would
      // land a half-border off the alignment the mechanism itself
      // would then correct (R-T4). Flash first; scroll next frame,
      // against the final rendered geometry.
      _flash(target, verse);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishVerseLanding(target, verse, isRestore: false);
      });
      return;
    }
    await _finishVerseLanding(target, verse, isRestore: true);
  }

  /// The in-page half of a verse landing (§4.2 step 2): if the
  /// verse is already fully visible on its page, land in place;
  /// otherwise `Scrollable.ensureVisible` at the shipped
  /// alignment 0.5 (duration zero for restores / reduced motion).
  Future<void> _finishVerseLanding(
    int target,
    int verse, {
    required bool isRestore,
  }) async {
    final ctx = verseContext(target, verse);
    if (ctx == null || !mounted) return;
    final verseBox = ctx.findRenderObject() as RenderBox?;
    final scrollable = Scrollable.of(ctx);
    final vpBox = scrollable.context.findRenderObject() as RenderBox?;
    var fullyVisible = false;
    if (verseBox != null && vpBox != null) {
      final verseRect = Rect.fromPoints(
        verseBox.localToGlobal(Offset.zero),
        verseBox.localToGlobal(
          verseBox.size.bottomRight(Offset.zero),
        ),
      );
      final vpRect = Rect.fromPoints(
        vpBox.localToGlobal(Offset.zero),
        vpBox.localToGlobal(vpBox.size.bottomRight(Offset.zero)),
      );
      fullyVisible =
          verseRect.top >= vpRect.top - 0.5 &&
          verseRect.bottom <= vpRect.bottom + 0.5;
    }
    if (!fullyVisible) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: (isRestore || WwMotion.reduced(context))
            ? Duration.zero
            : WwMotion.push,
        curve: WwMotion.curve,
      );
      if (!mounted) return;
    }
    if (!isRestore) widget.host.persistScreens();
  }

  void _flash(int ch, int v) {
    _flashTimer?.cancel();
    setState(() {
      _selectedChapter = ch;
      _selectedVerse = v;
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

  // ------------------------------------------------------------ page turns

  /// The pager's page report (§4.3): a page change is a §6.4 write
  /// point and a §2.2 selection event; the verse anchor clears.
  /// In-page scrolling never reaches this method.
  void _onPageChanged(int index) {
    final book = widget.data.books[_bookIndex];
    final global = book.start + index;
    if (global == _currentChapter) return;
    _flashTimer?.cancel();
    setState(() {
      _currentChapter = global;
      _selectedChapter = null;
      _selectedVerse = null;
      _toolbarChapter = null;
      _toolbarVerse = null;
      _toolbarEditing = false;
      _toolbarPos = null;
    });
    _screen.globalChapter = global;
    _screen.anchorVerse = null;
    widget.host.recordSelection(global);
    widget.host.persistScreens();
  }

  /// The §4.6 label-block buttons: turn the page exactly as the
  /// swipe does — animated 300ms/easeOut, instant under reduced
  /// motion. No history push (§7.2). The toolbar dismisses first
  /// and the turn proceeds (§5.1).
  void _turnTo(int globalChapter) {
    final book = widget.data.books[_bookIndex];
    final idx = globalChapter - book.start;
    if (idx < 0 || idx >= book.chapters) return;
    _dismissToolbar();
    if (WwMotion.reduced(context)) {
      _pageCtl.jumpToPage(idx);
    } else {
      _pageCtl.animateToPage(
        idx,
        duration: WwMotion.push,
        curve: WwMotion.curve,
      );
    }
  }

  // -------------------------------------------------------------- toolbar

  void _onVerseTap(int ch, int v) {
    _flashTimer?.cancel();
    if (_toolbarVerse == v && _toolbarChapter == ch) {
      _dismissToolbar();
      return;
    }
    // A verse tap sets the screen's verse anchor (§4.3); it is
    // never history (§7.2) and never a selection event (§2.2).
    _screen.anchorVerse = v;
    setState(() {
      _selectedChapter = ch;
      _selectedVerse = v;
      _toolbarChapter = ch;
      _toolbarVerse = v;
      _toolbarEditing = false;
      _toolbarPos = null;
    });
    final ctl = _pageControllers[ch];
    _toolbarRaiseOffset = (ctl != null && ctl.hasClients) ? ctl.offset : 0;
    _measureToolbar(ch, v);
  }

  /// Placement by rendered sizes only (§5.1): measure the verse's
  /// rendered rect and the card's rendered size post-frame, then
  /// apply below / above / docked in that order.
  void _measureToolbar(int ch, int v) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _toolbarVerse != v || _toolbarChapter != ch) return;
      final cardCtx = _cardKey.currentContext;
      final verseCtx = verseContext(ch, v);
      final stackCtx = _stackKey.currentContext;
      if (cardCtx == null || verseCtx == null || stackCtx == null) return;
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
        // Docked (§5.1 rule 3): scroll in-page the minimum — never
        // more than putting the verse's top at the viewport top —
        // so the verse's number and first lines stay above the card.
        _toolbarScrollGuard = true;
        Scrollable.ensureVisible(
          verseCtx,
          alignment: 0.0,
          duration: WwMotion.reduced(context)
              ? Duration.zero
              : WwMotion.push,
          curve: WwMotion.curve,
        ).whenComplete(() {
          _toolbarScrollGuard = false;
          final ctl = _pageControllers[ch];
          if (ctl != null && ctl.hasClients) {
            _toolbarRaiseOffset = ctl.offset;
          }
        });
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
      // Page-set swap first if the entry's book differs — landTo
      // performs it (§7.1 rung 1, §4.7).
      widget.host.recordSelection(ch);
      landTo(ch, v);
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
    // The conference layer (board run 8, §3): the section renders
    // only when the host carries the layer and it is ON. A host
    // without the layer, or the layer OFF, gets the shipped sheet
    // byte-for-byte (§1.1). Talks are newest-first from the data
    // layer (§3.3), one row per talk however often it cites the
    // verse; an enabled-but-unloaded dataset reads as no talks.
    final host = widget.host;
    final ConferenceHost? confHost =
        host is ConferenceHost ? host as ConferenceHost : null;
    final confOn = confHost?.conferenceEnabled ?? false;
    final talks = confOn
        ? (confHost?.conferenceData?.talksForVerse(ch, v) ??
              const <ConferenceTalk>[])
        : const <ConferenceTalk>[];
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
        // One shipped connection row, used by both sheet forms.
        Widget connectionRow(int tc, int tv) {
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(data.refName(tc, tv), style: WwType.refLabel),
                        const SizedBox(height: 2),
                        Text(
                          texts.verseText(translation, data, tc, tv),
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
                tooltip: 'Open ${data.refName(tc, tv)} in new screen',
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
                          borderRadius: BorderRadius.circular(WwRadius.chip),
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
        }

        // One conference talk row (§3.2): ≥48dp, title uncapped
        // in bodyOnPaper w600, the speaker line beneath it, and
        // NO trailing control — a talk has no screen in this app;
        // the row itself opens its talk view in the Library (§3.3).
        Widget talkRow(ConferenceTalk talk) {
          return Semantics(
            container: true,
            button: true,
            label:
                'Open talk: ${talk.title}, by ${talk.speaker}, '
                '${talk.conferenceLabel}',
            child: InkWell(
              onTap: () {
                Navigator.of(sheetContext).pop();
                confHost?.openConferenceTalk(talk);
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
                      talk.title,
                      style: WwType.bodyOnPaper.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${talk.speaker} · ${talk.conferenceLabel}',
                      style: WwType.captionOnPaper,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final header = <Widget>[
          Text(data.refName(ch, v), style: WwType.sheetRefTitle),
          const SizedBox(height: 8),
          Text(
            texts.verseText(translation, data, ch, v),
            style: WwType.readerSheetVerse,
          ),
          const SizedBox(height: 12),
        ];

        if (!confOn) {
          // The shipped sheet, byte-for-byte (§1.1 OFF contract).
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
                  ...header,
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
                        itemBuilder: (_, i) =>
                            connectionRow(conns[i][0], conns[i][1]),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // Layer ON (§3.1): ONE scroll region below the fixed
        // header, holding Connections then Conference talks —
        // never two independently scrolling lists in one sheet.
        final scrollChildren = <Widget>[
          const Text('Connections', style: WwType.refLabel),
          const SizedBox(height: 8),
          if (conns.isEmpty)
            const Text(
              'No cross references are recorded for this verse.',
              style: WwType.captionOnPaper,
            )
          else
            for (var i = 0; i < conns.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: WwColors.line),
              connectionRow(conns[i][0], conns[i][1]),
            ],
          const SizedBox(height: 16),
          const Text('Conference talks', style: WwType.refLabel),
          const SizedBox(height: 8),
          if (talks.isEmpty)
            const Text(
              'No conference talks are recorded for this verse.',
              style: WwType.captionOnPaper,
            )
          else
            for (var i = 0; i < talks.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: WwColors.line),
              talkRow(talks[i]),
            ],
        ];
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
                ...header,
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: scrollChildren,
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
            // §4.5 as amended: the top bar is FIXED. It never hides.
            _topBar(data, showToggle: true),
            Expanded(
              child: Stack(
                key: _stackKey,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissToolbar,
                    child: _pager(data, texts),
                  ),
                  if (_toolbarVerse != null) _toolbarOverlay(data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BibleData data, {required bool showToggle}) {
    final bookIndex = widget.data.chapters[_currentChapter].b;
    final testament = bookIndex < 39 ? 'Old Testament' : 'New Testament';
    final bookName = widget.data.books[bookIndex].name;
    return Container(
      key: const ValueKey('readerTopBar'),
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
                        data.chapterName(_currentChapter),
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

  // ---------------------------------------------------------------- pager

  Widget _pager(BibleData data, ScriptureText texts) {
    final book = data.books[_bookIndex];
    return PageView.builder(
      // §4.7: a page-set swap REBUILDS the pager for the new book —
      // the per-book key gives the rebuilt pager a fresh scroll
      // position at the new controller's initial page, instead of
      // migrating the outgoing book's position into it.
      key: ValueKey('pager-$_bookIndex'),
      controller: _pageCtl,
      itemCount: book.chapters,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final global = book.start + index;
        return _chapterPage(data, texts, global);
      },
    );
  }

  /// One chapter page (§4.1): the label block, then ALL of the
  /// chapter's verses built eagerly in a Column inside an in-page
  /// vertical scroll view whose extent ends at the chapter's end.
  Widget _chapterPage(BibleData data, ScriptureText texts, int global) {
    final verses = texts.chapterVerses(_translation, data, global);
    final book = data.books[data.chapters[global].b];
    final isLast = global == book.start + book.chapters - 1;
    return SingleChildScrollView(
      key: ValueKey('chapterPage-$global'),
      controller: _controllerFor(global),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelBlock(data, global),
          for (var vi = 0; vi < verses.length; vi++)
            _verseBlock(data, global, vi + 1, verses[vi]),
          if (isLast) _endBlock(data, global),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The chapter label block (§4.1): page furniture only — a plain
  /// label, data counts, and the §4.6 prev/next page-turn pair.
  /// No summaries, no prose, no placeholder.
  Widget _labelBlock(BibleData data, int ch) {
    final book = data.chapters[ch].b;
    final isFirst = ch == data.books[book].start;
    final isLast = ch == data.books[book].start + data.books[book].chapters - 1;
    final c = data.chapters[ch];
    return Container(
      color: WwColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
            onPressed: isFirst ? null : () => _turnTo(ch - 1),
            icon: Icon(
              Icons.chevron_left,
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
            onPressed: isLast ? null : () => _turnTo(ch + 1),
            icon: Icon(
              Icons.chevron_right,
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
    );
  }

  /// The end-of-book block (§4.1): inside the last chapter's page,
  /// after its last verse. Forward crossing is deliberate only.
  Widget _endBlock(BibleData data, int lastChapter) {
    final bookIndex = data.chapters[lastChapter].b;
    final book = data.books[bookIndex];
    final hasNext = bookIndex + 1 < data.books.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('End of ${book.name}', style: WwType.sheetRefTitle),
          if (hasNext) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final next = data.books[bookIndex + 1];
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
                'Open ${data.books[bookIndex + 1].name} 1',
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
