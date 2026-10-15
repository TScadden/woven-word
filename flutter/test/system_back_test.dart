import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/shell_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'shell_pump.dart';

/// Run-8 fix round, Item 4 — SYSTEM back (gesture or button) must
/// drive the shell's back priority ladder (§7.1) instead of
/// bubbling out to the OS. Every test here simulates the system
/// back route itself (`tester.binding.handlePopRoute()`, the same
/// entry the platform back event takes), never the in-app Back
/// buttons and never a direct handlePriorityBack() call:
///
///   rung 1 — toolbar / sheet / note editor / dialog dismisses;
///   rung 2 — reader jump history steps back;
///   rung 3 — the active tab's stack pops one level;
///   rung 4 — a non-Home tab root switches to Home;
///   rung 5 — Home root only: the exit is finally requested.
///
/// Audit note (probes run on the pre-fix tree, 2026-10-14): the
/// ladder itself already fired correctly from every reader and
/// tab state probed — the child navigators do NOT swallow the
/// system route around the shell's PopScope on this SDK. The one
/// escape the audit found was a modal-lifetime bug: dismissing
/// the Profiles name dialog threw "TextEditingController used
/// after being disposed" (its controller was disposed from the
/// dialog future's whenComplete while the exit transition still
/// built the field). The dialog and the My Notes editor sheet
/// now own their controllers; the dialog cases below are the
/// regression tests (they failed with that exception pre-fix).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
  });

  Future<void> pump(WidgetTester tester) =>
      pumpShell(tester, data: data, texts: texts);

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settleLanding(tester);
  }

  Future<void> tapVerseInPage(
    WidgetTester tester,
    int globalChapter,
    String verseTextPrefix,
  ) async {
    await tester.tap(
      find.descendant(
        of: chapterPage(globalChapter),
        matching: find.textContaining(verseTextPrefix),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('rung 1 — dismissible state inside the reader', () {
    testWidgets('toolbar open: back dismisses the toolbar only; '
        'history is NOT consumed until the next back', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'John 3'); // history: Genesis 1
      final john3 = data.books[42].start + 2;
      await tapVerseInPage(tester, john3, 'KJV John 3:1 ');
      expect(find.textContaining('Connections ·'), findsWidgets);
      await systemBack(tester);
      // Toolbar gone, still in the reader at John 3.
      expect(find.textContaining('Connections ·'), findsNothing);
      expect(readerList(), findsOneWidget);
      expect(find.text('John 3'), findsWidgets);
      // The NEXT back consumes the history rung.
      await systemBack(tester);
      expect(readerList(), findsOneWidget);
      expect(find.text('Genesis 1'), findsWidgets);
    });

    testWidgets('connections sheet open: back closes the sheet '
        'only', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'Genesis 1');
      await tapVerseInPage(tester, 0, 'KJV Genesis 1:1 ');
      await tester.tap(find.textContaining('Connections ·'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Psalms 119:1'), findsOneWidget);
      await systemBack(tester);
      expect(find.text('Psalms 119:1'), findsNothing);
      expect(readerList(), findsOneWidget);
      expect(find.text('Genesis 1'), findsWidgets);
    });

    testWidgets('note editor open: back returns to the toolbar '
        'action view, unsaved', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'Genesis 1');
      await tapVerseInPage(tester, 0, 'KJV Genesis 1:1 ');
      await tester.tap(find.text('Add note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'unsaved draft');
      await systemBack(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Add note'), findsOneWidget);
      expect(readerList(), findsOneWidget);
    });
  });

  group('rung 1 — modal dialogs dismiss cleanly', () {
    Future<void> openNameDialog(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Profiles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('New profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsOneWidget);
    }

    testWidgets('system back dismisses the name dialog, stays on '
        'Profiles, and throws nothing (Item 4 regression)',
        (tester) async {
      addTearDown(tester.view.reset);
      await openNameDialog(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsNothing);
      expect(find.text('New profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel dismisses the name dialog and throws '
        'nothing (the bug was dismissal-path independent)',
        (tester) async {
      addTearDown(tester.view.reset);
      await openNameDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TextField), findsNothing);
      expect(find.text('New profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('rung 2 — reader jump history', () {
    testWidgets('back steps to the previous chapter and the '
        'reader stays open', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await openViaSearch(tester, 'John 3');
      expect(find.text('John 3'), findsWidgets);
      await systemBack(tester);
      expect(readerList(), findsOneWidget);
      expect(find.text('Genesis 1'), findsWidgets);
    });
  });

  group('rung 3 — the active tab stack pops one level', () {
    testWidgets('Library book grid pops to the Library root',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await tapTab(tester, 'Library');
      await tester.tap(find.text('Old Testament'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await systemBack(tester);
      expect(find.text('39 books · 929 chapters'), findsOneWidget);
      expect(find.text('27 books · 260 chapters'), findsOneWidget);
    });

    testWidgets('reader with no history pops its route to the '
        'Screens list', (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);
      await tapTab(tester, 'Screens');
      await tester.tap(find.text('Genesis 1').last);
      await settleLanding(tester);
      expect(readerList(), findsOneWidget);
      await systemBack(tester);
      expect(readerList(), findsNothing);
      expect(
        find.text(
          'Places you are holding. Screens live on this device only.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('conference talk view pops one level at a time '
        'down the browse stack', (tester) async {
      addTearDown(tester.view.reset);
      final fixture = File(
        'test/fixtures/conference_fixture.json',
      ).readAsStringSync();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      SharedPreferences.setMockInitialValues(const {
        'ww_conference_layer': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: WwShell(
            dataLoader: () async => data,
            textsLoader: () async => texts,
            conferenceLoader: (canon) async =>
                ConferenceData.fromCanon(fixture, canon),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tapTab(tester, 'Library');
      await tester.tap(find.text('General Conference'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('October 2024'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.textContaining('The Words of Christ').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Scriptures cited'), findsOneWidget);
      // Talk view → talks list.
      await systemBack(tester);
      expect(find.text('Scriptures cited'), findsNothing);
      expect(
        find.textContaining('The Words of Christ'),
        findsOneWidget,
      );
      // Talks list → conferences list.
      await systemBack(tester);
      expect(
        find.text(
          'Newest first. Talk counts include only talks that cite '
          'the Bible.',
        ),
        findsOneWidget,
      );
      // Conferences list → Library root.
      await systemBack(tester);
      expect(find.text('39 books · 929 chapters'), findsOneWidget);
    });
  });

  group('rungs 4 and 5 — tab roots and the exit', () {
    testWidgets('Library and Screens roots switch to Home; the '
        'Home root finally requests the exit', (tester) async {
      addTearDown(tester.view.reset);
      var exitRequested = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemNavigator.pop') {
              exitRequested = true;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pump(tester);
      await tapTab(tester, 'Library');
      await systemBack(tester);
      expect(find.text('STUDY'), findsOneWidget, reason: 'rung 4');
      expect(exitRequested, isFalse);
      await tapTab(tester, 'Screens');
      await systemBack(tester);
      expect(find.text('STUDY'), findsOneWidget, reason: 'rung 4');
      expect(exitRequested, isFalse);
      // Home root: nothing above applies — the guard releases by
      // requesting the platform exit, exactly once here.
      await systemBack(tester);
      expect(exitRequested, isTrue, reason: 'rung 5');
      expect(find.text('STUDY'), findsOneWidget);
    });
  });
}
