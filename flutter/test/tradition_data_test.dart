import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show Uint8List;

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/confession_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/data/sefaria_data.dart';
import 'package:woven_word/data/tradition.dart';

import 'bundled_fixture.dart';
import 'fake_canon.dart';

/// Board run 9: the tradition data layer — the enum + canon
/// views, the Sefaria and confessions parse discipline (both
/// bounds dropped, never clamped; section indices never shifted
/// by a drop), the deuterocanon table, the multi-translation
/// text store, and the REAL bundled assets parsed by the real
/// classes (the licence-manifest shape check: what ships is what
/// the pipelines documented).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WwTradition', () {
    test('stored values round-trip; unknown reads as none', () {
      for (final t in WwTradition.values) {
        expect(WwTradition.fromStored(t.storedValue), t);
      }
      expect(WwTradition.fromStored(null), WwTradition.none);
      expect(WwTradition.fromStored('bogus'), WwTradition.none);
    });

    test('translation sets per tradition and testament', () {
      expect(translationsFor(WwTradition.none, otBook: true), [
        WwTranslation.kjv,
        WwTranslation.web,
      ]);
      expect(translationsFor(WwTradition.lds, otBook: false), [
        WwTranslation.kjv,
        WwTranslation.web,
      ]);
      expect(translationsFor(WwTradition.jewish, otBook: true), [
        WwTranslation.kjv,
        WwTranslation.web,
        WwTranslation.jps,
        WwTranslation.hebrew,
      ]);
      // The Tanakh translations never offer themselves on a New
      // Testament book.
      expect(translationsFor(WwTradition.jewish, otBook: false), [
        WwTranslation.kjv,
        WwTranslation.web,
      ]);
      expect(translationsFor(WwTradition.catholic, otBook: false), [
        WwTranslation.kjv,
        WwTranslation.web,
        WwTranslation.webc,
      ]);
      expect(translationsFor(WwTradition.protestant, otBook: true), [
        WwTranslation.kjv,
        WwTranslation.web,
      ]);
    });

    test('translation labels round-trip through fromStored', () {
      for (final t in WwTranslation.values) {
        expect(WwTranslation.fromStored(t.label), t);
      }
      expect(WwTranslation.fromStored(null), WwTranslation.kjv);
      expect(WwTranslation.fromStored('NRSV'), WwTranslation.kjv);
      expect(WwTranslation.hebrew.isRtl, isTrue);
      expect(WwTranslation.jps.isRtl, isFalse);
    });
  });

  group('CanonView.tanakh', () {
    test('39 books, each core index exactly once, JPS order', () {
      final data = fakeReaderData();
      final view = CanonView.tanakh(data);
      final indices = [for (final s in view.sections) ...s.books.map((b) => b.bookIndex)];
      expect(indices.length, 39);
      expect(indices.toSet().length, 39);
      expect(indices.toSet(), {for (var i = 0; i < 39; i++) i});
      expect(view.sections.map((s) => s.title), [
        'Torah',
        "Nevi'im · Prophets",
        'Ketuvim · Writings',
      ]);
      // Torah first; Ruth sits in Ketuvim (index 7 in Tanakh
      // position 29 overall); Chronicles closes the canon.
      expect(indices.first, 0);
      expect(indices[5], 5); // Joshua opens Nevi'im
      expect(indices[26], 18); // Psalms opens Ketuvim
      expect(indices.last, 13); // II Chronicles last
    });

    test('names come from the canon (one name per book, app-wide)', () {
      final data = fakeReaderData();
      final view = CanonView.tanakh(data);
      for (final s in view.sections) {
        for (final b in s.books) {
          expect(b.name, data.books[b.bookIndex].name);
        }
      }
      final christian = CanonView.forTradition(WwTradition.lds, data);
      expect(christian.sections.length, 2);
      expect(
        christian.sections.fold(0, (n, s) => n + s.books.length),
        66,
      );
    });
  });

  group('SefariaData.parse', () {
    final data = fakeReaderData();
    final counts = [for (final c in data.chapters) c.v];

    SefariaData parse(String src) =>
        SefariaData.parse(src, chapterVerseCounts: counts);

    test('keeps in-canon links, aggregates counts, drops the rest', () {
      final sd = parse(
        jsonEncode({
          'v': 1,
          'works': ['Mishnah Berakhot', 'Tosefta Berakhot'],
          'links': [
            [0, 1, 0, 3], // Genesis 1:1 × Mishnah (aggregated count)
            [0, 1, 0, 3], // exact duplicate row: deduped, not doubled
            [0, 1, 1, 1],
            [0, 11, 0, 1], // verse 11 > count 10: dropped
            [929, 1, 0, 1], // NT chapter: out of the Tanakh set anyway,
            // dropped by the caller's counts only if present; the
            // fake canon has 1189 chapters, so this one is kept by
            // parse and excluded by the PIPELINE — see note below.
            [-1, 1, 0, 1], // negative chapter: dropped
            [0, 0, 0, 1], // verse 0: dropped
            [0, 1, 7, 1], // work index out of range: dropped
          ],
        }),
      );
      final works = sd.worksForVerse(0, 1);
      expect(works, [('Mishnah Berakhot', 3), ('Tosefta Berakhot', 1)]);
      expect(sd.verseHasLinks(0, 1), isTrue);
      expect(sd.verseHasLinks(0, 2), isFalse);
      expect(sd.verseHasLinks(0, 11), isFalse);
    });

    test('urlFor prefers the recorded source ref, else builds one', () {
      final sd = parse(
        jsonEncode({
          'v': 1,
          'works': ['Mishnah Berakhot'],
          'links': [
            [0, 1, 0, 1],
          ],
          'refs': {'0:1:0': 'Mishnah Berakhot 1:1'},
        }),
      );
      expect(
        sd.urlFor('Mishnah Berakhot', 0, 1, data),
        'https://www.sefaria.org/Mishnah_Berakhot.1.1',
      );
      final bare = parse(
        jsonEncode({
          'v': 1,
          'works': ['Midrash'],
          'links': [
            [0, 1, 0, 1],
          ],
        }),
      );
      expect(
        bare.urlFor('Midrash', 0, 1, data),
        'https://www.sefaria.org/Midrash.Genesis.1.1',
      );
    });

    test('capped totals read back; verseUrl is the verse page', () {
      final sd = parse(
        jsonEncode({
          'v': 1,
          'works': ['Mishnah Berakhot'],
          'links': [
            [0, 1, 0, 1],
          ],
          'capped': {'0:1': 42},
        }),
      );
      expect(sd.verseWorkTotal(0, 1), 42);
      expect(sd.verseWorkTotal(0, 2), 0);
      expect(
        sd.verseUrl(0, 1, data),
        'https://www.sefaria.org/Genesis.1.1',
      );
    });
  });

  group('ConfessionData.parse', () {
    final data = fakeReaderData();
    final counts = [for (final c in data.chapters) c.v];

    test('a dropped section never shifts the surviving indices', () {
      final cd = ConfessionData.parse(
        jsonEncode({
          'v': 1,
          'docs': [
            {'id': 'wcf', 'title': 'WCF', 'year': 1647, 'url': 'https://x/'},
          ],
          'sections': [
            {'d': 0, 'id': '1.1', 'label': 'Chapter 1 · Section 1'},
            {'d': 9, 'id': '9.9', 'label': 'Ghost section'}, // dropped
            {'d': 0, 'id': '1.2', 'label': 'Chapter 1 · Section 2'},
          ],
          'edges': [
            [0, 0, 1],
            [1, 0, 1], // names the dropped raw section: must not land on 1.2
            [2, 0, 2],
            [2, 0, 99], // verse out of bounds: dropped
          ],
        }),
        chapterVerseCounts: counts,
      );
      expect(cd.sections.length, 2);
      expect(cd.sections[1].index, 1); // parsed index is contiguous
      expect(cd.sectionsForVerse(0, 1).map((s) => s.id), ['1.1']);
      expect(cd.sectionsForVerse(0, 2).map((s) => s.id), ['1.2']);
      expect(cd.verseHasProofs(0, 1), isTrue);
      expect(cd.urlFor(cd.sections[0]), 'https://x/');
    });
  });

  group('DeuterocanonData.parse', () {
    final deut = DeuterocanonData.parse(
      jsonEncode({
        'books': [
          {
            'slug': 'tobit',
            'name': 'Tobit',
            'abbr': 'Tob',
            'chapters': 2,
            'verseCounts': [3, 2],
          },
          {
            'slug': 'bad',
            'name': 'Bad',
            'abbr': 'Bad',
            'chapters': 2,
            'verseCounts': [3], // inconsistent: dropped whole
          },
        ],
      }),
    );

    test('bounds, labels, positions', () {
      expect(deut.books.length, 1);
      final tobit = deut.books.single;
      expect(tobit.bookIndex, DeuteroBook.bookIndexBase);
      expect(deut.positionInCanon(tobit.bookIndex, 1, 3), isTrue);
      expect(deut.positionInCanon(tobit.bookIndex, 1, 4), isFalse);
      expect(deut.positionInCanon(tobit.bookIndex, 3, 1), isFalse);
      expect(deut.positionInCanon(0, 1, 1), isFalse);
      expect(deut.refLabel(tobit.bookIndex, 2, 1), 'Tobit 2:1');
      expect(deut.totalChapters, 2);
    });
  });

  group('ScriptureText traditions', () {
    String textJson(String tag, {bool otOnly = false}) {
      final data = fakeReaderData();
      final byBook = <int, List<List<String>>>{};
      for (var gi = 0; gi < data.chapters.length; gi++) {
        final ch = data.chapters[gi];
        byBook.putIfAbsent(ch.b, () => []).add([
          for (var v = 1; v <= ch.v; v++) '$tag ${data.chapterName(gi)}:$v',
        ]);
      }
      return jsonEncode([
        for (var b = 0; b < 66; b++)
          if (otOnly && b >= 39) <List<String>>[] else byBook[b] ?? [],
      ]);
    }

    test('JPS renders on the OT, falls back to KJV on the NT', () {
      final data = fakeReaderData();
      final texts = ScriptureText.fromPayloads(
        kjv: textJson('KJV'),
        web: textJson('WEB'),
        jps: textJson('JPS', otOnly: true),
      );
      expect(texts.hasTranslation(WwTranslation.jps), isTrue);
      expect(texts.hasTranslation(WwTranslation.hebrew), isFalse);
      expect(texts.hasTranslation(WwTranslation.webc), isFalse);
      expect(texts.verseText(WwTranslation.jps, data, 0, 1), 'JPS Genesis 1:1');
      final john = data.books[42].start;
      // JPS has no John: the held place renders the KJV text,
      // never blank.
      expect(
        texts.verseText(WwTranslation.jps, data, john, 1),
        'KJV John 1:1',
      );
      expect(
        texts.chapterVerses(WwTranslation.jps, data, john).first,
        'KJV John 1:1',
      );
    });

    test('WEBC extras read by slug; core chapters map by table', () {
      final data = fakeReaderData();
      final webcBooks = jsonEncode([
        {
          'usfm': 'TOB',
          'name': 'Tobit',
          'core': null,
          'extra': 'tobit',
        },
        {
          'usfm': 'GEN',
          'name': 'Genesis',
          'core': 0,
          'extra': null,
        },
      ]);
      final webc = jsonEncode([
        [
          ['Tobit text one', 'Tobit text two'],
        ],
        [
          ['WEBC Genesis one'],
        ],
      ]);
      final texts = ScriptureText.fromPayloads(
        kjv: textJson('KJV'),
        web: textJson('WEB'),
        webc: webc,
        webcBooks: webcBooks,
      );
      expect(texts.hasTranslation(WwTranslation.webc), isTrue);
      expect(texts.extraChapterVerses('tobit', 1), [
        'Tobit text one',
        'Tobit text two',
      ]);
      expect(texts.extraVerseText('tobit', 1, 2), 'Tobit text two');
      expect(texts.extraVerseText('tobit', 9, 1), '');
      expect(texts.verseText(WwTranslation.webc, data, 0, 1),
          'WEBC Genesis one');
      // A core book the edition does not carry falls back to KJV.
      final john = data.books[42].start;
      expect(texts.verseText(WwTranslation.webc, data, john, 1), 'KJV John 1:1');
    });
  });

  group('bundled assets parse with the real classes', () {
    test('confessions.json: two documents, sorted deduped edges', () {
      // Parse against the REAL canon counts loaded from
      // data.json (the fake canon's 10-verse chapters would drop
      // real edges by design).
      final raw = readBundledJson('assets/confessions.json.gz');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect((json['docs'] as List).length, 2);
      expect((json['sections'] as List).length, 331);
      expect((json['edges'] as List).length, 5005);
      final realCanon = readBundledJson('assets/data.json.gz');
      final canonJson = jsonDecode(realCanon) as Map<String, dynamic>;
      final counts = [
        for (final c in canonJson['chapters'] as List)
          (c as Map)['v'] as int,
      ];
      final cd = ConfessionData.parse(raw, chapterVerseCounts: counts);
      expect(cd.docs.map((d) => d.id), ['wcf', 'lbc1689']);
      expect(cd.sections.length, 331);
      expect(cd.edgeCount, 5005);
    });

    test('sefaria.json.gz: the capped dataset parses whole', () {
      final realCanon = readBundledJson('assets/data.json.gz');
      final canonJson = jsonDecode(realCanon) as Map<String, dynamic>;
      final counts = [
        for (final c in canonJson['chapters'] as List)
          (c as Map)['v'] as int,
      ];
      final gz = File('assets/sefaria.json.gz').readAsBytesSync();
      final source = utf8.decode(GZipCodec().decode(Uint8List.fromList(gz)));
      final sd = SefariaData.parse(source, chapterVerseCounts: counts);
      expect(sd.workCount, 3407);
      expect(sd.linkCount, 534526);
      // Genesis 1:1 is the most-linked verse in the Tanakh: it
      // is capped at the 25 most-cited works (by citing-segment
      // count), and its full total is recorded — 478 works.
      final works = sd.worksForVerse(0, 1);
      expect(works.length, 25);
      expect(works.map((w) => w.$1), contains('Or HaChaim on Genesis'));
      expect(sd.verseWorkTotal(0, 1), 478);
      // Malachi 4 (global 928) has no links — the pipeline's
      // documented Hebrew-versification gap, visible in the data.
      expect(sd.verseHasLinks(928, 1), isFalse);
      // JPS and Hebrew bundles: 66 slots, Tanakh filled.
      final jps = jsonDecode(readBundledJson('assets/jps.json.gz')) as List;
      expect(jps.length, 66);
      expect((jps[0] as List).length, 50);
      expect((jps[39] as List), isEmpty);
      expect(((jps[0] as List)[0] as List)[0] as String,
          startsWith('IN THE beginning'));
      final heb = jsonDecode(readBundledJson('assets/hebrew.json.gz')) as List;
      expect(heb.length, 66);
      expect((heb[0] as List).length, 50);
      expect((heb[39] as List), isEmpty);
    });

    test('webc.json + deuterocanon.json: the extra canon is whole', () {
      final booksRaw = File('assets/webc_books.json').readAsStringSync();
      final books = jsonDecode(booksRaw) as List;
      expect(books.length, 73);
      final deutRaw = File('assets/deuterocanon.json').readAsStringSync();
      final deut = DeuterocanonData.parse(deutRaw);
      expect(deut.books.map((b) => b.slug), [
        'tobit',
        'judith',
        'esther-greek',
        'wisdom',
        'sirach',
        'baruch',
        '1-maccabees',
        '2-maccabees',
        'daniel-greek',
      ]);
      expect(deut.totalChapters, 161);
      // Every extra chapter's text exists in the WEBC payload.
      final webc = jsonDecode(readBundledJson('assets/webc.json.gz')) as List;
      final texts = ScriptureText.fromPayloads(
        kjv: '[]',
        web: '[]',
        webc: readBundledJson('assets/webc.json.gz'),
        webcBooks: booksRaw,
      );
      for (final b in deut.books) {
        for (var ch = 1; ch <= b.chapters; ch++) {
          expect(
            texts.extraChapterVerses(b.slug, ch).length,
            b.verseCounts[ch - 1],
            reason: '${b.slug} $ch',
          );
        }
      }
      expect(webc.length, 73);
    });
  });
}
