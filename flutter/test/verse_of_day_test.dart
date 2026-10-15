import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/verse_of_day.dart';

import 'fake_canon.dart';

void main() {
  group('buildVerseOfDayPool', () {
    final data = fakeReaderData();

    test('orders by count desc, ties in canonical order', () {
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
      final pool = buildVerseOfDayPool(
        data,
        WwTradition.none,
        poolSize: 100000,
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
      final pool = buildVerseOfDayPool(small, WwTradition.none, poolSize: 4);
      // Four verses carry one connection each; canonical order.
      expect(pool.map((p) => (p.chapter, p.verse)).toList(), [
        (0, 1),
        (0, 3),
        (2, 1),
        (2, 2),
      ]);
      expect(pool.every((p) => p.connectionCount == 1), isTrue);
    });

    test('canon restriction: jewish pool excludes the New Testament', () {
      // A 40-book canon whose highest-count verse is in the New
      // Testament (book 39): under `none` the pool leads with
      // that NT verse; under jewish the pool holds NO NT verse.
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
      final poolJewish = buildVerseOfDayPool(
        small,
        WwTradition.jewish,
        poolSize: 100000,
      );
      expect(poolJewish.every((p) => small.chapters[p.chapter].b < 39), isTrue);
      // The remaining traditions present the full canon here.
      for (final t in [
        WwTradition.catholic,
        WwTradition.none,
        WwTradition.lds,
        WwTradition.protestant,
      ]) {
        final pool = buildVerseOfDayPool(small, t, poolSize: 100000);
        expect(pool.length, 200, reason: '$t');
      }
      // The full fake canon agrees: jewish carries no NT verse.
      final poolJ = buildVerseOfDayPool(
        data,
        WwTradition.jewish,
        poolSize: 100000,
      );
      expect(poolJ.every((p) => data.chapters[p.chapter].b < 39), isTrue);
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
}
