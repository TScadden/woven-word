import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/scripture_text.dart';

import 'fake_canon.dart';
import 'shell_pump.dart';

/// §12 NAV / BACK / STORE groups for the shell, Library, and
/// Screens (board run 7 part B).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
  });

  Future<void> pump(WidgetTester tester, {Map<String, Object> prefs = const {}}) =>
      pumpShell(tester, data: data, texts: texts, prefs: prefs);

  group('NAV — navigation model', () {
    testWidgets('NAV-1 drill-down pushes and reader opens', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await tapTab(tester, 'Library');
      await tester.tap(find.text('Old Testament'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final bookGrid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (bookGrid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        39,
      );
      await tester.scrollUntilVisible(find.text('Psalms'), 200);
      await tester.tap(find.text('Psalms'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final chapterGrid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (chapterGrid.childrenDelegate as SliverChildBuilderDelegate)
            .childCount,
        150,
      );
      await tester.scrollUntilVisible(find.text('23'), 200);
      await tester.tap(find.text('23').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // The reader is open at Psalms 23 (top-bar breadcrumb title).
      expect(find.text('Psalms 23'), findsWidgets);
      expect(readerList(), findsOneWidget);
    });

    testWidgets('NAV-2 tab state preservation', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await drillToChapter(tester, data, data.books[42].start); // John 1
      // The Library stack stays drilled under the opened reader;
      // switching back to Library finds the chapter grid as left.
      await tapTab(tester, 'Library');
      expect(find.text('John'), findsWidgets); // chapter grid title
      await tapTab(tester, 'Home');
      expect(find.text('Continue reading'), findsOneWidget);
      await tapTab(tester, 'Library');
      expect(find.text('John'), findsWidgets);
    });

    testWidgets('NAV-3 re-tap pops to root, never touches others',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'Psalms 23'); // sets Home selection
      await tapTab(tester, 'Library');
      await tester.tap(find.text('Old Testament'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // Re-tap Library while drilled: pops to root.
      await tapTab(tester, 'Library');
      expect(find.text('39 books · 929 chapters'), findsOneWidget);
      expect(find.text('27 books · 260 chapters'), findsOneWidget);
      // Home selection survived re-taps.
      await tapTab(tester, 'Home');
      expect(find.text('Psalms 23'), findsWidgets);
      // The screen set is untouched: the reader is still open at
      // Psalms 23 on the Screens tab.
      await tapTab(tester, 'Screens');
      expect(readerList(), findsOneWidget);
      expect(find.text('Psalms 23'), findsWidgets);
    });

    testWidgets('NAV-4 badge truth at 1, 2, and the cap', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      Iterable<Element> badgeCandidates() => find
          .text('2')
          .evaluate()
          .where((e) => tester.getCenter(find.byWidget(e.widget)).dy > 700);
      expect(badgeCandidates(), isEmpty);
      await tapTab(tester, 'Screens');
      await tester.tap(find.widgetWithText(ElevatedButton, 'New screen'));
      await tester.pump();
      await tapTab(tester, 'Screens');
      expect(badgeCandidates(), isNotEmpty, reason: 'badge shows 2');
      // Create up to the cap of 5.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.widgetWithText(ElevatedButton, 'New screen'));
        await tester.pump();
        await tapTab(tester, 'Screens');
      }
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'New screen'),
      );
      expect(button.onPressed, isNull);
      expect(
        find.text('Five places is the limit. Close one to open another.'),
        findsOneWidget,
      );
      // Closing decrements.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      final button2 = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'New screen'),
      );
      expect(button2.onPressed, isNotNull);
    });

    testWidgets('NAV-5 breadcrumb from reader to testament grid',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'Psalms 23');
      // Tap the breadcrumb title in the reader top bar.
      final titleFinder = find.text('Psalms 23');
      final topTitle = titleFinder
          .evaluate()
          .map((e) => find.byWidget(e.widget))
          .where((f) => tester.getTopLeft(f).dy < 160)
          .first;
      await tester.tap(topTitle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Old Testament').last);
      await settleLanding(tester);
      // Library tab is at the OT book grid.
      expect(find.text('Genesis'), findsWidgets);
      // The reader's place is intact on its screen.
      await tapTab(tester, 'Screens');
      expect(find.text('Psalms 23'), findsWidgets);
      expect(readerList(), findsOneWidget);
    });
  });

  group('BACK — the §7.1 ladder', () {
    testWidgets('BACK-2/BACK-1 reader back: history then route pop',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'John 3'); // pushes Genesis 1 place
      // Top-bar back lands the pushed place (Genesis 1).
      await tester.tap(find.byTooltip('Back'));
      await settleLanding(tester);
      expect(find.text('Genesis 1'), findsWidgets);
      // History now empty: back pops to the Screens list.
      await tester.tap(find.byTooltip('Back'));
      await settleLanding(tester);
      expect(
        find.text('Places you are holding. Screens live on this device only.'),
        findsOneWidget,
      );
      // The screen's place is unchanged when reopened (BACK-2).
      await tester.tap(find.text('Genesis 1').last);
      await settleLanding(tester);
      expect(readerList(), findsOneWidget);
      expect(find.text('Genesis 1'), findsWidgets);
    });

    testWidgets('BACK-3 library and Home-stack pops', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await tapTab(tester, 'Library');
      await tester.tap(find.text('Old Testament'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('39 books · 929 chapters'), findsOneWidget);
      // Profiles (Home stack): system back pops to Home root.
      await tapTab(tester, 'Home');
      await tester.tap(find.byTooltip('Profiles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Profiles'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Woven Word'), findsOneWidget);
    });

    testWidgets('BACK-4 roots switch to Home; BACK-5 Home root exits',
        (tester) async {
      addTearDown(tester.view.reset);
      var popped = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemNavigator.pop') popped = true;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pump(tester);
      await tapTab(tester, 'Library');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Woven Word'), findsOneWidget, reason: 'Library root → Home');
      await tapTab(tester, 'Screens');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Woven Word'), findsOneWidget, reason: 'Screens root → Home');
      // Home root: the shell does not intercept — it exits.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(popped, isTrue, reason: 'SystemNavigator.pop requested');
    });

    testWidgets('BACK-6 dedupe: same-chapter open pushes nothing; '
        'A→B→A pushes exactly two', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      // The default screen is already at Genesis 1.
      await openViaSearch(tester, 'Genesis 1');
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Places you are holding. Screens live on this device only.'),
        findsOneWidget,
        reason: 'no history was pushed, so back popped the route',
      );
      // Chain: Genesis (reopen) → John 3 → Genesis 1 = two entries.
      await tester.tap(find.text('Genesis 1').last);
      await settleLanding(tester);
      await openViaSearch(tester, 'John 3');
      await openViaSearch(tester, 'Genesis 1');
      await tester.tap(find.byTooltip('Back'));
      await settleLanding(tester);
      expect(find.text('John 3'), findsWidgets, reason: 'first back → B');
      await tester.tap(find.byTooltip('Back'));
      await settleLanding(tester);
      expect(find.text('Genesis 1'), findsWidgets, reason: 'second back → A');
      await tester.tap(find.byTooltip('Back'));
      await settleLanding(tester);
      expect(
        find.text('Places you are holding. Screens live on this device only.'),
        findsOneWidget,
        reason: 'exactly two entries existed',
      );
    });
  });

  group('SCREENS — §6.3 close semantics', () {
    testWidgets('close button semantics label names the bound place',
        (tester) async {
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final psalms119 = data.books[18].start + 118;
      final screensDoc = jsonEncode({
        'active': 0,
        'screens': [
          {'book': 18, 'chapter': psalms119, 'anchor': 84},
          {'book': 0, 'chapter': data.books[0].start, 'anchor': null},
        ],
      });
      await pump(
        tester,
        prefs: {'ww_shell_tab': 'screens', 'ww_screens_v1': screensDoc},
      );
      expect(find.text('Psalms 119'), findsWidgets);
      // §6.3: the close button's semantics label names the place it
      // closes — not the bare tooltip label alone.
      expect(
        find.bySemanticsLabel('Close screen: Psalms 119'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Close screen: Genesis 1'),
        findsOneWidget,
      );
      // §6.1: the tooltip itself stays 'Close screen'.
      expect(find.byTooltip('Close screen'), findsNWidgets(2));
      semantics.dispose();
    });
  });

  group('STORE — persistence and search', () {
    testWidgets('STORE-3 relaunch restores tab, screens, '
        'translation; scope and retired selection keys removed',
        (tester) async {
      addTearDown(tester.view.reset);
      final psalms119 = data.books[18].start + 118;
      final screensDoc = jsonEncode({
        'active': 0,
        'screens': [
          {'book': 18, 'chapter': psalms119, 'anchor': 84, 'offset': 0.0, 'sig': null},
        ],
      });
      await pump(
        tester,
        prefs: {
          'ww_shell_tab': 'screens',
          'ww_home_selected': psalms119,
          'ww_translation': 'WEB',
          'ww_home_scope': 'ot',
          'ww_screens_v1': screensDoc,
        },
      );
      // Active tab restored: Screens list shows the held place.
      expect(find.text('Psalms 119'), findsWidgets);
      expect(find.text('verse 84'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ww_home_scope'), isNull);
      expect(prefs.getString('ww_translation'), 'WEB');
      // HOME ARCH GOES AMBIENT translation (lesson 40): the
      // shipped "Home selection restored" assertion landmarked
      // the selection panel's exact chapter title — the panel
      // and the ww_home_selected restore are RETIRED by the
      // founder ruling. The landmark now asserts the retirement
      // itself: the seeded key is removed on load, and Home
      // shows no panel for the seeded place (Continue reading's
      // subtitle is the longer 'Psalms 119 · verse 84' string,
      // never the panel's exact title).
      expect(prefs.getInt('ww_home_selected'), isNull);
      await tapTab(tester, 'Home');
      expect(find.text('Psalms 119'), findsNothing);
      expect(find.text('Connected chapters'), findsNothing);
      expect(find.text('Psalms 119 · verse 84'), findsOneWidget);
      // Translation restored in the reader (WEB verse text).
      await tapTab(tester, 'Screens');
      await tester.tap(find.text('Psalms 119').last);
      await settleLanding(tester);
      expect(find.textContaining('WEB Psalms 119:84'), findsWidgets);
    });

    testWidgets('STORE-3 corrupt screens doc yields the default set',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester, prefs: {'ww_screens_v1': 'not json {'});
      await tapTab(tester, 'Screens');
      expect(find.text('Genesis 1'), findsWidgets);
      expect(find.text('at chapter start'), findsOneWidget);
    });

    testWidgets('STORE-4 search: match, bare book, no-match line',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await tapTab(tester, 'Library');
      await tester.enterText(find.byType(TextField).first, 'gibberish xyz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(
        find.text('No match — try a book name and chapter, like John 3.'),
        findsOneWidget,
      );
      expect(readerList(), findsNothing, reason: 'navigated nowhere');
      await openViaSearch(tester, 'Genesis');
      expect(find.text('Genesis 1'), findsWidgets);
      await openViaSearch(tester, 'John 3');
      expect(find.text('John 3'), findsWidgets);
    });
  });
}
