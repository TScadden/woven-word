import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/library_search.dart';
import 'package:woven_word/data/tradition.dart';

import 'fake_canon.dart';

/// Search fix package: the §3 matching model as pure data —
/// contains/abbr book matching in canon presentation order,
/// the chapter rule (every match, never a clamp), tradition
/// scope, the Catholic deuterocanon, and the conference
/// layer's title/speaker matching in newest-first order.
void main() {
  late BibleData data;
  late ConferenceData conference;
  late DeuterocanonData deutero;

  const conferenceFixture = '''
{"v":1,"talks":[
 {"i":0,"t":"The Voice of the Lord","s":"John D. Amos","y":2024,"e":"O","n":"Saturday Morning","u":null,"c":0},
 {"i":1,"t":"John's Witness of Christ","s":"Mary E. Jones","y":2025,"e":"A","n":"Sunday Morning","u":null,"c":0},
 {"i":2,"t":"Hope in Christ","s":"John D. Amos","y":2023,"e":"A","n":"Saturday Evening","u":null,"c":0}
],"edges":[]}''';

  const deuteroFixture = '''
{"v":1,"books":[
 {"slug":"tobit","name":"Tobit","abbr":"Tob","chapters":14,"verseCounts":[10,10,10,10,10,10,10,10,10,10,10,10,10,10]},
 {"slug":"judith","name":"Judith","abbr":"Jdt","chapters":16,"verseCounts":[10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10]}
]}''';

  setUp(() {
    data = fakeReaderData();
    conference = ConferenceData.parse(
      conferenceFixture,
      chapterVerseCounts: [for (final c in data.chapters) c.v],
      chapters: data.chapters,
    );
    deutero = DeuterocanonData.parse(deuteroFixture);
  });

  LibrarySearchResults run(
    String query, {
    WwTradition tradition = WwTradition.none,
    bool withDeutero = false,
    bool withConference = false,
  }) => searchLibrary(
    data: data,
    tradition: tradition,
    query: query,
    deuterocanon: withDeutero ? deutero : null,
    conference: withConference ? conference : null,
  );

  int bookIndex(String name) =>
      data.books.indexWhere((b) => b.name == name);
  int chapterIndex(String name, int chapter) =>
      data.books[bookIndex(name)].start + chapter - 1;

  group('books (§3.1)', () {
    test('blank query yields no groups at all', () {
      expect(run('').isEmpty, isTrue);
      expect(run('   ').isEmpty, isTrue);
    });

    test('name contains, in canon order (the founder query)', () {
      final r = run('john');
      expect(r.books, [
        bookIndex('John'),
        bookIndex('1 John'),
        bookIndex('2 John'),
        bookIndex('3 John'),
      ]);
      expect(r.chapters, isEmpty);
      expect(r.deuteroBooks, isEmpty);
      expect(r.talks, isEmpty, reason: 'no conference supplied');
    });

    test('matching is case-insensitive and trims', () {
      expect(run('  JOHN ').books, run('john').books);
    });

    test('abbreviation prefix on the squashed query', () {
      // "1 Samuel"'s name does not contain "1sam" (the space);
      // the squashed abbreviation carries the match.
      expect(run('1sam').books, [bookIndex('1 Samuel')]);
      expect(run('ps').books, contains(bookIndex('Psalms')));
    });

    test('presentation order follows the tradition (Tanakh)', () {
      // Core order: Joshua, Job, Joel, Jonah, then the Johns.
      // Tanakh order: Joshua (Nevi'im), Joel, Jonah (Nevi'im),
      // Job (Ketuvim) — and no New Testament at all.
      expect(run('jo').books, [
        bookIndex('Joshua'),
        bookIndex('Job'),
        bookIndex('Joel'),
        bookIndex('Jonah'),
        bookIndex('John'),
        bookIndex('1 John'),
        bookIndex('2 John'),
        bookIndex('3 John'),
      ]);
      expect(run('jo', tradition: WwTradition.jewish).books, [
        bookIndex('Joshua'),
        bookIndex('Joel'),
        bookIndex('Jonah'),
        bookIndex('Job'),
      ]);
    });
  });

  group('chapters (§3.3)', () {
    test('book + chapter resolves the reference', () {
      expect(run('john 3').chapters, [chapterIndex('John', 3)]);
      expect(run('psalms 23').chapters, [chapterIndex('Psalms', 23)]);
      expect(run('ps 23').chapters, [chapterIndex('Psalms', 23)]);
    });

    test('numbered books resolve by name prefix', () {
      expect(run('1 john 3').chapters, [chapterIndex('1 John', 3)]);
      expect(run('2 john 1').chapters, [chapterIndex('2 John', 1)]);
    });

    test('an out-of-range chapter is NO result — never a clamp', () {
      expect(run('john 99').chapters, isEmpty);
      expect(run('john 99').isEmpty, isTrue);
      expect(run('2 john 2').chapters, isEmpty, reason: '2 John has 1 chapter');
      expect(run('john 0').chapters, isEmpty);
    });

    test('a bare book name yields no chapter result', () {
      expect(run('john').chapters, isEmpty);
      expect(run('3').chapters, isEmpty);
    });
  });

  group('tradition scope (§3.1)', () {
    test('Jewish mode offers no New Testament book or chapter', () {
      final r = run('john', tradition: WwTradition.jewish);
      expect(r.books, isEmpty);
      expect(r.chapters, isEmpty);
      expect(run('john 3', tradition: WwTradition.jewish).chapters, isEmpty);
      expect(
        run('genesis', tradition: WwTradition.jewish).books,
        [bookIndex('Genesis')],
      );
    });
  });

  group('deuterocanon (§3.2)', () {
    test('Catholic mode searches the table', () {
      final r = run('tobit', tradition: WwTradition.catholic, withDeutero: true);
      expect(r.deuteroBooks.map((b) => b.name), ['Tobit']);
      expect(r.books, isEmpty);
    });

    test('deutero chapter references resolve', () {
      final r = run(
        'tobit 3',
        tradition: WwTradition.catholic,
        withDeutero: true,
      );
      expect(r.deuteroChapters, [(deutero.books[0], 3)]);
      expect(
        run('tobit 99', tradition: WwTradition.catholic, withDeutero: true)
            .deuteroChapters,
        isEmpty,
      );
    });

    test('the table is inert outside Catholic mode', () {
      final r = run(
        'tobit',
        tradition: WwTradition.protestant,
        withDeutero: true,
      );
      expect(r.deuteroBooks, isEmpty);
      expect(r.isEmpty, isTrue);
    });

    test('Catholic mode without the table loaded stays core-only', () {
      final r = run('tobit', tradition: WwTradition.catholic);
      expect(r.deuteroBooks, isEmpty);
      expect(r.isEmpty, isTrue);
    });
  });

  group('talks (§3.4)', () {
    test('title or speaker match, newest first', () {
      final r = run('john', withConference: true);
      expect(r.talks.map((t) => t.id), [1, 0, 2]);
    });

    test('speaker-only match', () {
      final r = run('amos', withConference: true);
      expect(r.talks.map((t) => t.id), [0, 2]);
    });

    test('no conference supplied means no talks, structurally', () {
      expect(run('john').talks, isEmpty);
      expect(run('amos').talks, isEmpty);
    });

    test('a talk query does not leak into the book groups', () {
      final r = run('amos', withConference: true);
      expect(r.books, [bookIndex('Amos')], reason: 'the prophet still matches');
      expect(r.chapters, isEmpty);
    });
  });
}
