import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/screen_state.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/reader_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// Board run 8, spec §3 / §7: the reader connections sheet's
/// Conference talks section — OFF byte-for-byte (no section at
/// all), ON inside one scroll region with §3.2 rows (uncapped
/// titles, C-6 speaker lines, no trailing control), §3.3 ordering
/// as rendered, the duplicate rule, the §3.4 empty state, row
/// semantics, and the row tap landing on the talk view seam.
class ConferenceTestHost extends TestReaderHost implements ConferenceHost {
  ConferenceTestHost(super.data, super.screen);

  @override
  bool conferenceEnabled = false;

  @override
  ConferenceData? conferenceData;

  final openedTalks = <ConferenceTalk>[];

  @override
  void openConferenceTalk(ConferenceTalk talk) => openedTalks.add(talk);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;
  late ConferenceData conf;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
    final source = File('test/fixtures/conference_fixture.json')
        .readAsStringSync();
    conf = ConferenceData.fromCanon(source, data);
  });

  String verseText(int ch, int v) => 'KJV ${data.chapterName(ch)}:$v ';
  Finder inPage(int ch, Finder matching) =>
      find.descendant(of: chapterPage(ch), matching: matching);

  Future<ConferenceTestHost> pumpConfReader(
    WidgetTester tester, {
    bool enabled = false,
    bool withData = true,
    bool disableAnimations = false,
    ConferenceData? confOverride,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final screen = ReadingScreen(
      id: 1,
      bookIndex: data.chapters[0].b,
      globalChapter: 0,
    );
    final host = ConferenceTestHost(data, screen)
      ..conferenceEnabled = enabled
      ..conferenceData = withData ? (confOverride ?? conf) : null;
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        builder: (context, child) {
          var mq = MediaQuery.of(context);
          if (disableAnimations) {
            mq = mq.copyWith(disableAnimations: true);
          }
          return MediaQuery(data: mq, child: child!);
        },
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

  /// Taps a verse, then its toolbar Connections button, opening
  /// the sheet (the shipped path into _openConnections).
  Future<void> openSheet(
    WidgetTester tester,
    ConferenceTestHost host, {
    int ch = 0,
    int v = 1,
  }) async {
    // Bring the verse on screen first (a user scrolls to a verse
    // before tapping it; off-screen centers cannot be tapped).
    final ctx = host.state.verseContext(ch, v);
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, duration: Duration.zero);
      await tester.pump();
    }
    await tester.tap(inPage(ch, find.textContaining(verseText(ch, v))));
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

  testWidgets('OFF: the shipped sheet — no Conference talks '
      'text, no talk semantics nodes', (tester) async {
    final semantics = tester.ensureSemantics();
    final host = await pumpConfReader(tester, enabled: false);
    await openSheet(tester, host);
    expect(sheet(find.text('Connections')), findsOneWidget);
    expect(sheet(find.text('Conference talks')), findsNothing);
    expect(
      sheet(find.text('No conference talks are recorded for this verse.')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(
        'Open talk: Be Still, and Know That I Am God, by David A. '
        'Bednar, October 2024',
      ),
      findsNothing,
    );
    expect(host.openedTalks, isEmpty);
    semantics.dispose();
  });

  testWidgets('ON: section below Connections, newest-first as '
      'rendered (October before April within 2024), C-6 speaker '
      'lines, row semantics exact', (tester) async {
    final semantics = tester.ensureSemantics();
    final host = await pumpConfReader(tester, enabled: true);
    await openSheet(tester, host);
    expect(sheet(find.text('Conference talks')), findsOneWidget);
    // The first talk row is built on open: Wada, with its C-6
    // speaker line and its exact §7 semantics node, found
    // exactly once in the semantics tree.
    expect(
      sheet(
        find.text(
          'The Words of Christ and the Holy Ghost Will Lead Us to '
          'the Truth',
        ),
      ),
      findsOneWidget,
    );
    expect(sheet(find.text('Takashi Wada · October 2024')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Open talk: The Words of Christ and the Holy Ghost Will '
        'Lead Us to the Truth, by Takashi Wada, October 2024',
      ),
      findsOneWidget,
    );
    // Ordering AS RENDERED (§3.3): scroll the sheet's one region
    // in steps, recording each talk title's first appearance in
    // rendered (top-to-bottom) order. Genesis 1:1's citers are
    // 2024-O Wada (1), 2024-O Bednar (7), 2024-A Uchtdorf (2),
    // 2024-A Gong (5), 2023-O Cook, 1990-O Nelson — October
    // before April within 2024, and dataset order (id ascending)
    // inside a conference, never title order (fix F-1: title
    // order would put Bednar before Wada).
    const expectedOrder = [
      'The Words of Christ and the Holy Ghost Will Lead Us to '
          'the Truth',
      'Be Still, and Know That I Am God',
      'A Higher Joy',
      'All Things for Our Good',
      'Foundations of Faith',
      'Choices',
    ];
    final seenOrder = <String>[];
    Future<void> collect() async {
      final built = <(double, String)>[];
      for (final title in expectedOrder) {
        final finder = sheet(find.text(title));
        if (finder.evaluate().isNotEmpty) {
          built.add((tester.getTopLeft(finder).dy, title));
        }
      }
      built.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (_, title) in built) {
        if (!seenOrder.contains(title)) seenOrder.add(title);
      }
    }

    await collect();
    for (var i = 0; i < 16 && seenOrder.length < expectedOrder.length; i++) {
      await tester.drag(sheet(find.byType(ListView)), const Offset(0, -80));
      await tester.pump();
      await collect();
    }
    expect(seenOrder, expectedOrder);
    // The April rows carry C-6 speaker lines and §7 semantics too.
    await tester.scrollUntilVisible(
      sheet(find.text('A Higher Joy')),
      100,
      scrollable: sheet(find.byType(Scrollable)).first,
    );
    await tester.pump();
    expect(sheet(find.text('Dieter F. Uchtdorf · April 2024')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Open talk: A Higher Joy, by Dieter F. Uchtdorf, April 2024',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('ON: no trailing control on talk rows — the only '
      'IconButtons in the sheet belong to connection rows', (tester) async {
    final host = await pumpConfReader(tester, enabled: true);
    await openSheet(tester, host);
    // Genesis 1:1 has 3 connections, hence 3 trailing
    // open-in-new-screen buttons. Talk rows add none (§3.2).
    expect(sheet(find.byType(IconButton)), findsNWidgets(3));
    expect(
      sheet(find.byTooltip('Open Psalms 119:1 in new screen')),
      findsOneWidget,
    );
  });

  testWidgets('ON: a talk citing the verse twice renders once, '
      'at the bottom of the scroll region', (tester) async {
    final host = await pumpConfReader(tester, enabled: true);
    await openSheet(tester, host);
    // Talk 0 (Choices, 1990) has its Genesis 1:1 edge duplicated
    // in the raw fixture; the section lists talks, not citations.
    await tester.scrollUntilVisible(
      sheet(find.text('Choices')),
      100,
      scrollable: sheet(find.byType(Scrollable)).first,
    );
    await tester.pump();
    expect(sheet(find.text('Choices')), findsOneWidget);
    expect(
      sheet(find.text('Russell M. Nelson · October 1990')),
      findsOneWidget,
    );
  });

  testWidgets('ON: a talk citing the verse via duplicate and '
      'range edges renders ONE row', (tester) async {
    final semantics = tester.ensureSemantics();
    // One talk whose Genesis 1:1 edge is duplicated verbatim AND
    // arrives as part of a cited range (range edges are emitted
    // verse by verse: 1, 2, 3). Rows are talks, not citations
    // (§3.3 duplicate rule), so the sheet lists it once.
    final ranged = ConferenceData.parse(
      '{"v":1,"talks":[{"i":0,"t":"Range Talk","s":"Range Speaker",'
      '"y":2024,"e":"O","n":"Sunday Morning","u":null,"c":0}],'
      '"edges":[[0,0,1],[0,0,1],[0,0,2],[0,0,3]]}',
      chapterVerseCounts: [for (final c in data.chapters) c.v],
      chapters: data.chapters,
    );
    final host = await pumpConfReader(
      tester,
      enabled: true,
      confOverride: ranged,
    );
    await openSheet(tester, host);
    expect(sheet(find.text('Range Talk')), findsOneWidget);
    expect(sheet(find.text('Range Speaker · October 2024')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Open talk: Range Talk, by Range Speaker, October 2024',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('ON empty: header plus the C-7 line; the section '
      'never collapses to nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    final host = await pumpConfReader(tester, enabled: true);
    // Genesis 1:5: no connections, no talks.
    await openSheet(tester, host, v: 5);
    expect(sheet(find.text('Conference talks')), findsOneWidget);
    expect(
      sheet(find.text('No conference talks are recorded for this verse.')),
      findsOneWidget,
    );
    expect(
      sheet(find.text('No cross references are recorded for this verse.')),
      findsOneWidget,
    );
    // No talk-row node exists in the semantics tree (§3.5 gate:
    // the empty state is the ABSENCE of any talk row).
    expect(find.bySemanticsLabel(RegExp(r'^Open talk:')), findsNothing);
    semantics.dispose();
  });

  testWidgets('ON but dataset unloaded: header plus C-7 (the '
      'layer is on; this verse shows none)', (tester) async {
    final host = await pumpConfReader(tester, enabled: true, withData: false);
    await openSheet(tester, host);
    expect(sheet(find.text('Conference talks')), findsOneWidget);
    expect(
      sheet(find.text('No conference talks are recorded for this verse.')),
      findsOneWidget,
    );
  });

  testWidgets('row tap: sheet pops, the host opens that talk', (tester) async {
    final host = await pumpConfReader(tester, enabled: true);
    await openSheet(tester, host);
    // The first talk row sits low in the sheet's one scroll
    // region; scroll it fully into view before tapping.
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(
        'Open talk: Be Still, and Know That I Am God, by David A. '
        'Bednar, October 2024',
      ),
      60,
      scrollable: sheet(find.byType(Scrollable)).first,
    );
    await tester.pump();
    await tester.tap(
      find.bySemanticsLabel(
        'Open talk: Be Still, and Know That I Am God, by David A. '
        'Bednar, October 2024',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byType(BottomSheet), findsNothing);
    expect(host.openedTalks.map((t) => t.id), [7]);
  });

  testWidgets('reduced motion: the ON sheet presents its '
      'conference section with animations disabled', (tester) async {
    final host = await pumpConfReader(
      tester,
      enabled: true,
      disableAnimations: true,
    );
    await tester.tap(inPage(0, find.textContaining(verseText(0, 1))));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Connections · 3'));
    await tester.pump();
    expect(sheet(find.text('Conference talks')), findsOneWidget);
    expect(
      sheet(
        find.text(
          'The Words of Christ and the Holy Ghost Will Lead Us to '
          'the Truth',
        ),
      ),
      findsOneWidget,
    );
  });
}
