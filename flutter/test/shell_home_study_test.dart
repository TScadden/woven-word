import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/plans.dart';
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
    await pumpShell(
      tester,
      data: data,
      texts: texts,
      deuteroLoader: () async => deutero,
      sefariaLoader: fakeSefaria,
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
    final pick = verseOfDayForDate(data, WwTradition.none, DateTime.now())!;
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
    expect(find.text('30 days · 89 chapters'), findsOneWidget);
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
    expect(find.text('Day 1 of 30 · 0%'), findsOneWidget);

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
    expect(find.text('Day 1 of 30 · 1%'), findsOneWidget);
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
    expect(find.text('Day 1 of 30 · 1%'), findsOneWidget);

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
    expect(find.text('Day 1 of 30 · 1%'), findsOneWidget);
  });

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
}
