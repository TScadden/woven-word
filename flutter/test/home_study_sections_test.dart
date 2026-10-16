import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/data/verse_of_day.dart';
import 'package:woven_word/screens/home_tab.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();
  StudyPlanDef def(String id) => wwStudyPlans.firstWhere((p) => p.id == id);

  PlanCardData card(
    String id, {
    bool started = false,
    int done = 0,
    int day = 0,
    int percent = 0,
  }) => PlanCardData(
    plan: resolveBuiltinPlan(data, def(id)),
    started: started,
    doneCount: done,
    currentDay: day,
    percent: percent,
  );

  VerseOfDayCardData votd({
    int chapter = 0,
    int verse = 1,
    String reference = 'Genesis 1:1',
    int count = 716,
    String? text = 'In the beginning God created the heaven and the earth.',
    WwTranslation translation = WwTranslation.kjv,
  }) => VerseOfDayCardData(
    chapter: chapter,
    verse: verse,
    reference: reference,
    connectionCount: count,
    text: text,
    translation: translation,
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    int notesCount = 0,
    int highlightsCount = 0,
    VerseOfDayCardData? verseOfDay,
    List<PlanCardData> plans = const [],
    UserData? userData,
    double textScale = 1.0,
    void Function(int, int)? onVotd,
    void Function(String)? onPlan,
    void Function()? onCreate,
    Map<String, int>? toolTaps,
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        builder: (context, child) {
          final mq = MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale));
          return MediaQuery(data: mq, child: child!);
        },
        home: HomeTab(
          dataFuture: Future.value(data),
          userData: userData ?? UserData(),
          // Ambient rotation is landmarked in
          // arch_ambient_home_test.dart; this suite keeps it
          // paused so the run-11 sections render still.
          tradition: WwTradition.none,
          ambientActive: false,
          resumeBound: true,
          resumeSubtitle: 'Genesis 1',
          notesCount: notesCount,
          verseOfDay: verseOfDay,
          plans: plans,
          highlightsCount: highlightsCount,
          onOpenChapter: (_) {},
          onResume: () {},
          onOpenProfiles: () =>
              toolTaps?['profiles'] = (toolTaps['profiles'] ?? 0) + 1,
          onOpenMyNotes: () =>
              toolTaps?['notes'] = (toolTaps['notes'] ?? 0) + 1,
          onOpenVerseOfDay: onVotd ?? (_, _) {},
          onOpenPlan: onPlan ?? (_) {},
          onCreatePlan: onCreate ?? () {},
          onOpenHighlights: () =>
              toolTaps?['highlights'] = (toolTaps['highlights'] ?? 0) + 1,
          onRetryLoad: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  testWidgets('order: continue < votd < plans < tools (rendered positions)', (
    tester,
  ) async {
    // HOME ARCH GOES AMBIENT translation (lesson 40): the
    // ambient caption band makes the scroll area 48dp taller,
    // so at 360×800 the later sections now start outside the
    // ListView's build cache and the head sections leave it
    // when scrolled to. The order landmark is a sequence
    // claim, so this test pumps a taller viewport (360×1400)
    // where every section is built at once, then takes ALL
    // positions in one snapshot — the shipped assertions,
    // verbatim.
    await pumpHome(
      tester,
      verseOfDay: votd(),
      plans: [card('gospels')],
      size: const Size(360, 1400),
    );
    double dy(Finder f) => tester.getTopLeft(f).dy;
    final resume = dy(find.text('Continue reading'));
    final votdDy = dy(find.byKey(const ValueKey('votd-card')));
    final plansHeader = dy(find.text('STUDY PLANS'));
    final planCard = dy(find.byKey(const ValueKey('plan-cover-gospels')));
    final toolsHeader = dy(find.text('STUDY TOOLS'));
    final toolsCard = dy(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tool-my-notes')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(resume < votdDy, isTrue);
    expect(votdDy < plansHeader, isTrue);
    expect(plansHeader < planCard, isTrue);
    expect(planCard < toolsHeader, isTrue);
    expect(toolsHeader < toolsCard, isTrue);
  });

  testWidgets(
    'panel retired (HOME ARCH GOES AMBIENT, lesson 40 translation): '
    'no selection panel between resume and votd',
    (tester) async {
      // The shipped I-1 test landmarked the selection panel via
      // its Read button. The panel is REMOVED by the founder
      // ruling; the behavior it landmarked (a Home chapter
      // surface that opens reading) is re-landmarked in
      // arch_ambient_home_test.dart (ambient stage order, stage
      // tap opens the featured chapter, panel absent). Here the
      // run-11 order holds WITHOUT any panel: resume directly
      // precedes the Verse of the Day card.
      await pumpHome(tester, verseOfDay: votd(), plans: [card('gospels')]);
      expect(find.text('Read Genesis 1'), findsNothing);
      expect(find.text('Connected chapters'), findsNothing);
      expect(find.byTooltip('Clear selection'), findsNothing);
      final resume = tester.getTopLeft(find.text('Continue reading')).dy;
      final votdDy = tester
          .getTopLeft(find.byKey(const ValueKey('votd-card')))
          .dy;
      expect(resume < votdDy, isTrue);
    },
  );

  testWidgets('retirement: no STUDY header; My Notes appears exactly once', (
    tester,
  ) async {
    await pumpHome(tester, verseOfDay: votd(), plans: [card('gospels')]);
    expect(find.text('STUDY'), findsNothing);
    // Same build-cache translation as the order test above:
    // scroll the tools section into the built range first.
    await tester.scrollUntilVisible(
      find.text('My Notes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('My Notes'), findsOneWidget);
  });

  testWidgets(
    'votd content: verse, reference, grouped count caption; tap opens pick',
    (tester) async {
      (int, int)? opened;
      await pumpHome(
        tester,
        verseOfDay: votd(count: 1189),
        onVotd: (ch, v) => opened = (ch, v),
      );
      expect(
        find.text('In the beginning God created the heaven and the earth.'),
        findsOneWidget,
      );
      expect(find.text('Genesis 1:1'), findsWidgets);
      expect(find.text('1,189 connections'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('votd-card')));
      expect(opened, (0, 1));
    },
  );

  testWidgets('votd count 1 renders the singular caption', (tester) async {
    await pumpHome(tester, verseOfDay: votd(count: 1));
    expect(find.text('1 connection'), findsOneWidget);
  });

  testWidgets('votd loading and failure strings', (tester) async {
    await pumpHome(tester, verseOfDay: votd(text: null));
    expect(find.text("Loading today's verse…"), findsOneWidget);
    await pumpHome(tester, verseOfDay: votd(text: ''));
    expect(
      find.text("Today's verse text could not be loaded."),
      findsOneWidget,
    );
  });

  testWidgets(
    'plan cards: not-started, started, complete captions and progress',
    (tester) async {
      String? openedPlan;
      await pumpHome(
        tester,
        plans: [card('gospels')],
        onPlan: (id) => openedPlan = id,
      );
      expect(find.text('23 days · 89 chapters'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-progress-gospels')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plan-cover-gospels')));
      expect(openedPlan, 'gospels');

      await pumpHome(
        tester,
        plans: [card('gospels', started: true, done: 45, day: 12, percent: 50)],
      );
      expect(find.text('Day 12 of 23 · 50%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-progress-gospels')),
        findsOneWidget,
      );

      await pumpHome(
        tester,
        plans: [
          card('gospels', started: true, done: 89, day: 30, percent: 100),
        ],
      );
      expect(find.text('Complete · 100%'), findsOneWidget);
    },
  );

  testWidgets('plan cards: a single offered plan renders exactly one card', (
    tester,
  ) async {
    await pumpHome(tester, plans: [card('psalms-proverbs')]);
    expect(
      find.byKey(const ValueKey('plan-cover-psalms-proverbs')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-cover-gospels')), findsNothing);
    expect(find.byKey(const ValueKey('plan-cover-whole-bible')), findsNothing);
  });

  testWidgets('tools: captions and taps', (tester) async {
    final taps = <String, int>{};
    await pumpHome(tester, notesCount: 0, highlightsCount: 0, toolTaps: taps);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('No highlights yet'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);

    await pumpHome(tester, notesCount: 1, highlightsCount: 1, toolTaps: taps);
    expect(find.text('1 note'), findsOneWidget);
    expect(find.text('1 highlight'), findsOneWidget);

    await pumpHome(tester, notesCount: 7, highlightsCount: 3, toolTaps: taps);
    expect(find.text('7 notes'), findsOneWidget);
    expect(find.text('3 highlights'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tool-my-notes')));
    await tester.tap(find.byKey(const ValueKey('tool-highlights')));
    await tester.tap(find.byKey(const ValueKey('tool-profiles')));
    expect(taps, {'notes': 1, 'highlights': 1, 'profiles': 1});
  });

  testWidgets('geometry at 360x800, text scale 2.0 (rendered positions)', (
    tester,
  ) async {
    final userData = UserData();
    userData.renameProfile('default', 'A' * 40);
    await pumpHome(
      tester,
      textScale: 2.0,
      userData: userData,
      verseOfDay: votd(
        text: 'A long verse of the day text that keeps wrapping onward.',
      ),
      plans: [card('gospels', started: true, done: 45, day: 12, percent: 50)],
    );
    expect(tester.takeException(), isNull);

    // Section headers sit at the 16dp margin; the VOTD label at
    // margin + card padding.
    await tester.scrollUntilVisible(
      find.text('VERSE OF THE DAY'),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.getTopLeft(find.text('VERSE OF THE DAY')).dx, 16 + 16);
    final verseDy = tester
        .getTopLeft(
          find.text('A long verse of the day text that keeps wrapping onward.'),
        )
        .dy;
    final refDy = tester.getTopLeft(find.text('Genesis 1:1').first).dy;
    expect(refDy > verseDy, isTrue);

    await tester.scrollUntilVisible(
      find.text('STUDY PLANS'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.getTopLeft(find.text('STUDY PLANS')).dx, 16);
    final coverRect = tester.getRect(
      find.byKey(const ValueKey('plan-cover-gospels')),
    );
    expect(coverRect.size, const Size(112, 144));
    final fill = find.descendant(
      of: find.byKey(const ValueKey('plan-progress-gospels')),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.color == WwColors.goldBright,
      ),
    );
    final fillSize = tester.getSize(fill);
    expect(fillSize.width, closeTo(112 * 45 / 89, 0.5));
    expect(fillSize.height, 4);
    final titleRect = tester.getRect(find.text('The Gospels'));
    expect(titleRect.left >= coverRect.left - 0.5, isTrue);
    expect(titleRect.right <= coverRect.left + 112 + 0.5, isTrue);

    await tester.scrollUntilVisible(
      find.text('STUDY TOOLS'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.getTopLeft(find.text('STUDY TOOLS')).dx, 16);
    for (final key in ['tool-my-notes', 'tool-highlights', 'tool-profiles']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width >= 48, isTrue, reason: key);
      expect(size.height >= 48, isTrue, reason: key);
    }
    final toolsCardRect = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tool-my-notes')),
            matching: find.byType(Material),
          )
          .first,
    );
    final centers = [
      for (final icon in [Icons.notes, Icons.highlight, Icons.person_outline])
        tester.getCenter(find.byIcon(icon)).dx,
    ];
    for (var i = 0; i < 3; i++) {
      expect(
        centers[i],
        closeTo(toolsCardRect.left + toolsCardRect.width * (i + 0.5) / 3, 1.0),
        reason: 'icon $i center',
      );
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('create tile: only child when no plans; tap fires (§11.6.1)', (
    tester,
  ) async {
    var taps = 0;
    await pumpHome(tester, plans: const [], onCreate: () => taps++);
    expect(find.text('STUDY PLANS'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-cover-create')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-cover-gospels')), findsNothing);
    expect(find.text('Create your own plan'), findsOneWidget);
    expect(find.text('Choose books and a pace'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Create your own plan, Choose books and a pace'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plan-cover-create')));
    expect(taps, 1);
  });

  testWidgets('create tile sits after the last card (§11.6.1/3)', (
    tester,
  ) async {
    await pumpHome(tester, plans: [card('gospels'), card('psalms-proverbs')]);
    final g = tester
        .getTopLeft(find.byKey(const ValueKey('plan-cover-gospels')))
        .dx;
    final ps = tester
        .getTopLeft(find.byKey(const ValueKey('plan-cover-psalms-proverbs')))
        .dx;
    final tile = tester
        .getTopLeft(find.byKey(const ValueKey('plan-cover-create')))
        .dx;
    expect(g < ps, isTrue);
    expect(ps < tile, isTrue);
  });

  testWidgets('custom cards render like built-ins (§11.6.2)', (tester) async {
    final custom = resolveCustomPlan(
      data,
      CustomPlanDef(
        id: 'custom-1',
        name: 'My Psalms',
        segments: [PlanSegment(book: 18, from: 1, to: 10)],
        pace: PlanPace.verses(40),
      ),
    );
    await pumpHome(
      tester,
      plans: [
        PlanCardData(
          plan: custom,
          started: false,
          doneCount: 0,
          currentDay: 0,
          percent: 0,
        ),
      ],
    );
    expect(find.text('My Psalms'), findsOneWidget);
    expect(find.text('3 days · 10 chapters'), findsOneWidget);
    expect(find.text('Psalms'), findsWidgets);
    await pumpHome(
      tester,
      plans: [
        PlanCardData(
          plan: custom,
          started: true,
          doneCount: 5,
          currentDay: 1,
          percent: 50,
        ),
      ],
    );
    expect(find.text('Day 1 of 3 · 50%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-progress-custom-1')),
      findsOneWidget,
    );
    // 5+ books -> first / ellipsis / last
    final wide = resolveCustomPlan(
      data,
      CustomPlanDef(
        id: 'custom-2',
        name: 'Wide',
        segments: [
          for (final b in [0, 1, 2, 3, 4, 5])
            PlanSegment(book: b, from: 1, to: 1),
        ],
        pace: PlanPace.verses(40),
      ),
    );
    await pumpHome(
      tester,
      plans: [
        PlanCardData(
          plan: wide,
          started: false,
          doneCount: 0,
          currentDay: 0,
          percent: 0,
        ),
      ],
    );
    expect(find.text('Genesis'), findsWidgets);
    expect(find.text('…'), findsOneWidget);
    expect(find.text('Joshua'), findsWidgets);
  });
}
