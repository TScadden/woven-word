import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/reader_theme.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/my_notes_screen.dart';
import 'package:woven_word/screens/tradition_screens.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

/// Board run 9: the deuterocanon reader and its place in My
/// Notes — WEBC text paged by chapter, highlights and notes in
/// the shared store under reserved book indices, and rows that
/// open through the shell's one procedure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  ScriptureText texts() => ScriptureText.fromPayloads(
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

  Future<void> pumpReader(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
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
          textsLoader: () async => texts(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders the WEBC text with the honest coverage '
      'note on the first page', (tester) async {
    await pumpReader(tester);
    expect(find.text('Tobit 1'), findsWidgets);
    expect(find.text('Tobit verse one'), findsOneWidget);
    expect(find.text('Tobit verse three'), findsOneWidget);
    expect(
      find.text(
        'Part of the Catholic canon. The woven web does not yet '
        'cover the deuterocanon, so no cross references are '
        'recorded for these chapters.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a verse tap raises the action bar; a swatch '
      'writes the highlight under the reserved key', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpReader(tester);
    await tester.tap(find.text('Tobit verse two'));
    await tester.pump();
    expect(find.bySemanticsLabel('Gold highlight'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Gold highlight'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('ww_user_data')!) as Map<String, dynamic>;
    // Board run 10: the write lands as a full-verse span in the
    // webc set of the v3 document.
    final spans =
        ((stored['profiles'] as Map)['default'] as Map)['spans'] as Map;
    expect(spans, {
      'webc': [
        {'v': 'b1000c1v2', 's': 0, 'e': -1, 'a': 'Tobit verse two', 'c': 'gold'},
      ],
    });
    semantics.dispose();
  });

  testWidgets('the note editor saves through the shared store '
      'and dismisses cleanly on Cancel too', (tester) async {
    // Reader theme package: this test asserts the paper sheet's
    // explicit fill (the run 9 gate P0 law, now the palette's
    // paper values), so it opens under the stored Paper choice.
    await pumpReader(tester, prefs: {readerThemePrefsKey: 'paper'});
    await tester.tap(find.text('Tobit verse one'));
    await tester.pump();
    await tester.tap(find.text('Note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // The editor's field carries its paper fill explicitly: the
    // theme's dark-tuned fill would render typed text at 1.02:1
    // (run 9 gate P0). The empty-removes rule is disclosed.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isTrue);
    expect(field.decoration?.fillColor, WwColors.paper);
    expect(find.text('Saving an empty note removes it.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a tobit note');
    await tester.tap(find.text('Save note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('ww_user_data')!) as Map<String, dynamic>;
    // Board run 10: the note lives in the webc set of the v3
    // document (per-translation sets).
    final notes = ((stored['profiles'] as Map)['default'] as Map)['notes'] as Map;
    expect(notes, {
      'webc': {'b1000c1v1': 'a tobit note'},
    });

    // Reopen and cancel: no crash, no change (the controller's
    // lifetime is the sheet State's, LESSONS #33). The verse is
    // still selected after the save, so the bar is already up.
    expect(find.text('Edit note'), findsOneWidget);
    await tester.tap(find.text('Edit note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('a tobit note'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('my notes: a deuterocanon note renders with its '
      'reference and text, and opens through the procedure', (
    tester,
  ) async {
    final data = fakeReaderData();
    final opened = <(int, int, int)>[];
    // Board run 10 seed: the Tobit note lives in the WEBC set
    // (where the deutero reader writes), the Genesis note in the
    // KJV set; WEBC is the active translation and the tradition
    // is Catholic, so the Tobit note is the visible one.
    SharedPreferences.setMockInitialValues({
      'ww_translation': 'WEBC',
      'ww_user_data': jsonEncode({
        'version': 3,
        'activeProfileId': 'default',
        'names': {'default': 'My Profile'},
        'seq': 0,
        'profiles': {
          'default': {
            'spans': <String, dynamic>{},
            'notes': {
              'webc': {'b1000c1v2': 'deutero note'},
              'kjv': {'b0c1v1': 'core note'},
            },
          },
        },
      }),
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        home: MyNotesScreen(
          data: data,
          tradition: WwTradition.catholic,
          textsLoader: () async => ScriptureText.fromPayloads(
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
          ),
          deuteroLoader: () async => deutero,
          onOpenVerse: (b, c, v) => opened.add((b, c, v)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Tobit 1:2'), findsOneWidget);
    expect(find.text('deutero note'), findsOneWidget);
    // The Genesis note belongs to the KJV set: My Notes shows the
    // active translation's set (board run 10), so it is not in
    // this view — it returns when KJV is active again.
    expect(find.text('Genesis 1:1'), findsNothing);
    await tester.tap(find.text('Tobit 1:2'));
    await tester.pump();
    expect(opened, [(1000, 1, 2)]);
  });
}
