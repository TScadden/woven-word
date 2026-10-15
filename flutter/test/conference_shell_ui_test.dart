import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/conference_screens.dart';
import 'package:woven_word/screens/shell_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'shell_pump.dart';

/// Board run 8: the conference layer end-to-end in the real
/// shell — the OFF contract at the Library root (gate item 1),
/// enabling from Profiles (§2 in situ), the browse chain with
/// one-level Back at each level (§4.5), the sheet landing on the
/// talk view with its talks list beneath (§3.3/§4.5), and the
/// whole flow under reduced motion (§8).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  late ScriptureText texts;
  late String fixture;

  setUp(() {
    data = fakeReaderData();
    texts = fakeReaderTexts(data);
    fixture = File('test/fixtures/conference_fixture.json').readAsStringSync();
  });

  Future<void> pumpConfShell(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool disableAnimations = false,
    bool emptyDataset = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
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
        home: WwShell(
          dataLoader: () async => data,
          textsLoader: () async => texts,
          conferenceLoader: (canon) async => emptyDataset
              ? ConferenceData.parse(
                  '{"v":1,"talks":[],"edges":[]}',
                  chapterVerseCounts: [for (final c in canon.chapters) c.v],
                  chapters: canon.chapters,
                )
              : ConferenceData.fromCanon(fixture, canon),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  Future<void> navSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets('OFF root, enable in Profiles, browse chain, '
      'one-level Back at each level', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpConfShell(tester);

    // OFF contract (gate item 1): the Library root is shipped.
    await tapTab(tester, 'Library');
    await navSettle(tester);
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);
    expect(find.text('General Conference'), findsNothing);

    // Enable from Profiles (§2 in situ). Board run 9 re-map:
    // the conference toggle is the Latter-day Saint tradition
    // row now — same flow, same assertions, new surface.
    await tapTab(tester, 'Home');
    await tester.tap(find.byTooltip('Profiles'));
    await navSettle(tester);
    await tester.scrollUntilVisible(find.text('Latter-day Saint'), 100);
    await tester.pump();
    var node = tester.getSemantics(
      find.bySemanticsLabel('Latter-day Saint'),
    );
    expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);
    await tester.tap(find.text('Latter-day Saint'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    node = tester.getSemantics(find.bySemanticsLabel('Latter-day Saint'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ww_tradition'), 'lds');

    // Back to Home root, then Library: the tile is there, counted.
    await tester.tap(find.byTooltip('Back'));
    await navSettle(tester);
    await tapTab(tester, 'Library');
    await navSettle(tester);
    expect(find.text('General Conference'), findsOneWidget);
    expect(find.text('5 conferences · 8 talks'), findsOneWidget);
    expect(
      find.bySemanticsLabel('General Conference, 5 conferences, 8 talks'),
      findsOneWidget,
    );

    // Tile → conferences list.
    await tester.tap(find.text('General Conference'));
    await navSettle(tester);
    expect(
      find.text(
        'Newest first. Talk counts include only talks that cite '
        'the Bible.',
      ),
      findsOneWidget,
    );
    expect(find.text('October 2024'), findsOneWidget);

    // Conference row → talks list (dataset order).
    await tester.tap(
      find.bySemanticsLabel('Open October 2024 conference, 3 talks'),
    );
    await navSettle(tester);
    expect(
      find.text(
        'The Words of Christ and the Holy Ghost Will Lead Us to '
        'the Truth',
      ),
      findsOneWidget,
    );

    // Talk row → talk view.
    await tester.tap(
      find.bySemanticsLabel(
        'Open talk: The Words of Christ and the Holy Ghost Will '
        'Lead Us to the Truth, by Takashi Wada',
      ),
    );
    await navSettle(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('Scriptures cited'), findsOneWidget);
    expect(find.text('Read in Gospel Library'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('John 1:9'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(TalkViewScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    expect(find.text('John 1:9'), findsOneWidget);

    // A scripture row opens the reader at that verse (§4.4.2):
    // the shell switches to the Screens tab's reader.
    await tester.tap(find.bySemanticsLabel('Open John 1:9'));
    await navSettle(tester);
    await settleLanding(tester);
    expect(readerPager(), findsOneWidget);

    // Back to Library: the stack was left exactly as it was —
    // the talk view is still on top (still scrolled to the row
    // that was tapped, so its John 1:9 row is the visible part).
    await tapTab(tester, 'Library');
    await navSettle(tester);
    expect(find.byType(TalkViewScreen), findsOneWidget);
    expect(find.text('John 1:9'), findsOneWidget);

    // Back pops ONE level per tap (§4.5): talks, conferences,
    // root.
    await tester.tap(find.byTooltip('Back'));
    await navSettle(tester);
    expect(
      find.text(
        'The Words of Christ and the Holy Ghost Will Lead Us to '
        'the Truth',
      ),
      findsOneWidget,
    );
    expect(find.text('Scriptures cited'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await navSettle(tester);
    expect(
      find.text(
        'Newest first. Talk counts include only talks that cite '
        'the Bible.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await navSettle(tester);
    expect(find.text('General Conference'), findsOneWidget);
    expect(find.text('Old Testament'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('sheet talk row lands on the talk view with its '
      'talks list beneath (§3.3)', (tester) async {
    await pumpConfShell(tester, prefs: const {'ww_conference_layer': true});
    await openViaSearch(tester, 'Genesis 1');
    // Verse 1 → toolbar → connections sheet (layer ON).
    final verseFinder = find.descendant(
      of: chapterPage(0),
      matching: find.textContaining('KJV Genesis 1:1 '),
    );
    await tester.tap(verseFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    await tester.tap(find.text('Connections · 3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Conference talks'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(
        'Open talk: Be Still, and Know That I Am God, by David A. '
        'Bednar, October 2024',
      ),
      60,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(
      find.bySemanticsLabel(
        'Open talk: Be Still, and Know That I Am God, by David A. '
        'Bednar, October 2024',
      ),
    );
    await navSettle(tester);
    await tester.pump();
    await tester.pump();
    // The talk view is on the Library stack…
    expect(find.text('Scriptures cited'), findsOneWidget);
    expect(find.text('Be Still, and Know That I Am God'), findsWidgets);
    // …and Back lands on its conference's talks list (§4.5).
    await tester.tap(find.byTooltip('Back'));
    await navSettle(tester);
    expect(find.text('Live Up to Your Privileges'), findsOneWidget);
    expect(find.text('Scriptures cited'), findsNothing);
  });

  testWidgets('ON with an empty dataset: no tile renders (§4.1 '
      'dataset-empty rule)', (tester) async {
    await pumpConfShell(
      tester,
      prefs: const {'ww_conference_layer': true},
      emptyDataset: true,
    );
    await tapTab(tester, 'Library');
    await navSettle(tester);
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);
    expect(find.text('General Conference'), findsNothing);
  });

  testWidgets('reduced motion: tile, pushes, and sheet all '
      'present content with animations disabled (§8)', (tester) async {
    await pumpConfShell(
      tester,
      prefs: const {'ww_conference_layer': true},
      disableAnimations: true,
    );
    await tapTab(tester, 'Library');
    await tester.pump();
    expect(find.text('General Conference'), findsOneWidget);
    await tester.tap(find.text('General Conference'));
    await navSettle(tester);
    expect(find.text('October 2024'), findsOneWidget);
    await tester.tap(find.text('October 2024'));
    await navSettle(tester);
    expect(find.text('Be Still, and Know That I Am God'), findsOneWidget);
    // Sheet under reduced motion, layer ON.
    await openViaSearch(tester, 'Genesis 1');
    final verseFinder = find.descendant(
      of: chapterPage(0),
      matching: find.textContaining('KJV Genesis 1:1 '),
    );
    await tester.tap(verseFinder);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Connections · 3'));
    await tester.pump();
    expect(find.text('Conference talks'), findsOneWidget);
  });
}
