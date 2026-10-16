import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/verse_of_day.dart';
import 'package:woven_word/data/verse_of_day_curation.dart';

import 'bundled_fixture.dart';
import 'fake_canon.dart';

void main() {
  group('buildVerseOfDayPool', () {
    final data = fakeReaderData();

    test('orders by count desc, ties in canonical order', () {
      // No citation signal supplied: the §2.5 fallback pool,
      // whose ranking IS the shipped run 11 ranking.
      final pool = buildVerseOfDayPool(data, WwTradition.none);
      expect(pool.length, 365);
      // Genesis 1:1 has 3 deduped connections (Psalms 119:1,
      // John 1:1, Genesis 1:2).
      expect(
        pool[0],
        const VerseOfDayPick(chapter: 0, verse: 1, connectionCount: 3),
      );
      // The three count-1 verses follow in canonical order.
      final psalms119 = data.books[18].start + 118;
      final john1 = data.books[42].start;
      expect(
        pool[1],
        const VerseOfDayPick(chapter: 0, verse: 2, connectionCount: 1),
      );
      expect(
        pool[2],
        VerseOfDayPick(chapter: psalms119, verse: 1, connectionCount: 1),
      );
      expect(
        pool[3],
        VerseOfDayPick(chapter: john1, verse: 1, connectionCount: 1),
      );
      expect(pool[4].connectionCount, 0);
    });

    test('counts equal verseConnections lengths on sampled verses', () {
      // A citation function at the floor for every verse makes
      // every verse a survivor, so the pool spans the canon (the
      // citation rule never truncates — §5 test 5 pins that too).
      final pool = buildVerseOfDayPool(
        data,
        WwTradition.none,
        citationCount: (_, _) => votdCitationFloor,
      );
      final byPos = {
        for (final p in pool) (p.chapter, p.verse): p.connectionCount,
      };
      final psalms119 = data.books[18].start + 118;
      final john1 = data.books[42].start;
      for (final (ch, v) in [
        (0, 1),
        (0, 2),
        (psalms119, 1),
        (john1, 1),
        (500, 3),
      ]) {
        expect(
          byPos[(ch, v)],
          data.verseConnections(ch, v).length,
          reason: 'verse ($ch, $v)',
        );
      }
    });

    test('tie-breaking is canonical, not insertion order', () {
      // A two-book canon whose ref list presents the LATER
      // chapter's verse first; equal counts still order
      // chapter-asc, verse-asc.
      final books = <Map<String, Object>>[];
      final chapters = <Map<String, Object>>[];
      var start = 0;
      for (final (abbr, name, count) in [
        ('Gen', 'Genesis', 2),
        ('Exod', 'Exodus', 1),
      ]) {
        books.add({
          'abbr': abbr,
          'name': name,
          'chapters': count,
          'start': start,
        });
        for (var c = 1; c <= count; c++) {
          chapters.add({'b': books.length - 1, 'c': c, 'v': 5});
        }
        start += count;
      }
      final small = BibleData.fromJsonString(
        jsonEncode({
          'books': books,
          'chapters': chapters,
          'chapterArcs': <List<int>>[],
          'refs': [
            [2, 1, 0, 3, 1], // Exodus 1:1 <-> Genesis 1:3 (later chapter first)
            [0, 1, 2, 2, 1], // Genesis 1:1 <-> Exodus 1:2
          ],
        }),
      );
      final pool = buildVerseOfDayPool(small, WwTradition.none);
      // Four verses carry one connection each; they lead the
      // fallback pool in canonical order.
      expect(pool.take(4).map((p) => (p.chapter, p.verse)).toList(), [
        (0, 1),
        (0, 3),
        (2, 1),
        (2, 2),
      ]);
      expect(pool.take(4).every((p) => p.connectionCount == 1), isTrue);
    });

    test('canon restriction: jewish pool excludes the New Testament', () {
      // A 40-book canon whose highest-count verse is in the New
      // Testament (book 39): under `none` the (fallback) pool
      // leads with that NT verse; under jewish the pool holds NO
      // NT verse — here it is empty outright, because the Jewish
      // rule is the §2.2 connections floor and no verse in this
      // fixture reaches 55 connections.
      final books = <Map<String, Object>>[];
      final chapters = <Map<String, Object>>[];
      for (var b = 0; b < 40; b++) {
        books.add({
          'abbr': 'B$b',
          'name': b == 39 ? 'Matthew' : 'Book $b',
          'chapters': 1,
          'start': b,
        });
        chapters.add({'b': b, 'c': 1, 'v': 5});
      }
      final small = BibleData.fromJsonString(
        jsonEncode({
          'books': books,
          'chapters': chapters,
          'chapterArcs': <List<int>>[],
          'refs': [
            [39, 1, 0, 1, 1], // Matthew 1:1 <-> three OT verses
            [39, 1, 1, 1, 1],
            [39, 1, 2, 1, 1],
          ],
        }),
      );
      final poolNone = buildVerseOfDayPool(small, WwTradition.none);
      expect(poolNone.first.chapter, 39);
      expect(poolNone.first.connectionCount, 3);
      final poolJewish = buildVerseOfDayPool(small, WwTradition.jewish);
      expect(poolJewish.every((p) => small.chapters[p.chapter].b < 39), isTrue);
      expect(poolJewish, isEmpty);
      // The remaining traditions present the full canon here:
      // with every verse at the citation floor, each yields the
      // whole 200-verse canon, identically.
      List<VerseOfDayPick>? firstCore;
      for (final t in [
        WwTradition.catholic,
        WwTradition.none,
        WwTradition.lds,
        WwTradition.protestant,
      ]) {
        final pool = buildVerseOfDayPool(
          small,
          t,
          citationCount: (_, _) => votdCitationFloor,
        );
        expect(pool.length, 200, reason: '$t');
        firstCore ??= pool;
        expect(pool, firstCore, reason: '$t pool differs');
      }
      // The full fake canon agrees: its verses top out at 3
      // connections, so the Jewish connections floor yields an
      // empty pool (no NT verse, trivially).
      final poolJ = buildVerseOfDayPool(data, WwTradition.jewish);
      expect(poolJ.every((p) => data.chapters[p.chapter].b < 39), isTrue);
      expect(poolJ, isEmpty);
    });

    test(
      'small canon: pool is every verse, 0-count tail in canonical order',
      () {
        final books = <Map<String, Object>>[];
        final chapters = <Map<String, Object>>[];
        books.add({
          'abbr': 'Gen',
          'name': 'Genesis',
          'chapters': 1,
          'start': 0,
        });
        chapters.add({'b': 0, 'c': 1, 'v': 4});
        final small = BibleData.fromJsonString(
          jsonEncode({
            'books': books,
            'chapters': chapters,
            'chapterArcs': <List<int>>[],
            'refs': [
              [0, 2, 0, 4, 1],
            ],
          }),
        );
        final pool = buildVerseOfDayPool(small, WwTradition.none);
        expect(pool.length, 4);
        expect(
          pool[0],
          const VerseOfDayPick(chapter: 0, verse: 2, connectionCount: 1),
        );
        expect(
          pool[1],
          const VerseOfDayPick(chapter: 0, verse: 4, connectionCount: 1),
        );
        expect(
          pool[2],
          const VerseOfDayPick(chapter: 0, verse: 1, connectionCount: 0),
        );
        expect(
          pool[3],
          const VerseOfDayPick(chapter: 0, verse: 3, connectionCount: 0),
        );
      },
    );

    test('no truncation, no padding (spec §5 test 5)', () {
      // A one-book canon of 400 verses: with every verse at the
      // citation floor the survivors exceed 365 and ALL of them
      // are pooled; with only two verses at the floor the pool
      // is exactly those two.
      final books = <Map<String, Object>>[
        {'abbr': 'Gen', 'name': 'Genesis', 'chapters': 40, 'start': 0},
      ];
      final chapters = <Map<String, Object>>[
        for (var c = 1; c <= 40; c++) {'b': 0, 'c': c, 'v': 10},
      ];
      final small = BibleData.fromJsonString(
        jsonEncode({
          'books': books,
          'chapters': chapters,
          'chapterArcs': <List<int>>[],
          'refs': <List<int>>[],
        }),
      );
      final all = buildVerseOfDayPool(
        small,
        WwTradition.none,
        citationCount: (_, _) => votdCitationFloor,
      );
      expect(all.length, 400);
      final few = buildVerseOfDayPool(
        small,
        WwTradition.none,
        citationCount: (ch, v) =>
            (ch == 0 && (v == 1 || v == 2)) ? votdCitationFloor : 0,
      );
      expect(few.map((p) => (p.chapter, p.verse)).toList(), [(0, 1), (0, 2)]);
    });
  });

  group('date selection', () {
    final pool = [
      for (var i = 0; i < 10; i++)
        VerseOfDayPick(chapter: i, verse: 1, connectionCount: 0),
    ];

    test(
      'same pick all day; consecutive dates advance by one, DST included',
      () {
        final morning = verseOfDayFromPool(pool, DateTime(2026, 10, 15, 0, 1));
        final night = verseOfDayFromPool(pool, DateTime(2026, 10, 15, 23, 59));
        expect(morning, night);
        final d1 = verseOfDayFromPool(pool, DateTime(2026, 3, 7));
        final d2 = verseOfDayFromPool(pool, DateTime(2026, 3, 8));
        final d3 = verseOfDayFromPool(pool, DateTime(2026, 3, 9));
        expect(pool.indexOf(d2!), (pool.indexOf(d1!) + 1) % pool.length);
        expect(pool.indexOf(d3!), (pool.indexOf(d2) + 1) % pool.length);
      },
    );

    test('index wraps at pool length; empty pool is null', () {
      final epochPlus9 = verseOfDayFromPool(pool, DateTime(1970, 1, 10));
      final epochPlus10 = verseOfDayFromPool(pool, DateTime(1970, 1, 11));
      expect(epochPlus9, pool[9]);
      expect(epochPlus10, pool[0]);
      expect(verseOfDayFromPool(const [], DateTime(2026, 10, 15)), isNull);
    });

    test('daysSinceEpochLocal anchors', () {
      expect(daysSinceEpochLocal(DateTime(1970, 1, 1)), 0);
      expect(daysSinceEpochLocal(DateTime(1970, 1, 2)), 1);
      expect(daysSinceEpochLocal(DateTime(1970, 1, 1, 23, 59)), 0);
    });

    test('verseOfDayForDate composes pool and date', () {
      final data = fakeReaderData();
      final pick = verseOfDayForDate(
        data,
        WwTradition.none,
        DateTime(1970, 1, 2),
      );
      expect(pick, buildVerseOfDayPool(data, WwTradition.none)[1]);
    });

    test('the pick over a 410-length pool has period 410 (§5 test 7)', () {
      final pool410 = [
        for (var i = 0; i < 410; i++)
          VerseOfDayPick(chapter: i, verse: 1, connectionCount: 0),
      ];
      for (var i = 0; i < 410; i++) {
        expect(
          verseOfDayFromPool(pool410, DateTime(1970, 1, 1 + i)),
          pool410[i],
          reason: 'day $i',
        );
      }
      expect(verseOfDayFromPool(pool410, DateTime(1970, 1, 1 + 410)), pool410[0]);
      expect(verseOfDayFromPool(pool410, DateTime(1970, 1, 1 + 411)), pool410[1]);
    });
  });

  group('translationForVerseOfDay', () {
    bool all(WwTranslation t) => true;

    test('stored available -> stored', () {
      expect(
        translationForVerseOfDay(
          stored: WwTranslation.web,
          tradition: WwTradition.none,
          otBook: false,
          hasTranslation: all,
        ),
        WwTranslation.web,
      );
      expect(
        translationForVerseOfDay(
          stored: WwTranslation.webc,
          tradition: WwTradition.catholic,
          otBook: true,
          hasTranslation: all,
        ),
        WwTranslation.webc,
      );
    });

    test('stored JPS on an NT book under jewish -> kjv', () {
      expect(
        translationForVerseOfDay(
          stored: WwTranslation.jps,
          tradition: WwTradition.jewish,
          otBook: false,
          hasTranslation: all,
        ),
        WwTranslation.kjv,
      );
    });

    test(
      'stored Hebrew on an OT book under jewish with Hebrew bundled -> hebrew',
      () {
        expect(
          translationForVerseOfDay(
            stored: WwTranslation.hebrew,
            tradition: WwTradition.jewish,
            otBook: true,
            hasTranslation: all,
          ),
          WwTranslation.hebrew,
        );
      },
    );

    test('a stored translation the bundle lacks -> kjv', () {
      expect(
        translationForVerseOfDay(
          stored: WwTranslation.web,
          tradition: WwTradition.none,
          otBook: true,
          hasTranslation: (t) => t == WwTranslation.kjv,
        ),
        WwTranslation.kjv,
      );
    });
  });

  // ------------------------------------------------ quotable pools (§5)

  group('quotable pools (bundled assets)', () {
    late BibleData realData;
    late Map<(int, int), int> counts;
    late List<dynamic> kjvJson;
    late List<VerseOfDayPick> corePool;
    late List<VerseOfDayPick> jewishPool;
    late List<VerseOfDayPick> fallbackPool;

    String kjvTextOf(int ch, int v) {
      final chapter = realData.chapters[ch];
      return ((kjvJson[chapter.b] as List)[chapter.c - 1] as List)[v - 1]
          as String;
    }

    int chapterOf(String book, int chapterInBook) =>
        realData.books.firstWhere((b) => b.name == book).start +
        chapterInBook -
        1;

    (int, int) keyOf(String book, int chapterInBook, int verse) =>
        (chapterOf(book, chapterInBook), verse);

    Set<(int, int)> keysOf(List<VerseOfDayPick> pool) => {
      for (final p in pool) (p.chapter, p.verse),
    };

    setUpAll(() {
      realData = BibleData.fromJsonString(
        readBundledJson('assets/data.json.gz'),
      );
      counts = ConferenceData.citationCountsFromSource(
        readBundledJson('assets/conference.json.gz'),
        chapterCount: realData.chapters.length,
      );
      kjvJson = jsonDecode(readBundledJson('assets/kjv.json.gz')) as List;
      corePool = buildVerseOfDayPool(
        realData,
        WwTradition.none,
        citationCount: (ch, v) => counts[(ch, v)] ?? 0,
        kjvText: kjvTextOf,
      );
      jewishPool = buildVerseOfDayPool(
        realData,
        WwTradition.jewish,
        citationCount: (ch, v) => counts[(ch, v)] ?? 0,
        kjvText: kjvTextOf,
      );
      fallbackPool = buildVerseOfDayPool(
        realData,
        WwTradition.none,
        kjvText: kjvTextOf,
      );
    });

    test('predicate exemplars on the bundled KJV texts (§5 test 1)', () {
      // OUT — one exemplar per predicate.
      for (final (book, c, v, why) in [
        ('Matthew', 1, 2, 'P1 genealogy verb'),
        ('Ezra', 2, 3, 'P3 census list'),
        ('Numbers', 33, 10, 'P2 itinerary log'),
        ('Genesis', 10, 2, 'P4 name density'),
      ]) {
        expect(
          versePassesQuotabilityPredicates(
            kjvTextOf(chapterOf(book, c), v),
          ),
          isFalse,
          reason: '$book $c:$v ($why)',
        );
      }
      // IN — quotable verses the predicates must not catch.
      for (final (book, c, v) in [
        ('John', 11, 35), // "Jesus wept."
        ('Matthew', 28, 19), // ends in a colon
        ('Matthew', 16, 16), // a confession full of names
        ('Luke', 15, 4), // number words in a saying
        ('Genesis', 1, 1),
      ]) {
        expect(
          versePassesQuotabilityPredicates(
            kjvTextOf(chapterOf(book, c), v),
          ),
          isTrue,
          reason: '$book $c:$v',
        );
      }
    });

    test('core pool: 410, every member at the floors of §2 (§5 test 2)', () {
      expect(corePool.length, 410);
      for (final p in corePool) {
        expect(
          counts[(p.chapter, p.verse)] ?? 0,
          greaterThanOrEqualTo(votdCitationFloor),
          reason: '${realData.refName(p.chapter, p.verse)} citations',
        );
        expect(
          versePassesQuotabilityPredicates(kjvTextOf(p.chapter, p.verse)),
          isTrue,
          reason: realData.refName(p.chapter, p.verse),
        );
        expect(
          votdCuratorialExclusions.containsKey((p.chapter, p.verse)),
          isFalse,
          reason: realData.refName(p.chapter, p.verse),
        );
      }
    });

    test('jewish pool: 483, connections floor, Tanakh only (§5 test 2)', () {
      expect(jewishPool.length, 483);
      for (final p in jewishPool) {
        expect(
          p.connectionCount,
          greaterThanOrEqualTo(votdConnectionFloor),
          reason: realData.refName(p.chapter, p.verse),
        );
        expect(realData.chapters[p.chapter].b, lessThan(39));
        expect(
          versePassesQuotabilityPredicates(kjvTextOf(p.chapter, p.verse)),
          isTrue,
          reason: realData.refName(p.chapter, p.verse),
        );
        expect(
          votdCuratorialExclusions.containsKey((p.chapter, p.verse)),
          isFalse,
          reason: realData.refName(p.chapter, p.verse),
        );
      }
    });

    test('exemplar membership (§5 test 3)', () {
      final core = keysOf(corePool);
      final jewish = keysOf(jewishPool);
      expect(core.contains(keyOf('John', 11, 35)), isTrue);
      expect(core.contains(keyOf('Isaiah', 53, 5)), isTrue);
      expect(jewish.contains(keyOf('Isaiah', 53, 5)), isFalse);
      expect(core.contains(keyOf('Daniel', 9, 24)), isFalse);
      expect(jewish.contains(keyOf('Daniel', 9, 24)), isTrue);
      // Matthew 22:37 is the core pool's #2 by rank (behind
      // 22:39, the most-cited verse in the corpus).
      expect(
        (corePool[1].chapter, corePool[1].verse),
        keyOf('Matthew', 22, 37),
      );
      expect(
        (corePool[0].chapter, corePool[0].verse),
        keyOf('Matthew', 22, 39),
      );
    });

    test('excluded verses are out of their pools (§5 test 3)', () {
      final core = keysOf(corePool);
      final jewish = keysOf(jewishPool);
      for (final (book, c, v) in [
        ('Matthew', 25, 37),
        ('Ephesians', 4, 12),
        ('Luke', 15, 26),
      ]) {
        final key = keyOf(book, c, v);
        // Out BY exclusion: each is in the curatorial map.
        expect(votdCuratorialExclusions.containsKey(key), isTrue,
            reason: '$book $c:$v not in the exclusion map');
        expect(core.contains(key), isFalse, reason: '$book $c:$v in core');
      }
      for (final (book, c, v) in [
        ('Leviticus', 1, 3),
        ('Psalms', 2, 2),
      ]) {
        final key = keyOf(book, c, v);
        expect(votdCuratorialExclusions.containsKey(key), isTrue,
            reason: '$book $c:$v not in the exclusion map');
        expect(jewish.contains(key), isFalse, reason: '$book $c:$v in jewish');
      }
    });

    test('per-canon scoping (§5 test 4)', () {
      for (final t in [
        WwTradition.lds,
        WwTradition.protestant,
        WwTradition.catholic,
      ]) {
        final pool = buildVerseOfDayPool(
          realData,
          t,
          citationCount: (ch, v) => counts[(ch, v)] ?? 0,
          kjvText: kjvTextOf,
        );
        expect(pool, corePool, reason: '$t pool differs from the core pool');
      }
      expect(jewishPool, isNot(corePool));
      expect(
        jewishPool.every((p) => realData.chapters[p.chapter].b < 39),
        isTrue,
      );
      // A Catholic-tradition pool contains no deuterocanon book
      // (index ≥ 1000): the core pool IS the Catholic pool here,
      // and every pooled chapter's book is a core book.
      expect(
        corePool.every((p) => realData.chapters[p.chapter].b < 1000),
        isTrue,
      );
    });

    test('fallback: 365 by connections, exclusions still applied (§5 test 6)',
        () {
      expect(fallbackPool.length, votdFallbackPoolSize);
      final fallback = keysOf(fallbackPool);
      // Zechariah 8:20 (77 connections — inside the fallback's
      // range) is absent because the exclusion list names it.
      final zech = keyOf('Zechariah', 8, 20);
      expect(realData.verseConnections(zech.$1, zech.$2).length, 77);
      expect(votdCuratorialExclusions.containsKey(zech), isTrue);
      expect(fallback.contains(zech), isFalse);
      // No fallback member is in the exclusion map, and every
      // member passes the predicates.
      for (final p in fallbackPool) {
        expect(
          votdCuratorialExclusions.containsKey((p.chapter, p.verse)),
          isFalse,
          reason: realData.refName(p.chapter, p.verse),
        );
        expect(
          versePassesQuotabilityPredicates(kjvTextOf(p.chapter, p.verse)),
          isTrue,
          reason: realData.refName(p.chapter, p.verse),
        );
      }
      // The fallback ranking leads with the most-connected verse
      // and, per §2.5's honest consequence, the unexcluded hub
      // Daniel 9:24 returns here (it is out of the core pool on
      // citations alone).
      expect(
        (fallbackPool[0].chapter, fallbackPool[0].verse),
        keyOf('Isaiah', 9, 6),
      );
      expect(fallbackPool[0].connectionCount, 212);
      expect(fallback.contains(keyOf('Daniel', 9, 24)), isTrue);
    });
  });
}
