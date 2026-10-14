import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/scripture_text.dart';

/// Small hand-written dataset: one book, four chapters with verse
/// counts 3 / 2 / 4 / 2, so verse clamping is observable on both the
/// connection targets and the stored source keys.
String fakeJson(List<List<int>> refs) {
  return jsonEncode({
    'books': [
      {'abbr': 'Bk', 'name': 'Book', 'chapters': 4, 'start': 0},
    ],
    'chapters': [
      {'b': 0, 'c': 1, 'v': 3},
      {'b': 0, 'c': 2, 'v': 2},
      {'b': 0, 'c': 3, 'v': 4},
      {'b': 0, 'c': 4, 'v': 2},
    ],
    'chapterArcs': <List<int>>[],
    'refs': refs,
  });
}

void main() {
  group('verseConnections', () {
    test('bidirectional: one ref row counts both ways', () {
      final data = BibleData.fromJsonString(
        fakeJson([
          [0, 1, 1, 2, 4],
        ]),
      );
      expect(data.verseConnections(0, 1), [
        [1, 2, 4],
      ]);
      expect(data.verseConnections(1, 2), [
        [0, 1, 4],
      ]);
      expect(data.verseHasConnections(0, 1), isTrue);
      expect(data.verseHasConnections(1, 2), isTrue);
      expect(data.verseHasConnections(0, 2), isFalse);
      expect(data.verseConnections(0, 2), isEmpty);
      expect(data.verseConnections(99, 1), isEmpty);
      expect(data.verseHasConnections(99, 1), isFalse);
    });

    test('dedupes by target, keeping the max votes', () {
      final data = BibleData.fromJsonString(
        fakeJson([
          [0, 1, 1, 1, 3],
          [0, 1, 1, 1, 9],
          [1, 1, 0, 1, 5], // same pair, reverse direction
        ]),
      );
      expect(data.verseConnections(0, 1), [
        [1, 1, 9],
      ]);
      expect(data.verseConnections(1, 1), [
        [0, 1, 9],
      ]);
    });

    test('sorts votes desc, then target chapter asc, then verse asc', () {
      final data = BibleData.fromJsonString(
        fakeJson([
          [0, 1, 2, 2, 5],
          [0, 1, 1, 2, 5],
          [0, 1, 1, 1, 5],
          [0, 1, 2, 1, 8],
        ]),
      );
      expect(data.verseConnections(0, 1), [
        [2, 1, 8],
        [1, 1, 5],
        [1, 2, 5],
        [2, 2, 5],
      ]);
    });

    test('clamps source and target verses to their chapter lengths', () {
      // Chapter 0 holds 3 verses, chapter 1 holds 2: verse 99 clamps
      // to 3 on the source side and to 2 on the target side.
      final data = BibleData.fromJsonString(
        fakeJson([
          [0, 99, 1, 99, 6],
        ]),
      );
      expect(data.verseConnections(0, 3), [
        [1, 2, 6],
      ]);
      expect(data.verseConnections(1, 2), [
        [0, 3, 6],
      ]);
      // The lookup itself clamps too (versePos).
      expect(data.verseConnections(0, 99), [
        [1, 2, 6],
      ]);
      expect(data.verseHasConnections(0, 99), isTrue);
    });
  });

  group('ScriptureText', () {
    // Data index says both chapters hold 3 verses (the KJV count);
    // the WEB text's first chapter is shorter (2 verses) — the
    // Romans 14/16 versification difference in miniature.
    final data = BibleData.fromJsonString(
      jsonEncode({
        'books': [
          {'abbr': 'Bk', 'name': 'Book', 'chapters': 2, 'start': 0},
        ],
        'chapters': [
          {'b': 0, 'c': 1, 'v': 3},
          {'b': 0, 'c': 2, 'v': 3},
        ],
        'chapterArcs': <List<int>>[],
        'refs': <List<int>>[],
      }),
    );
    final texts = ScriptureText.fromJsonStrings(
      jsonEncode([
        [
          ['k1:1', 'k1:2', 'k1:3'],
          ['k2:1', 'k2:2', 'k2:3'],
        ],
      ]),
      jsonEncode([
        [
          ['w1:1', 'w1:2'],
          ['w2:1', 'w2:2', 'w2:3'],
        ],
      ]),
    );

    test('translation labels and asset paths', () {
      expect(WwTranslation.kjv.label, 'KJV');
      expect(WwTranslation.kjv.assetPath, 'assets/kjv.json');
      expect(WwTranslation.web.label, 'WEB');
      expect(WwTranslation.web.assetPath, 'assets/web.json');
      expect(WwTranslation.fromStored('WEB'), WwTranslation.web);
      expect(WwTranslation.fromStored('KJV'), WwTranslation.kjv);
      expect(WwTranslation.fromStored(null), WwTranslation.kjv);
    });

    test('chapterVerses returns the active translation chapter', () {
      expect(texts.chapterVerses(WwTranslation.kjv, data, 0), [
        'k1:1',
        'k1:2',
        'k1:3',
      ]);
      expect(texts.chapterVerses(WwTranslation.web, data, 0), ['w1:1', 'w1:2']);
      expect(texts.chapterVerses(WwTranslation.kjv, data, 1), [
        'k2:1',
        'k2:2',
        'k2:3',
      ]);
      expect(texts.chapterVerses(WwTranslation.kjv, data, 99), isEmpty);
    });

    test('verseText clamps to the text chapter length, never throws', () {
      expect(texts.verseText(WwTranslation.kjv, data, 0, 3), 'k1:3');
      // WEB chapter 1 has only 2 verses: verse 3 clamps to verse 2.
      expect(texts.verseText(WwTranslation.web, data, 0, 3), 'w1:2');
      expect(texts.verseText(WwTranslation.web, data, 0, 99), 'w1:2');
      expect(texts.verseText(WwTranslation.kjv, data, 0, 99), 'k1:3');
      expect(texts.verseText(WwTranslation.web, data, 1, 2), 'w2:2');
      // Out-of-range chapter returns ''.
      expect(texts.verseText(WwTranslation.kjv, data, 99, 1), '');
      expect(texts.verseText(WwTranslation.kjv, data, -1, 1), '');
    });
  });
}
