// HOME ARCH GOES AMBIENT (spec team/specs/arch-ambient-home.md):
// the ambient stage's pool/picker arithmetic, its rotation and
// every pause condition, the caption's exact format, the stage
// tap-through, the selection panel's absence, the retired
// ww_home_selected state, and the chapter partners that now
// live in the reader's connections sheet.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/ambient_stage.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/data/verse_of_day.dart';
import 'package:woven_word/screens/home_tab.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'reader_harness.dart';
import 'shell_pump.dart';

/// A Random whose nextInt returns the given values in cycle,
/// each reduced mod the requested max — deterministic picker
/// draws for widget tests.
class FixedRandom implements math.Random {
  FixedRandom(this.values);
  final List<int> values;
  var _i = 0;
  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

/// A Random that always draws the last index.
class LastRandom implements math.Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();
  final texts = fakeReaderTexts(data);

  // ------------------------------------------------------------ pool

  group('pool arithmetic (spec §2)', () {
    test('median: odd, even, single, empty', () {
      expect(ambientMedianOf(const []), 0);
      expect(ambientMedianOf(const [5]), 5);
      expect(ambientMedianOf(const [1, 3, 2]), 2);
      expect(ambientMedianOf(const [1, 2, 3, 4]), 2.5);
    });

    test('floor excludes sub-floor chapters; canon subset '
        'restricts both the median and the pool', () {
      const counts = [0, 10, 20, 30, 40, 100, 200, 300];
      final all = ambientEligible(counts: counts, inCanon: (_) => true);
      expect(all.median, 35); // (30 + 40) / 2
      expect(all.floor, 8.75);
      expect(all.pool, [1, 2, 3, 4, 5, 6, 7]); // the 0-count is out
      final subset = ambientEligible(
        counts: counts,
        inCanon: (ch) => ch < 4,
      );
      expect(subset.median, 15); // over [0, 10, 20, 30] only
      expect(subset.floor, 3.75);
      expect(subset.pool, [1, 2, 3]);
    });

    test('fake canon: Jewish pool is OT-only; Catholic pool is '
        'the full core pool (spec I-2)', () {
      final none = buildAmbientPool(data, WwTradition.none);
      final jewish = buildAmbientPool(data, WwTradition.jewish);
      final catholic = buildAmbientPool(data, WwTradition.catholic);
      expect(jewish.pool.every((ch) => ch <= 928), isTrue);
      expect(jewish.pool, contains(928)); // Malachi 4
      expect(jewish.pool, isNot(contains(929))); // Matthew 1
      expect(catholic.pool, none.pool);
      expect(ambientRange(data, WwTradition.jewish), (0, 928));
      expect(ambientRange(data, WwTradition.none), (0, 1188));
    });

    test('floor over real-shaped counts: median > 0 excludes '
        'zero-count chapters, keeps low-but-real ones', () {
      // Boost the fake canon: chapters 0..700 gain a self
      // reference (+2 each), so the median lands at 2.
      final json = jsonDecode(fakeReaderJson()) as Map<String, dynamic>;
      final refs = (json['refs'] as List).cast<List<dynamic>>();
      for (var i = 0; i <= 700; i++) {
        refs.add([i, 1, i, 1, 1]);
      }
      json['refs'] = refs;
      final boosted = BibleData.fromJsonString(jsonEncode(json));
      final built = buildAmbientPool(boosted, WwTradition.none);
      final john1 = boosted.books[42].start;
      expect(built.median, 2);
      expect(built.floor, 0.5);
      expect(built.pool.length, 702); // 701 boosted + John 1 (count 1)
      expect(built.pool, isNot(contains(800))); // count 0: excluded
      expect(built.pool, contains(john1));
      expect(built.pool, contains(0));
    });
  });

  group('picker (spec §3)', () {
    test('no immediate repeat over 500 draws; every draw in pool', () {
      final picker = AmbientPicker(math.Random(123));
      final pool = [for (var i = 0; i < 50; i++) i];
      int? current;
      for (var i = 0; i < 500; i++) {
        final next = picker.next(pool, current);
        expect(next, isNotNull);
        expect(pool, contains(next));
        expect(next, isNot(current), reason: 'draw $i repeated');
        current = next;
      }
    });

    test('degenerate pools: empty → null, single → itself', () {
      final picker = AmbientPicker(math.Random(1));
      expect(picker.next(const [], null), isNull);
      expect(picker.next(const [7], 7), 7);
      expect(picker.next(const [7], null), 7);
    });
  });

  test('geometry precompute (spec §7): partner arcs, rank order, '
      'mid-verse positions, counts', () {
    final geometry = buildAmbientArcGeometry(data);
    final ps119 = data.books[18].start + 118;
    final john1 = data.books[42].start;
    final arcs = geometry[0]!;
    expect(arcs.map((a) => a.partner).toList(), [0, ps119, john1]);
    expect(arcs.map((a) => a.count).toList(), [2, 1, 1]);
    expect(arcs.first.fromPos, data.versePos(0, 5));
    expect(arcs.first.toPos, data.versePos(0, 5));
    // Psalms 119's mid verse is 88 (it carries 176 verses).
    expect(
      arcs[1].toPos,
      data.versePos(ps119, (data.chapters[ps119].v / 2).ceil()),
    );
    expect(geometry[800], isNull); // no partners, no entry
  });

  // ------------------------------------------------------- HomeTab

  Future<void> pumpAmbient(
    WidgetTester tester, {
    WwTradition tradition = WwTradition.none,
    bool ambientActive = true,
    math.Random? random,
    bool disableAnimations = false,
    List<int>? opened,
    bool withSections = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
        home: HomeTab(
          dataFuture: Future.value(data),
          userData: UserData(),
          tradition: tradition,
          ambientActive: ambientActive,
          ambientRandom: random,
          resumeBound: true,
          resumeSubtitle: 'Genesis 1',
          notesCount: 0,
          verseOfDay: withSections
              ? VerseOfDayCardData(
                  chapter: 0,
                  verse: 1,
                  reference: 'Genesis 1:1',
                  connectionCount: 716,
                  text: 'In the beginning.',
                  translation: WwTranslation.kjv,
                )
              : null,
          plans: withSections
              ? [
                  PlanCardData(
                    plan: resolveBuiltinPlan(data, wwStudyPlans.first),
                    started: false,
                    doneCount: 0,
                    currentDay: 0,
                    percent: 0,
                  ),
                ]
              : const [],
          highlightsCount: 0,
          onOpenChapter: (ch) => opened?.add(ch),
          onResume: () {},
          onOpenProfiles: () {},
          onOpenMyNotes: () {},
          onOpenVerseOfDay: (_, _) {},
          onOpenPlan: (_) {},
          onCreatePlan: () {},
          onOpenHighlights: () {},
          onRetryLoad: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  String captionOf(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('ambient-caption')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  group('ambient stage (spec §4)', () {
    testWidgets('caption exact format + semantics label + geometry',
        (tester) async {
      await pumpAmbient(tester, random: FixedRandom([0]));
      // Fake canon: Genesis 1's total is 4 (three refs out, one
      // of them also back in) — the format is the founder's:
      // "<Chapter> · <count> connections".
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      expect(find.bySemanticsLabel('Open Genesis 1'), findsOneWidget);
      final stageSize = tester.getSize(
        find.byKey(const ValueKey('ambient-stage')),
      );
      expect(stageSize.width, 360);
      expect(stageSize.height, greaterThan(150)); // stage + caption
      final captionSize = tester.getSize(
        find.byKey(const ValueKey('ambient-caption')),
      );
      expect(captionSize.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rotation advances on the 3s ticker, morph '
        'settles, no immediate repeat', (tester) async {
      await pumpAmbient(tester, random: FixedRandom([0]));
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      await tester.pump(const Duration(seconds: 3));
      // The caption swaps with the feature; the morph is running.
      expect(captionOf(tester), 'Genesis 2 · 0 connections');
      await tester.pump(ambientMorphDuration);
      await tester.pump(const Duration(seconds: 3));
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
    });

    testWidgets('stage and caption taps open the featured chapter',
        (tester) async {
      final opened = <int>[];
      await pumpAmbient(tester, random: FixedRandom([0]), opened: opened);
      await tester.tap(find.byKey(const ValueKey('ambient-stage')));
      expect(opened, [0]);
      await tester.tap(find.text('Genesis 1 · 4 connections'));
      expect(opened, [0, 0]);
    });

    testWidgets('panel ABSENT: no panel widgets or semantics in '
        'the Home tree', (tester) async {
      await pumpAmbient(tester, random: FixedRandom([0]));
      expect(find.text('Connected chapters'), findsNothing);
      expect(find.text('Read Genesis 1'), findsNothing);
      expect(find.byTooltip('Clear selection'), findsNothing);
      expect(find.bySemanticsLabel('Clear selection'), findsNothing);
      expect(find.text('Clear selection'), findsNothing);
    });

    testWidgets('final order (spec §1): stage < caption < resume '
        '< votd < plans < tools, from rendered positions',
        (tester) async {
      await pumpAmbient(
        tester,
        random: FixedRandom([0]),
        withSections: true,
      );
      double dy(Finder f) => tester.getTopLeft(f).dy;
      // Same-stage consecutive pairs (rendered positions are
      // only comparable inside one scroll state): first the
      // pinned stage over the scroll head, then, after scrolling
      // the tail into view, plans over tools.
      final stage = dy(find.byKey(const ValueKey('ambient-stage')));
      final resume = dy(find.text('Continue reading'));
      final votd = dy(find.byKey(const ValueKey('votd-card')));
      expect(stage < resume, isTrue);
      expect(resume < votd, isTrue);
      await tester.scrollUntilVisible(
        find.text('STUDY TOOLS').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final plans = dy(find.text('STUDY PLANS'));
      final tools = dy(find.text('STUDY TOOLS'));
      expect(plans < tools, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pool follows tradition at the stage: last-draw '
        'under Jewish is Malachi 4', (tester) async {
      await pumpAmbient(
        tester,
        tradition: WwTradition.jewish,
        random: LastRandom(),
      );
      expect(captionOf(tester), startsWith('Malachi 4 · '));
    });

    testWidgets('pool follows tradition at the stage: last-draw '
        'under Bible-only is Revelation 22', (tester) async {
      await pumpAmbient(tester, random: LastRandom());
      expect(captionOf(tester), startsWith('Revelation 22 · '));
    });
  });

  group('pause matrix (spec §5)', () {
    testWidgets('tab not selected: no rotation; reselect resumes',
        (tester) async {
      await pumpAmbient(
        tester,
        random: FixedRandom([0]),
        ambientActive: false,
      );
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      await tester.pump(const Duration(seconds: 10));
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      await pumpAmbient(tester, random: FixedRandom([0]));
      await tester.pump(const Duration(seconds: 3));
      expect(captionOf(tester), 'Genesis 2 · 0 connections');
    });

    testWidgets('app backgrounded: no rotation; resume resumes',
        (tester) async {
      await pumpAmbient(tester, random: FixedRandom([0]));
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      // One frame to restart the ticker's clock, then the interval.
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(captionOf(tester), 'Genesis 2 · 0 connections');
    });

    testWidgets('route pushed above Home: no rotation; pop resumes',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          navigatorKey: navKey,
          navigatorObservers: [wwHomeRouteObserver],
          home: HomeTab(
            dataFuture: Future.value(data),
            userData: UserData(),
            tradition: WwTradition.none,
            ambientRandom: FixedRandom([0]),
            resumeBound: true,
            resumeSubtitle: 'Genesis 1',
            notesCount: 0,
            verseOfDay: null,
            plans: const [],
            highlightsCount: 0,
            onOpenChapter: (_) {},
            onResume: () {},
            onOpenProfiles: () {},
            onOpenMyNotes: () {},
            onOpenVerseOfDay: (_, _) {},
            onOpenPlan: (_) {},
            onCreatePlan: () {},
            onOpenHighlights: () {},
            onRetryLoad: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Cover route')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(seconds: 10));
      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // Still the pre-push feature: nothing rotated while covered.
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      await tester.pump(const Duration(seconds: 3));
      expect(captionOf(tester), 'Genesis 2 · 0 connections');
    });

    testWidgets('held scroll drag: no rotation while the user '
        'holds Home; release resumes', (tester) async {
      await pumpAmbient(tester, random: FixedRandom([0]));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(seconds: 10));
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(ambientMorphDuration);
      expect(captionOf(tester), 'Genesis 2 · 0 connections');
    });

    testWidgets('reduced motion: ONE still chapter, no rotation',
        (tester) async {
      await pumpAmbient(
        tester,
        random: FixedRandom([0]),
        disableAnimations: true,
      );
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      await tester.pump(const Duration(seconds: 12));
      expect(captionOf(tester), 'Genesis 1 · 4 connections');
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------- shell

  group('shell integration', () {
    testWidgets('ww_home_selected is removed on load and never '
        'rewritten; ww_home_scope removal unchanged (spec §6)',
        (tester) async {
      await pumpShell(
        tester,
        data: data,
        texts: texts,
        prefs: {'ww_home_selected': 5, 'ww_home_scope': 'ot'},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ww_home_selected'), isNull);
      expect(prefs.getString('ww_home_scope'), isNull);
      // Opening a chapter records the selection in memory only.
      await openViaSearch(tester, 'John 1');
      expect(readerList(), findsOneWidget);
      expect(prefs.getInt('ww_home_selected'), isNull);
    });

    testWidgets('stage tap opens the featured chapter in the '
        'reader through the shell routing', (tester) async {
      await pumpShell(tester, data: data, texts: texts);
      expect(find.byKey(const ValueKey('ambient-stage')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ambient-stage')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(readerList(), findsOneWidget);
    });

    testWidgets('switching tabs pauses rotation; returning '
        'resumes it (fresh interval)', (tester) async {
      await pumpShell(tester, data: data, texts: texts);
      String caption() => captionOf(tester);
      final before = caption();
      await tapTab(tester, 'Library');
      await tester.pump(const Duration(seconds: 10));
      await tapTab(tester, 'Home');
      await tester.pump();
      expect(caption(), before);
    });
  });

  // --------------------------------------------------------- reader

  group('chapter partners in the reader (spec §8)', () {
    testWidgets('sheet chapter section: partners present, ranked, '
        '≥48dp; tapping one routes to that chapter', (tester) async {
      final host = await pumpReader(tester, data: data, texts: texts);
      final ps119 = data.books[18].start + 118;
      final john1 = data.books[42].start;
      await tester.tap(
        find.textContaining('KJV Genesis 1:1 In the beginning verse 1'),
      );
      await settleReader(tester, host);
      await tester.tap(find.text('Connections · 3'));
      await tester.pump();
      // Let the sheet's entrance settle at its final position.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      // The verse section keeps its baseline position at the
      // top of the scroll region (spec §8, as amended).
      expect(find.text('Psalms 119:1'), findsOneWidget);
      // The chapter section closes the scroll region: scroll
      // the sheet's list to its last partner row (the row is
      // not built until the lazy list reaches it).
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('chapter-partner-$john1')),
        100,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Genesis 1 connects to'), findsOneWidget);
      // Ranked as shipped (partnersSorted): the self pair (2)
      // first, then count-1 partners by chapter ascending.
      final keys = [
        const ValueKey('chapter-partner-0'),
        ValueKey('chapter-partner-$ps119'),
        ValueKey('chapter-partner-$john1'),
      ];
      final dys = [
        for (final k in keys) tester.getTopLeft(find.byKey(k)).dy,
      ];
      expect(dys[0] < dys[1] && dys[1] < dys[2], isTrue,
          reason: 'partner rows in ranked order: $dys');
      for (final k in keys) {
        expect(tester.getSize(find.byKey(k)).height,
            greaterThanOrEqualTo(48), reason: '$k');
      }
      await tester.tap(find.byKey(ValueKey('chapter-partner-$john1')));
      await settleReader(tester, host);
      expect(host.state.currentChapter, john1);
      expect(find.text('Genesis 1 connects to'), findsNothing);
    });

    testWidgets('a partnerless chapter still gets its chapter '
        'section — no dead end', (tester) async {
      final exodus1 = data.books[1].start;
      final host = await pumpReader(
        tester,
        data: data,
        texts: texts,
        startChapter: exodus1,
      );
      await tester.tap(
        find.textContaining('KJV Exodus 1:1 In the beginning verse 1'),
      );
      await settleReader(tester, host);
      await tester.tap(find.text('Connections · 0'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Exodus 1 connects to'), findsOneWidget);
      expect(
        find.text('No chapter connections are recorded for this chapter.'),
        findsOneWidget,
      );
      expect(
        find.text('No cross references are recorded for this verse.'),
        findsOneWidget,
      );
    });
  });
}
