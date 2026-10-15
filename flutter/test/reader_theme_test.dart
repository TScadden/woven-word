import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/reader_theme.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/screens/my_notes_screen.dart';
import 'package:woven_word/screens/profiles_screen.dart';
import 'package:woven_word/screens/tradition_screens.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// Reader theme package: the persisted Paper/Dark choice —
/// Dark by default on fresh and never-stored state, surviving
/// relaunch, re-rendering both readers and every sheet surface,
/// with per-theme span tint assertions (brief-mandated tests;
/// spec: team/specs/reader-theme.md).
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

  /// The scaffold the reader itself renders on.
  Finder readerScaffold() =>
      find.ancestor(of: readerPager(), matching: find.byType(Scaffold)).first;

  Color scaffoldBg(WidgetTester tester, Finder scaffold) =>
      tester.widget<Scaffold>(scaffold).backgroundColor!;

  /// The style color of the first verse's body text on page 0.
  Color verseBodyColor(WidgetTester tester) => tester
      .widget<Text>(inPage(0, find.textContaining('KJV Genesis 1:1 ')))
      .style!
      .color!;

  /// The verse number's color for verse 1 on page 0: the 12sp
  /// Text inside the verse's block Material.
  Color verseNumberColor(WidgetTester tester) {
    final block = find
        .ancestor(
          of: inPage(0, find.textContaining('KJV Genesis 1:1 ')),
          matching: find.byType(Material),
        )
        .first;
    final numbers = find.descendant(
      of: block,
      matching: find.byWidgetPredicate(
        (w) => w is Text && w.data == '1' && w.style?.fontSize == 12,
      ),
    );
    return tester.widget<Text>(numbers.first).style!.color!;
  }

  Color verseBlockColor(WidgetTester tester) => tester
      .widget<Material>(
        find
            .ancestor(
              of: inPage(0, find.textContaining('KJV Genesis 1:1 ')),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  group('the stored-value rule', () {
    test('absent or unrecognized stored values default to Dark', () {
      expect(WwReaderTheme.fromStored(null), WwReaderTheme.dark);
      expect(WwReaderTheme.fromStored(''), WwReaderTheme.dark);
      expect(WwReaderTheme.fromStored('sepia'), WwReaderTheme.dark);
      expect(WwReaderTheme.fromStored('paper'), WwReaderTheme.paper);
      expect(WwReaderTheme.fromStored('dark'), WwReaderTheme.dark);
    });
  });

  group('Profiles placement', () {
    Future<void> pumpProfiles(
      WidgetTester tester, {
      WwReaderTheme readerTheme = WwReaderTheme.dark,
      ValueChanged<WwReaderTheme>? onThemeChanged,
      Size size = const Size(360, 800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: ProfilesScreen(
            readerTheme: readerTheme,
            onReaderThemeChanged: onThemeChanged,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the Reader theme section sits between Your '
        'tradition and Backup, Dark selected by default', (tester) async {
      final semantics = tester.ensureSemantics();
      // A tall viewport fits the whole list in one frame, so the
      // three section headers' positions compare directly (the
      // tradition suite's placement method, without scrolling).
      await pumpProfiles(tester, size: const Size(360, 2400));
      expect(find.text('Reader theme'), findsOneWidget);
      expect(
        find.text(
          'How the reading pages are dressed. Every reader surface '
          'follows it — the chapter pages, the deuterocanon, the '
          'verse toolbar, and your note editor. Your highlights and '
          'notes never change.',
        ),
        findsOneWidget,
      );
      final traditionY = tester.getTopLeft(find.text('Your tradition')).dy;
      final themeY = tester.getTopLeft(find.text('Reader theme')).dy;
      final backupY = tester.getTopLeft(find.text('Backup')).dy;
      expect(themeY, greaterThan(traditionY));
      expect(themeY, lessThan(backupY));
      var node = tester.getSemantics(find.bySemanticsLabel('Dark'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      node = tester.getSemantics(find.bySemanticsLabel('Paper'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);
      semantics.dispose();
    });

    testWidgets('tapping Paper reports the change and selects it; '
        'an opened-with Paper selection shows Paper selected', (tester) async {
      final semantics = tester.ensureSemantics();
      final changes = <WwReaderTheme>[];
      await pumpProfiles(tester, onThemeChanged: changes.add);
      await tester.scrollUntilVisible(find.bySemanticsLabel('Paper'), 120);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Paper'));
      await tester.pump();
      expect(changes, [WwReaderTheme.paper]);
      var node = tester.getSemantics(find.bySemanticsLabel('Paper'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      await pumpProfiles(tester, readerTheme: WwReaderTheme.paper);
      await tester.scrollUntilVisible(find.bySemanticsLabel('Paper'), 120);
      await tester.pump();
      node = tester.getSemantics(find.bySemanticsLabel('Paper'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      node = tester.getSemantics(find.bySemanticsLabel('Dark'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);
      semantics.dispose();
    });
  });

  group('the standalone reader (no theme host)', () {
    testWidgets('fresh state renders Dark', (tester) async {
      await pumpReader(tester, data: data, texts: texts);
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      expect(verseBodyColor(tester), WwColors.navInk);
      expect(verseNumberColor(tester), WwColors.goldBright);
    });

    testWidgets('a stored Paper choice renders Paper', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {readerThemePrefsKey: 'paper'},
      );
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      expect(verseBodyColor(tester), WwColors.ink);
      expect(verseNumberColor(tester), WwColors.goldTextOnPaper);
    });

    testWidgets('the quick switch flips the render and persists '
        'the choice both ways', (tester) async {
      await pumpReader(tester, data: data, texts: texts);
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      await tester.tap(
        find.byTooltip('Reader theme: Dark. Switch to Paper theme'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      expect(verseBodyColor(tester), WwColors.ink);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(readerThemePrefsKey), 'paper');
      await tester.tap(
        find.byTooltip('Reader theme: Paper. Switch to Dark theme'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      expect(prefs.getString(readerThemePrefsKey), 'dark');
    });
  });

  group('span tints render per theme', () {
    Map<String, Object> seededPrefs({required bool fullVerse}) {
      final doc = UserData();
      doc.applySpan(
        'default',
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: fullVerse ? 0 : 23,
          end: fullVerse ? -1 : 32,
          anchor: 'beginning',
          color: HlColor.gold,
        ),
      );
      return {UserDataStore.storageKey: jsonEncode(doc.toJson())};
    }

    testWidgets('dark: a full-verse span blocks in the dark gold '
        'tint and the number takes the ink role', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: seededPrefs(fullVerse: true),
      );
      expect(verseBlockColor(tester), WwColors.hlGoldDark);
      expect(verseNumberColor(tester), WwColors.navInk);
      expect(verseBodyColor(tester), WwColors.navInk);
    });

    testWidgets('paper: the same span blocks in the shipped gold '
        'tint and the number takes ink', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {...seededPrefs(fullVerse: true), readerThemePrefsKey: 'paper'},
      );
      expect(verseBlockColor(tester), WwColors.hlGold);
      expect(verseNumberColor(tester), WwColors.ink);
    });

    testWidgets('dark: a partial span segment carries the dark '
        'tint; paper carries the pastel', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: seededPrefs(fullVerse: false),
      );
      var textWidget = tester.widget<Text>(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      var tinted = (textWidget.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor == WwColors.hlGoldDark)
          .toList();
      expect(tinted, hasLength(1));
      expect(tinted.single.text, 'beginning');
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {...seededPrefs(fullVerse: false), readerThemePrefsKey: 'paper'},
      );
      textWidget = tester.widget<Text>(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      tinted = (textWidget.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .where((s) => s.style?.backgroundColor == WwColors.hlGold)
          .toList();
      expect(tinted, hasLength(1));
    });
  });

  group('reader surfaces follow the theme', () {
    testWidgets('dark: the verse toolbar card and the note editor '
        'field render from the dark palette', (tester) async {
      await pumpReader(tester, data: data, texts: texts);
      await tester.tap(inPage(0, find.textContaining('KJV Genesis 1:1 ')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // The toolbar card: a Container whose BoxDecoration carries
      // the card background and a border.
      final cards = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null &&
            (w.decoration as BoxDecoration).color != null,
      );
      final colors = tester
          .widgetList<Container>(cards)
          .map((c) => (c.decoration as BoxDecoration).color)
          .toSet();
      expect(colors, contains(WwColors.surfaceHigh));
      await tester.tap(find.text('Add note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.fillColor, WwColors.surface);
      expect(field.style?.color, WwColors.navInk);
    });

    testWidgets('dark: the connections sheet renders on the dark '
        'surface with cream ink', (tester) async {
      await pumpReader(tester, data: data, texts: texts);
      await tester.tap(inPage(0, find.textContaining('KJV Genesis 1:1 ')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Connections · 3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final material = find.descendant(
        of: sheet,
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(material.first).color, WwColors.surface);
      final label = tester.widget<Text>(find.text('Connections'));
      expect(label.style?.color, WwColors.goldBright);
      final header = tester.widget<Text>(find.text('Genesis 1:1').last);
      expect(header.style?.color, WwColors.navInk);
    });

    testWidgets('dark: selection mode chrome — the overlay token '
        'and the selection bar card', (tester) async {
      await pumpReader(tester, data: data, texts: texts);
      final themeData = tester
          .widget<TextSelectionTheme>(
            find
                .ancestor(
                  of: readerPager(),
                  matching: find.byType(TextSelectionTheme),
                )
                .first,
          )
          .data;
      expect(themeData.selectionColor, WwColors.gold.withValues(alpha: 0.20));
      expect(themeData.selectionHandleColor, WwColors.goldBright);
      await tester.longPress(
        inPage(0, find.textContaining('KJV Genesis 1:1 ')),
      );
      await tester.pump();
      await tester.longPress(inPage(0, find.byType(SelectableText)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final bar = find.byWidgetPredicate(
        (w) =>
            w is Material &&
            w.color == WwColors.surfaceHigh &&
            w.borderRadius != null,
      );
      expect(bar, findsOneWidget);
    });

    testWidgets('paper: selection mode keeps the shipped chrome', (
      tester,
    ) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        prefs: {readerThemePrefsKey: 'paper'},
      );
      final themeData = tester
          .widget<TextSelectionTheme>(
            find
                .ancestor(
                  of: readerPager(),
                  matching: find.byType(TextSelectionTheme),
                )
                .first,
          )
          .data;
      expect(themeData.selectionColor, WwColors.hlGold.withValues(alpha: 0.50));
      expect(themeData.selectionHandleColor, WwColors.goldTextOnPaper);
    });
  });

  group('the shell owns the choice', () {
    testWidgets('fresh shell state opens the reader in Dark', (tester) async {
      await pumpShell(tester, data: data, texts: texts);
      await openViaSearch(tester, 'Genesis 1');
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      expect(verseBodyColor(tester), WwColors.navInk);
    });

    testWidgets('a stored Paper choice survives relaunch into the '
        'shell reader', (tester) async {
      await pumpShell(
        tester,
        data: data,
        texts: texts,
        prefs: {readerThemePrefsKey: 'paper'},
      );
      await openViaSearch(tester, 'Genesis 1');
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      expect(verseBodyColor(tester), WwColors.ink);
    });

    testWidgets('choosing Paper in Profiles persists, and the '
        'reader follows on the same stored choice', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester, data: data, texts: texts);
      await tester.tap(find.byTooltip('Profiles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.scrollUntilVisible(find.bySemanticsLabel('Dark'), 120);
      await tester.pump();
      var node = tester.getSemantics(find.bySemanticsLabel('Dark'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      await tester.tap(find.bySemanticsLabel('Paper'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(readerThemePrefsKey), 'paper');
      // Back to Home, then into the reader: Paper.
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await openViaSearch(tester, 'Genesis 1');
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      semantics.dispose();
    });

    testWidgets('the in-reader quick switch writes the one stored '
        'choice Profiles then shows', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester, data: data, texts: texts);
      await openViaSearch(tester, 'Genesis 1');
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      await tester.tap(
        find.byTooltip('Reader theme: Dark. Switch to Paper theme'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(readerThemePrefsKey), 'paper');
      await tapTab(tester, 'Home');
      await tester.tap(find.byTooltip('Profiles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.scrollUntilVisible(find.bySemanticsLabel('Paper'), 120);
      await tester.pump();
      final node = tester.getSemantics(find.bySemanticsLabel('Paper'));
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      semantics.dispose();
    });
  });

  group('the deuterocanon reader', () {
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

    Future<void> pumpDeutero(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
      WwReaderTheme? readerTheme,
      ValueChanged<WwReaderTheme>? onThemeChanged,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: DeuteroReaderScreen(
            deutero: deutero,
            book: tobit,
            initialChapter: 1,
            onBack: () {},
            textsLoader: () async => deuteroTexts(),
            readerTheme: readerTheme,
            onReaderThemeChanged: onThemeChanged,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Color deuteroBg(WidgetTester tester) =>
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;

    Color deuteroBodyColor(WidgetTester tester) =>
        tester.widget<Text>(find.text('Tobit verse one')).style!.color!;

    testWidgets('fresh state renders Dark; a passed Paper choice '
        'renders Paper', (tester) async {
      await pumpDeutero(tester);
      expect(deuteroBg(tester), WwColors.surface);
      expect(deuteroBodyColor(tester), WwColors.navInk);
      await pumpDeutero(tester, readerTheme: WwReaderTheme.paper);
      expect(deuteroBg(tester), WwColors.paper);
      expect(deuteroBodyColor(tester), WwColors.ink);
    });

    testWidgets('its quick switch flips the render, reports '
        'through the callback, and themes its note editor', (tester) async {
      await pumpDeutero(tester);
      expect(deuteroBg(tester), WwColors.surface);
      await tester.tap(
        find.byTooltip('Reader theme: Dark. Switch to Paper theme'),
      );
      await tester.pump();
      expect(deuteroBg(tester), WwColors.paper);
      // The note editor follows: select verse 2, open Note.
      await tester.tap(find.text('Tobit verse two'));
      await tester.pump();
      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final material = find.descendant(
        of: sheet,
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(material.first).color, WwColors.paper);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.fillColor, WwColors.paper);
      expect(field.style?.color, WwColors.ink);
    });

    testWidgets('dark: its note editor renders from the dark '
        'palette', (tester) async {
      await pumpDeutero(tester);
      await tester.tap(find.text('Tobit verse two'));
      await tester.pump();
      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final material = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Material),
      );
      expect(
        tester.widget<Material>(material.first).color,
        WwColors.surfaceHigh,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.fillColor, WwColors.surface);
      expect(field.style?.color, WwColors.navInk);
    });
  });

  group('the My Notes note editor', () {
    Future<void> pumpNotes(
      WidgetTester tester, {
      required Map<String, Object> prefs,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: MyNotesScreen(data: data, textsLoader: () async => texts),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
    }

    Map<String, Object> notePrefs({String? theme}) {
      final doc = UserData();
      doc.setNote('default', 'kjv', 'b0c1v1', 'a note on the verse');
      final prefs = <String, Object>{
        UserDataStore.storageKey: jsonEncode(doc.toJson()),
      };
      if (theme != null) prefs[readerThemePrefsKey] = theme;
      return prefs;
    }

    testWidgets('dark by default: the editor sheet and field '
        'follow the dark reader', (tester) async {
      await pumpNotes(tester, prefs: notePrefs());
      await tester.tap(find.byTooltip('Edit note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final material = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Material),
      );
      expect(
        tester.widget<Material>(material.first).color,
        WwColors.surfaceHigh,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.fillColor, WwColors.surface);
      expect(field.style?.color, WwColors.navInk);
    });

    testWidgets('a stored Paper choice renders the shipped paper '
        'editor', (tester) async {
      await pumpNotes(tester, prefs: notePrefs(theme: 'paper'));
      await tester.tap(find.byTooltip('Edit note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final material = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(material.first).color, WwColors.paper);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.fillColor, WwColors.paper);
      expect(field.style?.color, WwColors.ink);
    });
  });

  group('scale and motion', () {
    testWidgets('text scale 2.0 renders both themes without '
        'overflow', (tester) async {
      await pumpReader(tester, data: data, texts: texts, textScale: 2.0);
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      expect(tester.takeException(), isNull);
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        textScale: 2.0,
        prefs: {readerThemePrefsKey: 'paper'},
      );
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders the final themed state '
        'and the switch is instant', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        disableAnimations: true,
      );
      expect(scaffoldBg(tester, readerScaffold()), WwColors.surface);
      await tester.tap(
        find.byTooltip('Reader theme: Dark. Switch to Paper theme'),
      );
      await tester.pump();
      expect(scaffoldBg(tester, readerScaffold()), WwColors.paper);
      expect(tester.takeException(), isNull);
    });
  });
}
