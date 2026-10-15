import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/user_data.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// §12 TOOL group (TOOL-1–TOOL-8) and BACK-0: the verse toolbar
/// (§5) re-homed onto the paged reader, its contract unchanged
/// (Amendment A, gate item 16).
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
  String vt(int ch, int v) => 'KJV ${data.chapterName(ch)}:$v ';
  Finder inPage(int ch, Finder matching) =>
      find.descendant(of: chapterPage(ch), matching: matching);

  Future<void> tapVerse(
    WidgetTester tester,
    TestReaderHost host,
    int ch,
    int v,
  ) async {
    // Bring the verse on screen first (a user scrolls to a verse
    // before tapping it; off-screen centers cannot be tapped).
    final ctx = host.state.verseContext(ch, v);
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, duration: Duration.zero);
      await tester.pump();
    }
    await tester.tap(inPage(ch, find.textContaining(vt(ch, v))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  bool slotSelected(WidgetTester tester, String label) => tester
      .getSemantics(find.bySemanticsLabel(label))
      .flagsCollection.isSelected == ui.Tristate.isTrue;

  Future<UserData> storedData() async {
    final prefs = await SharedPreferences.getInstance();
    final store = await UserDataStore.load(prefs);
    return store.data;
  }

  group('TOOL — verse toolbar', () {
    testWidgets('TOOL-1 one tap raises the toolbar for that verse',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      // Header ref, all six slots, Note, Connections with true count.
      expect(find.text('Genesis 1:1'), findsOneWidget);
      for (final label in [
        'Gold highlight',
        'Green highlight',
        'Blue highlight',
        'Pink highlight',
        'Purple highlight',
        'None highlight',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Connections · 3'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      // No highlight yet: None is the one active slot.
      expect(slotSelected(tester, 'None highlight'), isTrue);
      expect(slotSelected(tester, 'Gold highlight'), isFalse);
      // The verse carries the selected construction.
      expect(verseSelected(tester, host, 0, 1), isTrue);
    });

    testWidgets('TOOL-2 placement: card on screen, verse first line '
        'never covered', (tester) async {
      Future<void> checkCase(
        WidgetTester tester,
        TestReaderHost host,
        int ch,
        int v,
      ) async {
        await tapVerse(tester, host, ch, v);
        // The toolbar card is the overlay Positioned's child.
        final cardFinder = find.byWidgetPredicate(
          (w) => w is Positioned && w.child is Container,
        );
        expect(cardFinder, findsOneWidget);
        final cardRect = tester.getRect(cardFinder);
        // Fully on screen (360x800 test viewport, 16dp margins).
        expect(cardRect.left, greaterThanOrEqualTo(16 - 0.5));
        expect(cardRect.right, lessThanOrEqualTo(360 - 16 + 0.5));
        expect(cardRect.top, greaterThanOrEqualTo(0));
        expect(cardRect.bottom, lessThanOrEqualTo(800));
        // Never covers the verse's number column / first line.
        final vr = verseRect(tester, host, ch, v);
        final firstLine = Rect.fromLTRB(
          vr.left,
          vr.top + 1,
          vr.right,
          vr.top + 20,
        );
        expect(
          cardRect.overlaps(firstLine),
          isFalse,
          reason:
              'card must not cover the first line of ${data.refName(ch, v)}',
        );
      }

      // Verse at the viewport top.
      var host = await pumpReader(tester, data: data, texts: texts);
      await checkCase(tester, host, 0, 1);
      // A verse near the bottom of a long page.
      final ps119 = g(18, 119);
      host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: ps119,
        anchorVerse: 176,
      );
      // The last verse of the chapter page.
      await checkCase(tester, host, ps119, 176);
    });

    testWidgets('TOOL-3 dismiss: outside tap and same-verse tap',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      expect(find.text('Connections · 3'), findsOneWidget);
      // Outside tap: the page's left margin strip (the label
      // block itself is scrolled off after the verse was brought
      // to the top — the margin is the visible outside surface).
      await tester.tapAt(const Offset(8, 400));
      await tester.pump();
      expect(find.text('Connections · 3'), findsNothing);
      expect(verseSelected(tester, host, 0, 1), isFalse);
      // Same-verse tap.
      await tapVerse(tester, host, 0, 1);
      expect(find.text('Connections · 3'), findsOneWidget);
      await tapVerse(tester, host, 0, 1);
      expect(find.text('Connections · 3'), findsNothing);
      expect(verseSelected(tester, host, 0, 1), isFalse);
    });

    testWidgets('TOOL-3 dismiss: a different verse moves the toolbar',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      // Verse 3's first lines are visible below the raised card
      // (verse 2 sits under it — a covered verse cannot be tapped
      // on device either). Tap its visible first line.
      final vr = verseRect(tester, host, 0, 3);
      await tester.tapAt(Offset(vr.left + 60, vr.top + 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Genesis 1:3'), findsOneWidget);
      expect(find.text('Connections · 0'), findsOneWidget,
          reason: 'Genesis 1:3 has no connections');
      expect(verseSelected(tester, host, 0, 3), isTrue);
      expect(verseSelected(tester, host, 0, 1), isFalse);
    });

    testWidgets('TOOL-3 dismiss: in-page scroll beyond 8dp', (tester) async {
      final ps119 = g(18, 119);
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: ps119,
      );
      await tapVerse(tester, host, ps119, 1);
      expect(find.textContaining('Connections ·'), findsOneWidget);
      await scrollPage(tester, host, 100);
      expect(find.textContaining('Connections ·'), findsNothing);
      expect(verseSelected(tester, host, ps119, 1), isFalse);
    });

    testWidgets('TOOL-3 dismiss: a page turn dismisses and completes',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      expect(find.text('Connections · 3'), findsOneWidget);
      // The swipe starts on clear text below the raised card
      // (a gesture that starts on the card itself is the card's).
      await tester.flingFrom(
        const Offset(180, 720),
        const Offset(-200, 0),
        1000,
      );
      await settleReader(tester, host);
      expect(find.text('Connections · 3'), findsNothing);
      expect(host.state.currentChapter, 1,
          reason: 'the turn proceeded — the toolbar never eats it');
    });

    testWidgets('TOOL-3 dismiss: back dismisses the toolbar only',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.text('Connections · 3'), findsNothing);
      expect(host.fallbackCalls, 0, reason: 'no lower rung fired');
      expect(host.state.currentChapter, 0);
    });

    testWidgets('TOOL-4 colors: apply, persist, re-tap removes, '
        'None removes', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.bySemanticsLabel('Gold highlight'));
      await tester.pump();
      expect(slotSelected(tester, 'Gold highlight'), isTrue);
      var stored = await storedData();
      expect(
        stored.fullVerseColor('default', 'kjv', verseKey(0, 1, 1)),
        HlColor.gold,
      );
      // Re-tap the active color removes it.
      await tester.tap(find.bySemanticsLabel('Gold highlight'));
      await tester.pump();
      expect(slotSelected(tester, 'None highlight'), isTrue);
      stored = await storedData();
      expect(stored.fullVerseColor('default', 'kjv', verseKey(0, 1, 1)), isNull);
      // Apply another color, then None removes it.
      await tester.tap(find.bySemanticsLabel('Blue highlight'));
      await tester.pump();
      stored = await storedData();
      expect(stored.fullVerseColor('default', 'kjv', verseKey(0, 1, 1)), HlColor.blue);
      await tester.tap(find.bySemanticsLabel('None highlight'));
      await tester.pump();
      stored = await storedData();
      expect(stored.fullVerseColor('default', 'kjv', verseKey(0, 1, 1)), isNull);
      expect(host.state.currentChapter, 0);
    });

    testWidgets('TOOL-6 note editor: labels, save, cancel, empty save',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 3);
      expect(find.text('Add note'), findsOneWidget);
      await tester.tap(find.text('Add note'));
      await tester.pump();
      expect(find.text('Note'), findsOneWidget);
      expect(
        find.text('Saving an empty note removes it.'),
        findsOneWidget,
      );
      // Cancel returns unsaved.
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Add note'), findsOneWidget);
      var stored = await storedData();
      expect(stored.note('default', 'kjv', verseKey(0, 1, 3)), isNull);
      // Save returns to the action view showing the preview; the
      // button becomes Edit note.
      await tester.tap(find.text('Add note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'alpha note');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Edit note'), findsOneWidget);
      expect(find.text('alpha note'), findsOneWidget);
      stored = await storedData();
      expect(stored.note('default', 'kjv', verseKey(0, 1, 3)), 'alpha note');
      // Empty save removes the note.
      await tester.tap(find.text('Edit note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Add note'), findsOneWidget);
      stored = await storedData();
      expect(stored.note('default', 'kjv', verseKey(0, 1, 3)), isNull);
      expect(host.state.currentChapter, 0);
    });

    testWidgets('TOOL-5 independence: highlight and note never cascade',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      // Verse 1: highlight + note, then remove the highlight via
      // None — the note keeps.
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.bySemanticsLabel('Gold highlight'));
      await tester.pump();
      await tester.tap(find.text('Add note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'keep me');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('None highlight'));
      await tester.pump();
      var stored = await storedData();
      expect(stored.fullVerseColor('default', 'kjv', verseKey(0, 1, 1)), isNull);
      expect(stored.note('default', 'kjv', verseKey(0, 1, 1)), 'keep me');
      expect(find.text('keep me'), findsOneWidget,
          reason: 'the toolbar still previews the kept note');
      // Verse 2: highlight, then empty the note via the editor —
      // the highlight keeps.
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tapVerse(tester, host, 0, 2);
      await tester.tap(find.bySemanticsLabel('Pink highlight'));
      await tester.pump();
      await tester.tap(find.text('Add note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'temp');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Edit note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pump();
      stored = await storedData();
      expect(stored.note('default', 'kjv', verseKey(0, 1, 2)), isNull);
      expect(stored.fullVerseColor('default', 'kjv', verseKey(0, 1, 2)), HlColor.pink);
      expect(host.state.currentChapter, 0);
    });

    testWidgets('TOOL-7 connections sheet: connections only; row tap '
        'jumps same-screen with push and flash', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.text('Connections · 3'));
      await settleReader(tester, host);
      // The sheet holds the verse text and its connections — and
      // no highlight row, no note section (finder absence).
      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Psalms 119:1'), findsOneWidget);
      expect(find.text('John 1:1'), findsOneWidget);
      expect(find.bySemanticsLabel('Gold highlight'), findsNothing);
      expect(find.text('Add note'), findsNothing);
      expect(find.text('Edit note'), findsNothing);
      // Row-body tap: same-screen jump, history push, flash.
      final john1 = g(42, 1);
      await tester.tap(find.text('John 1:1'));
      await settleReader(tester, host);
      expect(host.state.currentChapter, john1);
      expect(host.screen.history.length, 1);
      expect(verseSelected(tester, host, john1, 1), isTrue);
    });

    testWidgets('TOOL-7 new-screen button opens a new screen; at the '
        'cap it falls back with the verbatim snackbar', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.text('Connections · 3'));
      await settleReader(tester, host);
      await tester.tap(
        find.byTooltip('Open John 1:1 in new screen'),
      );
      await settleReader(tester, host);
      expect(host.screens.length, 2);
      expect(host.state.currentChapter, g(42, 1));
      expect(verseSelected(tester, host, g(42, 1), 1), isTrue);
      // Fill to the cap, then try once more from a sheet.
      while (host.screens.length < wwMaxScreensForTest) {
        host.openChapter(0, verse: 1, inNewScreen: true);
      }
      await settleReader(tester, host);
      host.openChapter(0);
      await settleReader(tester, host);
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.text('Connections · 3'));
      await settleReader(tester, host);
      await tester.tap(
        find.byTooltip('Open Psalms 119:1 in new screen'),
      );
      await settleReader(tester, host);
      expect(host.screens.length, wwMaxScreensForTest);
      expect(
        find.text('Screen limit reached — opened here instead.'),
        findsOneWidget,
      );
      expect(host.state.currentChapter, g(18, 119),
          reason: 'the fallback jumped same-screen');
    });

    testWidgets('TOOL-8 a verse with no connections', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      await tapVerse(tester, host, 0, 5);
      expect(find.text('Connections · 0'), findsOneWidget);
      await tester.tap(find.text('Connections · 0'));
      await settleReader(tester, host);
      expect(
        find.text('No cross references are recorded for this verse.'),
        findsOneWidget,
      );
      expect(host.state.currentChapter, 0);
    });

    testWidgets('BACK-0 rungs: editor, then sheet, then toolbar',
        (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      // 0b: editor open → back returns to the action view, unsaved.
      await tapVerse(tester, host, 0, 1);
      await tester.tap(find.text('Add note'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'unsaved');
      expect(host.state.handlePriorityBack(), isTrue);
      await tester.pump();
      expect(find.text('Add note'), findsOneWidget);
      final stored = await storedData();
      expect(stored.note('default', 'kjv', verseKey(0, 1, 1)), isNull);
      // 0c: sheet open → back closes the sheet only; the toolbar
      // does not reopen and the verse is not re-flashed anew
      // (selection stays as the tap left it, sheet's verse only).
      await tester.tap(find.text('Connections · 3'));
      await settleReader(tester, host);
      expect(find.text('Psalms 119:1'), findsOneWidget);
      expect(host.state.handlePriorityBack(), isTrue);
      await settleReader(tester, host);
      expect(find.text('Psalms 119:1'), findsNothing);
      expect(find.text('Connections · 3'), findsNothing,
          reason: 'the toolbar does not reopen after the sheet');
      // 0d: toolbar open → back dismisses it only.
      await tapVerse(tester, host, 0, 1);
      expect(find.text('Connections · 3'), findsOneWidget);
      expect(host.state.handlePriorityBack(), isTrue);
      await tester.pump();
      expect(find.text('Connections · 3'), findsNothing);
      expect(host.fallbackCalls, 0);
    });
  });
}

/// The binding screen cap (§0.1), mirrored for the harness.
const int wwMaxScreensForTest = 5;
