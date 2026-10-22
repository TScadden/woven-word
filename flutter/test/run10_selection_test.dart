import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/reader_theme.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/screens/my_notes_screen.dart';
import 'package:woven_word/screens/tradition_screens.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// Board run 10: text-selection highlighting — the selection
/// mode, the span writes, per-translation visibility in the
/// reader, and canon dormancy in My Notes (spec §6.4–§6.7).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
  });

  Finder inPage(int ch, Finder matching) =>
      find.descendant(of: chapterPage(ch), matching: matching);

  Future<UserData> storedData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(UserDataStore.storageKey);
    if (raw == null) return UserData();
    return UserData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  const genText =
      'KJV Genesis 1:1 In the beginning verse 1 speaks of the woven '
      'word and its connections across the whole canon of scripture.';

  group('selection mode (core reader)', () {
    testWidgets('SEL-1 long-press enters the mode; a selection '
        'drag does not turn the page; at rest a swipe from the '
        'text still turns it', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      expect(inPage(0, find.byType(SelectableText)), findsNothing);
      // Long-press on the verse text enters selection mode.
      await tester.longPress(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      await tester.pump();
      expect(inPage(0, find.byType(SelectableText)), findsOneWidget);
      // A horizontal drag on the selecting text selects; it must
      // NOT turn the page.
      await tester.drag(
        inPage(0, find.byType(SelectableText)),
        const Offset(-140, 0),
      );
      await tester.pump();
      expect(host.state.currentChapter, 0);
      // A tap on another verse leaves the mode (and proceeds as
      // the shipped verse tap: its toolbar opens). Verse 2's
      // block is the visible neighbor — verse 3's center sits
      // below the fold in this harness.
      await tester.tap(inPage(0, find.textContaining('KJV Genesis 1:2 ')));
      await settleReader(tester, host);
      expect(inPage(0, find.byType(SelectableText)), findsNothing);
      // At rest, a fling starting on verse text turns the page —
      // the gesture discipline the mode construction protects.
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.fling(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
        const Offset(-200, 0),
        1000,
      );
      await settleReader(tester, host);
      expect(host.state.currentChapter, 1);
    });

    testWidgets('SEL-2 a word selection colors exactly that span', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final host = await pumpReader(tester, data: data, texts: texts);
      await tester.longPress(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      await tester.pump();
      // Take a word with a second long-press on the selectable
      // text; read the platform selection as the ground truth.
      await tester.longPress(inPage(0, find.byType(SelectableText)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final editable = tester.widget<EditableText>(
        inPage(0, find.byType(EditableText)),
      );
      final sel = editable.controller.selection;
      expect(sel.isValid, isTrue);
      expect(sel.isCollapsed, isFalse);
      final word = genText.substring(sel.start, sel.end);
      expect(word.contains(' '), isFalse, reason: 'a word was taken');
      // The selection bar is up; Gold applies the exact span.
      await tester.tap(find.bySemanticsLabel('Gold highlight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final stored = await storedData();
      final spans = stored.spansFor('default', 'kjv', 'b0c1v1');
      expect(spans, hasLength(1));
      expect(spans.single.start, sel.start);
      expect(spans.single.end, sel.end);
      expect(spans.single.anchor, word);
      expect(spans.single.color, HlColor.gold);
      // The write exited the mode.
      expect(inPage(0, find.byType(SelectableText)), findsNothing);
      expect(host.state.currentChapter, 0);
      semantics.dispose();
    });

    testWidgets('SEL-3 a stored span renders its tint at rest and '
        'persists across relaunch', (tester) async {
      final doc = UserData();
      doc.applySpan(
        'default',
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 23,
          end: 32,
          anchor: 'beginning',
          color: HlColor.gold,
        ),
      );
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {
          UserDataStore.storageKey: jsonEncode(doc.toJson()),
          // Reader theme package: these assertions render the
          // paper palette (the founder default is now Dark).
          readerThemePrefsKey: 'paper',
        },
      );
      // At rest the verse text is a rich Text whose segment for
      // 'beginning' carries the gold tint; the block itself does
      // not (partial span: tints live in the text).
      final textWidget = tester.widget<Text>(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      final segments = (textWidget.textSpan! as TextSpan).children!;
      final tinted = segments
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor == WwColors.hlGold)
          .toList();
      expect(tinted, hasLength(1));
      expect(tinted.single.text, 'beginning');
      final block = tester.widget<Material>(
        find
            .ancestor(
              of: inPage(0, find.textContaining('KJV Genesis 1:1 ')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(block.color, Colors.transparent);
    });

    testWidgets('SEL-4 the verse toolbar writes a full-verse span', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(tester, data: data, texts: texts);
      await tester.tap(inPage(0, find.textContaining('KJV Genesis 1:1 ')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.bySemanticsLabel('Blue highlight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final stored = await storedData();
      final spans = stored.spansFor('default', 'kjv', 'b0c1v1');
      expect(spans, hasLength(1));
      expect(spans.single.isFullVerse, isTrue);
      expect(spans.single.end, -1);
      expect(spans.single.anchor, genText);
      expect(spans.single.color, HlColor.blue);
      semantics.dispose();
    });

    testWidgets('SEL-5 switching translations swaps the visible '
        'set; switching back restores it', (tester) async {
      final doc = UserData();
      doc.applySpan(
        'default',
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 23,
          end: 32,
          anchor: 'beginning',
          color: HlColor.gold,
        ),
      );
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {
          UserDataStore.storageKey: jsonEncode(doc.toJson()),
          // Reader theme package: these assertions render the
          // paper palette (the founder default is now Dark).
          readerThemePrefsKey: 'paper',
        },
      );
      bool hasTint(String tag) {
        final w = tester.widget<Text>(
          inPage(0, find.textContaining('$tag Genesis 1:1 ')),
        );
        return (w.textSpan! as TextSpan).children!.any(
          (s) => s.style?.backgroundColor == WwColors.hlGold,
        );
      }

      expect(hasTint('KJV'), isTrue);
      await tester.tap(find.text('WEB'));
      await settleReader(tester, null);
      expect(hasTint('WEB'), isFalse, reason: 'the WEB set is fresh');
      await tester.tap(find.text('KJV'));
      await settleReader(tester, null);
      expect(hasTint('KJV'), isTrue, reason: 'the KJV set returns');
    });

    testWidgets('SEL-6 Clear on a selection removes only that '
        'range from a full-verse span', (tester) async {
      final semantics = tester.ensureSemantics();
      final doc = UserData();
      doc.applySpan(
        'default',
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 0,
          end: -1,
          anchor: genText,
          color: HlColor.gold,
        ),
      );
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {UserDataStore.storageKey: jsonEncode(doc.toJson())},
      );
      await tester.longPress(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      await tester.pump();
      await tester.longPress(inPage(0, find.byType(SelectableText)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final editable = tester.widget<EditableText>(
        inPage(0, find.byType(EditableText)),
      );
      final sel = editable.controller.selection;
      expect(sel.isCollapsed, isFalse);
      await tester.tap(
        find.bySemanticsLabel('Clear highlight on selected text'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final stored = await storedData();
      final spans = stored.spansFor('default', 'kjv', 'b0c1v1');
      // The cleared range is a hole: stored spans are gold, none
      // overlaps [sel.start, sel.end), and together they cover
      // the rest of the verse.
      var covered = 0;
      for (final s in spans) {
        final e = s.end == -1 ? genText.length : s.end;
        expect(s.color, HlColor.gold);
        expect(
          s.start < sel.end && e > sel.start,
          isFalse,
          reason: 'no span covers the cleared range',
        );
        covered += e - s.start;
      }
      expect(covered, genText.length - (sel.end - sel.start));
      semantics.dispose();
    });
  });

  group('selection mode (deuterocanon reader)', () {
    final deutero = DeuterocanonData.parse(
      jsonEncode({
        'books': [
          {
            'slug': 'tobit',
            'name': 'Tobit',
            'abbr': 'Tob',
            'chapters': 2,
            'verseCounts': [3, 2],
          },
        ],
      }),
    );
    final tobit = deutero.books.single;

    ScriptureText deuteroTexts() => ScriptureText.fromPayloads(
      kjv: '[]',
      web: '[]',
      webc: jsonEncode([
        [
          ['Tobit verse one', 'Tobit verse two', 'Tobit verse three'],
          ['Tobit two one', 'Tobit two two'],
        ],
      ]),
      webcBooks: jsonEncode([
        {'usfm': 'TOB', 'name': 'Tobit', 'core': null, 'extra': 'tobit'},
      ]),
    );

    testWidgets('SEL-7 a word selection writes a webc span', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: DeuteroReaderScreen(
            deutero: deutero,
            book: tobit,
            initialChapter: 1,
            onBack: () {},
            textsLoader: () async => deuteroTexts(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.longPress(find.text('Tobit verse two'));
      await tester.pump();
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.longPress(find.byType(SelectableText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final sel = editable.controller.selection;
      expect(sel.isCollapsed, isFalse);
      await tester.tap(find.bySemanticsLabel('Gold highlight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final stored = await storedData();
      final spans = stored.spansFor('default', 'webc', 'b1000c1v2');
      expect(spans, hasLength(1));
      expect(spans.single.start, sel.start);
      expect(spans.single.end, sel.end);
      expect(
        spans.single.anchor,
        'Tobit verse two'.substring(sel.start, sel.end),
      );
      expect(spans.single.color, HlColor.gold);
      semantics.dispose();
    });
  });

  group('canon dormancy (My Notes)', () {
    Future<void> pumpNotes(
      WidgetTester tester, {
      required Map<String, Object> prefs,
      required WwTradition tradition,
      DeuterocanonData? deuteroData,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      // A placeholder first: each scenario is a fresh mount, as
      // it is when the shell pushes My Notes.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: MyNotesScreen(
            data: data,
            tradition: tradition,
            textsLoader: () async => texts,
            deuteroLoader: deuteroData == null ? null : () async => deuteroData,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
    }

    Map<String, Object> docPrefs(UserData doc, {String? translation}) => {
      UserDataStore.storageKey: jsonEncode(doc.toJson()),
      'ww_translation': ?translation,
    };

    testWidgets('DORM-1 an NT note (KJV) is dormant under the '
        'Jewish tradition and returns unchanged', (tester) async {
      final doc = UserData();
      doc.setNote('default', 'kjv', 'b39c1v1', 'nt note');
      final prefs = docPrefs(doc);
      final before = prefs[UserDataStore.storageKey];
      await pumpNotes(tester, prefs: prefs, tradition: WwTradition.jewish);
      expect(find.text('nt note'), findsNothing);
      expect(find.text('No notes to show here'), findsOneWidget);
      await pumpNotes(tester, prefs: prefs, tradition: WwTradition.none);
      expect(find.text('nt note'), findsOneWidget);
      // Storage was never touched by either view.
      final after = (await SharedPreferences.getInstance()).getString(
        UserDataStore.storageKey,
      );
      expect(after, before);
    });

    testWidgets('DORM-2 a deuterocanon note (WEBC, Catholic) is '
        'dormant under Protestant and returns under Catholic', (tester) async {
      final deutero = DeuterocanonData.parse(
        jsonEncode({
          'books': [
            {
              'slug': 'tobit',
              'name': 'Tobit',
              'abbr': 'Tob',
              'chapters': 2,
              'verseCounts': [3, 2],
            },
          ],
        }),
      );
      final doc = UserData();
      doc.setNote('default', 'webc', 'b1000c1v1', 'tobit note');
      final prefs = docPrefs(doc, translation: 'WEBC');
      await pumpNotes(
        tester,
        prefs: prefs,
        tradition: WwTradition.protestant,
        deuteroData: deutero,
      );
      expect(find.text('tobit note'), findsNothing);
      expect(find.text('No notes to show here'), findsOneWidget);
      await pumpNotes(
        tester,
        prefs: prefs,
        tradition: WwTradition.catholic,
        deuteroData: deutero,
      );
      expect(find.text('tobit note'), findsOneWidget);
    });

    testWidgets('DORM-3 dormancy composes: hidden by either '
        'condition, visible only when both clear', (tester) async {
      final doc = UserData();
      doc.setNote('default', 'web', 'b39c1v1', 'web nt note');
      // (a) Right canon (none), wrong translation (KJV active):
      // hidden by translation scoping.
      await pumpNotes(
        tester,
        prefs: docPrefs(doc),
        tradition: WwTradition.none,
      );
      expect(find.text('web nt note'), findsNothing);
      // (b) Right translation (WEB), wrong canon (Jewish):
      // hidden by canon dormancy.
      await pumpNotes(
        tester,
        prefs: docPrefs(doc, translation: 'WEB'),
        tradition: WwTradition.jewish,
      );
      expect(find.text('web nt note'), findsNothing);
      // (c) Both clear: visible, unchanged.
      await pumpNotes(
        tester,
        prefs: docPrefs(doc, translation: 'WEB'),
        tradition: WwTradition.none,
      );
      expect(find.text('web nt note'), findsOneWidget);
    });
  });

  group('selection entry feel (run 10 fix round)', () {
    testWidgets('SEL-8 a long-press with ~10 px of drift during '
        'the press still enters selection mode for the pressed '
        'verse', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final center = tester.getCenter(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(6, 2));
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.moveBy(const Offset(4, 1));
      // ~420 ms total and ~10.8 px of drift: inside the tuned
      // recognizer's deadline and tolerance, beyond the stock
      // 500 ms one — the founder's failed press, replayed.
      await tester.pump(const Duration(milliseconds: 300));
      expect(inPage(0, find.byType(SelectableText)), findsOneWidget);
      expect(host.state.currentChapter, 0);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('SEL-9 a slow drag that crosses the slop before '
        'the deadline is a scroll: no selection mode, no page '
        'turn', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final center = tester.getCenter(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      final gesture = await tester.startGesture(center);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await settleReader(tester, host);
      expect(inPage(0, find.byType(SelectableText)), findsNothing);
      expect(host.state.currentChapter, 0);
    });

    testWidgets('SEL-10 deuterocanon reader: a long-press with '
        'drift enters selection mode there too', (tester) async {
      final deutero = DeuterocanonData.parse(
        jsonEncode({
          'books': [
            {
              'slug': 'tobit',
              'name': 'Tobit',
              'abbr': 'Tob',
              'chapters': 2,
              'verseCounts': [3, 2],
            },
          ],
        }),
      );
      final texts = ScriptureText.fromPayloads(
        kjv: '[]',
        web: '[]',
        webc: jsonEncode([
          [
            ['Tobit verse one', 'Tobit verse two', 'Tobit verse three'],
            ['Tobit two one', 'Tobit two two'],
          ],
        ]),
        webcBooks: jsonEncode([
          {'usfm': 'TOB', 'name': 'Tobit', 'core': null, 'extra': 'tobit'},
        ]),
      );
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: DeuteroReaderScreen(
            deutero: deutero,
            book: deutero.books.single,
            initialChapter: 1,
            onBack: () {},
            textsLoader: () async => texts,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final center = tester.getCenter(find.text('Tobit verse two'));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(5, 2));
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.moveBy(const Offset(4, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SelectableText), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });
  });
}
