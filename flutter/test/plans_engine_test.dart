import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/plans.dart';

import 'fake_canon.dart';

BibleData canonFromVerses(List<int> verses) {
  final json = jsonEncode({
    'books': [
      {'abbr': 'Bk', 'name': 'Book', 'chapters': verses.length, 'start': 0},
    ],
    'chapters': [
      for (var i = 0; i < verses.length; i++)
        {'b': 0, 'c': i + 1, 'v': verses[i]},
    ],
    'chapterArcs': <List<int>>[],
    'refs': <List<int>>[],
  });
  return BibleData.fromJsonString(json);
}

List<int> totals(BibleData d, List<List<int>> sched) => [
  for (final day in sched) day.fold(0, (s, ch) => s + d.chapters[ch].v),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fake = fakeReaderData();

  group('Mode A worked examples (§11.1.1)', () {
    test('examples', () {
      final d1 = canonFromVerses([10, 10, 10, 10, 10]);
      expect(scheduleByVerses(d1, [0, 1, 2, 3, 4], 40), [
        [0, 1, 2, 3],
        [4],
      ]);
      final d2 = canonFromVerses([10, 10]);
      expect(scheduleByVerses(d2, [0, 1], 40), [
        [0, 1],
      ]);
      final d3 = canonFromVerses([176]);
      expect(scheduleByVerses(d3, [0], 40), [
        [0],
      ]);
      final d4 = canonFromVerses([50, 10, 10]);
      expect(scheduleByVerses(d4, [0, 1, 2], 40), [
        [0],
        [1, 2],
      ]);
      final d5 = canonFromVerses([30, 30]);
      expect(scheduleByVerses(d5, [0, 1], 40), [
        [0],
        [1],
      ]);
      expect(scheduleByVerses(d1, [], 40), isEmpty);
    });
  });

  group('Mode A properties (§11.1.2)', () {
    test('concat, no empty, closeness invariant, monotonic days', () {
      final rng = math.Random(42);
      final vectors = <List<int>>[
        for (var i = 0; i < 200; i++)
          [for (var j = 0; j < rng.nextInt(30) + 1; j++) rng.nextInt(180) + 1],
      ];
      final lists = <List<int>>[
        for (final v in vectors) [for (var i = 0; i < v.length; i++) i],
        for (final def in wwStudyPlans) planChapters(fake, def),
      ];
      final datas = <BibleData>[
        for (final v in vectors) canonFromVerses(v),
        for (var i = 0; i < 3; i++) fake,
      ];
      for (var li = 0; li < lists.length; li++) {
        final d = datas[li];
        final chapters = lists[li];
        var prevDays = 1 << 30;
        for (final t in [1, 5, 40, 200]) {
          final sched = scheduleByVerses(d, chapters, t);
          expect(sched.expand((e) => e).toList(), chapters);
          expect(sched.every((e) => e.isNotEmpty), isTrue);
          expect(sched.length <= prevDays, isTrue);
          prevDays = sched.length;
          for (var di = 0; di < sched.length - 1; di++) {
            final tot = sched[di].fold(0, (s, ch) => s + d.chapters[ch].v);
            final v = d.chapters[sched[di + 1].first].v;
            expect(
              tot >= t || (tot + v - t).abs() >= (tot - t).abs(),
              isTrue,
              reason: 'day $di t=$t',
            );
          }
        }
      }
      // T=1 on fake Gospels: one chapter per day
      final gospels = planChapters(fake, wwStudyPlans.first);
      expect(scheduleByVerses(fake, gospels, 1).length, 89);
    });
  });

  group('Mode B worked examples (§11.1.3)', () {
    test('five examples verbatim', () {
      void check(
        List<int> verses,
        int n,
        List<List<int>> days,
        List<int> tots,
      ) {
        final d = canonFromVerses(verses);
        final sched = scheduleByDays(d, [
          for (var i = 0; i < verses.length; i++) i,
        ], n);
        expect(sched, days, reason: '$verses N=$n');
        expect(totals(d, sched), tots);
      }

      check(
        [10, 10, 10, 10, 10],
        2,
        [
          [0, 1, 2],
          [3, 4],
        ],
        [30, 20],
      );
      check(
        [31, 26, 32],
        2,
        [
          [0, 1],
          [2],
        ],
        [57, 32],
      );
      check(
        [50, 10, 10, 50],
        3,
        [
          [0],
          [1, 2],
          [3],
        ],
        [50, 20, 50],
      );
      check(
        [1, 1, 100, 1],
        3,
        [
          [0, 1],
          [2],
          [3],
        ],
        [2, 100, 1],
      );
      check(
        [10, 20, 30],
        3,
        [
          [0],
          [1],
          [2],
        ],
        [10, 20, 30],
      );
    });
  });

  group('Mode B properties (§11.1.4)', () {
    test('exactly N, concat, edges', () {
      final rng = math.Random(7);
      for (var trial = 0; trial < 60; trial++) {
        final len = rng.nextInt(20) + 1;
        final verses = [for (var i = 0; i < len; i++) rng.nextInt(150) + 1];
        final d = canonFromVerses(verses);
        final chapters = [for (var i = 0; i < len; i++) i];
        for (var n = 1; n <= len; n++) {
          final sched = scheduleByDays(d, chapters, n);
          expect(sched.length, n, reason: 'len=$len n=$n');
          expect(sched.every((e) => e.isNotEmpty), isTrue);
          expect(sched.expand((e) => e).toList(), chapters);
        }
        expect(scheduleByDays(d, chapters, 1), [chapters]);
        expect(scheduleByDays(d, chapters, len), [
          for (final c in chapters) [c],
        ]);
        expect(scheduleByDays(d, chapters, len + 50).length, len);
        expect(scheduleByDays(d, [], 3), isEmpty);
        expect(scheduleByVerses(d, [], 40), isEmpty);
      }
      // fake lists sampled N
      for (final def in wwStudyPlans) {
        final chapters = planChapters(fake, def);
        for (final n in [1, 2, 7, 40, chapters.length]) {
          final sched = scheduleByDays(fake, chapters, n);
          expect(sched.length, n);
          expect(sched.expand((e) => e).toList(), chapters);
        }
      }
    });
  });

  group('Resolution (§11.1.5)', () {
    test('customChapters clamps and dedupes', () {
      expect(
        customChapters(fake, [PlanSegment(book: 18, from: 149, to: 999)]),
        [626, 627],
      );
      expect(
        customChapters(fake, [PlanSegment(book: 18, from: 200, to: 210)]),
        isEmpty,
      );
      expect(
        customChapters(fake, [
          PlanSegment(book: 18, from: 1, to: 3),
          PlanSegment(book: 18, from: 3, to: 5),
        ]),
        [478, 479, 480, 481, 482],
      );
      expect(
        customChapters(fake, [PlanSegment(book: 999, from: 1, to: 3)]),
        isEmpty,
      );
    });

    test('resolveCustomPlan dispatches pace', () {
      CustomPlanDef mk(PlanPace pace) => CustomPlanDef(
        id: 'custom-1',
        name: 'Ps',
        segments: [PlanSegment(book: 18, from: 1, to: 10)],
        pace: pace,
      );
      final byVerses = resolveCustomPlan(fake, mk(PlanPace.verses(40)));
      expect(byVerses.schedule.map((d) => d.length).toList(), [4, 4, 2]);
      expect(totals(fake, byVerses.schedule), [40, 40, 20]);
      expect(byVerses.days, 3);
      final byDays = resolveCustomPlan(fake, mk(PlanPace.days(4)));
      expect(byDays.schedule.map((d) => d.length).toList(), [3, 2, 3, 2]);
      expect(totals(fake, byDays.schedule), [30, 20, 30, 20]);
      expect(byDays.days, 4);
      final clamped = resolveCustomPlan(fake, mk(PlanPace.days(99)));
      expect(clamped.days, 10);
      expect(clamped.schedule.every((d) => d.length == 1), isTrue);
    });
  });
}
