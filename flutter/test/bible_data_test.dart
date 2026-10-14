import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';

/// Builds a full 66-book dataset in memory (10 verses per chapter, no
/// refs) from the real canon structure, so search and chapter math run
/// against the true book layout.
String fakeBibleJson() {
  const canon = [
    ('Gen', 'Genesis', 50), ('Exod', 'Exodus', 40), ('Lev', 'Leviticus', 27),
    ('Num', 'Numbers', 36), ('Deut', 'Deuteronomy', 34), ('Josh', 'Joshua', 24),
    ('Judg', 'Judges', 21), ('Ruth', 'Ruth', 4), ('1Sam', '1 Samuel', 31),
    ('2Sam', '2 Samuel', 24), ('1Kgs', '1 Kings', 22), ('2Kgs', '2 Kings', 25),
    ('1Chr', '1 Chronicles', 29), ('2Chr', '2 Chronicles', 36),
    ('Ezra', 'Ezra', 10), ('Neh', 'Nehemiah', 13), ('Esth', 'Esther', 10),
    ('Job', 'Job', 42), ('Ps', 'Psalms', 150), ('Prov', 'Proverbs', 31),
    ('Eccl', 'Ecclesiastes', 12), ('Song', 'Song of Solomon', 8),
    ('Isa', 'Isaiah', 66), ('Jer', 'Jeremiah', 52), ('Lam', 'Lamentations', 5),
    ('Ezek', 'Ezekiel', 48), ('Dan', 'Daniel', 12), ('Hos', 'Hosea', 14),
    ('Joel', 'Joel', 3), ('Amos', 'Amos', 9), ('Obad', 'Obadiah', 1),
    ('Jonah', 'Jonah', 4), ('Mic', 'Micah', 7), ('Nah', 'Nahum', 3),
    ('Hab', 'Habakkuk', 3), ('Zeph', 'Zephaniah', 3), ('Hag', 'Haggai', 2),
    ('Zech', 'Zechariah', 14), ('Mal', 'Malachi', 4), ('Matt', 'Matthew', 28),
    ('Mark', 'Mark', 16), ('Luke', 'Luke', 24), ('John', 'John', 21),
    ('Acts', 'Acts', 28), ('Rom', 'Romans', 16), ('1Cor', '1 Corinthians', 16),
    ('2Cor', '2 Corinthians', 13), ('Gal', 'Galatians', 6), ('Eph', 'Ephesians', 6),
    ('Phil', 'Philippians', 4), ('Col', 'Colossians', 4),
    ('1Thess', '1 Thessalonians', 5), ('2Thess', '2 Thessalonians', 3),
    ('1Tim', '1 Timothy', 6), ('2Tim', '2 Timothy', 4), ('Titus', 'Titus', 3),
    ('Phlm', 'Philemon', 1), ('Heb', 'Hebrews', 13), ('Jas', 'James', 5),
    ('1Pet', '1 Peter', 5), ('2Pet', '2 Peter', 3), ('1John', '1 John', 5),
    ('2John', '2 John', 1), ('3John', '3 John', 1), ('Jude', 'Jude', 1),
    ('Rev', 'Revelation', 22),
  ];
  final books = <Map<String, Object>>[];
  final chapters = <Map<String, Object>>[];
  var start = 0;
  for (var bi = 0; bi < canon.length; bi++) {
    final (abbr, name, count) = canon[bi];
    books.add({'abbr': abbr, 'name': name, 'chapters': count, 'start': start});
    for (var c = 1; c <= count; c++) {
      chapters.add({'b': bi, 'c': c, 'v': 10});
    }
    start += count;
  }
  return jsonEncode({
    'books': books,
    'chapters': chapters,
    'chapterArcs': <List<int>>[],
    'refs': [
      [0, 1, 5, 2, 3], // Genesis 1 -> Joshua 1
      [5, 2, 0, 1, 3],
    ],
  });
}

void main() {
  final data = BibleData.fromJsonString(fakeBibleJson());

  test('canon shape: 66 books, 1189 chapters', () {
    expect(data.books.length, 66);
    expect(data.totalChapters, 1189);
    expect(data.totalVerses, 11890);
  });

  test('chapter names and positions round-trip', () {
    final psalms = data.books[18];
    expect(data.chapterName(psalms.start), 'Psalms 1');
    expect(data.chapterName(psalms.start + 22), 'Psalms 23');
    final pos = data.versePos(psalms.start + 22, 4);
    expect(data.chapterAtPosition(pos), psalms.start + 22);
    // Verse clamps to the chapter length.
    expect(data.versePos(0, 999), data.chapterStart[0] + 9);
  });

  test('scope ranges split at Malachi / Matthew', () {
    final (otLo, otHi) = data.scopeRange('ot');
    expect(otLo, 0);
    expect(data.chapterName(otHi), 'Malachi 4');
    final (ntLo, ntHi) = data.scopeRange('nt');
    expect(data.chapterName(ntLo), 'Matthew 1');
    expect(data.chapterName(ntHi), 'Revelation 22');
    expect(data.scopeRange('all'), (0, 1188));
  });

  test('jump search parses book and chapter', () {
    expect(data.chapterName(data.parseSearch('John 3')!), 'John 3');
    expect(data.chapterName(data.parseSearch('Psalms 23')!), 'Psalms 23');
    expect(data.chapterName(data.parseSearch('genesis')!), 'Genesis 1');
    expect(data.chapterName(data.parseSearch('Ps 119')!), 'Psalms 119');
    expect(data.parseSearch('not a book'), isNull);
    expect(data.parseSearch(''), isNull);
    // Chapter clamps to the book.
    expect(data.chapterName(data.parseSearch('Jude 9')!), 'Jude 1');
  });

  test('connection counts come from verse refs, both directions', () {
    expect(data.chapterConnCount[0], 2);
    expect(data.chapterConnCount[5], 2);
    expect(data.chapterPartners[0], {5: 2});
    expect(data.chapterPartners[5], {0: 2});
  });
}
