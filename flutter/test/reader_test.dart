import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/screen_state.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/user_data.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// §12 READ group (R-T1–R-T12) for the paged reader, as amended by
/// Amendment A, plus the reader-side BACK rungs and RM coverage.
/// All geometry is asserted on rendered rects — no offset model
/// exists to assert against (§4.2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
  });

  int g(int book, int chapterInBook) =>
      data.books[book].start + chapterInBook - 1;
  String verseText(String tag, int ch, int v) =>
      '$tag ${data.chapterName(ch)}:$v ';
  Finder inPage(int ch, Finder matching) =>
      find.descendant(of: chapterPage(ch), matching: matching);
  Finder verseBlocks(int ch) => find.descendant(
    of: chapterPage(ch),
    matching: find.byWidgetPredicate(
      (w) => w is InkWell && w.key is GlobalKey,
    ),
  );
  int pageCount(WidgetTester tester) =>
      (tester.widget<PageView>(find.byType(PageView)).childrenDelegate
              as SliverChildBuilderDelegate)
          .childCount!;
  Finder topBarText(String t) => find.descendant(
    of: find.byKey(const ValueKey('readerTopBar')),
    matching: find.text(t),
  );

  group('READ — paged reader (Amendment A)', () {
    testWidgets('R-T1 page truth: Genesis, both translations', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final genesis = data.books[0];
      expect(
        pageCount(tester),
        genesis.chapters,
      );
      // Chapter 1's page: label block + exactly its verses.
      expect(inPage(0, find.text('Genesis 1')), findsOneWidget);
      expect(
        inPage(
          0,
          find.text(
            '${data.chapters[0].v} verses · '
            '${data.chapterConnCount[0]} connections',
          ),
        ),
        findsOneWidget,
      );
      for (var v = 1; v <= data.chapters[0].v; v++) {
        expect(
          inPage(0, find.textContaining(verseText('KJV', 0, v))),
          findsOneWidget,
          reason: 'Genesis 1:$v on its own page',
        );
      }
      // The next chapter's first verse is absent from this page.
      expect(
        inPage(0, find.textContaining(verseText('KJV', 1, 1))),
        findsNothing,
      );
      // A mid page and the last page tell the same truth.
      host.state.landTo(g(0, 25), null);
      await settleReader(tester, host);
      expect(inPage(g(0, 25), find.text('Genesis 25')), findsOneWidget);
      expect(
        inPage(g(0, 25), find.textContaining(verseText('KJV', g(0, 25), 1))),
        findsOneWidget,
      );
      expect(
        inPage(g(0, 25), find.textContaining(verseText('KJV', g(0, 26), 1))),
        findsNothing,
      );
      host.state.landTo(g(0, 50), null);
      await settleReader(tester, host);
      expect(
        inPage(g(0, 50), find.textContaining(verseText('KJV', g(0, 50), 10))),
        findsOneWidget,
      );
      // WEB: same page count, the page's content in WEB.
      await tester.tap(find.text('WEB'));
      await settleReader(tester, host);
      expect(
        pageCount(tester),
        genesis.chapters,
      );
      expect(
        inPage(g(0, 50), find.textContaining(verseText('WEB', g(0, 50), 1))),
        findsOneWidget,
      );
      expect(
        inPage(g(0, 50), find.textContaining(verseText('KJV', g(0, 50), 1))),
        findsNothing,
      );
      expect(host.state.currentChapter, g(0, 50));
    });

    testWidgets('R-T1 page truth: Ruth (short book) and Psalms', (
      tester,
    ) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: g(7, 1), // Ruth 1
      );
      expect(
        pageCount(tester),
        data.books[7].chapters, // 4
      );
      for (var c = 1; c <= 4; c++) {
        host.state.landTo(g(7, c), null);
        await settleReader(tester, host);
        expect(
          inPage(g(7, c), find.text('Ruth $c')),
          findsOneWidget,
        );
        expect(
          verseBlocks(g(7, c)).evaluate().length,
          data.chapters[g(7, c)].v,
          reason: 'Ruth $c builds exactly its verses',
        );
      }
      // Psalms: 150 pages; Psalms 119's page builds all 176 verses.
      host.openChapter(g(18, 119));
      await settleReader(tester, host);
      expect(
        pageCount(tester),
        150,
      );
      expect(verseBlocks(g(18, 119)).evaluate().length, 176);
      expect(
        inPage(
          g(18, 119),
          find.textContaining(verseText('KJV', g(18, 119), 176)),
        ),
        findsOneWidget,
      );
      expect(
        inPage(
          g(18, 119),
          find.textContaining(verseText('KJV', g(18, 120), 1)),
        ),
        findsNothing,
      );
    });

    testWidgets('R-T2 verse landing: rendered-rect post-condition; '
        'chapter landing at page top', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = g(18, 119);
      host.openChapter(ps119, verse: 84);
      await settleReader(tester, host);
      expect(host.state.currentChapter, ps119);
      final vp = pageViewportRect(tester, ps119);
      final vr = verseRect(tester, host, ps119, 84);
      expect(vr.top >= vp.top - 0.5, isTrue, reason: 'verse fully in page');
      expect(vr.bottom <= vp.bottom + 0.5, isTrue);
      // ensureVisible alignment 0.5, computed from rendered rects.
      final fraction = (vr.top - vp.top) / (vp.height - vr.height);
      expect(fraction, closeTo(0.5, 0.06));
      // Last verse of a book's last chapter lands fully visible.
      final gen50 = g(0, 50);
      host.openChapter(gen50, verse: 10);
      await settleReader(tester, host);
      final vp2 = pageViewportRect(tester, gen50);
      final vr2 = verseRect(tester, host, gen50, 10);
      expect(vr2.top >= vp2.top - 0.5, isTrue);
      expect(vr2.bottom <= vp2.bottom + 0.5, isTrue);
      // Chapter landing: target page at in-page offset 0, label at top.
      host.openChapter(g(0, 30));
      await settleReader(tester, host);
      final ctl = host.state.scrollControllerFor(g(0, 30))!;
      expect(ctl.offset, 0);
      final labelRect = tester.getRect(
        inPage(g(0, 30), find.text('Genesis 30')),
      );
      expect(labelRect.top, closeTo(pageViewportRect(tester, g(0, 30)).top + 16, 1.5));
    });

    testWidgets('R-T3 cold jump: Psalms 119 v1 and v176 as first actions',
        (tester) async {
      final ps119 = g(18, 119);
      var host = await pumpReader(tester, data: data, texts: texts);
      expect(host.state.currentChapter, 0, reason: 'initial page is Genesis 1');
      host.openChapter(ps119, verse: 1);
      await settleReader(tester, host);
      expect(host.state.currentChapter, ps119);
      expect(host.state.pageController.page, 118);
      final vp = pageViewportRect(tester, ps119);
      final vr = verseRect(tester, host, ps119, 1);
      expect(vr.top >= vp.top - 0.5 && vr.bottom <= vp.bottom + 0.5, isTrue);

      host = await pumpReader(tester, data: data, texts: texts);
      host.openChapter(ps119, verse: 176);
      await settleReader(tester, host);
      expect(host.state.currentChapter, ps119);
      final vp2 = pageViewportRect(tester, ps119);
      final vr2 = verseRect(tester, host, ps119, 176);
      expect(vr2.top >= vp2.top - 0.5 && vr2.bottom <= vp2.bottom + 0.5, isTrue);
    });

    testWidgets('R-T4 mechanism cross-check: repeat ensureVisible moves '
        'the page by at most 0.5dp', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = g(18, 119);
      // Build (and let the geometry of) the target page first.
      host.openChapter(ps119);
      await settleReader(tester, host);
      host.openChapter(ps119, verse: 84);
      await settleReader(tester, host);
      final ctl = host.state.scrollControllerFor(ps119)!;
      final before = ctl.offset;
      await host.state.debugEnsureVisible(ps119, 84);
      await tester.pump();
      expect((ctl.offset - before).abs(), lessThanOrEqualTo(0.5));
    });

    testWidgets('R-T5 reduced motion: landing final after one pump; '
        'button turn instant', (tester) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        disableAnimations: true,
      );
      final ps119 = g(18, 119);
      host.openChapter(ps119, verse: 84);
      // Post-frame landing + zero-duration in-page scroll.
      await tester.pump();
      await tester.pump();
      expect(host.state.currentChapter, ps119);
      final vp = pageViewportRect(tester, ps119);
      final vr = verseRect(tester, host, ps119, 84);
      expect(vr.top >= vp.top - 0.5 && vr.bottom <= vp.bottom + 0.5, isTrue);
      final ctl = host.state.scrollControllerFor(ps119)!;
      final settled = ctl.offset;
      await tester.pump(const Duration(milliseconds: 300));
      expect(ctl.offset, settled, reason: 'no tween is pending');
      // A §4.6 button turn is instant under reduced motion.
      host.openChapter(g(0, 1));
      await settleReader(tester, host);
      await tester.tap(
        find.descendant(
          of: chapterPage(0),
          matching: find.byTooltip('Next chapter'),
        ),
      );
      await tester.pump();
      expect(host.state.currentChapter, 1);
      expect(host.state.pageController.page, 1);
    });

    testWidgets('R-T6 motion is real: button turn animates; a commanded '
        'jump never renders an intermediate page', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tester.tap(
        find.descendant(
          of: chapterPage(0),
          matching: find.byTooltip('Next chapter'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = host.state.pageController.page!;
      expect(mid > 0 && mid < 1, isTrue, reason: 'turn is mid-flight');
      await settleReader(tester, host);
      expect(host.state.pageController.page, 1);
      expect(host.state.currentChapter, 1);
      // Commanded jump Genesis 2 -> Genesis 40: no intermediate
      // chapter's page exists at any sampled moment.
      host.openChapter(g(0, 40));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(chapterPage(g(0, 20)).evaluate(), isEmpty);
        expect(chapterPage(g(0, 39)).evaluate(), isEmpty);
      }
      await settleReader(tester, host);
      expect(host.state.currentChapter, g(0, 40));
    });

    testWidgets('R-T7 second geometry: 400 wide, scale 1.3', (tester) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        size: const Size(400, 800),
        textScale: 1.3,
      );
      expect(
        pageCount(tester),
        50,
      );
      final ps119 = g(18, 119);
      host.openChapter(ps119, verse: 84);
      await settleReader(tester, host);
      expect(verseBlocks(ps119).evaluate().length, 176);
      final vp = pageViewportRect(tester, ps119);
      final vr = verseRect(tester, host, ps119, 84);
      expect(vr.top >= vp.top - 0.5 && vr.bottom <= vp.bottom + 0.5, isTrue);
      final fraction = (vr.top - vp.top) / (vp.height - vr.height);
      expect(fraction, closeTo(0.5, 0.08));
    });

    testWidgets('R-T8 current-chapter truth: in-page scroll never renames '
        'the bar; turns do; a returned drag does not', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = g(18, 119);
      host.openChapter(ps119);
      await settleReader(tester, host);
      expect(topBarText('Psalms 119'), findsOneWidget);
      // Scroll the long chapter from first verse to its end.
      final ctl = host.state.scrollControllerFor(ps119)!;
      ctl.jumpTo(ctl.position.maxScrollExtent);
      await tester.pump();
      expect(host.state.currentChapter, ps119);
      expect(topBarText('Psalms 119'), findsOneWidget);
      ctl.jumpTo(0);
      await tester.pump();
      // A page turn renames the bar and the breadcrumb's level.
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, ps119 + 1);
      expect(topBarText('Psalms 120'), findsOneWidget);
      // A drag past the midpoint and back leaves the original name.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      // (Touch slop consumes roughly the first step of travel.)
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump();
      }
      expect(host.state.pageController.page, greaterThan(119.5),
          reason: 'the drag crossed the midpoint');
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump();
      }
      await gesture.up();
      await settleReader(tester, host);
      expect(host.state.currentChapter, ps119 + 1);
      expect(topBarText('Psalms 120'), findsOneWidget);
    });

    testWidgets('R-T9 flash discipline', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = g(18, 119);
      // Programmatic verse landing flashes.
      host.openChapter(ps119, verse: 84);
      await settleReader(tester, host);
      expect(verseSelected(tester, host, ps119, 84), isTrue);
      // Passive in-page scrolling flashes nothing.
      host.openChapter(g(0, 1));
      await settleReader(tester, host);
      await scrollPage(tester, host, 500);
      expect(verseSelected(tester, host, 0, 5), isFalse);
      // A page turn flashes nothing.
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 1);
      expect(verseSelected(tester, host, 1, 1), isFalse);
      // A chapter landing flashes nothing.
      host.openChapter(g(0, 10));
      await settleReader(tester, host);
      expect(verseSelected(tester, host, g(0, 10), 1), isFalse);
      // A landing on an already-visible verse flashes in place,
      // without scrolling.
      final ctl = host.state.scrollControllerFor(g(0, 10))!;
      expect(ctl.offset, 0);
      host.state.landTo(g(0, 10), 1);
      await settleReader(tester, host);
      expect(ctl.offset, 0);
      expect(verseSelected(tester, host, g(0, 10), 1), isTrue);
    });

    testWidgets('R-T10 turns and boundaries', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      // Swipe turns forward and back.
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 1);
      await tester.fling(find.byType(PageView), const Offset(200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 0);
      // At the first chapter, a right swipe turns nothing; the
      // Previous button is disabled there.
      await tester.fling(find.byType(PageView), const Offset(200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 0);
      final prevBtn = tester.widget<IconButton>(
        find.descendant(
          of: chapterPage(0),
          matching: find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Previous chapter',
          ),
        ),
      );
      expect(prevBtn.onPressed, isNull);
      // Label-block Next turns the page.
      await tester.tap(
        find.descendant(
          of: chapterPage(0),
          matching: find.byTooltip('Next chapter'),
        ),
      );
      await settleReader(tester, host);
      expect(host.state.currentChapter, 1);
      // Scrolling to a chapter's end stops: the next chapter never
      // rolls in, continued dragging changes no chapter.
      final ps119 = g(18, 119);
      host.openChapter(ps119);
      await settleReader(tester, host);
      final ctl = host.state.scrollControllerFor(ps119)!;
      ctl.jumpTo(ctl.position.maxScrollExtent);
      await tester.pump();
      await tester.drag(
        find.byKey(ValueKey('chapterPage-$ps119')),
        const Offset(0, -300),
      );
      await tester.pump();
      expect(host.state.currentChapter, ps119);
      expect(
        inPage(ps119, find.text('Psalms 120')),
        findsNothing,
      );
      // A vertical drag scrolls in-page and turns nothing.
      ctl.jumpTo(0);
      await tester.pump();
      await tester.drag(
        find.byKey(ValueKey('chapterPage-$ps119')),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(ctl.offset > 0, isTrue);
      expect(host.state.currentChapter, ps119);
      // The last chapter's page: swipe and Next both stop.
      final gen50 = g(0, 50);
      host.openChapter(gen50);
      await settleReader(tester, host);
      final nextBtn = tester.widget<IconButton>(
        find.descendant(
          of: chapterPage(gen50),
          matching: find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Next chapter',
          ),
        ),
      );
      expect(nextBtn.onPressed, isNull);
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, gen50);
      // End-of-book block: Genesis 50 offers Exodus 1; tapping swaps
      // the page set with a history push.
      final ctl50 = host.state.scrollControllerFor(gen50)!;
      ctl50.jumpTo(ctl50.position.maxScrollExtent);
      await tester.pump();
      expect(
        inPage(gen50, find.text('End of Genesis')),
        findsOneWidget,
      );
      final historyBefore = host.screen.history.length;
      await tester.tap(
        inPage(gen50, find.widgetWithText(ElevatedButton, 'Open Exodus 1')),
      );
      await settleReader(tester, host);
      expect(host.state.currentChapter, g(1, 1));
      expect(
        pageCount(tester),
        data.books[1].chapters,
      );
      expect(host.screen.history.length, historyBefore + 1);
      // Revelation 22: nothing beyond; no next-book button.
      final rev22 = g(65, 22);
      host.openChapter(rev22);
      await settleReader(tester, host);
      final ctlRev = host.state.scrollControllerFor(rev22)!;
      ctlRev.jumpTo(ctlRev.position.maxScrollExtent);
      await tester.pump();
      expect(inPage(rev22, find.text('End of Revelation')), findsOneWidget);
      expect(
        inPage(rev22, find.text('The last book of the Bible.')),
        findsOneWidget,
      );
      expect(
        inPage(rev22, find.byType(ElevatedButton)),
        findsNothing,
      );
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, rev22);
    });

    testWidgets('R-T11 chrome: the top bar never hides', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = g(18, 119);
      host.openChapter(ps119);
      await settleReader(tester, host);
      final ctl = host.state.scrollControllerFor(ps119)!;
      ctl.jumpTo(ctl.position.maxScrollExtent);
      await tester.pump();
      var bar = tester.getSize(find.byKey(const ValueKey('readerTopBar')));
      expect(bar.height, 49);
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      bar = tester.getSize(find.byKey(const ValueKey('readerTopBar')));
      expect(bar.height, 49);
      await tester.fling(find.byType(PageView), const Offset(200, 0), 1000);
      await settleReader(tester, host);
      bar = tester.getSize(find.byKey(const ValueKey('readerTopBar')));
      expect(bar.height, 49);
    });

    testWidgets('R-T11 chrome under reduced motion', (tester) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        disableAnimations: true,
      );
      final ps119 = g(18, 119);
      host.openChapter(ps119);
      await settleReader(tester, host);
      final ctl = host.state.scrollControllerFor(ps119)!;
      ctl.jumpTo(ctl.position.maxScrollExtent);
      await tester.pump();
      final bar = tester.getSize(find.byKey(const ValueKey('readerTopBar')));
      expect(bar.height, 49);
    });

    testWidgets('R-T12 translation switch stays on the page', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = g(18, 119);
      // With a verse anchor: re-anchors in-page, no flash.
      host.openChapter(ps119, verse: 84);
      await settleReader(tester, host);
      // Expire the landing's 2.6s flash first: any selection after
      // the switch would be the switch's own doing.
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pump();
      expect(verseSelected(tester, host, ps119, 84), isFalse);
      await tester.tap(find.text('WEB'));
      await settleReader(tester, host);
      expect(host.state.currentChapter, ps119);
      expect(
        inPage(ps119, find.textContaining(verseText('WEB', ps119, 84))),
        findsOneWidget,
      );
      final vp = pageViewportRect(tester, ps119);
      final vr = verseRect(tester, host, ps119, 84);
      expect(vr.top >= vp.top - 0.5 && vr.bottom <= vp.bottom + 0.5, isTrue);
      expect(verseSelected(tester, host, ps119, 84), isFalse,
          reason: 'a translation switch never flashes');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ww_translation'), 'WEB');
      // Without an anchor: the page returns to its top.
      host.openChapter(g(0, 1));
      await settleReader(tester, host);
      await scrollPage(tester, host, 300);
      final ctl = host.state.scrollControllerFor(0)!;
      expect(ctl.offset > 0, isTrue);
      await tester.tap(find.text('KJV'));
      await settleReader(tester, host);
      expect(host.state.currentChapter, 0);
      expect(ctl.offset, 0);
      expect(prefs.getString('ww_translation'), 'KJV');
    });
  });

  group('BACK — reader rungs (conformed)', () {
    testWidgets('BACK-1 cross-book history entry swaps the page set',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final john1 = g(42, 1);
      host.openChapter(john1, verse: 1); // pushes Genesis 1 place
      await settleReader(tester, host);
      expect(host.state.currentChapter, john1);
      expect(
        pageCount(tester),
        data.books[42].chapters,
      );
      expect(host.state.handlePriorityBack(), isTrue);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 0);
      expect(
        pageCount(tester),
        data.books[0].chapters,
      );
      // A verse entry flashes on landing.
      host.openChapter(john1, verse: 1);
      await settleReader(tester, host);
      expect(host.state.handlePriorityBack(), isTrue);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 0);
    });

    testWidgets('STORE-3 legacy shape: offset/sig fields restore by '
        'page + anchor and apply no offset', (tester) async {
      final ps119 = g(18, 119);
      final (screens, active) = parseWwScreens(
        '{"active":0,"screens":[{"book":18,"chapter":$ps119,'
        '"anchor":84,"offset":4321.0,"sig":"360.0|1.0|KJV"}]}',
        data,
      );
      expect(screens.length, 1);
      expect(screens[0].globalChapter, ps119);
      expect(screens[0].anchorVerse, 84);
      // The serialized shape carries no offset/signature keys.
      final out = serializeWwScreens(screens, active);
      expect(out.contains('offset'), isFalse);
      expect(out.contains('sig'), isFalse);
      // Restoring that screen lands on the anchor in-page.
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: ps119,
        anchorVerse: 84,
      );
      final vp = pageViewportRect(tester, ps119);
      final vr = verseRect(tester, host, ps119, 84);
      expect(vr.top >= vp.top - 0.5 && vr.bottom <= vp.bottom + 0.5, isTrue);
      expect(verseSelected(tester, host, ps119, 84), isFalse,
          reason: 'a restore never flashes');
    });

    testWidgets('STORE-2 profile switching changes the reader marks '
        'for the same verse', (tester) async {
      // Seed a store whose second profile — not the default — has
      // a Gold highlight on Genesis 1:1.
      UserData docWith(String activeId) {
        final doc = UserData();
        final p2 = doc.createProfile('Second');
        doc.setHighlight(p2, verseKey(0, 1, 1), HlColor.gold);
        doc.setActiveProfile(activeId == 'p2' ? p2 : 'default');
        return doc;
      }

      String seed(UserData doc) => jsonEncode(doc.toJson());

      // Active = p2: the toolbar reads Gold as the active slot.
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {'ww_user_data': seed(docWith('p2'))},
      );
      await tester.tap(
        inPage(0, find.textContaining(verseText('KJV', 0, 1))),
      );
      await settleReader(tester);
      var goldNode = tester.getSemantics(find.bySemanticsLabel('Gold highlight'));
      expect(goldNode.flagsCollection.isSelected == ui.Tristate.isTrue, isTrue,
          reason: 'p2 sees its own Gold highlight active');
      // Switch the resolved active profile to default and reload:
      // the same verse shows None active — p2's mark never leaks.
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {'ww_user_data': seed(docWith('default'))},
      );
      await tester.tap(
        inPage(0, find.textContaining(verseText('KJV', 0, 1))),
      );
      await settleReader(tester);
      goldNode = tester.getSemantics(find.bySemanticsLabel('Gold highlight'));
      expect(goldNode.flagsCollection.isSelected == ui.Tristate.isTrue, isFalse);
      final noneNode = tester.getSemantics(find.bySemanticsLabel('None highlight'));
      expect(noneNode.flagsCollection.isSelected == ui.Tristate.isTrue, isTrue);
    });
  });

  group('RM — reduced motion surfaces', () {
    testWidgets('connections sheet renders instantly under '
        'disableAnimations', (tester) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        disableAnimations: true,
      );
      await tester.tap(
        inPage(0, find.textContaining(verseText('KJV', 0, 1))),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Connections · 3'));
      await tester.pump();
      expect(find.text('Psalms 119:1'), findsOneWidget);
      expect(host.state.currentChapter, 0);
    });

    testWidgets('a dialog renders instantly under disableAnimations',
        (tester) async {
      await pumpShell(
        tester,
        data: data,
        texts: texts,
        disableAnimations: true,
      );
      // Home top-bar profile chip → Profiles → New profile dialog.
      await tester.tap(find.byTooltip('Profiles'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('New profile'));
      await tester.pump();
      expect(find.text('Create'), findsOneWidget);
    });
  });
}
