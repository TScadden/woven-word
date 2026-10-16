import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/plans.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/tradition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData data;
  setUpAll(() async {
    data = await BibleData.load();
  });

  ResolvedPlan rp(String id) =>
      resolveBuiltinPlan(data, wwStudyPlans.firstWhere((p) => p.id == id));

  int dayVerses(ResolvedPlan p, int dayIdx) =>
      p.schedule[dayIdx].fold(0, (s, ch) => s + data.chapters[ch].v);

  test('totals (§11.7.1)', () {
    expect(rp('gospels').totalChapters, 89);
    expect(rp('gospels').totalVerses, 3779);
    expect(rp('psalms-proverbs').totalChapters, 181);
    expect(rp('psalms-proverbs').totalVerses, 3376);
    expect(rp('whole-bible').totalChapters, 1189);
    expect(rp('whole-bible').totalVerses, 31102);
  });

  test('derived days 87/84/767 (§11.7.2)', () {
    expect(rp('gospels').days, 87);
    expect(rp('psalms-proverbs').days, 84);
    expect(rp('whole-bible').days, 767);
  });

  test('spot days (§11.7.3)', () {
    final g = rp('gospels');
    expect(g.schedule[0], [929, 930]);
    expect(g.schedule[86], [1017]);
    expect(g.schedule[42], [973]);
    expect(dayVerses(g, 42), 80);
    expect(g.schedule[1], [931, 932]);
    expect(dayVerses(g, 1), 42);
    expect(g.schedule[2], [933]);
    expect(dayVerses(g, 2), 48);
    expect(g.schedule[85], [1016]);
    final ps = rp('psalms-proverbs');
    expect(ps.schedule[0], [478, 479, 480, 481]);
    expect(ps.schedule[48], [596]);
    expect(ps.schedule[83], [658]);
    expect(ps.schedule[1], [482, 483, 484]);
    expect(ps.schedule[82], [657]);
    final w = rp('whole-bible');
    expect(w.schedule[0], [0]);
    expect(w.schedule[95], [123]);
    expect(dayVerses(w, 95), 89);
    expect(w.schedule[392], [596]);
    expect(w.schedule[766], [1188]);
    expect(w.schedule[1], [1, 2]);
    expect(w.schedule[765], [1186, 1187]);
  });

  test('heaviest / lightest (§11.7.4)', () {
    int heaviest(ResolvedPlan p) =>
        [for (var i = 0; i < p.days; i++) dayVerses(p, i)]
            .reduce((a, b) => a > b ? a : b);
    int lightest(ResolvedPlan p) =>
        [for (var i = 0; i < p.days; i++) dayVerses(p, i)]
            .reduce((a, b) => a < b ? a : b);
    expect(heaviest(rp('gospels')), 80);
    expect(lightest(rp('gospels')), 20);
    expect(heaviest(rp('psalms-proverbs')), 176);
    expect(lightest(rp('psalms-proverbs')), 15);
    final w = rp('whole-bible');
    expect(heaviest(w), 176);
    expect(lightest(w), 11);
    // Heaviest non-Psalm-119 day: exclude the day containing 596.
    var best = 0;
    for (var i = 0; i < w.days; i++) {
      if (w.schedule[i].contains(596)) continue;
      final v = dayVerses(w, i);
      if (v > best) best = v;
    }
    expect(best, 89);
    // Day 258 (idx 257) = 1 Chronicles 6 alone 81; day 617 (idx 616) Luke 1 80.
    expect(w.schedule[257], [343]);
    expect(dayVerses(w, 257), 81);
    expect(w.schedule[616], [973]);
    expect(dayVerses(w, 616), 80);
  });

  test('availability matrix on real data (§11.7.5)', () {
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
    for (final e in expected.entries) {
      for (final c in e.value.entries) {
        final def = wwStudyPlans.firstWhere((p) => p.id == c.key);
        expect(
          planAvailable(def, e.key, data),
          c.value,
          reason: '${e.key}/${c.key}',
        );
      }
    }
  });

  test('old-rule contrast peaks 187/191/212 (§11.7.6)', () {
    int oldPeak(StudyPlanDef def, int days) {
      final chapters = planChapters(data, def);
      final base = chapters.length ~/ days;
      final rem = chapters.length % days;
      var peak = 0;
      var off = 0;
      for (var i = 1; i <= days; i++) {
        final size = base + (i <= rem ? 1 : 0);
        var sum = 0;
        for (var j = 0; j < size; j++) {
          sum += data.chapters[chapters[off + j]].v;
        }
        if (sum > peak) peak = sum;
        off += size;
      }
      return peak;
    }

    expect(oldPeak(wwStudyPlans[0], 30), 187);
    expect(oldPeak(wwStudyPlans[1], 60), 191);
    expect(oldPeak(wwStudyPlans[2], 365), 212);
  });
}
