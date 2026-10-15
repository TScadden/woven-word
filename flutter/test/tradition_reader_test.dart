import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/confession_data.dart';
import 'package:woven_word/data/screen_state.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/sefaria_data.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/reader_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// Board run 9: the reader under a tradition — the connections
/// sheet's tradition sections and link-outs, the translation
/// toggle's per-tradition/per-testament set, Hebrew RTL, and
/// the Bible-only sheet staying byte-for-byte the shipped one.
class TraditionTestHost extends TestReaderHost implements TraditionHost {
  TraditionTestHost(super.data, super.screen);

  @override
  WwTradition tradition = WwTradition.none;

  @override
  SefariaData? sefariaData;

  @override
  ConfessionData? confessionData;

  final openedUrls = <String>[];

  @override
  void openExternalLink(String url) => openedUrls.add(url);
}

String textJson(BibleData data, String tag, {bool otOnly = false}) {
  final byBook = <int, List<List<String>>>{};
  for (var gi = 0; gi < data.chapters.length; gi++) {
    final ch = data.chapters[gi];
    byBook.putIfAbsent(ch.b, () => []).add([
      for (var v = 1; v <= ch.v; v++)
        '$tag ${data.chapterName(gi)}:$v text of the verse',
    ]);
  }
  return jsonEncode([
    for (var b = 0; b < 66; b++)
      if (otOnly && b >= 39) <List<String>>[] else byBook[b] ?? [],
  ]);
}

/// WEBC texts shaped like the bundled edition: every core book
/// except Esther (16) and Daniel (26), which the edition carries
/// only as Greek extras, mapped by a webc_books table.
ScriptureText webcTexts(BibleData data) {
  const missing = {16, 26};
  final all = jsonDecode(textJson(data, 'WEBC')) as List;
  final order = [for (var b = 0; b < 66; b++) if (!missing.contains(b)) b];
  return ScriptureText.fromPayloads(
    kjv: textJson(data, 'KJV'),
    web: textJson(data, 'WEB'),
    webc: jsonEncode([for (final b in order) all[b]]),
    webcBooks: jsonEncode([for (final b in order) {'core': b}]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;
  late SefariaData sefaria;
  late ConfessionData confessions;

  setUp(() {
    data = fakeReaderData();
    texts = ScriptureText.fromPayloads(
      kjv: textJson(data, 'KJV'),
      web: textJson(data, 'WEB'),
      jps: textJson(data, 'JPS', otOnly: true),
      hebrew: textJson(data, 'HEB', otOnly: true),
    );
    final counts = [for (final c in data.chapters) c.v];
    sefaria = SefariaData.parse(
      jsonEncode({
        'v': 1,
        'works': ['Mishnah Berakhot'],
        'links': [
          [0, 1, 0, 2],
          [0, 3, 0, 1],
        ],
      }),
      chapterVerseCounts: counts,
    );
    confessions = ConfessionData.parse(
      jsonEncode({
        'v': 1,
        'docs': [
          {
            'id': 'wcf',
            'title': 'Westminster Confession of Faith',
            'year': 1647,
            'url': 'https://example.org/wcf',
          },
        ],
        'sections': [
          {
            'd': 0,
            'id': '1.1',
            'label': 'Chapter 1 · Section 1',
            'u': 'https://example.org/wcf/1.1',
          },
        ],
        'edges': [
          [0, 0, 1],
        ],
      }),
      chapterVerseCounts: counts,
    );
  });

  Future<TraditionTestHost> pumpTraditionReader(
    WidgetTester tester, {
    required WwTradition tradition,
    int startChapter = 0,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final screen = ReadingScreen(
      id: 1,
      bookIndex: data.chapters[startChapter].b,
      globalChapter: startChapter,
    );
    final host = TraditionTestHost(data, screen)
      ..tradition = tradition
      ..sefariaData = sefaria
      ..confessionData = confessions;
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
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

  Future<void> openSheet(
    WidgetTester tester,
    TraditionTestHost host, {
    int ch = 0,
    int v = 1,
  }) async {
    final ctx = host.state.verseContext(ch, v);
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, duration: Duration.zero);
      await tester.pump();
    }
    await tester.tap(
      find.descendant(
        of: chapterPage(ch),
        matching: find.textContaining('${data.chapterName(ch)}:$v text'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    final connCount = data.verseConnections(ch, v).length;
    await tester.tap(find.text('Connections · $connCount'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Finder sheet(Finder matching) =>
      find.descendant(of: find.byType(BottomSheet), matching: matching);

  testWidgets('jewish: the sheet gains an On Sefaria section; '
      'its row opens the work on Sefaria', (tester) async {
    final semantics = tester.ensureSemantics();
    final host = await pumpTraditionReader(tester, tradition: WwTradition.jewish);
    await openSheet(tester, host);
    expect(sheet(find.text('Connections')), findsOneWidget);
    expect(sheet(find.text('On Sefaria')), findsOneWidget);
    expect(sheet(find.text('Mishnah Berakhot')), findsOneWidget);
    expect(sheet(find.text('2 links')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Open Mishnah Berakhot on Sefaria'),
      findsOneWidget,
    );
    await tester.tap(sheet(find.text('Mishnah Berakhot')));
    await tester.pump();
    expect(host.openedUrls, [
      'https://www.sefaria.org/Mishnah_Berakhot.Genesis.1.1',
    ]);
    semantics.dispose();
  });

  testWidgets('jewish capped verse: the sheet says so and '
      'links to all of them', (tester) async {
    // Rebuild the host's dataset with a capped Genesis 1:1.
    final capped = SefariaData.parse(
      jsonEncode({
        'v': 1,
        'works': ['Mishnah Berakhot'],
        'links': [
          [0, 1, 0, 2],
        ],
        'capped': {'0:1': 42},
      }),
      chapterVerseCounts: [for (final c in data.chapters) c.v],
    );
    final host = await pumpTraditionReader(
      tester,
      tradition: WwTradition.jewish,
    );
    host.sefariaData = capped;
    await openSheet(tester, host);
    expect(sheet(find.text('See all 42 links on Sefaria')), findsOneWidget);
    await tester.tap(sheet(find.text('See all 42 links on Sefaria')));
    await tester.pump();
    expect(host.openedUrls, ['https://www.sefaria.org/Genesis.1.1']);
  });

  testWidgets('jewish: a verse without links reads so, plainly', (
    tester,
  ) async {
    final host = await pumpTraditionReader(tester, tradition: WwTradition.jewish);
    await openSheet(tester, host, v: 2);
    expect(sheet(find.text('On Sefaria')), findsOneWidget);
    expect(
      sheet(find.text('No Sefaria links are recorded for this verse.')),
      findsOneWidget,
    );
  });

  testWidgets('protestant: the sheet gains Confession proofs; '
      'its row opens the section at its host', (tester) async {
    final host = await pumpTraditionReader(
      tester,
      tradition: WwTradition.protestant,
    );
    await openSheet(tester, host);
    expect(sheet(find.text('Confession proofs')), findsOneWidget);
    expect(
      sheet(find.text('Westminster Confession of Faith')),
      findsOneWidget,
    );
    expect(
      sheet(find.text('Chapter 1 · Section 1 · proof text')),
      findsOneWidget,
    );
    await tester.tap(sheet(find.text('Westminster Confession of Faith')));
    await tester.pump();
    expect(host.openedUrls, ['https://example.org/wcf/1.1']);
  });

  testWidgets('none: the shipped sheet, no tradition sections', (
    tester,
  ) async {
    final host = await pumpTraditionReader(tester, tradition: WwTradition.none);
    await openSheet(tester, host);
    expect(sheet(find.text('Connections')), findsOneWidget);
    expect(sheet(find.text('On Sefaria')), findsNothing);
    expect(sheet(find.text('Confession proofs')), findsNothing);
    expect(sheet(find.text('Conference talks')), findsNothing);
  });

  /// Selects a translation through the >3-option chip menu:
  /// tap the chip (it shows the current compact label), then the
  /// item carrying the translation's full label.
  Future<void> selectViaMenu(
    WidgetTester tester,
    String chipLabel,
    String itemLabel,
  ) async {
    await tester.tap(find.text(chipLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text(itemLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets('jewish toggle: four options ride a chip menu on '
      'the OT; a JPS pick re-renders the page; the NT offers '
      'neither', (tester) async {
    final host = await pumpTraditionReader(tester, tradition: WwTradition.jewish);
    // The chip shows the current translation's compact label;
    // the full set appears only in the menu it opens.
    expect(find.text('JPS'), findsNothing);
    await tester.tap(find.text('KJV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('JPS'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    await tester.tap(find.text('JPS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.descendant(
        of: chapterPage(0),
        matching: find.textContaining('JPS Genesis 1:1 text'),
      ),
      findsOneWidget,
    );
    // Jump to John 1: the Tanakh translations leave the toggle
    // and the page renders the KJV text.
    final john = data.books[42].start;
    host.openChapter(john, verse: 1);
    await settleReader(tester, host);
    expect(find.text('JPS'), findsNothing);
    expect(find.text('Hebrew'), findsNothing);
    expect(
      find.descendant(
        of: chapterPage(john),
        matching: find.textContaining('KJV John 1:1 text'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hebrew renders right-to-left', (tester) async {
    final host = await pumpTraditionReader(tester, tradition: WwTradition.jewish);
    await selectViaMenu(tester, 'KJV', 'Hebrew');
    final verseText = tester.widget<Text>(
      find.descendant(
        of: chapterPage(0),
        matching: find.textContaining('HEB Genesis 1:1 text'),
      ),
    );
    expect(verseText.textDirection, TextDirection.rtl);
    expect(host.state.currentChapter, 0);
  });

  testWidgets('catholic: WEBC on Esther names the KJV fallback '
      'and points to the Greek Esther', (tester) async {
    texts = webcTexts(data);
    final esther = data.books[16].start;
    await pumpTraditionReader(
      tester,
      tradition: WwTradition.catholic,
      startChapter: esther,
    );
    // KJV is showing: no disclosure.
    expect(
      find.textContaining('Shown in the King James Version'),
      findsNothing,
    );
    await tester.tap(find.text('WEBC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(
      find.textContaining('Shown in the King James Version'),
      findsOneWidget,
    );
    expect(find.textContaining('Greek Esther'), findsOneWidget);
    // The verses on the page are the KJV fallback text.
    expect(
      find.descendant(
        of: chapterPage(esther),
        matching: find.textContaining('KJV Esther 1:1 text'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('catholic: WEBC on Daniel names the KJV fallback; '
      'WEBC on Genesis carries no disclosure', (tester) async {
    texts = webcTexts(data);
    final host = await pumpTraditionReader(
      tester,
      tradition: WwTradition.catholic,
    );
    await tester.tap(find.text('WEBC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(
      find.descendant(
        of: chapterPage(0),
        matching: find.textContaining('WEBC Genesis 1:1 text'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Shown in the King James Version'),
      findsNothing,
    );
    final daniel = data.books[26].start;
    host.openChapter(daniel, verse: 1);
    await settleReader(tester, host);
    expect(
      find.textContaining('Shown in the King James Version'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Daniel with the Greek portions'),
      findsOneWidget,
    );
  });
}
