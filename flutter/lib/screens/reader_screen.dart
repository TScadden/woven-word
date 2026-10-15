import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/confession_data.dart';
import '../data/conference_data.dart';
import '../data/screen_state.dart';
import '../data/reader_theme.dart';
import '../data/scripture_text.dart';
import '../data/sefaria_data.dart';
import '../data/tradition.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import '../widgets/arc_stage.dart';

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

/// The tradition-layer surface a host may carry (board run 9).
/// Generalized exactly the way [ConferenceHost] was: a host that
/// does not implement it renders the Bible-only reader — its
/// extra translations hidden, no tradition section in the
/// connections sheet, the verse dot lit by cross references
/// alone.
abstract class TraditionHost {
  WwTradition get tradition;
  SefariaData? get sefariaData;
  ConfessionData? get confessionData;

  /// Opens a tradition link outside the app (a work on Sefaria,
  /// a confession at its host).
  void openExternalLink(String url);
}

/// Reader theme services a host may carry (reader theme package).
/// Generalized the way [TraditionHost] was: the shell implements
/// it and owns the persisted choice; a host that does not leaves
/// the reader resolving the theme from the preference itself,
/// defaulting to Dark.
abstract class ReaderThemeHost {
  WwReaderTheme get readerTheme;
  void setReaderTheme(WwReaderTheme theme);
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

  static const translationKey = translationPrefsKey;

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

  // The connection arch panel (reader arch package): the
  // chapter-bars background image, rendered once per density
  // band and cached exactly as Home caches its stage image.
  static const _archStageSize = Size(1200, 500);
  final _archImages = <String, ui.Image>{};
  final _archRendering = <String>{};

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

  // Text selection (board run 10): selection is a MODE, entered
  // by long-press on a verse — only the verse in selection mode
  // renders as a SelectableText. (An always-on SelectableText
  // installs an eager horizontal-drag recognizer on Android
  // that would claim page-turn swipes starting on text; outside
  // the mode the verse text is the shipped plain Text and every
  // shipped gesture — tap, paging, scroll — is untouched.)
  // _selGen is bumped on every selection-bar write so the
  // verse's SelectableText is recreated: its platform selection
  // collapses and the applied tint shows clean.
  (int, int)? _selVerse;
  int _selGen = 0;
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
    for (final img in _archImages.values) {
      img.dispose();
    }
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
    return PageController(initialPage: globalChapter - book.start);
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
        // The reader theme, for a host that does not carry it
        // (reader theme package): the stored choice, Dark when
        // nothing is stored.
        _ownTheme = WwReaderTheme.fromStored(
          prefs.getString(readerThemePrefsKey),
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

  /// The tradition this reader renders under (board run 9): the
  /// host's, when it carries one; Bible only otherwise.
  WwTradition get _tradition {
    final host = widget.host;
    return host is TraditionHost
        ? (host as TraditionHost).tradition
        : WwTradition.none;
  }

  TraditionHost? get _traditionHost {
    final host = widget.host;
    return host is TraditionHost ? host as TraditionHost : null;
  }

  /// The reader theme this reader renders under (reader theme
  /// package): the host's live choice when it carries one (the
  /// shell owns the persisted setting), else the reader's own
  /// stored read. Dark whenever nothing has ever been stored.
  WwReaderTheme _ownTheme = WwReaderTheme.dark;

  WwReaderTheme get _readerTheme {
    final host = widget.host;
    return host is ReaderThemeHost
        ? (host as ReaderThemeHost).readerTheme
        : _ownTheme;
  }

  /// The palette every surface in this reader renders from.
  ReaderPalette get _palette => _readerTheme == WwReaderTheme.dark
      ? ReaderPalette.dark
      : ReaderPalette.paper;

  /// The top bar's quick switch: the same write Profiles makes —
  /// through the host when it carries the setting (it persists and
  /// notifies, and this reader re-renders from its getter), else
  /// the reader's own state + preference write, the seam the
  /// translation choice already uses.
  Future<void> _setReaderTheme(WwReaderTheme next) async {
    if (next == _readerTheme) return;
    final host = widget.host;
    if (host is ReaderThemeHost) {
      (host as ReaderThemeHost).setReaderTheme(next);
      return;
    }
    setState(() => _ownTheme = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(readerThemePrefsKey, next.storedValue);
    } catch (_) {}
  }

  /// The translations the toggle offers on the current book:
  /// the tradition's set for this testament, narrowed to the
  /// texts the bundle actually carries.
  List<WwTranslation> get _availableTranslations {
    final all = translationsFor(_tradition, otBook: _bookIndex < 39);
    final texts = _texts;
    if (texts == null) return all;
    return all.where(texts.hasTranslation).toList();
  }

  /// The translation actually rendered: the stored choice when
  /// the tradition offers it on this book, KJV otherwise — a
  /// stored Hebrew choice never renders on a New Testament page,
  /// and never renders blank (ScriptureText falls back per
  /// chapter as well).
  WwTranslation get _effT {
    final available = _availableTranslations;
    return available.contains(_translation) ? _translation : WwTranslation.kjv;
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
      final ctx = anchor != null ? verseContext(_currentChapter, anchor) : null;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: WwMotion.reduced(context) ? Duration.zero : WwMotion.push,
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

  /// The per-translation set key of the translation actually
  /// rendered (board run 10): highlights and notes live in the
  /// set of the translation they were made in, and a span's
  /// offsets only ever render against that translation.
  String get _tKey => _effT.name;

  List<HighlightSpan> _spansFor(int ch, int v) =>
      _userData.spansFor(_profileId, _tKey, _verseKeyFor(ch, v));

  String? _noteFor(int ch, int v) =>
      _userData.note(_profileId, _tKey, _verseKeyFor(ch, v));

  Color _tintFor(HlColor color) => _palette.tintAt(color.index);

  Future<void> _persistUserData() async {
    final store = _userStore;
    if (store == null) return;
    try {
      await store.save();
    } catch (_) {}
  }

  // ---------------------------------------------------- connection arch

  /// Whether the connection arch panel is expanded for the
  /// active profile (reader arch package). Resolved from the
  /// loaded model on every build (lesson 44) — the profile's
  /// remembered choice, never a mirrored field. Defaults to
  /// expanded (spec I-4).
  bool get _archExpanded => _userData.readerArchExpandedFor(_profileId);

  /// The minimize/expand toggle's write: mutate the model,
  /// persist through the same path as every user-data write.
  void _setArchExpanded(bool expanded) {
    if (expanded == _archExpanded) return;
    setState(() => _userData.setReaderArchExpanded(_profileId, expanded));
    _persistUserData();
  }

  /// Renders the arch panel's background (chapter bars only)
  /// once per density band, Home's caching pattern verbatim.
  Future<void> _ensureArchImage({
    required String key,
    required BibleData data,
    required double band,
  }) async {
    if (_archImages.containsKey(key) || _archRendering.contains(key)) return;
    _archRendering.add(key);
    try {
      final img = await renderArcImage(
        data: data,
        lo: 0,
        hi: data.totalChapters - 1,
        stage: _archStageSize,
        density: band,
        faint: false,
        includeArcs: false,
        includeLabels: false,
      );
      _archImages[key] = img;
      if (mounted) setState(() {});
    } finally {
      _archRendering.remove(key);
    }
  }

  /// The expanded arch panel (spec §3): the current chapter's
  /// connection web — Home's stage construction (bars image +
  /// [MiniSelectionPainter]) on the stage plate, inset by the
  /// screen margin, with the minimize control at its top
  /// right. Static: it changes only when the chapter does.
  Widget _archPanel(BibleData data) {
    return Padding(
      key: const ValueKey('reader-arch-panel'),
      padding: const EdgeInsets.fromLTRB(
        WwSpace.screenMargin,
        8,
        WwSpace.screenMargin,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WwRadius.sheet),
        child: Container(
          color: WwColors.stage,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final band = bandFor(densityFor(w));
              final key = 'reader-arch-$band';
              final img = _archImages[key];
              if (img == null) {
                _ensureArchImage(key: key, data: data, band: band);
              }
              return SizedBox(
                width: w,
                height: w * _archStageSize.height / _archStageSize.width,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: _archStageSize.width,
                          height: _archStageSize.height,
                          child: Stack(
                            children: [
                              if (img != null)
                                RawImage(
                                  image: img,
                                  width: _archStageSize.width,
                                  height: _archStageSize.height,
                                  fit: BoxFit.fill,
                                ),
                              Positioned.fill(
                                child: Semantics(
                                  container: true,
                                  label:
                                      'Chapter connections for '
                                      '${data.chapterName(_currentChapter)}',
                                  child: CustomPaint(
                                    key: const ValueKey('reader-arch-paint'),
                                    painter: MiniSelectionPainter(
                                      data: data,
                                      lo: 0,
                                      hi: data.totalChapters - 1,
                                      stage: _archStageSize,
                                      selected: _currentChapter,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        key: const ValueKey('reader-arch-minimize'),
                        tooltip: 'Hide chapter connections',
                        onPressed: () => _setArchExpanded(false),
                        icon: const Icon(
                          Icons.keyboard_arrow_up,
                          color: WwColors.goldBright,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: WwSpace.minTarget,
                          minHeight: WwSpace.minTarget,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The minimized state's expand affordance (spec §3): a
  /// 48dp chip floating at the top right of the pager
  /// viewport — the panel is fully out of the reading flow,
  /// and the control stays where the panel's toggle was.
  Widget _archExpandChip() {
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: _palette.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.chip),
          side: BorderSide(color: _palette.cardBorder),
        ),
        child: IconButton(
          key: const ValueKey('reader-arch-expand'),
          tooltip: 'Show chapter connections',
          onPressed: () => _setArchExpanded(true),
          icon: Icon(Icons.keyboard_arrow_down, color: _palette.accent),
          constraints: const BoxConstraints(
            minWidth: WwSpace.minTarget,
            minHeight: WwSpace.minTarget,
          ),
        ),
      ),
    );
  }

  /// The verse toolbar's color write (board run 10): a full-verse
  /// span in the current translation's set. A null [color] (the
  /// None swatch, or tapping the active full-verse color again)
  /// clears ALL of the verse's spans in this translation — the
  /// shipped None meaning, span edition.
  void _applyVerseColor(String key, String verseText, HlColor? color) {
    setState(() {
      if (color == null) {
        _userData.clearVerseSpans(_profileId, _tKey, key);
      } else {
        _userData.applySpan(
          _profileId,
          _tKey,
          HighlightSpan(
            verseKey: key,
            start: 0,
            end: -1,
            anchor: verseText,
            color: color,
          ),
          verseText: verseText,
        );
      }
    });
    _persistUserData();
  }

  void _applyNote(String key, String text) {
    setState(() => _userData.setNote(_profileId, _tKey, key, text));
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
        verseBox.localToGlobal(verseBox.size.bottomRight(Offset.zero)),
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
      _selVerse = null;
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
    // A tap while this verse is in selection mode leaves the
    // mode and does nothing else (board run 10): selection taps
    // belong to the selection, and the mode's own exit must be
    // one predictable gesture. A tap on any other verse clears
    // the mode and proceeds as the shipped tap.
    if (_selVerse == (ch, v)) {
      setState(() => _selVerse = null);
      return;
    }
    if (_selVerse != null) setState(() => _selVerse = null);
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
          duration: WwMotion.reduced(context) ? Duration.zero : WwMotion.push,
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
    // The outside-tap dismiss also leaves selection mode (board
    // run 10): one surface, one dismiss.
    if (_selVerse != null && _toolbarVerse == null) {
      setState(() => _selVerse = null);
      return;
    }
    if (_toolbarVerse == null) return;
    setState(() {
      _selVerse = null;
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

  /// Long-press on a verse enters selection mode for it (board
  /// run 10): the verse toolbar closes (the selection bar is the
  /// surface while selecting) and the verse's text becomes a
  /// SelectableText; the user's drag or second long-press on it
  /// takes the exact words.
  void _enterSelection(int ch, int v) {
    setState(() {
      if (_toolbarVerse != null) {
        if (_selectedChapter == _toolbarChapter &&
            _selectedVerse == _toolbarVerse) {
          _selectedChapter = null;
          _selectedVerse = null;
        }
        _toolbarChapter = null;
        _toolbarVerse = null;
        _toolbarEditing = false;
        _toolbarPos = null;
      }
      _selVerse = (ch, v);
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
    final translation = _effT;
    final conns = data.verseConnections(ch, v);
    // The conference layer (board run 8, §3): the section renders
    // only when the host carries the layer and it is ON. A host
    // without the layer, or the layer OFF, gets the shipped sheet
    // byte-for-byte (§1.1). Talks are newest-first from the data
    // layer (§3.3), one row per talk however often it cites the
    // verse; an enabled-but-unloaded dataset reads as no talks.
    final host = widget.host;
    final ConferenceHost? confHost = host is ConferenceHost
        ? host as ConferenceHost
        : null;
    final confOn = confHost?.conferenceEnabled ?? false;
    final talks = confOn
        ? (confHost?.conferenceData?.talksForVerse(ch, v) ??
              const <ConferenceTalk>[])
        : const <ConferenceTalk>[];
    // The tradition sections (board run 9): the sheet gains the
    // active tradition's corpus section, under the same §1.1
    // rule — no tradition, or a host without the surface, gets
    // the shipped sheet byte-for-byte. An enabled-but-unloaded
    // dataset reads as no links, the conference rule.
    final tradHost = _traditionHost;
    final tradition = tradHost?.tradition ?? WwTradition.none;
    final sefariaWorks = tradition == WwTradition.jewish
        ? (tradHost?.sefariaData?.worksForVerse(ch, v) ??
              const <(String, int)>[])
        : const <(String, int)>[];
    final confessionSections = tradition == WwTradition.protestant
        ? (tradHost?.confessionData?.sectionsForVerse(ch, v) ??
              const <ConfessionSection>[])
        : const <ConfessionSection>[];
    final layered =
        confOn ||
        tradition == WwTradition.jewish ||
        tradition == WwTradition.protestant;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _palette.bg,
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
                        Text(
                          data.refName(tc, tv),
                          style: _palette.refLabelStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          texts.verseText(translation, data, tc, tv),
                          style: _palette.snippetStyle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textDirection: translation.isRtl
                              ? TextDirection.rtl
                              : null,
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
                icon: Icon(Icons.open_in_new, size: 18, color: _palette.accent),
                constraints: const BoxConstraints(
                  minWidth: WwSpace.minTarget,
                  minHeight: WwSpace.minTarget,
                ),
              ),
            ],
          );
        }

        // The chapter section (HOME ARCH GOES AMBIENT, spec §8):
        // this chapter's partner chapters, ranked as shipped
        // (partnersSorted: count desc, chapter asc), each row
        // ≥48dp, tapping one pops the sheet and routes through
        // the host's one open-chapter procedure — same-book
        // partners page inside the reader, cross-book partners
        // take its book swap. Connections live in the reader
        // now that Home's selection panel is removed.
        Widget chapterPartnerRow(MapEntry<int, int> entry) {
          final pc = entry.key;
          final count = entry.value;
          return InkWell(
            key: ValueKey('chapter-partner-$pc'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              widget.host.openChapter(pc);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.chapterName(pc),
                    style: _palette.smallBodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1 ? '1 connection' : '$count connections',
                    style: _palette.captionStyle,
                  ),
                ],
              ),
            ),
          );
        }

        final partners = data.partnersSorted(ch);
        // The chapter section sits LAST in the sheet's scroll
        // region (spec §8, as amended at build): every shipped
        // section keeps its baseline position and build order,
        // and the partners are reached by scrolling the sheet.
        final chapterSection = <Widget>[
          const SizedBox(height: 16),
          Text(
            '${data.chapterName(ch)} connects to',
            style: _palette.refLabelStyle,
          ),
          const SizedBox(height: 8),
          if (partners.isEmpty)
            Text(
              'No chapter connections are recorded for this chapter.',
              style: _palette.captionStyle,
            )
          else
            for (var i = 0; i < partners.length; i++) ...[
              if (i > 0) Divider(height: 1, color: _palette.hairline),
              chapterPartnerRow(partners[i]),
            ],
        ];

        // One conference talk row (§3.2): ≥48dp, title uncapped
        // in bodyOnPaper w600, the speaker line beneath it, and
        // NO trailing control — a talk has no screen in this app;
        // the row itself opens its talk view in the Library (§3.3).
        // Its content's semantics are excluded under the
        // container (§3.5): one node, the exact label.
        Widget talkRow(ConferenceTalk talk) {
          return Semantics(
            container: true,
            button: true,
            label:
                'Open talk: ${talk.title}, by ${talk.speaker}, '
                '${talk.conferenceLabel}',
            child: ExcludeSemantics(
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
                        style: _palette.smallBodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${talk.speaker} · ${talk.conferenceLabel}',
                        style: _palette.captionStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // One Sefaria row (board run 9): the work this verse is
        // linked to, with its link count; the row opens the work
        // on Sefaria. One semantics node, the exact label — the
        // talk row's construction.
        Widget sefariaRow((String, int) work) {
          final (title, count) = work;
          return Semantics(
            container: true,
            button: true,
            label: 'Open $title on Sefaria',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  final sd = tradHost?.sefariaData;
                  if (sd == null) return;
                  tradHost?.openExternalLink(sd.urlFor(title, ch, v, data));
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
                        title,
                        style: _palette.smallBodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count == 1 ? '1 link' : '$count links',
                        style: _palette.captionStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // One confession-proof row (board run 9): the document
        // and the section that cites this verse; the row opens
        // the confession at its host.
        Widget confessionRow(ConfessionSection section) {
          final cd = tradHost?.confessionData;
          final doc = cd?.docFor(section);
          return Semantics(
            container: true,
            button: true,
            label:
                'Open ${doc?.title ?? 'confession'} ${section.label} '
                'proof text',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (cd == null) return;
                  tradHost?.openExternalLink(cd.urlFor(section));
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
                        doc?.title ?? '',
                        style: _palette.smallBodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${section.label} · proof text',
                        style: _palette.captionStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final header = <Widget>[
          Text(data.refName(ch, v), style: _palette.sheetTitleStyle),
          const SizedBox(height: 8),
          Text(
            texts.verseText(translation, data, ch, v),
            style: _palette.sheetVerseStyle,
            textDirection: translation.isRtl ? TextDirection.rtl : null,
          ),
          const SizedBox(height: 12),
        ];

        if (!layered) {
          // The shipped sheet (§1.1 OFF contract), extended by
          // the chapter section (spec §8): header fixed, then
          // ONE scroll region holding the chapter partners and
          // the verse connections — the layered form's single-
          // scroll construction, so a long partner list can
          // never push the verse section off the sheet. Every
          // shipped string and verse row is verbatim.
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
                      children: [
                        Text('Connections', style: _palette.refLabelStyle),
                        const SizedBox(height: 8),
                        if (conns.isEmpty)
                          Text(
                            'No cross references are recorded for this verse.',
                            style: _palette.captionStyle,
                          )
                        else
                          for (var i = 0; i < conns.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: _palette.hairline),
                            connectionRow(conns[i][0], conns[i][1]),
                          ],
                        ...chapterSection,
                      ],
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
          Text('Connections', style: _palette.refLabelStyle),
          const SizedBox(height: 8),
          if (conns.isEmpty)
            Text(
              'No cross references are recorded for this verse.',
              style: _palette.captionStyle,
            )
          else
            for (var i = 0; i < conns.length; i++) ...[
              if (i > 0) Divider(height: 1, color: _palette.hairline),
              connectionRow(conns[i][0], conns[i][1]),
            ],
          if (confOn) ...[
            const SizedBox(height: 16),
            Text('Conference talks', style: _palette.refLabelStyle),
            const SizedBox(height: 8),
            if (talks.isEmpty)
              Text(
                'No conference talks are recorded for this verse.',
                style: _palette.captionStyle,
              )
            else
              for (var i = 0; i < talks.length; i++) ...[
                if (i > 0) Divider(height: 1, color: _palette.hairline),
                talkRow(talks[i]),
              ],
          ],
          if (tradition == WwTradition.jewish) ...[
            const SizedBox(height: 16),
            Text('On Sefaria', style: _palette.refLabelStyle),
            const SizedBox(height: 8),
            if (sefariaWorks.isEmpty)
              Text(
                'No Sefaria links are recorded for this verse.',
                style: _palette.captionStyle,
              )
            else ...[
              for (var i = 0; i < sefariaWorks.length; i++) ...[
                if (i > 0) Divider(height: 1, color: _palette.hairline),
                sefariaRow(sefariaWorks[i]),
              ],
              // A capped verse (the pipeline keeps the 25
              // most-cited works) says so and links to the
              // verse's own Sefaria page, where every link
              // lives — never a silent truncation.
              if ((tradHost?.sefariaData?.verseWorkTotal(ch, v) ?? 0) >
                  sefariaWorks.length) ...[
                Divider(height: 1, color: _palette.hairline),
                Semantics(
                  container: true,
                  button: true,
                  label: 'See all links for this verse on Sefaria',
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        final sd = tradHost?.sefariaData;
                        if (sd == null) return;
                        tradHost?.openExternalLink(sd.verseUrl(ch, v, data));
                      },
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: WwSpace.minTarget,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'See all ${tradHost?.sefariaData?.verseWorkTotal(ch, v)} '
                          'links on Sefaria',
                          style: _palette.smallBodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
          if (tradition == WwTradition.protestant) ...[
            const SizedBox(height: 16),
            Text('Confession proofs', style: _palette.refLabelStyle),
            const SizedBox(height: 8),
            if (confessionSections.isEmpty)
              Text(
                'No confession proofs are recorded for this verse.',
                style: _palette.captionStyle,
              )
            else
              for (var i = 0; i < confessionSections.length; i++) ...[
                if (i > 0) Divider(height: 1, color: _palette.hairline),
                confessionRow(confessionSections[i]),
              ],
          ],
          // The chapter section closes the scroll region
          // (spec §8, as amended at build).
          ...chapterSection,
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
                  child: ListView(shrinkWrap: true, children: scrollChildren),
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
        backgroundColor: _palette.bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(data, showToggle: false),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'The text could not be loaded.',
                        style: _palette.smallBodyStyle,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _retry,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, WwSpace.minTarget),
                        ),
                        child: Text(
                          'Try again',
                          style: _palette.buttonLabelAccentStyle,
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
        backgroundColor: _palette.bg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(data, showToggle: false),
              Expanded(
                child: Center(
                  child: Text(
                    'Loading the text…',
                    style: _palette.captionStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            // §4.5 as amended: the top bar is FIXED. It never hides.
            _topBar(data, showToggle: true),
            // The connection arch panel (reader arch package):
            // the slot collapses to nothing when the profile's
            // remembered state is minimized. Reduced motion
            // renders the final state: the slot is swapped
            // outright, with no AnimatedSize in the tree (a
            // zero-duration AnimatedSize mutates its render
            // object during its own layout — the instant swap
            // is the design law's construction anyway).
            if (WwMotion.reduced(context))
              _archExpanded ? _archPanel(data) : const SizedBox.shrink()
            else
              AnimatedSize(
                duration: WwMotion.expand,
                curve: WwMotion.curve,
                alignment: Alignment.topCenter,
                child: _archExpanded
                    ? _archPanel(data)
                    : const SizedBox.shrink(),
              ),
            Expanded(
              child: Stack(
                key: _stackKey,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissToolbar,
                    child: TextSelectionTheme(
                      // Spec §3.4 (board run 10) as themed (reader
                      // theme package): the selection chrome comes
                      // from the palette — paper keeps its shipped
                      // values (overlay hlGold at 0.50, handles and
                      // cursor goldTextOnPaper, worst ink ratio
                      // 12.48); dark uses gold at 0.20 with
                      // goldBright handles (gate: worst navInk
                      // ratio 4.94, handles 3.08).
                      data: TextSelectionThemeData(
                        selectionColor: _palette.selectionOverlay,
                        selectionHandleColor: _palette.accent,
                        cursorColor: _palette.accent,
                      ),
                      child: _pager(data, texts),
                    ),
                  ),
                  if (!_archExpanded) _archExpandChip(),
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
      decoration: BoxDecoration(
        color: _palette.chrome,
        border: Border(bottom: BorderSide(color: _palette.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _handleBack,
            icon: Icon(Icons.arrow_back, color: _palette.ink),
            constraints: const BoxConstraints(
              minWidth: WwSpace.minTarget,
              minHeight: WwSpace.minTarget,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PopupMenuButton<String>(
              color: _palette.cardBg,
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
                PopupMenuItem(
                  value: 'library',
                  height: 48,
                  child: Text('Library', style: _palette.smallBodyStyle),
                ),
                PopupMenuItem(
                  value: 'testament',
                  height: 48,
                  child: Text(testament, style: _palette.smallBodyStyle),
                ),
                PopupMenuItem(
                  value: 'book',
                  height: 48,
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 20, color: _palette.muted),
                      const SizedBox(width: 8),
                      Text(
                        bookName,
                        style: _palette.smallBodyStyle.copyWith(
                          color: _palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'jump',
                  height: 48,
                  child: Text(
                    'Jump to reference…',
                    style: _palette.smallBodyStyle,
                  ),
                ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.chapterName(_currentChapter),
                        style: _palette.titleStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: _palette.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _themeSwitch(),
          if (showToggle) ...[const SizedBox(width: 8), _translationToggle()],
        ],
      ),
    );
  }

  /// The reader theme quick switch (reader theme package): one
  /// 48dp target in the top bar, present in every reader state.
  /// The icon names the theme a tap switches TO; the tooltip
  /// states the current theme and the action. The write goes
  /// through the same path as the Profiles setting (§1 of the
  /// package spec) — there is one stored choice, two switches.
  Widget _themeSwitch() {
    final theme = _readerTheme;
    final next = theme.other;
    return IconButton(
      tooltip: 'Reader theme: ${theme.label}. Switch to ${next.label} theme',
      onPressed: () => _setReaderTheme(next),
      icon: Icon(
        next == WwReaderTheme.dark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        color: _palette.accent,
      ),
      constraints: const BoxConstraints(
        minWidth: WwSpace.minTarget,
        minHeight: WwSpace.minTarget,
      ),
    );
  }

  Widget _translationToggle() {
    final available = _availableTranslations;
    // Board run 9: with more than three options (Jewish on the
    // Old Testament: KJV, WEB, JPS, Hebrew) the segmented toggle
    // cannot fit the top bar beside the chapter title at phone
    // widths — it becomes a single chip showing the current
    // translation, opening the app's menu pattern with the full
    // labels. Three or fewer options keep the shipped segmented
    // construction, with compact labels (WwTranslation.toggleLabel).
    // Reader theme package: beside the theme switch, the
    // segmented form outgrows the bar's 360dp budget at large
    // text scales (lesson 37; measured: three options overflow
    // from scale 1.3, two from 1.6), so it takes the same chip
    // form there — same control, same menu, full labels.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (available.length > 3 ||
        (available.length == 3 && textScale >= 1.3) ||
        (available.length > 1 && textScale >= 1.6)) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: _palette.line),
          borderRadius: BorderRadius.circular(WwRadius.chip),
        ),
        child: PopupMenuButton<WwTranslation>(
          color: _palette.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WwRadius.chip),
          ),
          tooltip: 'Translation',
          onSelected: _setTranslation,
          itemBuilder: (_) => [
            for (final t in available)
              PopupMenuItem(
                value: t,
                height: 48,
                child: Row(
                  children: [
                    if (t == _effT)
                      Icon(Icons.check, size: 20, color: _palette.accent)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    Text(t.label, style: _palette.smallBodyStyle),
                  ],
                ),
              ),
          ],
          child: Container(
            constraints: const BoxConstraints(
              minWidth: WwSpace.minTarget,
              minHeight: WwSpace.minTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_effT.toggleLabel, style: _palette.chipLabelStyle),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: _palette.muted,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _palette.line),
        borderRadius: BorderRadius.circular(WwRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in available)
            Material(
              color: t == _effT ? _palette.goldFill : Colors.transparent,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    t.toggleLabel,
                    style: t == _effT
                        ? WwType.goldButtonLabel
                        : _palette.toggleUnselectedStyle,
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
    final verses = texts.chapterVerses(_effT, data, global);
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
      color: _palette.bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.chapterName(ch), style: _palette.titleStyle),
                const SizedBox(height: 4),
                Text(
                  '${c.v} verses · ${data.chapterConnCount[ch]} connections',
                  style: _palette.captionStyle,
                ),
                if (_webcFallbackNote(book) != null) ...[
                  const SizedBox(height: 4),
                  Text(_webcFallbackNote(book)!, style: _palette.captionStyle),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous chapter',
            onPressed: isFirst ? null : () => _turnTo(ch - 1),
            icon: Icon(
              Icons.chevron_left,
              size: 20,
              color: isFirst ? _palette.muted : _palette.ink,
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
              color: isLast ? _palette.muted : _palette.ink,
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

  /// WEBC fallback disclosure (run 9 gate): the World English
  /// Bible Catholic Edition carries no separate Esther or Daniel
  /// text — both exist only as their Greek editions — so under the
  /// WEBC toggle those chapters fall back to KJV. The label block
  /// names the fallback and points to the full Greek edition
  /// rather than letting the toggle claim text it is not showing.
  String? _webcFallbackNote(int bookIndex) {
    if (_effT != WwTranslation.webc) return null;
    if (bookIndex == 16) {
      return 'Shown in the King James Version: the World English Bible '
          'Catholic Edition has no separate Esther. The full Greek '
          'Esther is in the Catholic Old Testament list.';
    }
    if (bookIndex == 26) {
      return 'Shown in the King James Version: the World English Bible '
          'Catholic Edition has no separate Daniel. Daniel with the '
          'Greek portions is in the Catholic Old Testament list.';
    }
    return null;
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
          Text('End of ${book.name}', style: _palette.sheetTitleStyle),
          if (hasNext) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final next = data.books[bookIndex + 1];
                widget.host.openChapter(next.start);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _palette.goldFill,
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
            Text('The last book of the Bible.', style: _palette.captionStyle),
          ],
        ],
      ),
    );
  }

  Widget _verseBlock(BibleData data, int ch, int v, String text) {
    final selected = v == _selectedVerse && ch == _selectedChapter;
    // The dot means "this verse has connections" (board run 9):
    // cross references always; plus the active tradition's
    // corpus, when the host carries one. The conference layer's
    // dot behavior is unchanged from run 8 — talks never lit it.
    var hasConns = data.verseHasConnections(ch, v);
    final tradHost = _traditionHost;
    if (!hasConns && tradHost != null) {
      if (tradHost.tradition == WwTradition.jewish) {
        hasConns = tradHost.sefariaData?.verseHasLinks(ch, v) ?? false;
      } else if (tradHost.tradition == WwTradition.protestant) {
        hasConns = tradHost.confessionData?.verseHasProofs(ch, v) ?? false;
      }
    }
    final spans = _spansFor(ch, v);
    final fullColor = _userData.fullVerseColor(
      _profileId,
      _tKey,
      _verseKeyFor(ch, v),
    );
    final fullTint = fullColor == null ? null : _tintFor(fullColor);
    final hasNote = _noteFor(ch, v) != null;
    final background = selected
        ? _palette.selectedBackground(fullTint)
        : (fullTint ?? Colors.transparent);
    final restingPlain = !selected && spans.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(WwRadius.row),
        child: InkWell(
          key: _keyForVerse(ch, v),
          borderRadius: BorderRadius.circular(WwRadius.row),
          onTap: () => _onVerseTap(ch, v),
          onLongPress: () => _enterSelection(ch, v),
          child: Container(
            constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WwRadius.row),
              border: selected
                  ? Border.all(color: _palette.accent, width: 2)
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
                            ? _palette.verseNumberStyle
                            : _palette.verseNumberOnTintStyle,
                      ),
                      if (hasConns) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: restingPlain
                                ? _palette.dotResting
                                : _palette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      if (hasNote) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.notes, size: 16, color: _palette.accent),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Board run 10: in selection mode the verse text
                  // is a SelectableText — drag or long-press takes
                  // the exact words, the handles extend, and the
                  // §2.2 bar colors the span. Outside the mode it
                  // is the shipped plain Text.
                  child: _selVerse == (ch, v)
                      ? SelectableText.rich(
                          TextSpan(
                            children: _verseSegments(
                              text,
                              spans,
                              suppressBg: fullColor != null,
                            ),
                          ),
                          key: ValueKey('vtext-$ch-$v-$_selGen'),
                          style: _palette.bodyStyle,
                          textDirection: _effT.isRtl ? TextDirection.rtl : null,
                          contextMenuBuilder: (menuContext, state) =>
                              _selectionMenu(menuContext, state, ch, v, text),
                        )
                      : Text.rich(
                          TextSpan(
                            children: _verseSegments(
                              text,
                              spans,
                              suppressBg: fullColor != null,
                            ),
                          ),
                          style: _palette.bodyStyle,
                          textDirection: _effT.isRtl ? TextDirection.rtl : null,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The verse text as segments (board run 10, spec §3.1): the
  /// disjoint span walk — unspanned runs carry no background,
  /// spanned runs carry their tint. When the verse carries a
  /// full-verse span the BLOCK carries the tint (the shipped
  /// run-4 construction), so the segments render bare
  /// ([suppressBg]).
  List<TextSpan> _verseSegments(
    String text,
    List<HighlightSpan> spans, {
    required bool suppressBg,
  }) {
    if (suppressBg || spans.isEmpty) return [TextSpan(text: text)];
    final out = <TextSpan>[];
    var cursor = 0;
    for (final span in spans) {
      final s = span.start.clamp(0, text.length);
      final e = (span.end == -1 ? text.length : span.end).clamp(0, text.length);
      if (e <= s) continue;
      if (s > cursor) out.add(TextSpan(text: text.substring(cursor, s)));
      out.add(
        TextSpan(
          text: text.substring(s, e),
          style: TextStyle(backgroundColor: _tintFor(span.color)),
        ),
      );
      cursor = e;
    }
    if (cursor < text.length) out.add(TextSpan(text: text.substring(cursor)));
    if (out.isEmpty) out.add(TextSpan(text: text));
    return out;
  }

  /// The selection action bar (board run 10, spec §2.2): the
  /// app's own paper card in place of the platform menu — the
  /// five swatches (the toolbar's exact construction), Clear
  /// (the selection's range only), and Copy. Anchored at the
  /// selection; a collapsed selection shows no bar.
  Widget _selectionMenu(
    BuildContext menuContext,
    EditableTextState state,
    int ch,
    int v,
    String verseText,
  ) {
    final selection = state.currentTextEditingValue.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return const SizedBox.shrink();
    }
    final len = verseText.length;
    final start = selection.start.clamp(0, len);
    final end = selection.end.clamp(0, len);
    if (end <= start) return const SizedBox.shrink();
    final key = _verseKeyFor(ch, v);
    final spans = _userData.spansFor(_profileId, _tKey, key);
    HlColor? covering;
    var overlaps = false;
    for (final span in spans) {
      final rs = span.start.clamp(0, len);
      final re = span.end == -1 ? len : span.end.clamp(0, len);
      if (rs < end && re > start) overlaps = true;
      if (rs <= start && re >= end) covering = span.color;
    }
    final anchors = state.contextMenuAnchors;
    final media = MediaQuery.sizeOf(menuContext);
    // Layout budget at 360dp (lesson 37): five 48dp swatches,
    // two 48dp icon actions, 8dp card padding each side = 352dp.
    const barWidth = 352.0;
    const barHeight = 64.0;
    var left = anchors.primaryAnchor.dx - barWidth / 2;
    if (left < 8) left = 8;
    if (left > media.width - barWidth - 8) {
      left = media.width - barWidth - 8;
    }
    var top = anchors.primaryAnchor.dy - barHeight - 12;
    if (top < 8) {
      top = (anchors.secondaryAnchor?.dy ?? anchors.primaryAnchor.dy) + 12;
    }
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: _palette.cardBg,
            borderRadius: BorderRadius.circular(WwRadius.sheet),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _palette.line),
                borderRadius: BorderRadius.circular(WwRadius.sheet),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in HlColor.values)
                    _swatch(
                      color: color,
                      active: covering == color,
                      onTap: () => _applySelectionColor(
                        state,
                        key,
                        verseText,
                        start,
                        end,
                        color,
                      ),
                    ),
                  _menuAction(
                    icon: Icons.format_color_reset,
                    label: 'Clear highlight on selected text',
                    enabled: overlaps,
                    onTap: () =>
                        _clearSelection(state, key, verseText, start, end),
                  ),
                  _menuAction(
                    icon: Icons.copy,
                    label: 'Copy selected text',
                    enabled: true,
                    onTap: () {
                      state.copySelection(SelectionChangedCause.toolbar);
                      state.hideToolbar();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One 48dp icon action of the selection bar, with its
  /// semantics label as its name (lesson 25).
  Widget _menuAction({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: WwSpace.minTarget,
              height: WwSpace.minTarget,
              child: Icon(
                icon,
                size: 20,
                color: enabled ? _palette.ink : _palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A selection-bar color write: the exact selected span, in
  /// the current translation's set. The menu hides first; the
  /// generation bump then recreates the verse's selectable text,
  /// collapsing the platform selection so the tint shows clean.
  void _applySelectionColor(
    EditableTextState state,
    String key,
    String verseText,
    int start,
    int end,
    HlColor color,
  ) {
    state.hideToolbar();
    setState(() {
      _selGen++;
      _selVerse = null;
      _userData.applySpan(
        _profileId,
        _tKey,
        HighlightSpan(
          verseKey: key,
          start: start,
          end: end,
          anchor: verseText.substring(start, end),
          color: color,
        ),
        verseText: verseText,
      );
    });
    _persistUserData();
  }

  /// The selection bar's Clear: only the selected range loses
  /// coverage (the toolbar's None is the verse-wide clear).
  void _clearSelection(
    EditableTextState state,
    String key,
    String verseText,
    int start,
    int end,
  ) {
    state.hideToolbar();
    setState(() {
      _selGen++;
      _selVerse = null;
      _userData.clearSpanRange(
        _profileId,
        _tKey,
        key,
        start,
        end,
        verseText: verseText,
      );
    });
    _persistUserData();
  }

  // --------------------------------------------------------------- toolbar

  Widget _toolbarOverlay(BibleData data) {
    final ch = _toolbarChapter!;
    final v = _toolbarVerse!;
    final pos = _toolbarPos ?? const Offset(16, 64);
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final width = math.min(MediaQuery.sizeOf(context).width - 32, 400.0);
    final Widget card = Container(
      key: _cardKey,
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _palette.cardBg,
        borderRadius: BorderRadius.circular(WwRadius.sheet),
        border: Border.all(color: _palette.cardBorder),
      ),
      child: _toolbarEditing
          ? _noteEditorView(data, ch, v)
          : _toolbarActionsView(data, ch, v),
    );
    if (_toolbarEditing && keyboard > 0) {
      return Positioned(left: pos.dx, bottom: keyboard + 8, child: card);
    }
    return Positioned(left: pos.dx, top: pos.dy, child: card);
  }

  Widget _toolbarActionsView(BibleData data, int ch, int v) {
    final key = _verseKeyFor(ch, v);
    final currentHighlight = _userData.fullVerseColor(_profileId, _tKey, key);
    final currentNote = _userData.note(_profileId, _tKey, key);
    final verseText = _texts?.verseText(_effT, data, ch, v) ?? '';
    final connCount = data.verseConnections(ch, v).length;
    final narrow = MediaQuery.sizeOf(context).width < 344;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(data.refName(ch, v), style: _palette.sheetTitleStyle),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: _dismissToolbar,
              icon: Icon(Icons.close, size: 20, color: _palette.ink),
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
            style: _palette.snippetStyle,
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
                    onTap: () => _applyVerseColor(
                      key,
                      verseText,
                      color == currentHighlight ? null : color,
                    ),
                  ),
                _noneSwatch(
                  active: _spansFor(ch, v).isEmpty,
                  onTap: () => _applyVerseColor(key, verseText, null),
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
                  side: BorderSide(color: _palette.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                ),
                child: Text(
                  currentNote != null ? 'Edit note' : 'Add note',
                  style: _palette.buttonLabelStyle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _openConnections(ch, v),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, WwSpace.minTarget),
                  side: BorderSide(color: _palette.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                ),
                child: Text(
                  'Connections · $connCount',
                  style: _palette.buttonLabelStyle,
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
        Text(data.refName(ch, v), style: _palette.sheetTitleStyle),
        const SizedBox(height: 8),
        Text('Note', style: _palette.refLabelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtl,
          style: _palette.smallBodyStyle,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            filled: true,
            fillColor: _palette.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WwRadius.input),
              borderSide: BorderSide(color: _palette.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WwRadius.input),
              borderSide: BorderSide(color: _palette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WwRadius.input),
              borderSide: BorderSide(color: _palette.accent),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Saving an empty note removes it.', style: _palette.captionStyle),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _toolbarEditing = false),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, WwSpace.minTarget),
              ),
              child: Text('Cancel', style: _palette.buttonLabelStyle),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _applyNote(key, _noteCtl.text);
                setState(() => _toolbarEditing = false);
              },
              style: TextButton.styleFrom(
                backgroundColor: _palette.goldFill,
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
                    color: active ? _palette.accent : _palette.line,
                    width: active ? 2 : 1,
                  ),
                ),
                child: active
                    ? Icon(Icons.check, size: 20, color: _palette.ink)
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
                  color: _palette.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? _palette.accent : _palette.line,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Icon(
                  Icons.do_not_disturb_alt,
                  size: 20,
                  color: _palette.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
