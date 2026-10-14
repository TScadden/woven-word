import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/screen_state.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/reader_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

/// A [ReaderHost] that mirrors the shell's §7.4 procedure against a
/// single reader route, so the paged reader can be tested through
/// its real seams (§12 F-3) without the whole shell.
class TestReaderHost implements ReaderHost {
  TestReaderHost(this.data, this.screen) : screens = [screen];

  final BibleData data;
  ReadingScreen screen;
  final List<ReadingScreen> screens;
  final readerKey = GlobalKey<ReaderScreenState>();
  final selections = <int>[];
  int persistCount = 0;
  int fallbackCalls = 0;
  String? breadcrumbAction;
  int _nextId = 2;

  ReaderScreenState get state => readerKey.currentState!;

  @override
  bool openChapter(int ch, {int? verse, bool inNewScreen = false}) {
    if (inNewScreen) {
      if (screens.length >= wwMaxScreens) {
        openChapter(ch, verse: verse);
        return false;
      }
      final created = ReadingScreen(
        id: _nextId++,
        bookIndex: data.chapters[ch].b,
        globalChapter: ch,
        anchorVerse: verse,
      );
      screens.add(created);
      screen = created;
      recordSelection(ch);
      persistScreens();
      final st = readerKey.currentState;
      if (st != null) {
        st.bindScreen(created);
        if (verse != null) st.landTo(ch, verse);
      }
      return true;
    }
    final s = screen;
    final book = data.chapters[ch].b;
    if (!s.bound) {
      s.bookIndex = book;
      s.globalChapter = ch;
      s.anchorVerse = verse;
    } else {
      final current = s.place;
      final target = (ch, verse);
      if (current != target) {
        if (s.history.isEmpty || s.history.last != current) {
          s.history.add(current);
        }
        if (book != s.bookIndex) s.bookIndex = book;
        s.globalChapter = ch;
        s.anchorVerse = verse;
      }
    }
    recordSelection(ch);
    persistScreens();
    readerKey.currentState?.landTo(ch, verse);
    return true;
  }

  @override
  void readerBackFallback() => fallbackCalls++;

  @override
  void persistScreens() => persistCount++;

  @override
  void recordSelection(int ch) => selections.add(ch);

  @override
  void breadcrumbLibrary() => breadcrumbAction = 'library';

  @override
  void breadcrumbTestament(int bookIndex) =>
      breadcrumbAction = 'testament:$bookIndex';

  @override
  void jumpToReference() => breadcrumbAction = 'jump';
}

/// Pumps a standalone paged reader for [startChapter] (with an
/// optional verse anchor, as a §6.4 restore would carry).
Future<TestReaderHost> pumpReader(
  WidgetTester tester, {
  required BibleData data,
  required ScriptureText texts,
  int startChapter = 0,
  int? anchorVerse,
  Size size = const Size(360, 800),
  double? textScale,
  bool disableAnimations = false,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final screen = ReadingScreen(
    id: 1,
    bookIndex: data.chapters[startChapter].b,
    globalChapter: startChapter,
    anchorVerse: anchorVerse,
  );
  final host = TestReaderHost(data, screen);
  await tester.pumpWidget(
    MaterialApp(
      theme: wwTheme(),
      builder: (context, child) {
        var mq = MediaQuery.of(context);
        if (textScale != null) {
          mq = mq.copyWith(textScaler: TextScaler.linear(textScale));
        }
        if (disableAnimations) {
          mq = mq.copyWith(disableAnimations: true);
        }
        return MediaQuery(data: mq, child: child!);
      },
      home: ReaderScreen(
        key: host.readerKey,
        data: data,
        screen: screen,
        host: host,
        textsLoader: () async => texts,
      ),
    ),
  );
  await settleReader(tester, host);
  return host;
}

/// Pumps until the reader is stable: post-frame landings may need
/// a frame or two after a pager rebuild before the verse contexts
/// exist, and the §4.2 landing animation runs 300ms. Stability =
/// the pager's page and the current page's in-page offset are
/// unchanged across two consecutive 100ms pumps (well inside the
/// 2.6s flash window, so flash assertions survive settling).
Future<void> settleReader(
  WidgetTester tester, [
  TestReaderHost? host,
]) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  if (host == null) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    return;
  }
  (double?, double?)? prev;
  var stableRuns = 0;
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    (double?, double?)? cur;
    try {
      final st = host.state;
      final page = st.pageController.hasClients
          ? st.pageController.page
          : null;
      final ctl = st.scrollControllerFor(st.currentChapter);
      final off = (ctl != null && ctl.hasClients) ? ctl.offset : null;
      cur = (page, off);
    } catch (_) {
      cur = null;
    }
    if (cur != null && cur == prev) {
      if (++stableRuns >= 2) break;
    } else {
      stableRuns = 0;
    }
    prev = cur;
  }
  await tester.pump();
}

/// The rendered rect of a verse block (its GlobalKey context).
Rect verseRect(WidgetTester tester, TestReaderHost host, int ch, int v) {
  final ctx = host.state.verseContext(ch, v)!;
  final box = ctx.findRenderObject()! as RenderBox;
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

/// The rendered rect of the open chapter page's viewport.
Rect pageViewportRect(WidgetTester tester, int ch) {
  final element = tester.element(
    find.byKey(ValueKey('chapterPage-$ch')),
  );
  final box = element.findRenderObject()! as RenderBox;
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

/// Whether a verse block currently carries the selected
/// construction (the 2dp outline on its Container).
bool verseSelected(WidgetTester tester, TestReaderHost host, int ch, int v) {
  final ctx = host.state.verseContext(ch, v);
  if (ctx == null) return false;
  var found = false;
  void visit(Element e) {
    if (e.widget is Container) {
      final c = e.widget as Container;
      final d = c.decoration;
      if (d is BoxDecoration && d.border != null) found = true;
    }
    e.visitChildren(visit);
  }

  ctx.visitChildElements(visit);
  // The key sits on the InkWell; its child Container carries the
  // outline. visitChildElements from the InkWell element reaches it.
  return found;
}

/// Scrolls the current chapter page in-page by [dy] (negative =
/// toward the chapter's end) and settles.
Future<void> scrollPage(
  WidgetTester tester,
  TestReaderHost host,
  double dy,
) async {
  final ctl = host.state.scrollControllerFor(host.state.currentChapter)!;
  final target = (ctl.offset + dy).clamp(0.0, ctl.position.maxScrollExtent);
  ctl.jumpTo(target);
  await tester.pump();
}
