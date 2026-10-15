import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';

import 'bundled_fixture.dart';
import 'fake_canon.dart';

/// Board run 8: the conference connections data layer, parsed
/// from test/fixtures/conference_fixture.json against the fake
/// 66-book canon (10 verses per chapter, Psalms 119 = 176).
///
/// Fixture shape: 8 talks (1990–2024, April + October), 33 raw
/// edges over Genesis 1–2 / Psalms 1, 23, 119 / John 1, including
/// 3 duplicate rows and 7 out-of-canon rows the parser must drop
/// (chapter at/past the canon end, negative chapter, verse 0,
/// verse past the chapter, unknown talk id). Post-dedupe valid
/// edge count is 23.
///
/// Global chapters in the canon: Genesis 1 = 0, Genesis 2 = 1,
/// Psalms 1 = 478, Psalms 23 = 500, Psalms 119 = 596, John 1 = 997.
void main() {
  late BibleData canon;
  late ConferenceData data;

  setUp(() {
    canon = fakeReaderData();
    final source = File('test/fixtures/conference_fixture.json')
        .readAsStringSync();
    data = ConferenceData.fromCanon(source, canon);
  });

  group('parse + talk fields', () {
    test('talks carry the pipeline fields verbatim', () {
      expect(data.talkCount, 8);
      final wada = data.talkById(1)!;
      expect(
        wada.title,
        'The Words of Christ and the Holy Ghost Will Lead Us to the Truth',
      );
      expect(wada.speaker, 'Takashi Wada');
      expect(wada.year, 2024);
      expect(wada.session, 'O');
      expect(wada.sessionName, 'Sunday Afternoon');
      expect(wada.url, startsWith('https://www.churchofjesuschrist.org/'));
      expect(wada.urlIsConference, isFalse);
      // The pipeline's x field: the talk's own Citation Index page.
      expect(
        wada.indexUrl,
        'https://scriptures.byu.edu/content/talks_ajax/8801/',
      );
      expect(wada.conferenceLabel, 'October 2024');

      final uchtdorf = data.talkById(2)!;
      expect(uchtdorf.session, 'A');
      expect(uchtdorf.conferenceLabel, 'April 2024');
    });

    test('a null url stays null and is not a conference fallback', () {
      final freeman = data.talkById(3)!;
      expect(freeman.url, isNull);
      expect(freeman.urlIsConference, isFalse);
      // No x field in the fixture row: the Index page stays null
      // (Freeman is the fixture's neither-link talk).
      expect(freeman.indexUrl, isNull);
    });

    test('c:1 marks the conference-level fallback link', () {
      final cook = data.talkById(4)!;
      expect(cook.url, contains('/general-conference/2023/10'));
      expect(cook.urlIsConference, isTrue);
      // …and his x field carries his own Citation Index page, the
      // amended routing's target for the c:1 set.
      expect(
        cook.indexUrl,
        'https://scriptures.byu.edu/content/talks_ajax/8500/',
      );
    });

    test('unknown talk id resolves to null', () {
      expect(data.talkById(999), isNull);
    });
  });

  group('dedupe + canon dropping', () {
    test('edgeCount is post-dedupe and post-drop', () {
      // 33 raw rows − 3 duplicates − 7 out-of-canon = 23.
      expect(data.edgeCount, 23);
    });

    test('duplicate rows do not duplicate a verse\u2019s talks', () {
      // Genesis 1:1 is cited by talks 0, 1, 2, 4, 5, 7 in the raw
      // rows, with talk 0\u2019s row repeated verbatim.
      final ids = data.talksForVerse(0, 1).map((t) => t.id).toList();
      expect(ids.where((id) => id == 0).length, 1);
      expect(ids.toSet().length, ids.length);
    });

    test('out-of-canon edges name no verse', () {
      // Verse 99 of Genesis 1 (10 in the fake canon) dropped.
      expect(data.talksForVerse(0, 99), isEmpty);
      // Verse 11 of Psalms 23 dropped.
      expect(data.talksForVerse(500, 11), isEmpty);
      // Verse 0 dropped (both bounds bind).
      expect(data.talksForVerse(997, 0), isEmpty);
    });

    test('chapter at the canon end is dropped, not clamped', () {
      final counts = [for (final c in canon.chapters) c.v];
      final small = ConferenceData.parse(
        '{"v":1,"talks":[{"i":0,"t":"T","s":"S","y":2020,"e":"A",'
        '"n":"N","u":null,"c":0}],"edges":[[0,1189,1],[0,1188,1]]}',
        chapterVerseCounts: counts,
        chapters: canon.chapters,
      );
      // Chapter 1189 (== chapter count) drops; 1188 (Revelation 22)
      // is the last real chapter and survives.
      expect(small.edgeCount, 1);
      expect(small.talksForVerse(1188, 1).single.id, 0);
    });

    test('verse past the chapter length is dropped, not clamped', () {
      final counts = [for (final c in canon.chapters) c.v];
      final small = ConferenceData.parse(
        '{"v":1,"talks":[{"i":0,"t":"T","s":"S","y":2020,"e":"A",'
        '"n":"N","u":null,"c":0}],"edges":[[0,0,10],[0,0,11]]}',
        chapterVerseCounts: counts,
        chapters: canon.chapters,
      );
      // Genesis 1 has 10 verses in the fake canon: 10 survives,
      // 11 drops instead of clamping onto verse 10.
      expect(small.edgeCount, 1);
      expect(small.talksForVerse(0, 10).single.id, 0);
      expect(small.talksForVerse(0, 11), isEmpty);
    });
  });

  group('talksForVerse ordering', () {
    test('newest first: year desc, October before April, dataset '
        'order within a conference', () {
      // John 1:1 citers: 2024-O in dataset order — Wada (1),
      // Freeman (3), Bednar (7) — then 2024-A Uchtdorf, then
      // 1990-O Nelson. Title order within 2024 October would be
      // Bednar / Freeman / Wada, so this assertion fails if any
      // alphabetical tie-break returns (spec §3.3, fix F-1).
      final titles = data.talksForVerse(997, 1).map((t) => t.title).toList();
      expect(titles, [
        'The Words of Christ and the Holy Ghost Will Lead Us to the Truth',
        'Live Up to Your Privileges',
        'Be Still, and Know That I Am God',
        'A Higher Joy',
        'Choices',
      ]);
    });

    test('October beats April within the same year at one verse', () {
      // Psalms 23:1 citers: Wada 2024-O, Gong 2024-A, Cook 2023-O,
      // Eyring 2019-O.
      final ids = data.talksForVerse(500, 1).map((t) => t.id).toList();
      expect(ids, [1, 5, 4, 6]);
    });

    test('an uncited verse and an unknown chapter return empty', () {
      expect(data.talksForVerse(0, 5), isEmpty);
      expect(data.talksForVerse(9999, 1), isEmpty);
      expect(data.verseHasTalks(997, 1), isTrue);
      expect(data.verseHasTalks(0, 5), isFalse);
    });
  });

  group('refsForTalk', () {
    // Groups are compared field-wise: a record holding a List
    // compares that list by identity, so whole-record equality
    // cannot see two equal groups as equal.
    List<(int, int, String)> flatten(List<(int, int, List<int>)> groups) => [
      for (final g in groups) (g.$1, g.$2, g.$3.join(',')),
    ];

    test('groups by chapter in canon order with ascending verses', () {
      // Wada cites Genesis 1:1, Psalms 23:1, Psalms 119:105,
      // John 1:1 and John 1:9 — canon order, John\u2019s verses grouped.
      expect(flatten(data.refsForTalk(1)), [
        (0, 1, '1'),
        (18, 23, '1'),
        (18, 119, '105'),
        (42, 1, '1,9'),
      ]);
    });

    test('multiple verses in one chapter group together, sorted', () {
      // Eyring cites Genesis 2:4 and Psalms 23:1, 23:6.
      expect(flatten(data.refsForTalk(6)), [(0, 2, '4'), (18, 23, '1,6')]);
    });

    test('an unknown talk has no references', () {
      expect(data.refsForTalk(999), isEmpty);
    });
  });

  group('conferences + coverage', () {
    test('conferences aggregates newest first', () {
      expect(data.conferences(), [
        (2024, 'O', 3),
        (2024, 'A', 2),
        (2023, 'O', 1),
        (2019, 'O', 1),
        (1990, 'O', 1),
      ]);
    });

    test('talksInConference keeps dataset order, not title order', () {
      // The fixture's bundled order for 2024 October is Wada (1),
      // Freeman (3), Bednar (7) — title order would be
      // [7, 3, 1] (Be Still / Live Up / The Words), so this
      // assertion fails if any alphabetical re-sort returns.
      final ids = data.talksInConference(2024, 'O').map((t) => t.id).toList();
      expect(ids, [1, 3, 7]);
      expect(data.talksInConference(2024, 'A').map((t) => t.id), [2, 5]);
      expect(data.talksInConference(2000, 'A'), isEmpty);
    });

    test('conferences counts only talks with a Bible citation', () {
      final mixed = ConferenceData.parse(
        '{"v":1,"talks":['
        '{"i":0,"t":"Citing Talk","s":"S","y":2025,"e":"O","n":"N",'
        '"u":null,"c":0},'
        '{"i":1,"t":"Non Citing Talk","s":"S","y":2025,"e":"O","n":"N",'
        '"u":null,"c":0},'
        '{"i":2,"t":"Another Citing Talk","s":"S","y":2024,"e":"A",'
        '"n":"N","u":null,"c":0}'
        '],"edges":[[0,0,1],[2,0,1]]}',
        chapterVerseCounts: [for (final c in canon.chapters) c.v],
        chapters: canon.chapters,
      );
      // 2025 October holds two talks in the dataset but only one
      // cites the Bible, so its count is 1, not 2 (spec §4.1).
      expect(mixed.conferences(), [(2025, 'O', 1), (2024, 'A', 1)]);
    });

    test(
      'a conference with zero citing talks is absent from conferences()',
      () {
        final zero = ConferenceData.parse(
          '{"v":1,"talks":['
          '{"i":0,"t":"Citing Talk","s":"S","y":2025,"e":"O","n":"N",'
          '"u":null,"c":0},'
          '{"i":1,"t":"Out Of Canon Only","s":"S","y":2020,"e":"A",'
          '"n":"N","u":null,"c":0},'
          '{"i":2,"t":"No Citations","s":"S","y":2019,"e":"O","n":"N",'
          '"u":null,"c":0}'
          '],"edges":[[0,0,1],[1,0,99]]}',
          chapterVerseCounts: [for (final c in canon.chapters) c.v],
          chapters: canon.chapters,
        );
        // Talk 1's only edge is out of canon (verse 99 of a
        // 10-verse chapter, dropped at parse) and talk 2 has no
        // edges at all, so neither 2020 April nor 2019 October
        // appears (spec §4.2).
        expect(zero.conferences(), [(2025, 'O', 1)]);
      },
    );

    test('coverage stats span the dataset', () {
      expect(data.talkCount, 8);
      expect(data.edgeCount, 23);
      expect(data.firstYear, 1990);
      expect(data.lastYear, 2024);
    });

    test('the shipped dataset: routing counts under the amended '
        'rule (founder correction, Oct 14 2026)', () {
      final realCanon = BibleData.fromJsonString(
        readBundledJson('assets/data.json.gz'),
      );
      final shipped = ConferenceData.fromCanon(
        readBundledJson('assets/conference.json.gz'),
        realCanon,
      );
      // The dataset does not shrink: every talk back to April
      // 1942 stays, and every talk carries its Citation Index
      // page (the harvest records one per conference-page link).
      expect(shipped.talkCount, 4964);
      expect(shipped.firstYear, 1942);
      expect(shipped.edgeCount, 68999);
      expect(shipped.talks.where((t) => t.indexUrl != null).length, 4964);
      expect(
        shipped.talks.every(
          (t) => t.indexUrl!.startsWith(
            'https://scriptures.byu.edu/content/talks_ajax/',
          ),
        ),
        isTrue,
      );
      // Routing, in the app's precedence (data-driven, no year
      // cutoff): per-talk Gospel Library / Citation Index /
      // residual conference link / neither.
      bool perTalkGl(ConferenceTalk t) => t.url != null && !t.urlIsConference;
      expect(shipped.talks.where(perTalkGl).length, 3014);
      expect(
        shipped.talks.where((t) => !perTalkGl(t) && t.indexUrl != null).length,
        1950,
      );
      expect(
        shipped.talks
            .where((t) => !perTalkGl(t) && t.indexUrl == null && t.url != null)
            .length,
        0,
      );
      expect(
        shipped.talks.where((t) => !perTalkGl(t) && t.indexUrl == null).length,
        0,
      );
      // The dataset's first talk (April 1942, dataset order)
      // routes to its own Index page: its only Gospel Library
      // link is the conference-level fallback (c:1), which the
      // amended routing no longer uses when an Index page exists.
      final first = shipped.talks.first;
      expect(first.year, 1942);
      expect(first.title, 'Upholding the Hands of Our Leaders');
      expect(first.urlIsConference, isTrue);
      expect(first.url, contains('/general-conference/1942/04'));
      expect(
        first.indexUrl,
        'https://scriptures.byu.edu/content/talks_ajax/3/',
      );
    });

    test('the empty placeholder dataset parses to empty coverage', () {
      final empty = ConferenceData.parse(
        '{"v":1,"talks":[],"edges":[]}',
        chapterVerseCounts: [for (final c in canon.chapters) c.v],
        chapters: canon.chapters,
      );
      expect(empty.talkCount, 0);
      expect(empty.edgeCount, 0);
      expect(empty.firstYear, isNull);
      expect(empty.lastYear, isNull);
      expect(empty.conferences(), isEmpty);
      expect(empty.talksForVerse(0, 1), isEmpty);
      expect(empty.refsForTalk(0), isEmpty);
    });
  });

  group('citationCountsFromSource (quotable spec §3.2 / §5 test 8)', () {
    test('distinct talks per verse; out-of-range edges dropped; '
        'verse upper bound not clamped', () {
      final counts = ConferenceData.citationCountsFromSource(
        '{"v":1,"talks":[],"edges":['
        '[0,0,1],[0,0,1],[1,0,1],[1,0,2],'
        '[2,10,1],[2,-1,1],[2,0,0],'
        '[3,0,99],[3,9,5]'
        ']}',
        chapterCount: 10,
      );
      // (0,1): talks 0 and 1 — talk 0's duplicate row counts
      // once. Chapter 10 (== chapterCount) and chapter -1 drop;
      // verse 0 drops. Verse 99 is KEPT (counts for verses that
      // do not exist are inert; the builder only asks about real
      // verses).
      expect(counts, {(0, 1): 2, (0, 2): 1, (0, 99): 1, (9, 5): 1});
    });

    test('no edges counts nothing', () {
      expect(
        ConferenceData.citationCountsFromSource(
          '{"v":1,"talks":[],"edges":[]}',
          chapterCount: 1189,
        ),
        isEmpty,
      );
    });

    test('the shipped dataset: counts agree with the parsed index', () {
      final source = readBundledJson('assets/conference.json.gz');
      final realCanon = BibleData.fromJsonString(
        readBundledJson('assets/data.json.gz'),
      );
      final counts = ConferenceData.citationCountsFromSource(
        source,
        chapterCount: realCanon.chapters.length,
      );
      final shipped = ConferenceData.fromCanon(source, realCanon);
      // Every counted verse carries exactly the talks the full
      // parse indexes for it, and the totals agree.
      var total = 0;
      for (final e in counts.entries) {
        expect(
          shipped.talksForVerse(e.key.$1, e.key.$2).length,
          e.value,
          reason: 'verse ${e.key}',
        );
        total += e.value;
      }
      expect(total, shipped.edgeCount);
      // The spec's headline: Matthew 22:39 is the most-cited
      // verse in the Bible by this measure (259 distinct talks).
      final matthew22 = realCanon.books
              .firstWhere((b) => b.name == 'Matthew')
              .start +
          21;
      expect(counts[(matthew22, 39)], 259);
      expect(counts[(matthew22, 37)], 238);
    });
  });
}
