import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/plans.dart';
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
          data: data,
          plan: gospels,
          profileId: 'default',
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
      expect(find.text('30 days · 89 chapters'), findsOneWidget);
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
      expect(decoded['default']['gospels']['startedOn'], '2026-10-15');
      expect(find.text('Day 1 of 30 · 0 of 89 chapters · 0%'), findsOneWidget);
      expect(find.text("TODAY'S READING"), findsOneWidget);
      expect(find.text('Matthew 1 · Matthew 2 · Matthew 3'), findsOneWidget);
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
      expect(decoded['default']['gospels']['done'], [929]);
      await tester.scrollUntilVisible(
        find.text('Day 1 of 30 · 1 of 89 chapters · 1%'),
        -100,
      );
      expect(find.text('Day 1 of 30 · 1 of 89 chapters · 1%'), findsOneWidget);
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
      expect(decoded['default']['gospels']['done'], isEmpty);

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
      expect(decoded['default']['gospels']['done'], [1017]);
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
      expect(find.text('Day 11 of 30 · 0 of 89 chapters · 0%'), findsOneWidget);
      final schedule = planSchedule(data, gospels);
      final expected = [for (final ch in schedule[10]) data.chapterName(ch)]
          .join(' · ');
      expect(expected, 'Mark 3 · Mark 4 · Mark 5');
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
      expect(find.text('30 days · 89 chapters'), findsOneWidget);
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
}
