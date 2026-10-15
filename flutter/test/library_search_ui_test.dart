import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/conference_screens.dart';
import 'package:woven_word/screens/library_tab.dart';
import 'package:woven_word/screens/tradition_screens.dart';

import 'fake_canon.dart';
import 'shell_pump.dart';

/// Search fix package: Library search is live — results
/// re-derive on every keystroke with no submit anywhere in
/// these tests (except the one that pins the submit jump),
/// navigation from each group stays inside the Library
/// navigator with the query preserved on Back, and scope
/// follows the tradition + the conference layer's state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;

  const noMatchLine = 'No match — try a book name and chapter, like John 3.';

  const conferenceFixture = '''
{"v":1,"talks":[
 {"i":0,"t":"The Voice of the Lord","s":"John D. Amos","y":2024,"e":"O","n":"Saturday Morning","u":null,"c":0},
 {"i":1,"t":"John's Witness of Christ","s":"Mary E. Jones","y":2025,"e":"A","n":"Sunday Morning","u":null,"c":0},
 {"i":2,"t":"Hope in Christ","s":"John D. Amos","y":2023,"e":"A","n":"Saturday Evening","u":null,"c":0}
],"edges":[]}''';

  const deuteroFixture = '''
{"v":1,"books":[
 {"slug":"tobit","name":"Tobit","abbr":"Tob","chapters":14,"verseCounts":[10,10,10,10,10,10,10,10,10,10,10,10,10,10]},
 {"slug":"judith","name":"Judith","abbr":"Jdt","chapters":16,"verseCounts":[10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10]}
]}''';

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
  });

  Future<ConferenceData> loadConference(BibleData canon) async =>
      ConferenceData.parse(
        conferenceFixture,
        chapterVerseCounts: [for (final c in canon.chapters) c.v],
        chapters: canon.chapters,
      );

  Future<DeuterocanonData> loadDeutero() async =>
      DeuterocanonData.parse(deuteroFixture);

  Future<void> navSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Future<void> toLibrary(WidgetTester tester) async {
    await tapTab(tester, 'Library');
    await navSettle(tester);
  }

  /// Type (replacing the field's text) and render one frame.
  /// No submit action is ever sent in the live tests.
  Future<void> typeQuery(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
  }

  testWidgets('results change per keystroke, no submit; clearing '
      'restores the browse tiles', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester, data: data, texts: texts);
    await toLibrary(tester);
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);

    await typeQuery(tester, 'j');
    expect(find.text('Old Testament'), findsNothing);
    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('Job'), findsOneWidget);

    await typeQuery(tester, 'joh');
    expect(find.text('Job'), findsNothing, reason: 'narrowed per keystroke');
    expect(find.text('John'), findsOneWidget);
    expect(find.text('1 John'), findsOneWidget);

    await typeQuery(tester, 'john');
    expect(find.bySemanticsLabel('Open book: John'), findsOneWidget);
    expect(find.bySemanticsLabel('Open book: 1 John'), findsOneWidget);

    await typeQuery(tester, '');
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('BOOKS'), findsNothing);
    semantics.dispose();
  });

  testWidgets('chapters group resolves references live; an '
      'out-of-range chapter and gibberish show the no-match line '
      'with no submit', (tester) async {
    await pumpShell(tester, data: data, texts: texts);
    await toLibrary(tester);

    await typeQuery(tester, 'john 3');
    expect(find.text('CHAPTERS'), findsOneWidget);
    expect(find.text('BOOKS'), findsNothing);
    expect(find.text('John 3'), findsOneWidget);

    await typeQuery(tester, 'john 99');
    expect(find.text('CHAPTERS'), findsNothing);
    expect(find.text(noMatchLine), findsOneWidget);

    await typeQuery(tester, 'gibberish xyz');
    expect(find.text(noMatchLine), findsOneWidget);
    expect(readerList(), findsNothing);
  });

  testWidgets('book row pushes the chapter grid inside the '
      'Library navigator; Back returns to the live results with '
      'the query preserved', (tester) async {
    await pumpShell(tester, data: data, texts: texts);
    await toLibrary(tester);

    await typeQuery(tester, 'john');
    await tester.tap(find.text('John'));
    await navSettle(tester);
    expect(find.byType(ChapterGrid), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await navSettle(tester);
    expect(find.byType(ChapterGrid), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'john');
    expect(find.text('1 John'), findsOneWidget);
    expect(find.text('Old Testament'), findsNothing);
  });

  testWidgets('chapter row opens the reader at that chapter', (
    tester,
  ) async {
    await pumpShell(tester, data: data, texts: texts);
    await toLibrary(tester);

    await typeQuery(tester, 'john 3');
    await tester.tap(find.text('John 3'));
    await navSettle(tester);
    expect(readerList(), findsWidgets);
    // The reader heads its chapter pages "John 3" (the page
    // and its incoming neighbor both render it).
    expect(find.text('John 3'), findsWidgets);
  });

  testWidgets('the keyboard search action still jumps (§2.6)', (
    tester,
  ) async {
    await pumpShell(tester, data: data, texts: texts);
    await toLibrary(tester);

    await typeQuery(tester, 'john 3');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await navSettle(tester);
    expect(readerList(), findsWidgets);
    expect(find.text('John 3'), findsWidgets);
  });

  testWidgets('conference layer ON: talks match live, newest '
      'first; the talk view is a direct push and Back restores '
      'the search', (tester) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      prefs: const {'ww_conference_layer': true},
      conferenceLoader: loadConference,
    );
    await toLibrary(tester);

    await typeQuery(tester, 'amos');
    expect(find.text('TALKS'), findsOneWidget);
    final voice = find.text('The Voice of the Lord');
    final hope = find.text('Hope in Christ');
    expect(voice, findsOneWidget);
    expect(hope, findsOneWidget);
    expect(
      tester.getTopLeft(voice).dy,
      lessThan(tester.getTopLeft(hope).dy),
      reason: 'October 2024 above April 2023 (newest first)',
    );

    await typeQuery(tester, 'john');
    expect(find.text("John's Witness of Christ"), findsOneWidget);
    await tester.tap(find.text("John's Witness of Christ"));
    await navSettle(tester);
    expect(find.byType(TalkViewScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await navSettle(tester);
    expect(find.byType(TalkViewScreen), findsNothing);
    expect(find.text('TALKS'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'john');
  });

  testWidgets('conference layer OFF: no talks exist for the '
      'same query', (tester) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      conferenceLoader: loadConference,
    );
    await toLibrary(tester);

    await typeQuery(tester, 'john');
    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('TALKS'), findsNothing);
    expect(find.text("John's Witness of Christ"), findsNothing);
  });

  testWidgets('Jewish scope: no New Testament results; the '
      'Tanakh browse returns on clear', (tester) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      prefs: const {'ww_tradition': 'jewish'},
    );
    await toLibrary(tester);

    await typeQuery(tester, 'john');
    expect(find.text(noMatchLine), findsOneWidget);
    expect(find.text('John'), findsNothing);

    await typeQuery(tester, 'genesis');
    expect(find.text('Genesis'), findsOneWidget);

    await typeQuery(tester, '');
    expect(find.text('Tanakh'), findsOneWidget);
  });

  testWidgets('Catholic scope: deuterocanon books and chapters '
      'are searchable and open their own surfaces', (tester) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      prefs: const {'ww_tradition': 'catholic'},
      deuteroLoader: loadDeutero,
    );
    await toLibrary(tester);

    await typeQuery(tester, 'tobit');
    expect(find.text('Tobit'), findsOneWidget);
    expect(find.text('14 chapters · Deuterocanon'), findsOneWidget);
    await tester.tap(find.text('Tobit'));
    await navSettle(tester);
    expect(find.byType(DeuteroChapterGrid), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await navSettle(tester);
    expect(find.byType(DeuteroChapterGrid), findsNothing);

    await typeQuery(tester, 'tobit 3');
    expect(find.text('CHAPTERS'), findsOneWidget);
    expect(find.text('Tobit 3'), findsOneWidget);
    await tester.tap(find.text('Tobit 3'));
    await navSettle(tester);
    expect(find.byType(DeuteroReaderScreen), findsOneWidget);
  });

  testWidgets('results render without overflow at text scale 2.0', (
    tester,
  ) async {
    await pumpShell(tester, data: data, texts: texts, textScale: 2.0);
    await toLibrary(tester);

    await typeQuery(tester, 'john');
    expect(find.text('BOOKS'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await typeQuery(tester, 'john 3');
    expect(find.text('CHAPTERS'), findsOneWidget);
    expect(find.text('John 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
