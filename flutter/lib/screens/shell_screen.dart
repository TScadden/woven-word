import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bible_data.dart';
import '../data/confession_data.dart';
import '../data/conference_data.dart';
import '../data/deuterocanon.dart';
import '../data/screen_state.dart';
import '../data/scripture_text.dart';
import '../data/sefaria_data.dart';
import '../data/tradition.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import 'conference_screens.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'my_notes_screen.dart';
import 'profiles_screen.dart';
import 'reader_screen.dart';
import 'screens_tab.dart';
import 'tradition_screens.dart';

/// The shell (board run 7 part B, §1): three tabs, three
/// navigators inside an [IndexedStack], one stack discipline, and
/// the §7.1 back contract implemented by exactly one handler,
/// [ShellController.handleBack]. Also the §7.4 open-chapter
/// procedure every entry point uses, and the §6 screen set's
/// persistence write points.
class WwShell extends StatefulWidget {
  const WwShell({
    super.key,
    this.dataLoader,
    this.textsLoader,
    this.conferenceLoader,
    this.sefariaLoader,
    this.confessionLoader,
    this.deuteroLoader,
  });

  final Future<BibleData> Function()? dataLoader;
  final Future<ScriptureText> Function()? textsLoader;
  final Future<ConferenceData> Function(BibleData canon)? conferenceLoader;
  final Future<SefariaData> Function(BibleData canon)? sefariaLoader;
  final Future<ConfessionData> Function(BibleData canon)? confessionLoader;
  final Future<DeuterocanonData> Function()? deuteroLoader;

  @override
  State<WwShell> createState() => _WwShellState();
}

class _RootRoute<T> extends PageRouteBuilder<T> {
  _RootRoute({required WidgetBuilder builder})
    : super(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, _, _, child) => child,
      );
}

class ShellController extends ChangeNotifier
    implements
        ReaderHost,
        ConferenceHost,
        ConferenceLayerState,
        TraditionHost,
        TraditionLayerState {
  ShellController({
    required this.dataLoader,
    required this.textsLoader,
    this.conferenceLoader,
    this.sefariaLoader,
    this.confessionLoader,
    this.deuteroLoader,
  }) {
    dataFuture = (dataLoader ?? BibleData.load)();
    dataFuture
        .then((d) {
          data = d;
          _loadPrefs();
        })
        .catchError((_) {});
    _loadUserData();
  }

  final Future<BibleData> Function()? dataLoader;
  final Future<ScriptureText> Function()? textsLoader;
  final Future<ConferenceData> Function(BibleData canon)? conferenceLoader;
  final Future<SefariaData> Function(BibleData canon)? sefariaLoader;
  final Future<ConfessionData> Function(BibleData canon)? confessionLoader;
  final Future<DeuterocanonData> Function()? deuteroLoader;
  late final Future<BibleData> dataFuture;
  BibleData? data;

  // ------------------------------------------------- conference layer

  /// The persisted toggle for the General Conference connections
  /// layer (board run 8): off by default, opt-in only.
  static const String conferenceLayerKey = 'ww_conference_layer';

  /// Whether the conference layer is enabled. Persisted under
  /// [conferenceLayerKey]; read in [_loadPrefs], written by
  /// [setConferenceEnabled].
  @override
  bool conferenceEnabled = false;

  /// The loaded conference dataset, or null while the layer is
  /// disabled, still loading, or after a failed load (a failed
  /// asset load degrades to "the layer shows nothing" — the shell
  /// never crashes over it).
  @override
  ConferenceData? conferenceData;

  Future<void>? _conferenceLoad;

  /// Loads the conference dataset on first use. Concurrent calls
  /// share one in-flight load; a call after a failure retries.
  /// Never throws.
  Future<void> ensureConferenceLoaded() async {
    if (conferenceData != null) return;
    final inFlight = _conferenceLoad;
    if (inFlight != null) return inFlight;
    final d = data;
    if (d == null) return;
    final load = () async {
      try {
        conferenceData = await (conferenceLoader ?? ConferenceData.load)(d);
      } catch (e) {
        debugPrint('Woven Word: conference layer failed to load: $e');
        conferenceData = null;
      } finally {
        _conferenceLoad = null;
      }
      notifyListeners();
    }();
    _conferenceLoad = load;
    return load;
  }

  /// Sets the conference layer (board run 8's API, kept): since
  /// board run 9 the toggle IS the tradition selection — on
  /// selects the Latter-day Saint tradition, off selects Bible
  /// only. Persists through [setTradition].
  Future<void> setConferenceEnabled(bool enabled) async {
    await setTradition(enabled ? WwTradition.lds : WwTradition.none);
  }

  // ------------------------------------------------ tradition layers

  /// The founder's tradition selection (board run 9): the one
  /// state the canon presentation, the connections layers, the
  /// translations, and the link-outs all read. Bible only
  /// ([WwTradition.none]) is the default and a first-class state.
  /// Persisted under [traditionPrefsKey]; restored in
  /// [_loadPrefs], with the run-8 conference toggle migrated
  /// there. User profiles, highlights, and notes are never
  /// touched by a tradition switch — verse keys stay canonical.
  @override
  WwTradition tradition = WwTradition.none;

  /// The loaded layer datasets, or null while their tradition is
  /// not selected, still loading, or after a failed load (a
  /// failed asset load degrades to "the layer shows nothing" —
  /// the shell never crashes over it, the conference rule).
  @override
  SefariaData? sefariaData;

  @override
  ConfessionData? confessionData;

  @override
  DeuterocanonData? deuterocanonData;

  Future<void>? _sefariaLoad;
  Future<void>? _confessionLoad;
  Future<void>? _deuteroLoad;

  /// Sets and persists the tradition selection, and kicks the
  /// newly selected layer's lazy load. The conference layer's
  /// enabled flag follows the selection (it IS the LDS layer).
  Future<void> setTradition(WwTradition next) async {
    if (tradition != next) {
      tradition = next;
      conferenceEnabled = next == WwTradition.lds;
      notifyListeners();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(traditionPrefsKey, next.storedValue);
    } catch (_) {}
    await _kickTraditionLoads();
  }

  /// Starts the active tradition's dataset load (the conference
  /// rule: a layer's data loads when its tradition is selected,
  /// not before). Awaited by [setTradition] so a caller that
  /// awaits the selection can read the layer's state — the
  /// run-8 setConferenceEnabled contract.
  Future<void> _kickTraditionLoads() async {
    switch (tradition) {
      case WwTradition.lds:
        await ensureConferenceLoaded();
      case WwTradition.jewish:
        await ensureSefariaLoaded();
      case WwTradition.protestant:
        await ensureConfessionLoaded();
      case WwTradition.catholic:
        await ensureDeuteroLoaded();
      case WwTradition.none:
        break;
    }
  }

  /// Loads the Sefaria links dataset on first use; concurrent
  /// calls share one in-flight load, a call after a failure
  /// retries. Never throws (the conference loader's pattern).
  Future<void> ensureSefariaLoaded() async {
    if (sefariaData != null) return;
    final inFlight = _sefariaLoad;
    if (inFlight != null) return inFlight;
    final d = data;
    if (d == null) return;
    final load = () async {
      try {
        sefariaData = await (sefariaLoader ?? SefariaData.load)(d);
      } catch (e) {
        debugPrint('Woven Word: Sefaria layer failed to load: $e');
        sefariaData = null;
      } finally {
        _sefariaLoad = null;
      }
      notifyListeners();
    }();
    _sefariaLoad = load;
    return load;
  }

  /// Loads the confessions dataset on first use (same pattern).
  Future<void> ensureConfessionLoaded() async {
    if (confessionData != null) return;
    final inFlight = _confessionLoad;
    if (inFlight != null) return inFlight;
    final d = data;
    if (d == null) return;
    final load = () async {
      try {
        confessionData = await (confessionLoader ?? ConfessionData.load)(d);
      } catch (e) {
        debugPrint('Woven Word: confessions layer failed to load: $e');
        confessionData = null;
      } finally {
        _confessionLoad = null;
      }
      notifyListeners();
    }();
    _confessionLoad = load;
    return load;
  }

  /// Loads the deuterocanon table on first use (same pattern).
  /// Also kicked at startup under every tradition: the Home
  /// notes count and My Notes count deuterocanon notes wherever
  /// they were written.
  Future<void> ensureDeuteroLoaded() async {
    if (deuterocanonData != null) return;
    final inFlight = _deuteroLoad;
    if (inFlight != null) return inFlight;
    final load = () async {
      try {
        deuterocanonData = await (deuteroLoader ?? DeuterocanonData.load)();
      } catch (e) {
        debugPrint('Woven Word: deuterocanon failed to load: $e');
        deuterocanonData = null;
      } finally {
        _deuteroLoad = null;
      }
      notifyListeners();
    }();
    _deuteroLoad = load;
    return load;
  }

  /// Tradition link-outs (the reader's Sefaria and confession
  /// rows): opened outside the app; a failed open is logged,
  /// never thrown into the UI.
  @override
  void openExternalLink(String url) {
    unawaited(() async {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Woven Word: external link failed: $e');
      }
    }());
  }

  String tab = 'home';
  List<ReadingScreen> screens = [];
  int activeScreenIndex = 0;
  int? selection;
  UserData userData = UserData();

  /// The stored translation choice, refreshed at load (board
  /// run 10): the Home notes count and My Notes show the active
  /// translation's set, so the shell reads the reader's
  /// preference alongside its own.
  WwTranslation translation = WwTranslation.kjv;
  bool readerOpen = false;
  int _nextScreenId = 2;

  final homeNavKey = GlobalKey<NavigatorState>();
  final libraryNavKey = GlobalKey<NavigatorState>();
  final screensNavKey = GlobalKey<NavigatorState>();
  final readerKey = GlobalKey<ReaderScreenState>();
  final homeTabKey = GlobalKey<HomeTabState>();
  final libraryRootKey = GlobalKey<LibraryRootState>();

  ReadingScreen get activeScreen => screens[activeScreenIndex];

  // -------------------------------------------------------------- prefs

  Future<void> _loadPrefs() async {
    final d = data;
    if (d == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // §10: the retired scope key is removed on first launch.
      await prefs.remove('ww_home_scope');
      final savedTab = prefs.getString('ww_shell_tab');
      if (savedTab == 'home' ||
          savedTab == 'library' ||
          savedTab == 'screens') {
        tab = savedTab!;
      }
      final savedSelection = prefs.getInt('ww_home_selected');
      if (savedSelection != null &&
          savedSelection >= 0 &&
          savedSelection < d.totalChapters) {
        selection = savedSelection;
      }
      final (parsed, active) = parseWwScreens(
        prefs.getString('ww_screens_v1'),
        d,
        fallbackChapter: selection,
      );
      screens = parsed;
      activeScreenIndex = active;
      _nextScreenId = screens.length + 1;
      // Tradition (board run 9): the selection restores from its
      // own key, and its layer loads on startup only when the
      // persisted choice carries one. Migration: a pre-run-9
      // install whose conference toggle was on becomes the
      // Latter-day Saint tradition — the same layer, renamed.
      final storedTradition = prefs.getString(traditionPrefsKey);
      if (storedTradition != null) {
        tradition = WwTradition.fromStored(storedTradition);
      } else if (prefs.getBool(conferenceLayerKey) ?? false) {
        tradition = WwTradition.lds;
      }
      conferenceEnabled = tradition == WwTradition.lds;
      unawaited(_kickTraditionLoads());
      // The reader's translation choice (board run 10): read for
      // the Home notes count's per-translation visibility.
      translation = WwTranslation.fromStored(
        prefs.getString(translationPrefsKey),
      );
      // The deuterocanon table loads under every tradition (the
      // Home notes count and My Notes count its notes wherever
      // they were written).
      ensureDeuteroLoaded();
    } catch (_) {
      if (screens.isEmpty) {
        final ch = selection ?? 0;
        screens = [
          ReadingScreen(id: 1, bookIndex: d.chapters[ch].b, globalChapter: ch),
        ];
        activeScreenIndex = 0;
      }
    }
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      userData = store.data;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void persistScreens() {
    if (screens.isEmpty) return;
    final snapshot = serializeWwScreens(screens, activeScreenIndex);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString('ww_screens_v1', snapshot))
        .catchError((_) => false);
  }

  Future<void> _persistTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ww_shell_tab', tab);
    } catch (_) {}
  }

  @override
  void recordSelection(int ch) {
    selection = ch;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt('ww_home_selected', ch))
        .catchError((_) => false);
    notifyListeners();
  }

  void clearSelection() {
    selection = null;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.remove('ww_home_selected'))
        .catchError((_) => false);
    notifyListeners();
  }

  // ---------------------------------------------------------------- tabs

  void switchTab(String id) {
    if (tab == id) return;
    // §6.4 write point: a tab switch away from Screens — and the
    // screen set is cheap to keep truthful at every switch.
    persistScreens();
    tab = id;
    _persistTab();
    notifyListeners();
  }

  void onTabTap(int index) {
    final id = ['home', 'library', 'screens'][index];
    if (id != tab) {
      switchTab(id);
      return;
    }
    // Re-tap: pop that tab to its root; at the root, scroll to top
    // for the scrolling roots (Home, Library) (§1.1).
    final nav = _navFor(id);
    if (nav?.canPop() ?? false) {
      nav!.popUntil((route) => route.isFirst);
    } else if (id == 'home') {
      homeTabKey.currentState?.scrollToTop();
    } else if (id == 'library') {
      libraryRootKey.currentState?.scrollToTop();
    }
  }

  GlobalKey<NavigatorState> _navKeyFor(String id) => switch (id) {
    'library' => libraryNavKey,
    'screens' => screensNavKey,
    _ => homeNavKey,
  };

  NavigatorState? _navFor(String id) => _navKeyFor(id).currentState;

  // ------------------------------------------------------- open a chapter

  @override
  bool openChapter(int ch, {int? verse, bool inNewScreen = false}) {
    final d = data;
    if (d == null || ch < 0 || ch >= d.totalChapters) return false;
    if (inNewScreen) {
      if (screens.length >= wwMaxScreens) {
        // §7.4 cap fallback: same-screen jump, receipt by caller.
        openChapter(ch, verse: verse);
        return false;
      }
      final screen = ReadingScreen(
        id: _nextScreenId++,
        bookIndex: d.chapters[ch].b,
        globalChapter: ch,
        anchorVerse: verse,
      );
      screens = [...screens, screen];
      activeScreenIndex = screens.length - 1;
      recordSelection(ch);
      persistScreens();
      switchTab('screens');
      _openOrBindReader(landChapter: ch, landVerse: verse);
      notifyListeners();
      return true;
    }
    final screen = activeScreen;
    final book = d.chapters[ch].b;
    if (!screen.bound) {
      screen.bookIndex = book;
      screen.globalChapter = ch;
      screen.anchorVerse = verse;
    } else {
      final current = screen.place;
      final target = (ch, verse);
      if (current != target) {
        if (screen.history.isEmpty || screen.history.last != current) {
          screen.history.add(current);
        }
        if (book != screen.bookIndex) {
          screen.bookIndex = book;
        }
        screen.globalChapter = ch;
        screen.anchorVerse = verse;
      }
    }
    recordSelection(ch);
    persistScreens();
    switchTab('screens');
    _openOrBindReader(landChapter: ch, landVerse: verse);
    notifyListeners();
    return true;
  }

  void _openOrBindReader({int? landChapter, int? landVerse}) {
    if (readerOpen) {
      final state = readerKey.currentState;
      if (state == null) return;
      if (!identical(state.screen, activeScreen)) {
        state.bindScreen(activeScreen);
      }
      if (landChapter != null) state.landTo(landChapter, landVerse);
      return;
    }
    final nav = screensNavKey.currentState;
    if (nav == null) return;
    final d = data!;
    readerOpen = true;
    nav
        .push(
          WwPageRoute(
            builder: (_) => ReaderScreen(
              key: readerKey,
              data: d,
              screen: activeScreen,
              host: this,
              textsLoader: textsLoader,
            ),
          ),
        )
        .then((_) {
          readerOpen = false;
          notifyListeners();
        });
    if (landChapter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        readerKey.currentState?.landTo(landChapter, landVerse);
      });
    }
  }

  @override
  void readerBackFallback() {
    screensNavKey.currentState?.pop();
  }

  // ----------------------------------------------------------- breadcrumb

  @override
  void breadcrumbLibrary() {
    switchTab('library');
    libraryNavKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  void breadcrumbTestament(int bookIndex) {
    switchTab('library');
    final nav = libraryNavKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    _pushBookGrid(bookIndex < 39);
  }

  @override
  void jumpToReference() {
    switchTab('library');
    libraryNavKey.currentState?.popUntil((route) => route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      libraryRootKey.currentState?.focusSearch();
    });
  }

  // ------------------------------------------------------------- library

  void _pushBookGrid(bool isOT) {
    final d = data;
    final nav = libraryNavKey.currentState;
    if (d == null || nav == null) return;
    nav.push(
      WwPageRoute(
        builder: (_) => BookGrid(
          data: d,
          isOT: isOT,
          onOpenBook: _pushChapterGrid,
          onBack: () => nav.pop(),
          onBreadcrumbRoot: () => nav.popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  // ------------------------------------------ conference browse (§4)

  /// The Library root tile's tap: push the conferences list.
  void openConferenceBrowse() {
    _pushConferencesList();
  }

  /// A sheet talk row's tap (§3.3): the sheet has already popped;
  /// switch to the Library tab and land on the talk's talk view
  /// with the conferences list and that conference's talks list
  /// placed beneath it, so Back unwinds the browse coherently
  /// (§4.5). The reader's place in the Screens tab is untouched.
  @override
  void openConferenceTalk(ConferenceTalk talk) {
    switchTab('library');
    final nav = libraryNavKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    _pushConferencesList();
    _pushTalksList(talk.year, talk.session);
    _pushTalkView(talk);
  }

  void _pushConferencesList() {
    final cd = conferenceData;
    final nav = libraryNavKey.currentState;
    if (cd == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-conferences'),
        builder: (_) => ConferenceListScreen(
          conferenceData: cd,
          onBack: () => nav.pop(),
          onBreadcrumbRoot: () => nav.popUntil((r) => r.isFirst),
          onOpenConference: _pushTalksList,
        ),
      ),
    );
  }

  void _pushTalksList(int year, String session) {
    final cd = conferenceData;
    final nav = libraryNavKey.currentState;
    if (cd == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-conference-talks'),
        builder: (_) => ConferenceTalksScreen(
          conferenceData: cd,
          year: year,
          session: session,
          onBack: () => nav.pop(),
          onBreadcrumb: (value) {
            if (value == 'library') {
              nav.popUntil((r) => r.isFirst);
            } else if (value == 'conferences') {
              nav.popUntil(
                (r) => r.isFirst || r.settings.name == 'ww-conferences',
              );
            }
          },
          onOpenTalk: _pushTalkView,
        ),
      ),
    );
  }

  void _pushTalkView(ConferenceTalk talk) {
    final d = data;
    final cd = conferenceData;
    final nav = libraryNavKey.currentState;
    if (d == null || cd == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-conference-talk'),
        builder: (_) => TalkViewScreen(
          data: d,
          conferenceData: cd,
          talk: talk,
          textsLoader: textsLoader,
          onBack: () => nav.pop(),
          onBreadcrumb: (value) {
            if (value == 'library') {
              nav.popUntil((r) => r.isFirst);
            } else if (value == 'conferences') {
              nav.popUntil(
                (r) => r.isFirst || r.settings.name == 'ww-conferences',
              );
            } else if (value == 'talks') {
              nav.popUntil(
                (r) => r.isFirst || r.settings.name == 'ww-conference-talks',
              );
            }
          },
          onOpenVerse: (ch, verse) => openChapter(ch, verse: verse),
        ),
      ),
    );
  }

  void _pushChapterGrid(int bookIndex) {
    final d = data;
    final nav = libraryNavKey.currentState;
    if (d == null || nav == null) return;
    nav.push(
      WwPageRoute(
        builder: (_) => ChapterGrid(
          data: d,
          bookIndex: bookIndex,
          onOpenChapter: (ch) => openChapter(ch),
          onBack: () => nav.pop(),
          onBreadcrumb: (value) {
            if (value == 'library') {
              nav.popUntil((r) => r.isFirst);
            } else if (value == 'testament') {
              nav.pop();
            }
          },
        ),
      ),
    );
  }

  // ------------------------------------------------ tradition browsing

  /// The Tanakh grid (Jewish tradition): the canon view's
  /// sections over the core books; a book tap lands on the
  /// shipped chapter grid, a chapter tap on the reader.
  void _openTanakhGrid() {
    final d = data;
    final nav = libraryNavKey.currentState;
    if (d == null || nav == null) return;
    final view = CanonView.tanakh(d);
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-tanakh'),
        builder: (_) => SectionedBookGrid(
          title: 'Tanakh',
          sections: [
            for (final section in view.sections)
              BookGridSection(section.title, [
                for (final b in section.books)
                  BookGridEntry(
                    name: b.name,
                    chapters: d.books[b.bookIndex].chapters,
                    onTap: () => _pushChapterGrid(b.bookIndex),
                  ),
              ]),
          ],
          onBack: () => nav.pop(),
          breadcrumbItems: const [
            ('library', 'Library'),
            ('__current', 'Tanakh'),
          ],
          onBreadcrumb: (value) {
            if (value == 'library') nav.popUntil((r) => r.isFirst);
          },
        ),
      ),
    );
  }

  /// The Catholic Old Testament grid: core and deuterocanon
  /// books in Catholic order in one section — Tobit and Judith
  /// after Nehemiah, the Greek Esther after Esther, Wisdom and
  /// Sirach after the Song, Baruch after Lamentations, the Greek
  /// Daniel after Daniel, the Maccabees closing the testament.
  /// Any extra book the table carries beyond those named here
  /// appends in table order rather than vanishing.
  void _openCatholicOtGrid() {
    final d = data;
    final deutero = deuterocanonData;
    final nav = libraryNavKey.currentState;
    if (d == null || deutero == null || nav == null) return;
    final entries = <BookGridEntry>[];
    final placed = <String>{};
    void extra(String slug) {
      final b = deutero.bySlug(slug);
      if (b == null || !placed.add(slug)) return;
      entries.add(
        BookGridEntry(
          name: b.name,
          chapters: b.chapters,
          deutero: true,
          onTap: () => _pushDeuteroChapters(b),
        ),
      );
    }

    for (var i = 0; i < 39 && i < d.books.length; i++) {
      final bookIndex = i;
      entries.add(
        BookGridEntry(
          name: d.books[bookIndex].name,
          chapters: d.books[bookIndex].chapters,
          onTap: () => _pushChapterGrid(bookIndex),
        ),
      );
      switch (i) {
        case 15:
          extra('tobit');
          extra('judith');
        case 16:
          extra('esther-greek');
        case 21:
          extra('wisdom');
          extra('sirach');
        case 24:
          extra('baruch');
        case 26:
          extra('daniel-greek');
        case 38:
          extra('1-maccabees');
          extra('2-maccabees');
      }
    }
    for (final b in deutero.books) {
      if (!placed.contains(b.slug)) extra(b.slug);
    }
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-catholic-ot'),
        builder: (_) => SectionedBookGrid(
          title: 'Old Testament',
          sections: [BookGridSection('Old Testament', entries)],
          onBack: () => nav.pop(),
          breadcrumbItems: const [
            ('library', 'Library'),
            ('__current', 'Old Testament'),
          ],
          onBreadcrumb: (value) {
            if (value == 'library') nav.popUntil((r) => r.isFirst);
          },
        ),
      ),
    );
  }

  void _pushDeuteroChapters(DeuteroBook book) {
    final nav = libraryNavKey.currentState;
    if (nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-deutero-chapters'),
        builder: (_) => DeuteroChapterGrid(
          book: book,
          onBack: () => nav.pop(),
          onBreadcrumb: (value) {
            if (value == 'library') {
              nav.popUntil((r) => r.isFirst);
            } else if (value == 'canon') {
              nav.pop();
            }
          },
          onOpenChapter: (chapterInBook) =>
              _openDeuteroReader(libraryNavKey, book, chapterInBook, null),
        ),
      ),
    );
  }

  /// Pushes the deuterocanon reader on [navKey]'s stack — the
  /// Library stack from the Catholic browse, the Home stack from
  /// a My Notes row, so Back returns to where the tap happened.
  void _openDeuteroReader(
    GlobalKey<NavigatorState> navKey,
    DeuteroBook book,
    int chapterInBook,
    int? verse,
  ) {
    final deutero = deuterocanonData;
    final nav = navKey.currentState;
    if (deutero == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-deutero-reader'),
        builder: (_) => DeuteroReaderScreen(
          deutero: deutero,
          book: book,
          initialChapter: chapterInBook,
          initialVerse: verse,
          textsLoader: textsLoader,
          onBack: () => nav.pop(),
        ),
      ),
    );
  }

  /// The confessions browse (Protestant tradition): documents,
  /// then a document's sections, then a section's cited verses.
  void _openConfessions() {
    final cd = confessionData;
    final nav = libraryNavKey.currentState;
    if (cd == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-confessions'),
        builder: (_) => ConfessionDocsScreen(
          confessionData: cd,
          onBack: () => nav.pop(),
          onBreadcrumbRoot: () => nav.popUntil((r) => r.isFirst),
          onOpenDoc: _pushConfessionSections,
        ),
      ),
    );
  }

  void _pushConfessionSections(int docIndex) {
    final cd = confessionData;
    final nav = libraryNavKey.currentState;
    if (cd == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-confession-sections'),
        builder: (_) => ConfessionSectionsScreen(
          confessionData: cd,
          docIndex: docIndex,
          onBack: () => nav.pop(),
          onBreadcrumb: (value) {
            if (value == 'library') {
              nav.popUntil((r) => r.isFirst);
            } else if (value == 'confessions') {
              nav.popUntil(
                (r) => r.isFirst || r.settings.name == 'ww-confessions',
              );
            }
          },
          onOpenSection: _pushConfessionSection,
        ),
      ),
    );
  }

  void _pushConfessionSection(ConfessionSection section) {
    final d = data;
    final cd = confessionData;
    final nav = libraryNavKey.currentState;
    if (d == null || cd == null || nav == null) return;
    nav.push(
      WwPageRoute(
        settings: const RouteSettings(name: 'ww-confession-section'),
        builder: (_) => ConfessionSectionScreen(
          data: d,
          confessionData: cd,
          section: section,
          textsLoader: textsLoader,
          onBack: () => nav.pop(),
          onBreadcrumb: (value) {
            if (value == 'library') {
              nav.popUntil((r) => r.isFirst);
            } else if (value == 'confessions') {
              nav.popUntil(
                (r) => r.isFirst || r.settings.name == 'ww-confessions',
              );
            } else if (value == 'sections') {
              nav.popUntil(
                (r) => r.isFirst || r.settings.name == 'ww-confession-sections',
              );
            }
          },
          onOpenVerse: (ch, verse) => openChapter(ch, verse: verse),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- home

  Future<void> _openProfiles() async {
    final nav = homeNavKey.currentState;
    if (nav == null) return;
    await nav.push(
      WwPageRoute(
        builder: (_) => ProfilesScreen(
          tradition: tradition,
          onTraditionChanged: setTradition,
        ),
      ),
    );
    _loadUserData();
  }

  Future<void> _openMyNotes() async {
    final d = data;
    final nav = homeNavKey.currentState;
    if (d == null || nav == null) return;
    await nav.push(
      WwPageRoute(
        builder: (_) => MyNotesScreen(
          data: d,
          tradition: tradition,
          textsLoader: textsLoader,
          deuteroLoader: () async {
            await ensureDeuteroLoaded();
            return deuterocanonData;
          },
          onOpenVerse: (book, chapterInBook, verse) {
            if (book >= DeuteroBook.bookIndexBase) {
              final dBook = deuterocanonData?.byBookIndex(book);
              if (dBook != null) {
                _openDeuteroReader(homeNavKey, dBook, chapterInBook, verse);
              }
              return;
            }
            final global = d.books[book].start + chapterInBook - 1;
            openChapter(global, verse: verse);
          },
        ),
      ),
    );
    _loadUserData();
  }

  void _resume() {
    if (screens.isEmpty) return;
    final screen = activeScreen;
    if (!screen.bound) {
      openChapter(0);
      return;
    }
    switchTab('screens');
    if (!readerOpen) {
      _openOrBindReader();
    } else if (!identical(readerKey.currentState?.screen, screen)) {
      readerKey.currentState?.bindScreen(screen);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- screens

  void activateScreen(int index) {
    if (index < 0 || index >= screens.length) return;
    persistScreens();
    activeScreenIndex = index;
    final screen = activeScreen;
    if (screen.bound && selection != screen.globalChapter) {
      recordSelection(screen.globalChapter);
    }
    persistScreens();
    if (!screen.bound) {
      switchTab('library');
      notifyListeners();
      return;
    }
    if (readerOpen) {
      readerKey.currentState?.bindScreen(screen);
    } else {
      _openOrBindReader();
    }
    notifyListeners();
  }

  void closeScreen(int index) {
    if (screens.length <= 1 || index < 0 || index >= screens.length) return;
    final wasActive = index == activeScreenIndex;
    screens = [...screens]..removeAt(index);
    if (index < activeScreenIndex) {
      activeScreenIndex--;
    } else if (wasActive) {
      // Next neighbour below; if it was last, the one above (§6.3).
      activeScreenIndex = index < screens.length ? index : screens.length - 1;
      if (readerOpen) {
        readerKey.currentState?.bindScreen(activeScreen);
      }
    }
    persistScreens();
    notifyListeners();
  }

  void newScreen() {
    if (screens.length >= wwMaxScreens) return;
    final screen = ReadingScreen(id: _nextScreenId++);
    screens = [...screens, screen];
    activeScreenIndex = screens.length - 1;
    persistScreens();
    switchTab('library');
    notifyListeners();
  }

  // ----------------------------------------------------------------- back

  /// The one back handler (§7.1): system back and the reader's
  /// top-bar back both resolve here (the reader delegates its
  /// priority rungs to its own state first).
  void handleBack() {
    if (readerOpen) {
      final state = readerKey.currentState;
      if (state != null && state.handlePriorityBack()) return;
      readerBackFallback();
      return;
    }
    final nav = _navFor(tab);
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (tab != 'home') {
      switchTab('home');
      return;
    }
    SystemNavigator.pop();
  }
}

class _WwShellState extends State<WwShell> {
  late final ShellController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = ShellController(
      dataLoader: widget.dataLoader,
      textsLoader: widget.textsLoader,
      conferenceLoader: widget.conferenceLoader,
      sefariaLoader: widget.sefariaLoader,
      confessionLoader: widget.confessionLoader,
      deuteroLoader: widget.deuteroLoader,
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctl,
      builder: (context, _) {
        final tabIndex = ['home', 'library', 'screens'].indexOf(_ctl.tab);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _ctl.handleBack();
          },
          child: Scaffold(
            backgroundColor: WwColors.stage,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: IndexedStack(
                      index: tabIndex,
                      children: [
                        _tabNavigator(_ctl.homeNavKey, _homeRoot),
                        _tabNavigator(_ctl.libraryNavKey, _libraryRoot),
                        _tabNavigator(_ctl.screensNavKey, _screensRoot),
                      ],
                    ),
                  ),
                  _tabBar(tabIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tabNavigator(
    GlobalKey<NavigatorState> key,
    WidgetBuilder rootBuilder,
  ) {
    return Navigator(
      key: key,
      onGenerateRoute: (settings) => _RootRoute(builder: rootBuilder),
    );
  }

  Widget _homeRoot(BuildContext context) {
    final d = _ctl.data;
    final activeBound = _ctl.screens.isNotEmpty && _ctl.activeScreen.bound;
    var resumeSubtitle = 'Genesis 1';
    if (activeBound && d != null) {
      final screen = _ctl.activeScreen;
      resumeSubtitle = d.chapterName(screen.globalChapter);
      if (screen.anchorVerse != null) {
        resumeSubtitle += ' · verse ${screen.anchorVerse}';
      }
    }
    var notesCount = 0;
    if (d != null) {
      // The My Notes card counts what My Notes would show (board
      // run 10): the active translation's notes, in positions the
      // canon carries, whose books the current tradition presents
      // — dormant notes are stored, never counted here.
      notesCount = _ctl.userData
          .notesFor(_ctl.userData.activeProfileId, _ctl.translation.name)
          .where(
            (n) =>
                notePositionInCanon(
                  d,
                  n.book,
                  n.chapter,
                  n.verse,
                  deutero: _ctl.deuterocanonData,
                ) &&
                canonContainsBook(_ctl.tradition, d, n.book),
          )
          .length;
    }
    return HomeTab(
      key: _ctl.homeTabKey,
      dataFuture: _ctl.dataFuture,
      userData: _ctl.userData,
      selection: _ctl.selection,
      resumeBound: activeBound,
      resumeSubtitle: resumeSubtitle,
      notesCount: notesCount,
      onOpenChapter: (ch) => _ctl.openChapter(ch),
      onClearSelection: _ctl.clearSelection,
      onResume: _ctl._resume,
      onOpenProfiles: _ctl._openProfiles,
      onOpenMyNotes: _ctl._openMyNotes,
      onRetryLoad: () {
        // The data future is fixed at construction; a retry reloads
        // prefs/user data. (Load failure of the bundled asset is
        // not expected; the error surface matches §2.5.)
        _ctl._loadUserData();
      },
    );
  }

  Widget _libraryRoot(BuildContext context) {
    return LibraryRoot(
      key: _ctl.libraryRootKey,
      dataFuture: _ctl.dataFuture,
      onTestament: _ctl._pushBookGrid,
      onOpenChapter: (ch) => _ctl.openChapter(ch),
      conferenceState: _ctl,
      onOpenConference: _ctl.openConferenceBrowse,
      traditionState: _ctl,
      onOpenTanakh: _ctl._openTanakhGrid,
      onOpenCatholicOt: _ctl._openCatholicOtGrid,
      onOpenConfessions: _ctl._openConfessions,
      // Live search (search fix package, §5): result taps push
      // inside the Library navigator over the root, whose
      // search state survives underneath. The talk view takes
      // the direct push, not openConferenceTalk — that path
      // resets the stack for the reader sheet's landings.
      onOpenBook: _ctl._pushChapterGrid,
      onOpenDeuteroBook: _ctl._pushDeuteroChapters,
      onOpenDeuteroChapter: (book, chapterInBook) =>
          _ctl._openDeuteroReader(_ctl.libraryNavKey, book, chapterInBook, null),
      onOpenTalk: _ctl._pushTalkView,
    );
  }

  Widget _screensRoot(BuildContext context) {
    return ScreensTab(
      data: _ctl.data,
      screens: _ctl.screens,
      activeIndex: _ctl.screens.isEmpty ? 0 : _ctl.activeScreenIndex,
      onRowTap: _ctl.activateScreen,
      onClose: _ctl.closeScreen,
      onNew: _ctl.newScreen,
    );
  }

  Widget _tabBar(int tabIndex) {
    return Container(
      constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
      decoration: const BoxDecoration(
        color: WwColors.nav,
        border: Border(top: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: Row(
        children: [
          _tabSlot(
            index: 0,
            selected: tabIndex == 0,
            icon: Icons.home,
            iconOutlined: Icons.home_outlined,
            label: 'Home',
          ),
          _tabSlot(
            index: 1,
            selected: tabIndex == 1,
            icon: Icons.menu_book,
            iconOutlined: Icons.menu_book_outlined,
            label: 'Library',
          ),
          _tabSlot(
            index: 2,
            selected: tabIndex == 2,
            icon: Icons.layers,
            iconOutlined: Icons.layers_outlined,
            label: 'Screens',
            badgeCount: _ctl.screens.length,
          ),
        ],
      ),
    );
  }

  Widget _tabSlot({
    required int index,
    required bool selected,
    required IconData icon,
    required IconData iconOutlined,
    required String label,
    int badgeCount = 0,
  }) {
    final color = selected ? WwColors.goldBright : WwColors.mutedOnDark;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: badgeCount >= 2 ? '$label, $badgeCount screens open' : label,
        child: InkWell(
          onTap: () => _ctl.onTabTap(index),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 2,
                      color: WwColors.goldBright,
                    ),
                  ),
                ),
              // The content spans the full slot width and centers
              // its column in the slot (run-8 fix round, Defect 1):
              // the Stack sizes to the full slot (the indicator's
              // Positioned left/right prove it), but a shrink-wrapped
              // container hugged the slot's left edge under the
              // Stack's default topStart alignment, so the icon and
              // label sat at the column's left while the indicator
              // centered on the column — the founder's screenshot.
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: WwSpace.topBarHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          selected ? icon : iconOutlined,
                          size: 22,
                          color: color,
                        ),
                        if (badgeCount >= 2)
                          Positioned(
                            top: -6,
                            right: -12,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: WwColors.goldBright,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$badgeCount',
                                style: WwType.badgeCount,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: selected
                          ? WwType.tabLabelSelected
                          : WwType.tabLabelUnselected,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
