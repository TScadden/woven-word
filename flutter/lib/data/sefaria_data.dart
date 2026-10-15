import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bible_data.dart';

/// The Jewish connections dataset (board run 9): for Tanakh
/// verses, the works on Sefaria that link to the verse — Talmud,
/// Midrash, commentary, halakhah — with link counts, parsed from
/// the bundled dataset (shipped gzipped as
/// `assets/sefaria.json.gz`).
///
/// The pipeline's shape is fixed:
/// ```
/// {"v":1,
///  "works":["Berakhot", "Rashi on Genesis", …],
///  "links":[[globalChapter, verse, workIndex, count], …],
///  "refs":{"chapter:verse:workIndex": "Rashi on Genesis 1:1", …},
///  "capped":{"chapter:verse": totalWorks, …}}
/// ```
/// `refs` is optional: when the pipeline recorded the most
/// specific source ref for a (verse, work) pair, it drives the
/// link-out URL; otherwise the URL is built from the work title
/// and the verse's own ref. Facts only — no Sefaria text is
/// bundled; every row links out to Sefaria (see
/// tools/sefaria/README.md for the route and licence posture).
///
/// Canon discipline matches [ConferenceData]: an entry naming a
/// chapter or verse outside the supplied canon is dropped, never
/// clamped into a different verse (both bounds bind; lesson 18).
/// Only Tanakh chapters can appear — the pipeline filters to the
/// Old Testament before bundling.
class SefariaData {
  SefariaData._(
    this._works,
    this._byVerse,
    this._refs,
    this.linkCount, [
    this._cappedTotals = const {},
  ]);

  final List<String> _works;

  /// (globalChapter, verse) -> [(workIndex, linkCount)], sorted
  /// by count descending then work title ascending on read.
  final Map<(int, int), List<(int, int)>> _byVerse;

  /// "chapter:verse:workIndex" -> the pipeline's recorded source
  /// ref (e.g. "Rashi on Genesis 1:1"), when present.
  final Map<String, String> _refs;

  /// "chapter:verse" -> the verse's FULL citing-work total, for
  /// verses the pipeline capped at the 25 most-cited works
  /// (tools/sefaria/cap_links.py). Absent = the verse is complete
  /// as shipped. The sheet renders a "See all links on Sefaria"
  /// row for capped verses; nothing is silently truncated.
  final Map<String, int> _cappedTotals;

  /// Link entries after dedupe and canon dropping — the count
  /// coverage surfaces report.
  final int linkCount;

  /// Every citing work's title, in bundled order.
  List<String> get works => List.unmodifiable(_works);

  int get workCount => _works.length;

  /// Verses carrying at least one Sefaria connection.
  int get verseCount => _byVerse.length;

  /// The works linking to one verse: (work title, link count),
  /// strongest first (count descending, title ascending for
  /// ties). An out-of-canon or unlinked verse returns empty.
  List<(String, int)> worksForVerse(int globalChapter, int verse) {
    final found = _byVerse[(globalChapter, verse)];
    if (found == null || found.isEmpty) return const [];
    final rows = [
      for (final (workIndex, count) in found)
        if (workIndex >= 0 && workIndex < _works.length)
          (_works[workIndex], count, workIndex),
    ];
    rows.sort((a, b) {
      final byCount = b.$2.compareTo(a.$2);
      if (byCount != 0) return byCount;
      return a.$1.compareTo(b.$1);
    });
    return [for (final r in rows) (r.$1, r.$2)];
  }

  /// Whether any work links to the verse (the reader's dot check
  /// without paying for the sort).
  bool verseHasLinks(int globalChapter, int verse) =>
      _byVerse[(globalChapter, verse)]?.isNotEmpty ?? false;

  /// How many works cite the verse in full: the shipped count,
  /// or the pipeline's recorded total for a capped verse.
  int verseWorkTotal(int globalChapter, int verse) =>
      _cappedTotals['$globalChapter:$verse'] ??
      (_byVerse[(globalChapter, verse)]?.length ?? 0);

  /// The verse's own page on Sefaria — where every link for the
  /// verse lives, capped or not.
  String verseUrl(int globalChapter, int verse, BibleData canon) {
    final chapter = canon.chapters[globalChapter];
    final bookName = _sefariaBookName(canon.books[chapter.b].name);
    return 'https://www.sefaria.org/${_sefariaUrlForm('$bookName ${chapter.c}:$verse')}';
  }

  /// The Sefaria page for a (verse, work) row: the work's own
  /// text at that verse. Sefaria refs use underscores for spaces
  /// in URLs. When the pipeline recorded a specific source ref
  /// it is used verbatim; otherwise the ref is the work title
  /// plus the verse's ref in Sefaria's book naming (the Tanakh
  /// view's names — "I Samuel", "Song of Songs" — are Sefaria's).
  String urlFor(
    String workTitle,
    int globalChapter,
    int verse,
    BibleData canon,
  ) {
    final workIndex = _works.indexOf(workTitle);
    final recorded = workIndex >= 0
        ? _refs['$globalChapter:$verse:$workIndex']
        : null;
    if (recorded != null && recorded.isNotEmpty) {
      return 'https://www.sefaria.org/${_sefariaUrlForm(recorded)}';
    }
    final chapter = canon.chapters[globalChapter];
    final bookName = _sefariaBookName(canon.books[chapter.b].name);
    final ref = '$workTitle.$bookName ${chapter.c}:$verse';
    return 'https://www.sefaria.org/${_sefariaUrlForm(ref)}';
  }

  /// Sefaria's canonical ref-URL form (verified live against
  /// sefaria.org at build time, tools/sefaria/README §3):
  /// segment separators are dots and title spaces are
  /// underscores — "Rashi on Genesis 1:1:1" serves at
  /// Rashi_on_Genesis.1.1.1. The space before the first numeric
  /// segment is a separator too; spaces inside the title are
  /// not.
  static String _sefariaUrlForm(String ref) {
    var out = ref.replaceAll(':', '.');
    final boundary = RegExp(r' (?=[0-9])').firstMatch(out);
    if (boundary != null) {
      out = out.replaceRange(boundary.start, boundary.end, '.');
    }
    return out.replaceAll(' ', '_');
  }

  /// Sefaria's Tanakh book names where they differ from the core
  /// canon's (KJV) names.
  static String _sefariaBookName(String coreName) => switch (coreName) {
    'Song of Solomon' => 'Song of Songs',
    _ => coreName,
  };

  /// Pure parse of the bundled shape (testable without the asset
  /// bundle), mirroring [ConferenceData.parse]'s discipline.
  static SefariaData parse(
    String source, {
    required List<int> chapterVerseCounts,
  }) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final works = <String>[];
    final rawWorks = json['works'];
    if (rawWorks is List) {
      for (final w in rawWorks) {
        if (w is String) works.add(w);
      }
    }
    final byVerse = <(int, int), List<(int, int)>>{};
    final seen = <(int, int, int)>{};
    var linkCount = 0;
    final rawLinks = json['links'];
    if (rawLinks is List) {
      for (final raw in rawLinks) {
        if (raw is! List || raw.length < 4) continue;
        final chapter = (raw[0] as num).toInt();
        final verse = (raw[1] as num).toInt();
        final workIndex = (raw[2] as num).toInt();
        final count = (raw[3] as num).toInt();
        if (workIndex < 0 || workIndex >= works.length) continue;
        if (chapter < 0 || chapter >= chapterVerseCounts.length) continue;
        if (verse < 1 || verse > chapterVerseCounts[chapter]) continue;
        if (!seen.add((chapter, verse, workIndex))) continue;
        linkCount++;
        byVerse.putIfAbsent((chapter, verse), () => []).add((workIndex, count));
      }
    }
    final refs = <String, String>{};
    final rawRefs = json['refs'];
    if (rawRefs is Map) {
      for (final entry in rawRefs.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is String) refs[k] = v;
      }
    }
    final capped = <String, int>{};
    final rawCapped = json['capped'];
    if (rawCapped is Map) {
      for (final entry in rawCapped.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is num) capped[k] = v.toInt();
      }
    }
    return SefariaData._(works, byVerse, refs, linkCount, capped);
  }

  /// [parse] against a parsed [BibleData] canon.
  static SefariaData fromCanon(String source, BibleData canon) =>
      parse(source, chapterVerseCounts: [for (final c in canon.chapters) c.v]);

  /// Loads and indexes the bundled dataset off the UI thread.
  /// The asset ships gzipped (assets/sefaria.json.gz — 37 MB of
  /// JSON at ~5 MB) and is inflated in the same isolate that
  /// parses it. A missing or malformed asset throws here; the
  /// shell's lazy loader catches it and degrades to an unloaded
  /// layer.
  static Future<SefariaData> load(BibleData canon) async {
    final data = await rootBundle.load('assets/sefaria.json.gz');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return compute(_parseSefariaGz, (bytes, canon));
  }
}

/// Top-level parse entry for [compute] in [SefariaData.load]:
/// inflate, decode, parse.
SefariaData _parseSefariaGz((Uint8List, BibleData) args) {
  final inflated = GZipCodec().decode(args.$1);
  return SefariaData.fromCanon(utf8.decode(inflated), args.$2);
}
