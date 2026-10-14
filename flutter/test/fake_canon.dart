import 'dart:convert';

import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/scripture_text.dart';

/// A full 66-book fake canon in the real canon structure (same book
/// order/counts as `bible_data_test.dart`'s fake), with per-chapter
/// verse counts chosen for reader tests: 10 verses everywhere,
/// except Psalms 119 which carries its real 176 so cold verse
/// landings at scale are testable (R-T3), and Genesis 1 / John 1
/// cross references for connection tests.
String fakeReaderJson() {
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
      final verses = (name == 'Psalms' && c == 119) ? 176 : 10;
      chapters.add({'b': bi, 'c': c, 'v': verses});
    }
    start += count;
  }
  // Global chapter indices used by tests.
  final psalmsStart = books[18]['start'] as int;
  final johnStart = books[42]['start'] as int;
  return jsonEncode({
    'books': books,
    'chapters': chapters,
    'chapterArcs': <List<int>>[],
    'refs': [
      // Genesis 1:1 <-> Psalms 119:1, and Genesis 1:1 <-> John 1:1.
      [0, 1, psalmsStart + 118, 1, 7],
      [0, 1, johnStart, 1, 5],
      // Genesis 1:2 <-> Genesis 1:1 (same-chapter connection).
      [0, 2, 0, 1, 3],
    ],
  });
}

BibleData fakeReaderData() => BibleData.fromJsonString(fakeReaderJson());

/// Fake texts for [data]: every chapter's verses match the data's
/// verse counts; verse text is long enough to wrap at phone widths
/// so verse heights are text-derived, not floor-derived. KJV and
/// WEB differ in wording/length, so their stream models differ.
ScriptureText fakeReaderTexts(BibleData data) {
  List<List<List<String>>> build(String tag, String filler) {
    final byBook = <int, List<List<String>>>{};
    for (var gi = 0; gi < data.chapters.length; gi++) {
      final ch = data.chapters[gi];
      final verses = <String>[
        for (var v = 1; v <= ch.v; v++)
          '$tag ${data.chapterName(gi)}:$v '
              '$filler verse $v speaks of the woven word and its '
              'connections across the whole canon of scripture.',
      ];
      byBook.putIfAbsent(ch.b, () => []).add(verses);
    }
    return [for (var b = 0; b < data.books.length; b++) byBook[b] ?? []];
  }

  final kjv = build('KJV', 'In the beginning');
  final web = build('WEB', 'At the very start of all things');
  return ScriptureText.fromJsonStrings(jsonEncode(kjv), jsonEncode(web));
}
