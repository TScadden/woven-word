import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/screens/my_notes_screen.dart';

/// A two-book mini canon: Genesis (2 chapters) and Exodus (1).
BibleData miniCanon() {
  final books = <Map<String, Object>>[];
  final chapters = <Map<String, Object>>[];
  var start = 0;
  for (final (abbr, name, count) in [
    ('Gen', 'Genesis', 2),
    ('Exod', 'Exodus', 1),
  ]) {
    books.add({'abbr': abbr, 'name': name, 'chapters': count, 'start': start});
    for (var c = 1; c <= count; c++) {
      chapters.add({'b': books.length - 1, 'c': c, 'v': 10});
    }
    start += count;
  }
  return BibleData.fromJsonString(
    jsonEncode({
      'books': books,
      'chapters': chapters,
      'chapterArcs': <List<int>>[],
      'refs': <List<int>>[],
    }),
  );
}

void main() {
  group('notePositionInCanon (My Notes corrupt-key filter)', () {
    final data = miniCanon();

    test('real positions pass', () {
      expect(notePositionInCanon(data, 0, 1, 1), isTrue);
      expect(notePositionInCanon(data, 0, 2, 10), isTrue);
      expect(notePositionInCanon(data, 1, 1, 5), isTrue);
    });

    test('chapter zero is rejected (regression: b0c0v1 computed '
        'global chapter -1 and crashed the reference label)', () {
      expect(notePositionInCanon(data, 0, 0, 1), isFalse);
      expect(notePositionInCanon(data, 1, 0, 1), isFalse);
    });

    test('verse zero is rejected', () {
      expect(notePositionInCanon(data, 0, 1, 0), isFalse);
    });

    test('out-of-canon book and chapter are rejected', () {
      expect(notePositionInCanon(data, 2, 1, 1), isFalse);
      expect(notePositionInCanon(data, 99, 1, 1), isFalse);
      expect(notePositionInCanon(data, 0, 3, 1), isFalse);
      expect(notePositionInCanon(data, 1, 2, 1), isFalse);
    });

    test('the filter drops a zero-chapter note from the list rows', () {
      final userData = UserData();
      userData.setNote('default', 'kjv', 'b0c1v1', 'real note');
      // Written straight into the bucket, the way a corrupt stored
      // document would load it — setNote would store it too, since
      // the store is key-agnostic by design.
      userData.setNote('default', 'kjv', 'b0c0v1', 'corrupt note');
      final rows = userData
          .notesFor('default', 'kjv')
          .where(
            (n) => notePositionInCanon(data, n.book, n.chapter, n.verse),
          )
          .toList();
      expect(rows.map((n) => n.key), ['b0c1v1']);
    });
  });
}
