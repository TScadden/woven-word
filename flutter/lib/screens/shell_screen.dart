import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/screen_state.dart';
import '../data/scripture_text.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'my_notes_screen.dart';
import 'profiles_screen.dart';
import 'reader_screen.dart';
import 'screens_tab.dart';

/// The shell (board run 7 part B, §1): three tabs, three
/// navigators inside an [IndexedStack], one stack discipline, and
/// the §7.1 back contract implemented by exactly one handler,
/// [ShellController.handleBack]. Also the §7.4 open-chapter
/// procedure every entry point uses, and the §6 screen set's
/// persistence write points.
class WwShell extends StatefulWidget {
  const WwShell({super.key, this.dataLoader, this.textsLoader});

  final Future<BibleData> Function()? dataLoader;
  final Future<ScriptureText> Function()? textsLoader;

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

class ShellController extends ChangeNotifier implements ReaderHost {
  ShellController({required this.dataLoader, required this.textsLoader}) {
    dataFuture = (dataLoader ?? BibleData.load)();
    dataFuture.then((d) {
      data = d;
      _loadPrefs();
    }).catchError((_) {});
    _loadUserData();
  }

  final Future<BibleData> Function()? dataLoader;
  final Future<ScriptureText> Function()? textsLoader;
  late final Future<BibleData> dataFuture;
  BibleData? data;

  String tab = 'home';
  List<ReadingScreen> screens = [];
  int activeScreenIndex = 0;
  int? selection;
  UserData userData = UserData();
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
      if (savedTab == 'home' || savedTab == 'library' || savedTab == 'screens') {
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

  // ---------------------------------------------------------------- home

  Future<void> _openProfiles() async {
    final nav = homeNavKey.currentState;
    if (nav == null) return;
    await nav.push(WwPageRoute(builder: (_) => const ProfilesScreen()));
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
          onOpenVerse: (book, chapterInBook, verse) {
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
      notesCount = _ctl.userData
          .notesFor(_ctl.userData.activeProfileId)
          .where(
            (n) => notePositionInCanon(d, n.book, n.chapter, n.verse),
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
              Container(
                constraints: const BoxConstraints(
                  minHeight: WwSpace.topBarHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
