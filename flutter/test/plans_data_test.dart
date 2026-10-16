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

  group('resolved schedule distribution (Mode A, v2 §11.9)', () {
    List<List<int>> sched(String id) =>
        resolveBuiltinPlan(data, def(id)).schedule;
    List<int> sizes(String id) => sched(id).map((d) => d.length).toList();

    test('exact day-size lists and lengths', () {
      expect(sched('gospels').length, 23);
      expect(sched('psalms-proverbs').length, 47);
      expect(sched('whole-bible').length, 298);
      expect(sizes('gospels'), [...List.filled(22, 4), 1]);
      expect(sizes('psalms-proverbs'), [
        ...List.filled(29, 4),
        2,
        1,
        ...List.filled(15, 4),
        2,
      ]);
      final whole = sched('whole-bible');
      expect(whole[149], [596]);
      expect([for (final d in whole) d.length].where((n) => n != 4).toList(), [
        1,
      ]);
    });

    test('concatenation equals planChapters; no empty day', () {
      for (final plan in wwStudyPlans) {
        final schedule = resolveBuiltinPlan(data, plan).schedule;
        expect(
          schedule.expand((d) => d).toList(),
          planChapters(data, plan),
          reason: plan.id,
        );
        expect(schedule.every((d) => d.isNotEmpty), isTrue, reason: plan.id);
      }
    });

    test('spot chapters', () {
      final gospels = sched('gospels');
      expect(gospels[0], [929, 930, 931, 932]);
      expect(gospels[22], [1017]);
      final psalms = sched('psalms-proverbs');
      expect(psalms[0], [478, 479, 480, 481]);
      expect(psalms[46], [657, 658]);
      final whole = sched('whole-bible');
      expect(whole[0], [0, 1, 2, 3]);
      expect(whole[297], [1185, 1186, 1187, 1188]);
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
        expect(decoded.keys, ['version', 'progress', 'custom', 'customSeq']);
        expect(
          (decoded['progress'] as Map).keys,
          containsAll(['default', 'p2']),
        );
        final gospels =
            ((decoded['progress'] as Map)['default'] as Map)['gospels'] as Map;
        expect(gospels.keys, containsAll(['startedOn', 'done']));
        expect(gospels['startedOn'], '2026-10-05');
        expect(gospels['done'], [929, 931]); // sorted ascending

        final reloaded = await PlansStore.load(prefs);
        expect(reloaded.document, store.document);
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
      expect(PlansStore.parseDocument(unknown).progress, parsed);
      expect(
        jsonDecode(
          PlansStore.encodeDocument(PlansStore.parseDocument(unknown)),
        ),
        {
          'version': 2,
          'progress': jsonDecode(unknown),
          'custom': <String, dynamic>{},
          'customSeq': <String, dynamic>{},
        },
      );
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
      expect(store.document.progress, isEmpty);
      await store.save();
      expect(jsonDecode(prefs.getString(plansPrefsKey)!), {
        'version': 2,
        'progress': <String, dynamic>{},
        'custom': <String, dynamic>{},
        'customSeq': <String, dynamic>{},
      });
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
  group('v2 document (spec §11.2)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('v2 round-trip: exact shape, key order, deep equality', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = await PlansStore.load(prefs);
      store.startPlan('default', 'gospels', DateTime(2026, 10, 5));
      store.toggleChapter('default', 'gospels', 929);
      final c1 = store.createCustom(
        'default',
        name: '  Morning Psalms ',
        segments: [PlanSegment(book: 18, from: 1, to: 10)],
        pace: PlanPace.verses(40),
      );
      expect(c1.id, 'custom-1');
      expect(c1.name, 'Morning Psalms');
      store.createCustom(
        'p2',
        name: 'In a month',
        segments: [PlanSegment(book: 39, from: 1, to: 28)],
        pace: PlanPace.days(30),
      );
      await store.save();
      final decoded =
          jsonDecode(prefs.getString(plansPrefsKey)!) as Map<String, dynamic>;
      expect(decoded.keys, ['version', 'progress', 'custom', 'customSeq']);
      final def0 = ((decoded['custom'] as Map)['default'] as List).first as Map;
      expect(def0.keys, ['id', 'name', 'segments', 'pace']);
      expect((def0['segments'] as List).first.keys, ['book', 'from', 'to']);
      final reloaded = await PlansStore.load(prefs);
      expect(reloaded.document, store.document);
    });

    test('v1 load: progress preserved, save writes v2 with same progress', () async {
      const v1 =
          '{"default":{"gospels":{"startedOn":"2026-10-05","done":[929,931]}}}';
      SharedPreferences.setMockInitialValues({plansPrefsKey: v1});
      final prefs = await SharedPreferences.getInstance();
      final store = await PlansStore.load(prefs);
      expect(store.document.progress, PlansStore.parse(v1));
      expect(store.document.custom, isEmpty);
      expect(store.document.customSeq, isEmpty);
      await store.save();
      final decoded =
          jsonDecode(prefs.getString(plansPrefsKey)!) as Map<String, dynamic>;
      expect(decoded['version'], 2);
      expect(decoded['progress'], jsonDecode(v1));
    });

    test('v2 defensive parse drops bad entries individually', () {
      Map<String, dynamic> docWith(Object? defEntry) => {
        'version': 2,
        'progress': <String, dynamic>{},
        'custom': {
          'p': [
            defEntry,
            {
              'id': 'custom-9',
              'name': 'Good',
              'segments': [
                {'book': 18, 'from': 1, 'to': 2},
              ],
              'pace': {'mode': 'verses', 'versesPerDay': 40},
            },
          ],
        },
        'customSeq': <String, dynamic>{},
      };
      final good = {
        'id': 'custom-1',
        'name': 'Ok',
        'segments': [
          {'book': 18, 'from': 1, 'to': 2},
        ],
        'pace': {'mode': 'verses', 'versesPerDay': 40},
      };
      Map<String, dynamic> variant(void Function(Map<String, dynamic>) f) {
        final m = jsonDecode(jsonEncode(good)) as Map<String, dynamic>;
        f(m);
        return m;
      }

      final bads = <Object?>[
        42,
        variant((m) => m['id'] = 'x-1'),
        variant((m) => m['id'] = 'custom-0'),
        variant((m) => m['name'] = '   '),
        variant((m) => m['segments'] = []),
        variant(
          (m) => m['segments'] = [
            {'book': -1, 'from': 1, 'to': 2},
          ],
        ),
        variant(
          (m) => m['segments'] = [
            {'book': 18, 'from': 0, 'to': 2},
          ],
        ),
        variant(
          (m) => m['segments'] = [
            {'book': 18, 'from': 3, 'to': 2},
          ],
        ),
        variant((m) => m['pace'] = {'mode': 'weeks'}),
        variant((m) => m['pace'] = {'mode': 'verses', 'versesPerDay': 0}),
        variant((m) => m['pace'] = {'mode': 'verses', 'versesPerDay': 1001}),
        variant((m) => m['pace'] = {'mode': 'verses', 'versesPerDay': '40'}),
        variant((m) => m['pace'] = {'mode': 'days', 'days': 0}),
      ];
      for (final bad in bads) {
        final parsed = PlansStore.parseDocument(jsonEncode(docWith(bad)));
        final kept = parsed.custom['p']!;
        expect(kept.length, 1, reason: '$bad');
        expect(kept.single.id, 'custom-9');
      }
      // duplicate id: first wins
      final dup = PlansStore.parseDocument(
        jsonEncode({
          'version': 2,
          'progress': {},
          'customSeq': {},
          'custom': {
            'p': [good, good],
          },
        }),
      );
      expect(dup.custom['p']!.length, 1);
      // name trimmed on keep
      final trimmed = PlansStore.parseDocument(
        jsonEncode(docWith(variant((m) => m['name'] = '  Padded  '))),
      );
      expect(trimmed.custom['p']!.first.name, 'Padded');
      // progress member malformed -> empty progress, customs survive
      final badProg = PlansStore.parseDocument(
        jsonEncode({
          'version': 2,
          'progress': 42,
          'custom': {
            'p': [good],
          },
          'customSeq': {},
        }),
      );
      expect(badProg.progress, isEmpty);
      expect(badProg.custom['p']!.length, 1);
      // custom profile not a list dropped
      final badList = PlansStore.parseDocument(
        jsonEncode({
          'version': 2,
          'progress': {},
          'custom': {
            'p': 42,
            'q': [good],
          },
          'customSeq': {},
        }),
      );
      expect(badList.custom.containsKey('p'), isFalse);
      expect(badList.custom['q']!.length, 1);
      // seq bad entries dropped
      final badSeq = PlansStore.parseDocument(
        jsonEncode({
          'version': 2,
          'progress': {},
          'custom': {},
          'customSeq': {'p': -1, 'q': 'x', 'r': 3},
        }),
      );
      expect(badSeq.customSeq, {'r': 3});
    });

    test('seq discipline: never reused, self-heals', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = await PlansStore.load(prefs);
      CustomPlanDef mk(PlansStore st) => st.createCustom(
        'default',
        name: 'X',
        segments: [PlanSegment(book: 18, from: 1, to: 1)],
        pace: PlanPace.verses(40),
      );
      expect(mk(store).id, 'custom-1');
      expect(mk(store).id, 'custom-2');
      store.deleteCustom('default', 'custom-1');
      expect(mk(store).id, 'custom-3');
      // heal: seq 0 but custom-7 live
      final healed = PlansStore.parseDocument(
        jsonEncode({
          'version': 2,
          'progress': {},
          'customSeq': {'default': 0},
          'custom': {
            'default': [
              {
                'id': 'custom-7',
                'name': 'Seven',
                'segments': [
                  {'book': 18, 'from': 1, 'to': 1},
                ],
                'pace': {'mode': 'days', 'days': 5},
              },
            ],
          },
        }),
      );
      expect(healed.customSeq['default'], 7);
      final store2 = PlansStore.parseDocument(jsonEncode(healed.toJson()));
      expect(store2.customSeq['default'], 7);
      SharedPreferences.setMockInitialValues({
        plansPrefsKey: jsonEncode(healed.toJson()),
      });
      final prefs2 = await SharedPreferences.getInstance();
      final loaded = await PlansStore.load(prefs2);
      expect(
        loaded
            .createCustom(
              'default',
              name: 'Next',
              segments: [PlanSegment(book: 18, from: 1, to: 1)],
              pace: PlanPace.verses(40),
            )
            .id,
        'custom-8',
      );
    });

    test('custom mutators: update in place, delete removes progress, restart keeps def', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = await PlansStore.load(prefs);
      final a = store.createCustom(
        'default',
        name: 'A',
        segments: [PlanSegment(book: 18, from: 1, to: 5)],
        pace: PlanPace.verses(40),
      );
      final b = store.createCustom(
        'default',
        name: 'B',
        segments: [PlanSegment(book: 19, from: 1, to: 5)],
        pace: PlanPace.days(10),
      );
      store.startPlan('default', a.id, DateTime(2026, 10, 5));
      store.toggleChapter('default', a.id, 478);
      store.updateCustom(
        'default',
        CustomPlanDef(id: a.id, name: 'A2', segments: a.segments, pace: a.pace),
      );
      expect(store.customsFor('default').map((d) => d.id), [a.id, b.id]);
      expect(store.customsFor('default').first.name, 'A2');
      expect(store.progressFor('default', a.id)!.done, {478});
      store.updateCustom(
        'default',
        CustomPlanDef(
          id: 'custom-99',
          name: 'Z',
          segments: a.segments,
          pace: a.pace,
        ),
      );
      expect(store.customsFor('default').length, 2);
      store.restartPlan('default', a.id);
      expect(store.progressFor('default', a.id), isNull);
      expect(store.customFor('default', a.id), isNotNull);
      store.startPlan('default', a.id, DateTime(2026, 10, 6));
      store.deleteCustom('default', a.id);
      expect(store.customFor('default', a.id), isNull);
      expect(store.progressFor('default', a.id), isNull);
      expect(store.document.customSeq['default'], 2);
      store.deleteCustom('default', 'custom-99');
      expect(store.customsFor('default').length, 1);
    });

    test('custom availability (dormancy, pure)', () {
      final matt = CustomPlanDef(
        id: 'custom-1',
        name: 'M',
        segments: [PlanSegment(book: 39, from: 1, to: 5)],
        pace: PlanPace.verses(40),
      );
      for (final t in [
        WwTradition.none,
        WwTradition.protestant,
        WwTradition.catholic,
        WwTradition.lds,
      ]) {
        expect(customAvailable(matt, t, data), isTrue, reason: '$t');
      }
      expect(customAvailable(matt, WwTradition.jewish, data), isFalse);
      final ps = CustomPlanDef(
        id: 'custom-2',
        name: 'P',
        segments: [PlanSegment(book: 18, from: 1, to: 5)],
        pace: PlanPace.verses(40),
      );
      for (final t in WwTradition.values) {
        expect(customAvailable(ps, t, data), isTrue, reason: '$t');
      }
      final empty = CustomPlanDef(
        id: 'custom-3',
        name: 'E',
        segments: [PlanSegment(book: 18, from: 200, to: 210)],
        pace: PlanPace.verses(40),
      );
      for (final t in WwTradition.values) {
        expect(customAvailable(empty, t, data), isFalse, reason: '$t');
      }
    });
  });

  group('migration (spec §11.3)', () {
    test('v1 progress survives: percent identical, day reclamps to 23', () {
      const v1 =
          '{"default":{"gospels":{"startedOn":"2026-09-15","done":[929,930,931]}}}';
      final doc = PlansStore.parseDocument(v1);
      final progress = doc.progress['default']!['gospels']!;
      expect(progress.startedOn, '2026-09-15');
      expect(progress.done, {929, 930, 931});
      final resolved = resolveBuiltinPlan(data, def('gospels'));
      final doneCount = planDoneCount(progress, resolved.chapters);
      expect(planPercent(doneCount, 89), planPercent(3, 89));
      expect(
        planDayFor(
          startedOn: progress.startedOn,
          today: DateTime(2026, 10, 15),
          days: resolved.days,
        ),
        23,
      );
      final after = PlansStore.encodeDocument(doc);
      expect((jsonDecode(after) as Map)['progress'], jsonDecode(v1));
    });
  });
}
