import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/sefaria_data.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/data/verse_of_day.dart';
import 'package:woven_word/screens/all_highlights_screen.dart';
import 'package:woven_word/screens/home_tab.dart';
import 'package:woven_word/screens/my_notes_screen.dart';
import 'package:woven_word/screens/plan_detail_screen.dart';
import 'package:woven_word/screens/profiles_screen.dart';
import 'package:woven_word/screens/reader_screen.dart';

import 'bundled_fixture.dart';
import 'fake_canon.dart';
import 'shell_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();
  final texts = fakeReaderTexts(data);
  final deutero = DeuterocanonData.parse(
    jsonEncode({
      'books': [
        {
          'slug': 'tobit',
          'name': 'Tobit',
          'abbr': 'Tob',
          'chapters': 2,
          'verseCounts': [10, 10],
        },
      ],
    }),
  );

  Future<SefariaData> fakeSefaria(canon) async => SefariaData.parse(
    jsonEncode({
      'v': 1,
      'works': ['Mishnah Berakhot'],
      'links': [
        [0, 1, 0, 1],
      ],
    }),
    chapterVerseCounts: [for (final c in canon.chapters) c.v],
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  Finder homeScrollable() => find
      .descendant(of: find.byType(HomeTab), matching: find.byType(Scrollable))
      .first;

  Future<void> scrollHomeTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 120, scrollable: homeScrollable());
    await tester.pump();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Back').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
  }

  testWidgets('routing: tools, plan card, and the verse of the day', (
    tester,
  ) async {
    // The quotable pool's signal (quotable spec §3.2): the real
    // bundled citation counts, computed from the asset directly.
    final counts = ConferenceData.citationCountsFromSource(
      readBundledJson('assets/conference.json.gz'),
      chapterCount: data.chapters.length,
    );
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
      citationCountsLoader: (_) async => counts,
    );
    await settle(tester);

    // Highlights tool -> All Highlights.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-highlights')));
    await tester.tap(find.byKey(const ValueKey('tool-highlights')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.byType(AllHighlightsScreen), findsOneWidget);
    await back(tester);

    // My Notes tool -> My Notes.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-my-notes')));
    await tester.tap(find.byKey(const ValueKey('tool-my-notes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.byType(MyNotesScreen), findsOneWidget);
    await back(tester);

    // Profiles tool -> Profiles.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-profiles')));
    await tester.tap(find.byKey(const ValueKey('tool-profiles')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.byType(ProfilesScreen), findsOneWidget);
    await back(tester);

    // Plan card -> the plan's detail screen.
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    await tester.tap(find.byKey(const ValueKey('plan-cover-gospels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.byType(PlanDetailScreen), findsOneWidget);
    expect(find.text('The Gospels'), findsWidgets);
    await back(tester);

    // Verse of the Day card -> Screens tab, reader open at the pick.
    // The pick comes from the quotable pool built exactly as the
    // shell builds it: real citation counts + the fake texts'
    // KJV verses feeding the §2.3 predicates.
    final pick = verseOfDayForDate(
      data,
      WwTradition.none,
      DateTime.now(),
      citationCount: (ch, v) => counts[(ch, v)] ?? 0,
      kjvText: (ch, v) => texts.verseText(WwTranslation.kjv, data, ch, v),
    )!;
    await scrollHomeTo(tester, find.byKey(const ValueKey('votd-card')));
    await tester.tap(find.byKey(const ValueKey('votd-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.byType(ReaderScreen), findsOneWidget);
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.screen.globalChapter, pick.chapter);
    expect(reader.screen.anchorVerse, pick.verse);
  });

  testWidgets('live plan state: start and check from Home update the card', (
    tester,
  ) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
    );
    await settle(tester);

    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.text('23 days · 89 chapters'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-cover-gospels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.byType(PlanDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-start')));
    await settle(tester);
    await back(tester);

    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.byKey(const ValueKey('plan-progress-gospels')), findsOneWidget);
    expect(find.text('Day 1 of 23 · 0%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-cover-gospels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-toggle-929')),
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
    await settle(tester);
    await back(tester);

    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.text('Day 1 of 23 · 1%'), findsOneWidget);
  });

  testWidgets('tradition dormancy at the shell level', (tester) async {
    final today = DateTime.now();
    final plansJson = jsonEncode({
      'default': {
        'gospels': {
          'startedOn':
              '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          'done': [929],
        },
      },
    });
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      prefs: {plansPrefsKey: plansJson},
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
    );
    await settle(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.byKey(const ValueKey('plan-cover-gospels')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-cover-psalms-proverbs')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-cover-whole-bible')),
      findsOneWidget,
    );
    expect(find.text('Day 1 of 23 · 1%'), findsOneWidget);

    // Switch to Jewish via Profiles.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-profiles')));
    await tester.tap(find.byKey(const ValueKey('tool-profiles')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.byType(ProfilesScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Jewish'), 100);
    await tester.pump();
    await tester.tap(find.text('Jewish'));
    await settle(tester);
    await back(tester);

    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-psalms-proverbs')),
    );
    expect(
      find.byKey(const ValueKey('plan-cover-psalms-proverbs')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-cover-gospels')), findsNothing);
    expect(find.byKey(const ValueKey('plan-cover-whole-bible')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(plansPrefsKey), plansJson);

    // Switch back to Bible only: the Gospels card returns intact.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-profiles')));
    await tester.tap(find.byKey(const ValueKey('tool-profiles')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Bible only'), 100);
    await tester.pump();
    await tester.tap(find.text('Bible only'));
    await settle(tester);
    await back(tester);

    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.byKey(const ValueKey('plan-cover-gospels')), findsOneWidget);
    expect(find.text('Day 1 of 23 · 1%'), findsOneWidget);
  });

  testWidgets(
    'votd gating: no section until counts resolve; failure falls back',
    (tester) async {
      final counts = ConferenceData.citationCountsFromSource(
        readBundledJson('assets/conference.json.gz'),
        chapterCount: data.chapters.length,
      );
      final pending = Completer<Map<(int, int), int>>();
      await pumpShell(
        tester,
        data: data,
        texts: texts,
        deuteroLoader: () async => deutero,
        sefariaLoader: fakeSefaria,
        citationCountsLoader: (_) => pending.future,
      );
      await settle(tester);
      // Texts are loaded but the counts have not resolved: Home
      // renders without the Verse of the Day section (quotable
      // spec §3.3 — no "loading" card, no partial-input pick).
      expect(find.byKey(const ValueKey('votd-card')), findsNothing);
      pending.complete(counts);
      await settle(tester);
      await scrollHomeTo(tester, find.byKey(const ValueKey('votd-card')));
      expect(find.byKey(const ValueKey('votd-card')), findsOneWidget);

      // A failed counts load resolves to the §2.5 fallback pool:
      // the card renders, never an error surface.
      await pumpShell(
        tester,
        data: data,
        texts: texts,
        deuteroLoader: () async => deutero,
        sefariaLoader: fakeSefaria,
        citationCountsLoader: (_) async => throw StateError('no asset'),
      );
      await settle(tester);
      await scrollHomeTo(tester, find.byKey(const ValueKey('votd-card')));
      expect(find.byKey(const ValueKey('votd-card')), findsOneWidget);
    },
  );

  testWidgets('highlights count honesty: active set only, no dormant spans', (
    tester,
  ) async {
    HighlightSpan span(String key) => HighlightSpan(
      verseKey: key,
      start: 0,
      end: 5,
      anchor: 'a',
      color: HlColor.gold,
    );
    final userData = UserData();
    userData.profiles['default'] = ProfileData(
      spans: {
        'kjv': [span('b0c1v1'), span('b1000c1v1')], // core + deuterocanon
        'web': [span('b0c1v2')], // another translation's set
      },
    );
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      prefs: {
        'ww_user_data': jsonEncode(userData.toJson()),
        'ww_translation': 'KJV',
      },
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
    );
    await settle(tester);
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-highlights')));
    // The KJV core span counts; the WEB set's span does not, and
    // the deuterocanon span is dormant under Bible only.
    expect(find.text('1 highlight'), findsOneWidget);
  });
  testWidgets('percent updates both directions, card after pop (§11.6.4/5)', (
    tester,
  ) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
    );
    await settle(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    await tester.tap(find.byKey(const ValueKey('plan-cover-gospels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('plan-start')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-toggle-929')),
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Day 1 of 23 · 1 of 89 chapters · 1%'),
      -100,
    );
    await tester.pump();
    expect(find.text('Day 1 of 23 · 1 of 89 chapters · 1%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-toggle-929')),
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Day 1 of 23 · 0 of 89 chapters · 0%'),
      -100,
    );
    await tester.pump();
    expect(find.text('Day 1 of 23 · 0 of 89 chapters · 0%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-toggle-929')),
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
    await settle(tester);
    await back(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.text('Day 1 of 23 · 1%'), findsOneWidget);
    // Uncheck and return: card shows 0% with progress bar still present.
    await tester.tap(find.byKey(const ValueKey('plan-cover-gospels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-toggle-929')),
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
    await settle(tester);
    await back(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(find.text('Day 1 of 23 · 0%'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-progress-gospels')), findsOneWidget);
  });

  testWidgets('custom lifecycle at shell level (§11.6.6)', (tester) async {
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
    );
    await settle(tester);
    // Create via the tile.
    await scrollHomeTo(tester, find.byKey(const ValueKey('plan-cover-create')));
    await tester.tap(find.byKey(const ValueKey('plan-cover-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.text('New plan'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Shell Custom');
    await tester.pump();
    for (var i = 0;
        i < 30 &&
            find
                .byKey(const ValueKey('plan-editor-book-18'))
                .evaluate()
                .isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('plan-editor-book-18')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-18')));
    await tester.pump();
    for (var i = 0;
        i < 30 &&
            find
                .byKey(const ValueKey('plan-editor-save'))
                .evaluate()
                .isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    // Card appears after built-ins.
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-custom-1')),
    );
    expect(find.text('Shell Custom'), findsWidgets);
    final prefs1 = await SharedPreferences.getInstance();
    final doc1 = PlansStore.parseDocument(prefs1.getString(plansPrefsKey));
    expect(doc1.custom['default']!.single.id, 'custom-1');
    // Open, start, check.
    await tester.tap(find.byKey(const ValueKey('plan-cover-custom-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('plan-start')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-toggle-478')),
      120,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-toggle-478')));
    await settle(tester);
    await back(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-custom-1')),
    );
    // Psalms whole book at 40/day: schedule days derived; percent 1/150 -> 0%? 150 chapters: 1 done = 0%.
    expect(find.textContaining('Day 1 of'), findsWidgets);
    // Delete from detail.
    await tester.tap(find.byKey(const ValueKey('plan-cover-custom-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    final detailList = find.descendant(
      of: find.byType(PlanDetailScreen),
      matching: find.byType(ListView),
    );
    for (var i = 0;
        i < 40 &&
            find.byKey(const ValueKey('plan-delete')).evaluate().isEmpty;
        i++) {
      await tester.drag(detailList, const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(find.byKey(const ValueKey('plan-delete')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await settle(tester);
    expect(find.byKey(const ValueKey('plan-cover-custom-1')), findsNothing);
    expect(find.byKey(const ValueKey('plan-cover-gospels')), findsWidgets);
    expect(find.byKey(const ValueKey('plan-cover-create')), findsOneWidget);
    final prefs2 = await SharedPreferences.getInstance();
    final doc2 = PlansStore.parseDocument(prefs2.getString(plansPrefsKey));
    expect(doc2.custom['default'], isNull);
    expect(doc2.customSeq['default'], 1);
  });

  testWidgets('custom dormancy at shell level (§11.6.7)', (tester) async {
    final today = DateTime.now();
    final key =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = PlansDocument();
    doc.custom['default'] = [
      CustomPlanDef(
        id: 'custom-1',
        name: 'Matt Plan',
        segments: [PlanSegment(book: 39, from: 1, to: 5)],
        pace: PlanPace.verses(40),
      ),
    ];
    doc.customSeq['default'] = 1;
    doc.progress['default'] = {
      'custom-1': PlanProgress(startedOn: key, done: {929}),
    };
    final plansJson = PlansStore.encodeDocument(doc);
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      prefs: {plansPrefsKey: plansJson},
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
    );
    await settle(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-custom-1')),
    );
    expect(find.byKey(const ValueKey('plan-cover-custom-1')), findsOneWidget);
    // Switch to Jewish.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-profiles')));
    await tester.tap(find.byKey(const ValueKey('tool-profiles')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Jewish'), 100);
    await tester.pump();
    await tester.tap(find.text('Jewish'));
    await settle(tester);
    await back(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-psalms-proverbs')),
    );
    expect(find.byKey(const ValueKey('plan-cover-custom-1')), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-cover-psalms-proverbs')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-cover-create')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(plansPrefsKey), plansJson);
    // Switch back.
    await scrollHomeTo(tester, find.byKey(const ValueKey('tool-profiles')));
    await tester.tap(find.byKey(const ValueKey('tool-profiles')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Bible only'), 100);
    await tester.pump();
    await tester.tap(find.text('Bible only'));
    await settle(tester);
    await back(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const ValueKey('plan-cover-custom-1')),
    );
    expect(find.byKey(const ValueKey('plan-cover-custom-1')), findsOneWidget);
    expect(find.text('Day 1 of 2 · 20%'), findsOneWidget);
  });
}
