import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/tradition.dart';

import 'fake_canon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();
  StudyPlanDef def(String id) => wwStudyPlans.firstWhere((p) => p.id == id);

  group('planChapters and totals', () {
    test('lengths and first/last chapter names', () {
      final gospels = planChapters(data, def('gospels'));
      final psalms = planChapters(data, def('psalms-proverbs'));
      final whole = planChapters(data, def('whole-bible'));
      expect(gospels.length, 89);
      expect(psalms.length, 181);
      expect(whole.length, 1189);
      expect(data.chapterName(gospels.first), 'Matthew 1');
      expect(data.chapterName(gospels.last), 'John 21');
      expect(data.chapterName(psalms.first), 'Psalms 1');
      expect(data.chapterName(psalms.last), 'Proverbs 31');
      expect(data.chapterName(whole.first), 'Genesis 1');
      expect(data.chapterName(whole.last), 'Revelation 22');
    });
  });

  group('planSchedule distribution (base/remainder, I-2)', () {
    List<int> sizes(String id) =>
        planSchedule(data, def(id)).map((d) => d.length).toList();

    test('exact day-size lists', () {
      expect(sizes('gospels'), [...List.filled(29, 3), 2]);
      expect(sizes('psalms-proverbs'), [4, ...List.filled(59, 3)]);
      expect(sizes('whole-bible'), [
        ...List.filled(94, 4),
        ...List.filled(271, 3),
      ]);
    });

    test('concatenation equals planChapters; no empty day; non-increasing', () {
      for (final plan in wwStudyPlans) {
        final schedule = planSchedule(data, plan);
        expect(
          schedule.expand((d) => d).toList(),
          planChapters(data, plan),
          reason: plan.id,
        );
        expect(schedule.every((d) => d.isNotEmpty), isTrue, reason: plan.id);
        final s = schedule.map((d) => d.length).toList();
        for (var i = 1; i < s.length; i++) {
          expect(s[i] <= s[i - 1], isTrue, reason: '${plan.id} day ${i + 1}');
        }
      }
    });

    test('spot chapters', () {
      final gospels = planSchedule(data, def('gospels'));
      expect(gospels[0], [929, 930, 931]);
      expect(gospels[29], [1016, 1017]);
      final psalms = planSchedule(data, def('psalms-proverbs'));
      expect(psalms[0], [478, 479, 480, 481]);
      expect(psalms[59], [656, 657, 658]);
      final whole = planSchedule(data, def('whole-bible'));
      expect(whole[93].length, 4);
      expect(whole[93].last, 375);
      expect(whole[364], [1186, 1187, 1188]);
    });
  });

  group('PlansStore persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'round-trip: raw JSON shape is exactly §4.5, state deep-equals',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = await PlansStore.load(prefs);
        store.startPlan('default', 'gospels', DateTime(2026, 10, 5));
        store.toggleChapter('default', 'gospels', 931);
        store.toggleChapter('default', 'gospels', 929);
        store.startPlan('default', 'whole-bible', DateTime(2026, 1, 1));
        for (final ch in planChapters(data, def('whole-bible'))) {
          store.toggleChapter('default', 'whole-bible', ch);
        }
        store.startPlan('p2', 'psalms-proverbs', DateTime(2026, 9, 1));
        await store.save();

        final raw = prefs.getString(plansPrefsKey)!;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded.keys, containsAll(['default', 'p2']));
        final gospels = (decoded['default'] as Map)['gospels'] as Map;
        expect(gospels.keys, containsAll(['startedOn', 'done']));
        expect(gospels['startedOn'], '2026-10-05');
        expect(gospels['done'], [929, 931]); // sorted ascending

        final reloaded = await PlansStore.load(prefs);
        expect(reloaded.state, store.state);
        expect(
          reloaded.progressFor('default', 'gospels'),
          PlanProgress(startedOn: '2026-10-05', done: {929, 931}),
        );
        expect(
          reloaded.progressFor('default', 'whole-bible')!.done.length,
          1189,
        );
      },
    );

    test('defensive parse: each malformed input drops only what it must', () {
      expect(PlansStore.parse(null), isEmpty);
      expect(PlansStore.parse('not json'), isEmpty);
      expect(PlansStore.parse('[]'), isEmpty);
      expect(PlansStore.parse('{"p": 42}'), isEmpty);
      expect(PlansStore.parse('{"p": {"gospels": 7}}'), isEmpty);

      const good = '{"startedOn": "2026-10-05", "done": []}';
      for (final bad in [
        '2026-13-01',
        '2026-02-30',
        '15/10/2026',
        '2026-1-5',
        '20261015',
      ]) {
        final parsed = PlansStore.parse(
          '{"p": {"gospels": {"startedOn": "$bad", "done": []}, '
          '"psalms-proverbs": $good}}',
        );
        expect(parsed['p']!.containsKey('gospels'), isFalse, reason: bad);
        expect(
          parsed['p']!.containsKey('psalms-proverbs'),
          isTrue,
          reason: bad,
        );
      }
      final numericStart = PlansStore.parse(
        '{"p": {"gospels": {"startedOn": 20261005, "done": []}}}',
      );
      expect(numericStart, isEmpty);

      final doneNotList = PlansStore.parse(
        '{"p": {"gospels": {"startedOn": "2026-10-05", "done": 42}}}',
      );
      expect(doneNotList, isEmpty);

      final mixedDone = PlansStore.parse(
        '{"p": {"gospels": {"startedOn": "2026-10-05", '
        '"done": [1, "2", -3, 1, 2.5]}}}',
      );
      expect(mixedDone['p']!['gospels']!.done, {1});

      // Unknown ids survive a load/save cycle verbatim.
      const unknown =
          '{"future-profile": {"future-plan": {"startedOn": "2026-01-02", "done": [5]}}}';
      final parsed = PlansStore.parse(unknown);
      expect(jsonDecode(PlansStore.encode(parsed)), jsonDecode(unknown));
    });

    test('mutators', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = await PlansStore.load(prefs);
      store.startPlan('default', 'gospels', DateTime(2026, 10, 5));
      expect(store.progressFor('default', 'gospels')!.startedOn, '2026-10-05');
      await store.save();
      final before = prefs.getString(plansPrefsKey);

      // startPlan on an existing entry is a byte-identical no-op.
      store.startPlan('default', 'gospels', DateTime(2027, 1, 1));
      await store.save();
      expect(prefs.getString(plansPrefsKey), before);
      expect(store.progressFor('default', 'gospels')!.startedOn, '2026-10-05');

      store.toggleChapter('default', 'gospels', 929);
      expect(store.progressFor('default', 'gospels')!.done, {929});
      store.toggleChapter('default', 'gospels', 929);
      expect(store.progressFor('default', 'gospels')!.done, isEmpty);

      // toggleChapter with no entry is a no-op.
      store.toggleChapter('default', 'whole-bible', 0);
      expect(store.progressFor('default', 'whole-bible'), isNull);

      store.restartPlan('default', 'gospels');
      expect(store.state, isEmpty);
      await store.save();
      expect(jsonDecode(prefs.getString(plansPrefsKey)!), <String, dynamic>{});
    });
  });

  group('day arithmetic', () {
    test('planDayFor clamps and defaults', () {
      expect(
        planDayFor(
          startedOn: '2026-10-15',
          today: DateTime(2026, 10, 15),
          days: 30,
        ),
        1,
      );
      expect(
        planDayFor(
          startedOn: '2026-10-20',
          today: DateTime(2026, 10, 15),
          days: 30,
        ),
        1,
      );
      expect(
        planDayFor(
          startedOn: '2026-10-15',
          today: DateTime(2026, 11, 13),
          days: 30,
        ),
        30,
      );
      expect(
        planDayFor(
          startedOn: '2026-10-15',
          today: DateTime(2027, 11, 19),
          days: 30,
        ),
        30,
      );
      expect(
        planDayFor(
          startedOn: 'not-a-date',
          today: DateTime(2026, 10, 15),
          days: 30,
        ),
        1,
      );
    });

    test('planDateKey zero-pads; calendarDaysBetween is DST-immune', () {
      expect(planDateKey(DateTime(2026, 10, 5)), '2026-10-05');
      expect(
        calendarDaysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
        2,
      );
    });

    test('planDoneCount intersects; planPercent floors', () {
      final chapters = planChapters(data, def('gospels'));
      final progress = PlanProgress(
        startedOn: '2026-10-01',
        done: {929, 0, 5000}, // one gospels chapter, one psalms, one bogus
      );
      expect(planDoneCount(progress, chapters), 1);
      expect(planDoneCount(null, chapters), 0);
      expect(planPercent(1, 89), 1);
      expect(planPercent(89, 89), 100);
      expect(planPercent(0, 0), 0);
    });
  });

  group('availability matrix (§4.1)', () {
    test('all 15 cells', () {
      final expected = <WwTradition, Map<String, bool>>{
        WwTradition.none: {
          'gospels': true,
          'psalms-proverbs': true,
          'whole-bible': true,
        },
        WwTradition.lds: {
          'gospels': true,
          'psalms-proverbs': true,
          'whole-bible': true,
        },
        WwTradition.protestant: {
          'gospels': true,
          'psalms-proverbs': true,
          'whole-bible': true,
        },
        WwTradition.catholic: {
          'gospels': true,
          'psalms-proverbs': true,
          'whole-bible': true,
        },
        WwTradition.jewish: {
          'gospels': false,
          'psalms-proverbs': true,
          'whole-bible': false,
        },
      };
      for (final entry in expected.entries) {
        for (final cell in entry.value.entries) {
          expect(
            planAvailable(def(cell.key), entry.key, data),
            cell.value,
            reason: '${entry.key} / ${cell.key}',
          );
        }
      }
    });

    test('dormancy: tradition switches perform no store write', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await PlansStore.load(prefs);
      store.startPlan('default', 'gospels', DateTime(2026, 10, 1));
      store.toggleChapter('default', 'gospels', 929);
      await store.save();
      final before = prefs.getString(plansPrefsKey);

      // Availability is recomputed per tradition; the store is
      // never touched by the switch.
      expect(planAvailable(def('gospels'), WwTradition.jewish, data), isFalse);
      expect(planAvailable(def('gospels'), WwTradition.catholic, data), isTrue);
      expect(prefs.getString(plansPrefsKey), before);

      final reloaded = await PlansStore.load(prefs);
      expect(reloaded.progressFor('default', 'gospels')!.done, {929});
    });
  });
}
