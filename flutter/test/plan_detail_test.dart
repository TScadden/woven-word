import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/plan_detail_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();
  final gospels = wwStudyPlans.firstWhere((p) => p.id == 'gospels');

  String startedJson(String startedOn, List<int> done) => jsonEncode({
    'default': {
      'gospels': {'startedOn': startedOn, 'done': done},
    },
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    DateTime? fixedNow,
    bool disableAnimations = false,
    List<int>? opened,
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
          if (disableAnimations) mq = mq.copyWith(disableAnimations: true);
          return MediaQuery(data: mq, child: child!);
        },
        home: PlanDetailScreen(
          key: const ValueKey('detail-builtin'),
          data: data,
          plan: resolveBuiltinPlan(data, gospels),
          profileId: 'default',
          tradition: WwTradition.none,
          onOpenChapter: (ch) => opened?.add(ch),
          now: () => fixedNow ?? DateTime(2026, 10, 15),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  Future<String?> rawPlans() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(plansPrefsKey);
  }

  bool isToggleKey(Key? k) =>
      k is ValueKey<String> && k.value.startsWith('plan-toggle-');

  testWidgets(
    'not-started: status, start button, no toggles, label tap opens chapter',
    (tester) async {
      final opened = <int>[];
      await pumpDetail(tester, opened: opened);
      expect(find.text('23 days · 89 chapters'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-start')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => isToggleKey(w.key)), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-chapter-929')),
        100,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-chapter-929')));
      expect(opened, [929]);
    },
  );

  testWidgets(
    'start flow: persists startedOn, toggles appear, status and today line',
    (tester) async {
      await pumpDetail(tester, fixedNow: DateTime(2026, 10, 15));
      await tester.tap(find.byKey(const ValueKey('plan-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final decoded = jsonDecode((await rawPlans())!) as Map<String, dynamic>;
      expect(
        decoded['progress']['default']['gospels']['startedOn'],
        '2026-10-15',
      );
      expect(find.text('Day 1 of 23 · 0 of 89 chapters · 0%'), findsOneWidget);
      expect(find.text("TODAY'S READING"), findsOneWidget);
      expect(
        find.text('Matthew 1 · Matthew 2 · Matthew 3 · Matthew 4'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-toggle-929')),
        100,
      );
      expect(find.byKey(const ValueKey('plan-toggle-929')), findsOneWidget);
    },
  );

  testWidgets(
    'toggle flow: persists, percent and semantics update, ungated later day',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDetail(
        tester,
        prefs: {plansPrefsKey: startedJson('2026-10-15', [])},
        fixedNow: DateTime(2026, 10, 15),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-toggle-929')),
        100,
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Mark Matthew 1 as read'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      var decoded = jsonDecode((await rawPlans())!) as Map<String, dynamic>;
      expect(decoded['progress']['default']['gospels']['done'], [929]);
      await tester.scrollUntilVisible(
        find.text('Day 1 of 23 · 1 of 89 chapters · 1%'),
        -100,
      );
      expect(find.text('Day 1 of 23 · 1 of 89 chapters · 1%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-toggle-929')),
        100,
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel('Mark Matthew 1 as not read'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('plan-toggle-929')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      decoded = jsonDecode((await rawPlans())!) as Map<String, dynamic>;
      expect(decoded['progress']['default']['gospels']['done'], isEmpty);

      // Ungated: a later day's chapter toggles too.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-toggle-1017')),
        300,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-toggle-1017')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      decoded = jsonDecode((await rawPlans())!) as Map<String, dynamic>;
      expect(decoded['progress']['default']['gospels']['done'], [1017]);
      semantics.dispose();
    },
  );

  testWidgets(
    'current day: started 10 days ago reads Day 11 with its chapters',
    (tester) async {
      await pumpDetail(
        tester,
        prefs: {plansPrefsKey: startedJson('2026-10-05', [])},
        fixedNow: DateTime(2026, 10, 15),
      );
      expect(find.text('Day 11 of 23 · 0 of 89 chapters · 0%'), findsOneWidget);
      final schedule = resolveBuiltinPlan(data, gospels).schedule;
      final expected = [for (final ch in schedule[10]) data.chapterName(ch)]
          .join(' · ');
      expect(expected, 'Mark 13 · Mark 14 · Mark 15 · Mark 16');
      expect(find.text(expected), findsOneWidget);
    },
  );

  testWidgets(
    'restart flow: dialog props, cancel is byte-identical, confirm resets',
    (tester) async {
      final seed = startedJson('2026-10-15', [929]);
      await pumpDetail(
        tester,
        prefs: {plansPrefsKey: seed},
        fixedNow: DateTime(2026, 10, 15),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-restart')),
        200,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-restart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, WwColors.surfaceHigh);
      expect(dialog.surfaceTintColor, Colors.transparent);
      final shape = dialog.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(WwRadius.sheet));
      expect(find.text('Restart The Gospels?'), findsOneWidget);
      expect(
        find.text(
          'Your check marks for this plan will be cleared, and the plan will return to not started. Your highlights and notes are not affected.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsNothing);
      expect(await rawPlans(), seed);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-restart')),
        200,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-restart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Restart'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));

      final after = await rawPlans();
      expect(PlansStore.parse(after), isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-start')),
        -300,
      );
      expect(find.byKey(const ValueKey('plan-start')), findsOneWidget);
      expect(find.text('23 days · 89 chapters'), findsOneWidget);
    },
  );

  testWidgets('complete state: status, complete line, no today label', (
    tester,
  ) async {
    final all = planChapters(data, gospels);
    await pumpDetail(
      tester,
      prefs: {plansPrefsKey: startedJson('2026-01-01', all)},
      fixedNow: DateTime(2026, 10, 15),
    );
    expect(find.text('Complete · 89 of 89 chapters · 100%'), findsOneWidget);
    expect(
      find.text('You have read every chapter in this plan.'),
      findsOneWidget,
    );
    expect(find.text("TODAY'S READING"), findsNothing);
  });

  testWidgets('reduced motion: restart dialog still appears and functions', (
    tester,
  ) async {
    final seed = startedJson('2026-10-15', []);
    await pumpDetail(
      tester,
      prefs: {plansPrefsKey: seed},
      disableAnimations: true,
      fixedNow: DateTime(2026, 10, 15),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-restart')),
      200,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-restart')));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await rawPlans(), seed);
  });
  // ---- v2 additions (§11.4) ----
  Future<void> pumpCustom(
    WidgetTester tester, {
    required CustomPlanDef def,
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanDetailScreen(
                    key: ValueKey('detail-${def.id}'),
                    data: data,
                    plan: resolveCustomPlan(data, def),
                    profileId: 'default',
                    tradition: WwTradition.none,
                    onOpenChapter: (_) {},
                    now: () => DateTime(2026, 10, 15),
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  Map<String, Object> customPrefs(
    CustomPlanDef def, {
    String startedOn = '2026-10-15',
    List<int> done = const [],
  }) {
    // Build a v2 prefs string through the document API.
    final doc = PlansDocument();
    doc.custom['default'] = [def];
    doc.customSeq['default'] = 1;
    if (startedOn.isNotEmpty) {
      doc.progress['default'] = {
        def.id: PlanProgress(startedOn: startedOn, done: done.toSet()),
      };
    }
    return {plansPrefsKey: PlansStore.encodeDocument(doc)};
  }

  final psalmDef = CustomPlanDef(
    id: 'custom-1',
    name: 'Psalms Start',
    segments: [PlanSegment(book: 18, from: 1, to: 10)],
    pace: PlanPace.days(4),
  );

  testWidgets('pace line: built-in (§11.4.1)', (tester) async {
    await pumpDetail(tester);
    expect(find.text('About 40 verses a day'), findsOneWidget);
  });

  testWidgets('pace line: days-pace custom (§11.4.1)', (tester) async {
    await pumpCustom(
      tester,
      def: psalmDef,
      prefs: customPrefs(psalmDef, startedOn: ''),
    );
    expect(find.text('About 25 verses a day'), findsOneWidget);
  });

  testWidgets('pace line: verses-pace customs (§11.4.1)', (tester) async {
    final five = CustomPlanDef(
      id: 'custom-2',
      name: 'Five',
      segments: [PlanSegment(book: 18, from: 1, to: 10)],
      pace: PlanPace.verses(5),
    );
    await pumpCustom(
      tester,
      def: five,
      prefs: customPrefs(five, startedOn: ''),
    );
    expect(find.text('About 5 verses a day'), findsOneWidget);
  });

  testWidgets('pace line: one-verse custom (§11.4.1)', (tester) async {
    final one = CustomPlanDef(
      id: 'custom-3',
      name: 'One',
      segments: [PlanSegment(book: 18, from: 1, to: 10)],
      pace: PlanPace.verses(1),
    );
    await pumpCustom(
      tester,
      def: one,
      prefs: customPrefs(one, startedOn: ''),
    );
    expect(find.text('About 1 verse a day'), findsOneWidget);
  });

  testWidgets('edit/delete presence matrix (§11.4.3)', (tester) async {
    await pumpDetail(tester);
    expect(find.byKey(const ValueKey('plan-edit')), findsNothing);
    expect(find.byKey(const ValueKey('plan-delete')), findsNothing);
    await pumpCustom(tester, def: psalmDef, prefs: customPrefs(psalmDef));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-edit')),
      200,
    );
    expect(find.byKey(const ValueKey('plan-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-restart')), findsOneWidget);
  });

  testWidgets(
    'delete flow: dialog props, cancel identical, confirm pops (§11.4.4)',
    (tester) async {
      final prefsMap = customPrefs(psalmDef, done: [478]);
      final seed = prefsMap[plansPrefsKey] as String;
      await pumpCustom(tester, def: psalmDef, prefs: prefsMap);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-delete')),
        200,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, WwColors.surfaceHigh);
      expect(dialog.surfaceTintColor, Colors.transparent);
      expect(
        (dialog.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(WwRadius.sheet),
      );
      expect(find.text('Delete Psalms Start?'), findsOneWidget);
      expect(
        find.text(
          'This plan and its check marks will be deleted. Your highlights and notes are not affected.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(await rawPlans(), seed);
      expect(find.byType(PlanDetailScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-delete')),
        200,
      );
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
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PlanDetailScreen), findsNothing);
      final after = PlansStore.parseDocument(await rawPlans());
      expect(after.custom['default'], isNull);
      expect(after.progress['default'], isNull);
      expect(after.customSeq['default'], 1);
    },
  );

  testWidgets('edit round-trip at detail level (§11.4.5)', (tester) async {
    final prefsMap = customPrefs(psalmDef, done: [478, 479, 480, 481, 482]);
    await pumpCustom(tester, def: psalmDef, prefs: prefsMap);
    expect(find.text('Day 1 of 4 · 5 of 10 chapters · 50%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-edit')),
      200,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    // Editor seeded with the name; rename and save.
    await tester.enterText(find.byType(TextField).first, 'Renamed Plan');
    await tester.pump();
    for (var i = 0;
        i < 30 &&
            find.byKey(const ValueKey('plan-editor-save')).evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-editor-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Renamed Plan'), findsWidgets);
    final stored = PlansStore.parseDocument(await rawPlans());
    expect(stored.custom['default']!.single.name, 'Renamed Plan');
    expect(stored.progress['default']!['custom-1']!.done, {
      478,
      479,
      480,
      481,
      482,
    });
  });
}
