import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/screens/tradition_screens.dart';
import 'package:woven_word/theme/ww_theme.dart';
import 'package:woven_word/widgets/arc_stage.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';

/// Reader arch package (spec team/specs/reader-arch.md): the
/// reader's connection arch panel — collapsible, remembered
/// per profile, riding the backup document. ARCH-1..4 are the
/// store/backup groups; ARCH-5..11 the widget groups.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-1 store: the per-profile arch setting', () {
    test('defaults to expanded with no document at all', () {
      final data = UserData();
      expect(data.readerArchExpandedFor(UserData.defaultProfileId), isTrue);
      expect(data.readerArchExpandedFor('missing'), isTrue);
    });

    test('set/get round trip; a write materializes the bucket', () {
      final data = UserData();
      data.setReaderArchExpanded('p1', false);
      expect(data.readerArchExpandedFor('p1'), isFalse);
      data.setReaderArchExpanded('p1', true);
      expect(data.readerArchExpandedFor('p1'), isTrue);
    });

    test('two profiles hold opposite states independently', () {
      final data = UserData();
      final p2 = data.createProfile('Second');
      data.setReaderArchExpanded(UserData.defaultProfileId, true);
      data.setReaderArchExpanded(p2, false);
      expect(data.readerArchExpandedFor(UserData.defaultProfileId), isTrue);
      expect(data.readerArchExpandedFor(p2), isFalse);
    });

    test('the document round trip preserves opposite values', () {
      final data = UserData();
      final p2 = data.createProfile('Second');
      data.setReaderArchExpanded(UserData.defaultProfileId, true);
      data.setReaderArchExpanded(p2, false);
      final restored = UserData.fromJson(
        jsonDecode(data.exportJson()) as Map<String, dynamic>,
      );
      expect(
        restored.readerArchExpandedFor(UserData.defaultProfileId),
        isTrue,
      );
      expect(restored.readerArchExpandedFor(p2), isFalse);
    });

    test('a document without the member loads expanded (legacy)', () {
      final restored = UserData.fromJson({
        'version': 3,
        'activeProfileId': 'default',
        'names': <String, String>{},
        'seq': 0,
        'profiles': {
          'default': {'spans': {}, 'notes': {}},
        },
      });
      expect(restored.readerArchExpandedFor('default'), isTrue);
    });

    test('a non-bool member in a stored document loads defensive', () {
      final restored = UserData.fromJson({
        'version': 3,
        'profiles': {
          'default': {'spans': {}, 'notes': {}, 'readerArchExpanded': 'no'},
        },
      });
      expect(restored.readerArchExpandedFor('default'), isTrue);
    });
  });

  group('ARCH-2 backup: the setting rides the document', () {
    test('export -> validate -> import carries both profiles', () {
      final data = UserData();
      final p2 = data.createProfile('Second');
      data.setReaderArchExpanded(UserData.defaultProfileId, false);
      data.setReaderArchExpanded(p2, true);
      // A backup with no spans/notes would read as empty; give
      // it real content the way a founder's document has.
      data.setNote(UserData.defaultProfileId, 'kjv', 'b0c1v1', 'note');
      final result = UserDataStore.validateImport(data.exportJson());
      expect(result.isValid, isTrue, reason: '${result.error}');
      final imported = result.data!;
      expect(
        imported.readerArchExpandedFor(UserData.defaultProfileId),
        isFalse,
      );
      expect(imported.readerArchExpandedFor(p2), isTrue);
    });

    test('a non-bool member is rejected as notBackup', () {
      final doc = jsonEncode({
        'version': 3,
        'profiles': {
          'default': {'spans': {}, 'notes': {}, 'readerArchExpanded': 1},
        },
      });
      final result = UserDataStore.validateImport(doc);
      expect(result.isValid, isFalse);
      expect(result.error, BackupImportError.notBackup);
    });

    test('a v3 backup without the member validates (pre-package)', () {
      final doc = jsonEncode({
        'version': 3,
        'profiles': {
          'default': {
            'spans': {},
            'notes': {
              'kjv': {'b0c1v1': 'note'},
            },
          },
        },
      });
      final result = UserDataStore.validateImport(doc);
      expect(result.isValid, isTrue, reason: '${result.error}');
      expect(
        result.data!.readerArchExpandedFor(UserData.defaultProfileId),
        isTrue,
      );
    });
  });

  group('ARCH-3 reader widget: states, persistence, chapters', () {
    late BibleData data;
    late ScriptureText texts;

    setUp(() {
      data = fakeReaderData();
      texts = fakeReaderTexts(data);
    });

    const panel = ValueKey('reader-arch-panel');
    const paint = ValueKey('reader-arch-paint');
    const minimize = ValueKey('reader-arch-minimize');
    const expand = ValueKey('reader-arch-expand');

    MiniSelectionPainter archPainter(WidgetTester tester) =>
        tester.widget<CustomPaint>(find.byKey(paint)).painter
            as MiniSelectionPainter;

    testWidgets('ARCH-5 the panel renders expanded by default, '
        'painting the open chapter', (tester) async {
      await pumpReader(tester, data: data, texts: texts, startChapter: 0);
      expect(find.byKey(panel), findsOneWidget);
      expect(find.byKey(minimize), findsOneWidget);
      expect(find.byKey(expand), findsNothing);
      expect(archPainter(tester).selected, 0);
    });

    testWidgets('ARCH-6 minimize persists across a relaunch', (tester) async {
      await pumpReader(tester, data: data, texts: texts, startChapter: 0);
      await tester.tap(find.byKey(minimize));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(panel), findsNothing);
      expect(find.byKey(expand), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(UserDataStore.storageKey);
      expect(saved, isNotNull);
      final doc = jsonDecode(saved!) as Map<String, dynamic>;
      final bucket =
          (doc['profiles'] as Map)['default'] as Map<String, dynamic>;
      expect(bucket['readerArchExpanded'], isFalse);
      // Relaunch on the saved document: opens minimized.
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: 0,
        prefs: {UserDataStore.storageKey: saved},
      );
      expect(find.byKey(panel), findsNothing);
      expect(find.byKey(expand), findsOneWidget);
      // And expanding again persists back.
      await tester.tap(find.byKey(expand));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(panel), findsOneWidget);
    });

    testWidgets('ARCH-7 the active profile\'s state rules: p2 '
        'minimized wins over default expanded', (tester) async {
      final seed = UserData();
      final p2 = seed.createProfile('Second');
      seed.setReaderArchExpanded(UserData.defaultProfileId, true);
      seed.setReaderArchExpanded(p2, false);
      seed.setActiveProfile(p2);
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: 0,
        prefs: {UserDataStore.storageKey: seed.exportJson()},
      );
      expect(find.byKey(panel), findsNothing);
      expect(find.byKey(expand), findsOneWidget);
    });

    testWidgets('ARCH-8 the arch follows the chapter across a '
        'page turn', (tester) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: 0,
      );
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 1);
      expect(archPainter(tester).selected, 1);
    });

    testWidgets('ARCH-9 gestures: the reading area still turns '
        'pages with the panel expanded; the panel itself is '
        'outside the pager path', (tester) async {
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: 0,
      );
      // A fling that starts ON the panel never reaches the
      // pager (the panel sits above it in the Column).
      await tester.fling(find.byKey(panel), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 0);
      // A fling on the reading area turns the page.
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
      await settleReader(tester, host);
      expect(host.state.currentChapter, 1);
    });

    testWidgets('ARCH-10 text scale 2.0: no overflow, panel '
        'present, both controls at least 48dp', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: 0,
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(panel), findsOneWidget);
      final minSize = tester.getSize(find.byKey(minimize));
      expect(minSize.width, greaterThanOrEqualTo(48));
      expect(minSize.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(minimize));
      await tester.pump(const Duration(milliseconds: 400));
      final expSize = tester.getSize(find.byKey(expand));
      expect(expSize.width, greaterThanOrEqualTo(48));
      expect(expSize.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ARCH-11 reduced motion: the toggle renders '
        'the final state immediately', (tester) async {
      await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: 0,
        disableAnimations: true,
      );
      expect(find.byKey(panel), findsOneWidget);
      await tester.tap(find.byKey(minimize));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(panel), findsNothing);
      expect(find.byKey(expand), findsOneWidget);
    });
  });

  group('ARCH-4 deuterocanon reader: no arch surface', () {
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

    testWidgets('ARCH-12 no panel, no controls — the web does '
        'not cover these chapters', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final tobit = deutero.books.single;
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
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          home: DeuteroReaderScreen(
            deutero: deutero,
            book: tobit,
            initialChapter: 1,
            onBack: () {},
            textsLoader: () async => texts,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('reader-arch-panel')), findsNothing);
      expect(
        find.byKey(const ValueKey('reader-arch-minimize')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('reader-arch-expand')), findsNothing);
    });
  });
}
