import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/plan_editor_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();

  Future<void> pumpEditor(
    WidgetTester tester, {
    CustomPlanDef? initialDef,
    WwTradition tradition = WwTradition.none,
    Map<String, Object> prefs = const {},
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        builder: (context, child) {
          final mq = MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale));
          return MediaQuery(data: mq, child: child!);
        },
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanEditorScreen(
                    data: data,
                    tradition: tradition,
                    profileId: 'default',
                    initialDef: initialDef,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  Future<void> dragUntilHelper(WidgetTester tester, Finder f, double dy) async {
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (f.evaluate().isNotEmpty) {
      await tester.ensureVisible(f);
      await tester.pump();
    }
  }

  Future<void> scrollUpTo(WidgetTester tester, Finder f) =>
      dragUntilHelper(tester, f, 400);

  Future<void> scrollTo(WidgetTester tester, Finder f) =>
      dragUntilHelper(tester, f, -400);

  testWidgets('create defaults (§11.5.1)', (tester) async {
    final semH = tester.ensureSemantics();
    await pumpEditor(tester);
    expect(find.text('New plan'), findsOneWidget);
    // Daily amount selected semantics + verses 40 visible
    // (asserted before scrolling away unbuilds the pace card).
    expect(find.bySemanticsLabel('Daily amount'), findsOneWidget);
    expect(find.text('40'), findsWidgets);
    await scrollTo(tester, find.text('0 chapters · 0 verses · 0 days'));
    expect(find.text('0 chapters · 0 verses · 0 days'), findsOneWidget);
    expect(find.text('Give your plan a name to save it.'), findsOneWidget);
    expect(
      find.text('Choose at least one chapter to save your plan.'),
      findsOneWidget,
    );
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    final save = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('plan-editor-save')),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Save plan'), findsOneWidget);
    semH.dispose();
  });

  testWidgets('live summary + enablement (§11.5.2/3)', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'My Plan');
    await tester.pump();
    // Select Psalms, choose range 1-10.
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-book-18')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-18')));
    await tester.pump();
    await scrollTo(tester, find.text('Chapter range'));
    await tester.tap(find.text('Chapter range'));
    await tester.pump();
    // Last chapter stepper down from 150 to 10: tap decrease 140 times is
    // slow; instead assert summary via whole book first.
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    // Whole Psalms: 150 chapters, 150*10+166 verses... summary must equal engine.
    final draft = CustomPlanDef(
      id: 'custom-0',
      name: 'My Plan',
      segments: [PlanSegment(book: 18, from: 1, to: 150)],
      pace: PlanPace.verses(40),
    );
    final r = resolveCustomPlan(data, draft);
    expect(
      find.text(
        '${r.totalChapters} chapters · ${r.totalVerses} verses · ${r.days} days'
            .replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]},',
            ),
      ),
      findsOneWidget,
    );
    final save = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('plan-editor-save')),
    );
    expect(save.onPressed, isNotNull);
    // Clear name -> disabled + reason (field is at the top;
    // scroll back up to it first).
    await scrollUpTo(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    await scrollTo(tester, find.text('Give your plan a name to save it.'));
    expect(find.text('Give your plan a name to save it.'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    final save2 = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('plan-editor-save')),
    );
    expect(save2.onPressed, isNull);
  });

  testWidgets('literal summary: Psalms 1-10 range (§11.5.2)', (tester) async {
    // Seed via edit mode with the range already in place.
    final def = CustomPlanDef(
      id: 'custom-1',
      name: 'Range Plan',
      segments: [PlanSegment(book: 18, from: 1, to: 10)],
      pace: PlanPace.verses(40),
    );
    // Seed prefs so editor load doesn't wipe; editor seeds from def.
    final doc = PlansDocument();
    doc.custom['default'] = [def];
    doc.customSeq['default'] = 1;
    await pumpEditor(
      tester,
      initialDef: def,
      prefs: {plansPrefsKey: PlansStore.encodeDocument(doc)},
    );
    expect(find.text('Edit plan'), findsOneWidget);
    await scrollTo(tester, find.text('10 chapters · 100 verses · 3 days'));
    expect(find.text('10 chapters · 100 verses · 3 days'), findsOneWidget);
    // Switch to Finish in, set days to 4 (stepper starts at 30 clamped to 10).
    await scrollUpTo(tester, find.text('Finish in'));
    await tester.tap(find.text('Finish in'));
    await tester.pump();
    // days seeded clamped to coverage (10). Decrease to 4.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Decrease days'));
      await tester.pump();
    }
    await scrollTo(tester, find.text('10 chapters · 100 verses · 4 days'));
    expect(find.text('10 chapters · 100 verses · 4 days'), findsOneWidget);
  });

  testWidgets('steppers: verses step/bounds, days re-clamp (§11.5.4)', (
    tester,
  ) async {
    final semH = tester.ensureSemantics();
    await pumpEditor(tester);
    await tester.tap(find.byTooltip('Increase verses per day'));
    await tester.pump();
    expect(find.text('45'), findsWidgets);
    // Days re-clamp: select Gospels books (89 chapters) in Finish-in mode.
    await scrollTo(tester, find.text('Finish in'));
    await tester.tap(find.text('Finish in'));
    await tester.pump();
    for (final b in [39, 40, 41, 42]) {
      await scrollTo(tester, find.byKey(ValueKey('plan-editor-book-$b')));
      await tester.tap(find.byKey(ValueKey('plan-editor-book-$b')));
      await tester.pump();
    }
    await scrollUpTo(tester, find.byTooltip('Increase days'));
    // Days clamped to 1 while coverage was empty at the mode
    // switch; raise it to 30 now that 89 chapters are covered.
    for (var i = 0; i < 29; i++) {
      await tester.tap(find.byTooltip('Increase days'));
      await tester.pump();
    }
    expect(find.text('30'), findsWidgets);
    // Re-clamp: deselect Matthew/Mark/Luke -> 21 chapters left
    // (John), and the days value clamps 30 -> 21 in the same
    // update (summary shows the engine's 21 days).
    for (final b in [39, 40, 41]) {
      await scrollTo(tester, find.byKey(ValueKey('plan-editor-book-$b')));
      await tester.tap(find.byKey(ValueKey('plan-editor-book-$b')));
      await tester.pump();
    }
    await scrollTo(tester, find.text('21 chapters · 210 verses · 21 days'));
    expect(find.text('21 chapters · 210 verses · 21 days'), findsOneWidget);
    // Empty coverage floors days to 1 (spec §6.4); selecting
    // Ruth (4 chapters) then shows 1 day.
    await scrollUpTo(tester, find.byKey(const ValueKey('plan-editor-book-42')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-42')));
    await tester.pump();
    await scrollUpTo(tester, find.byKey(const ValueKey('plan-editor-book-7')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-7')));
    await tester.pump();
    await scrollTo(tester, find.text('4 chapters · 40 verses · 1 days'));
    expect(find.text('4 chapters · 40 verses · 1 days'), findsOneWidget);
    semH.dispose();
  });

  testWidgets('verses stepper upper bound (§11.5.4)', (tester) async {
    final def = CustomPlanDef(
      id: 'custom-1',
      name: 'Maxed',
      segments: [PlanSegment(book: 18, from: 1, to: 10)],
      pace: PlanPace.verses(200),
    );
    final doc = PlansDocument();
    doc.custom['default'] = [def];
    doc.customSeq['default'] = 1;
    await pumpEditor(
      tester,
      initialDef: def,
      prefs: {plansPrefsKey: PlansStore.encodeDocument(doc)},
    );
    // At the bound the button is disabled: tapping it (the
    // tooltip wraps the button, same center) changes nothing.
    await tester.tap(find.byTooltip('Increase verses per day'));
    await tester.pump();
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('verses stepper lower bound (§11.5.4)', (tester) async {
    final def5 = CustomPlanDef(
      id: 'custom-1',
      name: 'Minned',
      segments: [PlanSegment(book: 18, from: 1, to: 10)],
      pace: PlanPace.verses(5),
    );
    final doc5 = PlansDocument();
    doc5.custom['default'] = [def5];
    doc5.customSeq['default'] = 1;
    await pumpEditor(
      tester,
      initialDef: def5,
      prefs: {plansPrefsKey: PlansStore.encodeDocument(doc5)},
    );
    await tester.tap(find.byTooltip('Decrease verses per day'));
    await tester.pump();
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('range steppers clamp each other (§11.5.5)', (tester) async {
    await pumpEditor(tester);
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-book-39')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-39')));
    await tester.pump();
    await scrollTo(tester, find.text('Chapter range'));
    await tester.tap(find.text('Chapter range'));
    await tester.pump();
    await scrollTo(tester, find.text('First chapter'));
    expect(find.text('First chapter'), findsOneWidget);
    expect(find.text('Last chapter'), findsOneWidget);
    // First can rise at most to Last (28); decrease Last disabled at == First after raising.
    for (var i = 0; i < 30; i++) {
      await tester.tap(find.byTooltip('Increase first chapter for Matthew'));
      await tester.pump();
    }
    // First == Last == 28: decreasing Last is disabled, so
    // tapping it leaves both values at 28 (two '28' texts:
    // First and Last stepper values).
    await tester.tap(find.byTooltip('Decrease last chapter for Matthew'));
    await tester.pump();
    expect(find.text('28'), findsNWidgets(2));
  });

  testWidgets('create save: trimmed name, v2 shape, pops (§11.5.6)', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.enterText(find.byType(TextField).first, '  Trimmed Name  ');
    await tester.pump();
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-book-0')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-0')));
    await tester.pump();
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlanEditorScreen), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(prefs.getString(plansPrefsKey)!) as Map<String, dynamic>;
    expect(decoded.keys, ['version', 'progress', 'custom', 'customSeq']);
    final def0 = ((decoded['custom'] as Map)['default'] as List).first as Map;
    expect(def0['id'], 'custom-1');
    expect(def0['name'], 'Trimmed Name');
    expect(decoded['customSeq'], {'default': 1});
  });

  testWidgets('edit seeding + unchanged save deep-equals (§11.5.7)', (
    tester,
  ) async {
    final def = CustomPlanDef(
      id: 'custom-3',
      name: 'Seeded',
      segments: [PlanSegment(book: 39, from: 2, to: 5)],
      pace: PlanPace.days(12),
    );
    final doc = PlansDocument();
    doc.custom['default'] = [def];
    doc.customSeq['default'] = 3;
    final seed = PlansStore.encodeDocument(doc);
    await pumpEditor(tester, initialDef: def, prefs: {plansPrefsKey: seed});
    expect(find.text('Seeded'), findsWidgets);
    final semH = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Finish in'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    final after = PlansStore.parseDocument(prefs.getString(plansPrefsKey));
    // Name/id/segments/position survive verbatim; the days
    // pace is seeded clamped to the coverage count (12 -> 4,
    // spec §6.1 seeding rule), so that is the saved pace.
    expect(
      after.custom['default']!.single,
      CustomPlanDef(
        id: def.id,
        name: def.name,
        segments: def.segments,
        pace: PlanPace.days(4),
      ),
    );
    semH.dispose();
  });

  testWidgets('multi-segment book collapses to bounding range (§11.5.7)', (
    tester,
  ) async {
    final def = CustomPlanDef(
      id: 'custom-1',
      name: 'Multi',
      segments: [
        PlanSegment(book: 18, from: 2, to: 4),
        PlanSegment(book: 18, from: 8, to: 10),
      ],
      pace: PlanPace.verses(40),
    );
    final doc = PlansDocument();
    doc.custom['default'] = [def];
    doc.customSeq['default'] = 1;
    await pumpEditor(
      tester,
      initialDef: def,
      prefs: {plansPrefsKey: PlansStore.encodeDocument(doc)},
    );
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    final after = PlansStore.parseDocument(prefs.getString(plansPrefsKey));
    expect(after.custom['default']!.single.segments, [
      PlanSegment(book: 18, from: 2, to: 10),
    ]);
  });

  testWidgets('carried out-of-canon segment survives save (§11.5.7)', (
    tester,
  ) async {
    final def = CustomPlanDef(
      id: 'custom-1',
      name: 'Mixed',
      segments: [
        PlanSegment(book: 18, from: 1, to: 3),
        PlanSegment(book: 39, from: 1, to: 2),
      ],
      pace: PlanPace.verses(40),
    );
    final doc = PlansDocument();
    doc.custom['default'] = [def];
    doc.customSeq['default'] = 1;
    await pumpEditor(
      tester,
      initialDef: def,
      tradition: WwTradition.jewish,
      prefs: {plansPrefsKey: PlansStore.encodeDocument(doc)},
    );
    await tester.enterText(find.byType(TextField).first, 'Mixed Edited');
    await tester.pump();
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    final after = PlansStore.parseDocument(prefs.getString(plansPrefsKey));
    final saved = after.custom['default']!.single;
    expect(saved.name, 'Mixed Edited');
    expect(saved.segments.last, PlanSegment(book: 39, from: 1, to: 2));
  });

  testWidgets('no-save exits write nothing (§11.5.8)', (tester) async {
    const seed = '{"version":2,"progress":{},"custom":{},"customSeq":{}}';
    await pumpEditor(tester, prefs: {plansPrefsKey: seed});
    await tester.enterText(find.byType(TextField).first, 'Dirty');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(plansPrefsKey), seed);
  });

  testWidgets('canon scoping (§11.5.9)', (tester) async {
    await pumpEditor(tester, tradition: WwTradition.jewish);
    expect(find.byKey(const ValueKey('plan-editor-book-39')), findsNothing);
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-book-18')));
    expect(find.byKey(const ValueKey('plan-editor-book-18')), findsOneWidget);
  });

  testWidgets('geometry at text scale 2.0 (§11.5.10)', (tester) async {
    await pumpEditor(tester, textScale: 2.0);
    await tester.enterText(find.byType(TextField).first, 'Geo');
    await tester.pump();
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-book-18')));
    await tester.tap(find.byKey(const ValueKey('plan-editor-book-18')));
    await tester.pump();
    await scrollTo(tester, find.text('Chapter range'));
    await tester.tap(find.text('Chapter range'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final tip in [
      'Decrease first chapter for Psalms',
      'Increase last chapter for Psalms',
    ]) {
      await scrollTo(tester, find.byTooltip(tip));
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.height >= 48, isTrue, reason: tip);
    }
    await scrollTo(tester, find.byKey(const ValueKey('plan-editor-save')));
    final saveSize = tester.getSize(
      find.byKey(const ValueKey('plan-editor-save')),
    );
    expect(saveSize.height >= 48, isTrue);
        expect(tester.takeException(), isNull);
  });
}
