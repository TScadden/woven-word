import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/highlights_index.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/user_data.dart';

import 'fake_canon.dart';

HighlightSpan span(
  int book,
  int chapter,
  int verse, {
  int start = 0,
  int end = 5,
  String anchor = 'anchor',
  HlColor color = HlColor.gold,
}) => HighlightSpan(
  verseKey: verseKey(book, chapter, verse),
  start: start,
  end: end,
  anchor: anchor,
  color: color,
);

void main() {
  final data = fakeReaderData();
  final texts = fakeReaderTexts(data);
  final deutero = DeuterocanonData.parse(
    jsonEncode({
      'books': [
        {
          'slug': 'tobit',
          'name': 'Tobit',
          'abbr': 'Tob',
          'chapters': 2,
          'verseCounts': [10, 10],
        },
        {
          'slug': 'wisdom',
          'name': 'Wisdom',
          'abbr': 'Wis',
          'chapters': 1,
          'verseCounts': [10],
        },
      ],
    }),
  );

  List<HighlightBookGroup> groups(
    List<HighlightSpan> spans,
    WwTradition tradition, {
    DeuterocanonData? deuteroTable,
    ScriptureText? textOverride,
    bool useTexts = true,
  }) => groupHighlights(
    data: data,
    deutero: deuteroTable,
    spans: spans,
    tradition: tradition,
    texts: useTexts ? (textOverride ?? texts) : null,
    translation: WwTranslation.kjv,
  );

  group('grouping order', () {
    test('canon order, not input order (tradition none)', () {
      final g = groups([
        span(42, 1, 1),
        span(0, 1, 1),
        span(18, 1, 1),
      ], WwTradition.none);
      expect(g.map((b) => b.bookName).toList(), ['Genesis', 'Psalms', 'John']);
    });

    test('jewish: Psalms before Ruth (Ketuvim order)', () {
      final g = groups([span(7, 1, 1), span(18, 1, 1)], WwTradition.jewish);
      expect(g.map((b) => b.bookName).toList(), ['Psalms', 'Ruth']);
    });

    test('chapters ascending within a book', () {
      final g = groups([
        span(0, 3, 1),
        span(0, 1, 1),
        span(0, 2, 1),
      ], WwTradition.none);
      expect(g.single.chapters.map((c) => c.chapter).toList(), [1, 2, 3]);
    });
  });

  group('row order', () {
    test('verse, then start, then end', () {
      final g = groups([
        span(0, 1, 2, start: 0, end: -1),
        span(0, 1, 1, start: 10, end: 20, anchor: 'a10'),
        span(0, 1, 1, start: 0, end: 5, anchor: 'a0-5'),
        span(0, 1, 1, start: 0, end: 3, anchor: 'a0-3'),
      ], WwTradition.none);
      final rows = g.single.chapters.single.rows;
      expect(rows.map((r) => (r.verse, r.span.start, r.span.end)).toList(), [
        (1, 0, 3),
        (1, 0, 5),
        (1, 10, 20),
        (2, 0, -1),
      ]);
    });
  });

  group('visibility', () {
    test('NT span dropped under jewish, shown under none', () {
      final spans = [span(42, 1, 1)];
      expect(
        visibleSpansForIndex(
          data: data,
          deutero: null,
          spans: spans,
          tradition: WwTradition.jewish,
        ),
        isEmpty,
      );
      expect(
        visibleSpansForIndex(
          data: data,
          deutero: null,
          spans: spans,
          tradition: WwTradition.none,
        ),
        hasLength(1),
      );
    });

    test('out-of-canon positions and unparseable keys are dropped', () {
      final bad = [
        const HighlightSpan(
          verseKey: 'b0c0v1',
          start: 0,
          end: 5,
          anchor: 'x',
          color: HlColor.gold,
        ),
        const HighlightSpan(
          verseKey: 'b0c1v0',
          start: 0,
          end: 5,
          anchor: 'x',
          color: HlColor.gold,
        ),
        span(0, 51, 1), // Genesis has 50 chapters
        span(0, 1, 11), // Genesis 1 has 10 verses
        const HighlightSpan(
          verseKey: 'garbage',
          start: 0,
          end: 5,
          anchor: 'x',
          color: HlColor.gold,
        ),
      ];
      for (final tradition in WwTradition.values) {
        expect(
          visibleSpansForIndex(
            data: data,
            deutero: deutero,
            spans: bad,
            tradition: tradition,
          ),
          isEmpty,
          reason: '$tradition visible',
        );
        expect(
          groups(bad, tradition, deuteroTable: deutero),
          isEmpty,
          reason: '$tradition groups',
        );
      }
    });
  });

  group('deuterocanon', () {
    final tobit = span(DeuteroBook.bookIndexBase, 1, 1, anchor: 'tobit anchor');
    final wisdom = span(
      DeuteroBook.bookIndexBase + 1,
      1,
      2,
      anchor: 'wisdom anchor',
    );

    test('shows only under catholic, after all core groups, table order', () {
      for (final t in [
        WwTradition.none,
        WwTradition.protestant,
        WwTradition.jewish,
        WwTradition.lds,
      ]) {
        expect(
          groups([tobit], t, deuteroTable: deutero),
          isEmpty,
          reason: '$t',
        );
      }
      final g = groups(
        [wisdom, span(0, 1, 1), tobit],
        WwTradition.catholic,
        deuteroTable: deutero,
      );
      expect(g.map((b) => b.bookName).toList(), ['Genesis', 'Tobit', 'Wisdom']);
      final tobitRow = g[1].chapters.single.rows.single;
      expect(tobitRow.refLabel, 'Tobit 1:1');
      expect(tobitRow.book, DeuteroBook.bookIndexBase);
    });

    test('dropped entirely when deutero is null', () {
      expect(groups([tobit], WwTradition.catholic), isEmpty);
    });
  });

  group('display text', () {
    test('partial span shows its anchor', () {
      final g = groups([
        span(0, 1, 1, anchor: 'the anchor text'),
      ], WwTradition.none);
      expect(
        g.single.chapters.single.rows.single.displayText,
        'the anchor text',
      );
    });

    test('full-verse span shows the verse text, not its anchor', () {
      final g = groups([
        span(0, 1, 1, start: 0, end: -1, anchor: 'a different anchor'),
      ], WwTradition.none);
      final row = g.single.chapters.single.rows.single;
      expect(row.displayText, texts.verseText(WwTranslation.kjv, data, 0, 1));
      expect(row.displayText, isNot('a different anchor'));
    });

    test('partial span with an empty anchor falls back to the verse text', () {
      final g = groups([span(0, 1, 1, anchor: '')], WwTradition.none);
      expect(
        g.single.chapters.single.rows.single.displayText,
        texts.verseText(WwTranslation.kjv, data, 0, 1),
      );
    });

    test('with texts null a full-verse span falls back to its anchor', () {
      final g = groups(
        [span(0, 1, 1, start: 0, end: -1, anchor: 'fallback anchor')],
        WwTradition.none,
        useTexts: false,
      );
      expect(
        g.single.chapters.single.rows.single.displayText,
        'fallback anchor',
      );
    });
  });

  group('count consistency', () {
    test(
      'visibleSpansForIndex length equals grouped row count, every tradition',
      () {
        final fixture = [
          span(0, 1, 1),
          span(42, 1, 1),
          span(18, 2, 3),
          span(DeuteroBook.bookIndexBase, 1, 1),
          span(0, 51, 1),
          const HighlightSpan(
            verseKey: 'nope',
            start: 0,
            end: 5,
            anchor: 'x',
            color: HlColor.blue,
          ),
        ];
        for (final t in WwTradition.values) {
          final visible = visibleSpansForIndex(
            data: data,
            deutero: deutero,
            spans: fixture,
            tradition: t,
          );
          final g = groups(fixture, t, deuteroTable: deutero);
          final rowCount = g.fold<int>(
            0,
            (sum, b) =>
                sum + b.chapters.fold<int>(0, (s, c) => s + c.rows.length),
          );
          expect(rowCount, visible.length, reason: '$t');
        }
      },
    );
  });
}
