import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One book of the Bible: abbreviation, full name, chapter count, and the
/// global chapter index where the book starts.
class Book {
  final String abbr;
  final String name;
  final int chapters;
  final int start;
  const Book(this.abbr, this.name, this.chapters, this.start);
}

/// One chapter: book index, chapter number inside the book, verse count.
class Chapter {
  final int b;
  final int c;
  final int v;
  const Chapter(this.b, this.c, this.v);
}

/// The full cross-reference dataset, parsed from assets/data.json
/// (OpenBible.info cross references, CC BY / Treasury of Scripture
/// Knowledge). Mirrors the web v1 indexing in app.js exactly.
class BibleData {
  final List<Book> books;
  final List<Chapter> chapters;

  /// Chapter-level arc pairs: [chapterA, chapterB, verseRefCount].
  final List<List<int>> chapterArcs;

  /// Raw verse-level refs: [fromChapter, fromVerse, toChapter, toVerse,
  /// votes]. Kept for the reader and verse screens.
  final List<List<int>> refs;

  /// Global verse offset where each chapter starts.
  final List<int> chapterStart;
  final int totalVerses;

  /// Exact connection counts per chapter (out + in), as the web sheet
  /// computes them from the verse refs.
  final List<int> chapterConnCount;

  /// chapter -> {partnerChapter: verseRefCount}, both directions.
  final Map<int, Map<int, int>> chapterPartners;

  /// Verse-level connections, keyed by the clamped global verse
  /// position (see [versePos]) of the source verse. Every ref row is
  /// stored both ways, mirroring the web v1 `refsByVerse` map: values
  /// are [targetChapter, targetVerse, votes] with the target verse
  /// clamped to its chapter's length. Entries are NOT deduped here —
  /// [verseConnections] dedupes on read.
  final Map<int, List<List<int>>> verseConnsByPos;

  const BibleData._(
    this.books,
    this.chapters,
    this.chapterArcs,
    this.refs,
    this.chapterStart,
    this.totalVerses,
    this.chapterConnCount,
    this.chapterPartners,
    this.verseConnsByPos,
  );

  /// The connections of one verse: deduped by target (keeping the
  /// highest votes for a target), sorted by votes descending, then
  /// target chapter ascending, then target verse ascending — the web
  /// v1 connections order, with a deterministic tie-break.
  List<List<int>> verseConnections(int ch, int v) {
    if (ch < 0 || ch >= chapters.length) return const [];
    final raw = verseConnsByPos[versePos(ch, v)];
    if (raw == null || raw.isEmpty) return const [];
    // Target verse is < 1000 for every real chapter, so this key is
    // unique per (targetChapter, targetVerse) pair.
    final bestVotes = <int, int>{};
    for (final entry in raw) {
      final key = entry[0] * 1000 + entry[1];
      final prev = bestVotes[key];
      if (prev == null || entry[2] > prev) bestVotes[key] = entry[2];
    }
    final deduped = [
      for (final e in bestVotes.entries) [e.key ~/ 1000, e.key % 1000, e.value],
    ];
    deduped.sort((a, b) {
      final byVotes = b[2].compareTo(a[2]);
      if (byVotes != 0) return byVotes;
      final byChapter = a[0].compareTo(b[0]);
      if (byChapter != 0) return byChapter;
      return a[1].compareTo(b[1]);
    });
    return deduped;
  }

  /// True when the verse has at least one recorded connection (the
  /// reader's gold dot).
  bool verseHasConnections(int ch, int v) {
    if (ch < 0 || ch >= chapters.length) return false;
    final raw = verseConnsByPos[versePos(ch, v)];
    return raw != null && raw.isNotEmpty;
  }

  /// The chapter's partners sorted by connection count descending,
  /// ties broken by chapter index ascending.
  List<MapEntry<int, int>> partnersSorted(int ch) {
    final partners = chapterPartners[ch];
    if (partners == null) return const [];
    final entries = partners.entries.toList();
    entries.sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  int get totalChapters => chapters.length;

  String chapterName(int ch) => '${books[chapters[ch].b].name} ${chapters[ch].c}';
  String refName(int ch, int v) => '${chapterName(ch)}:$v';

  /// Global verse position of (chapter, verse), verse clamped to the
  /// chapter (the KJV / TSK versification quirk in 3 John is handled the
  /// same way the web app clamps it).
  int versePos(int ch, int v) {
    final len = chapters[ch].v;
    return chapterStart[ch] + v.clamp(1, len) - 1;
  }

  /// The chapter containing a global verse position.
  int chapterAtPosition(int pos) {
    var lo = 0, hi = chapters.length - 1, ans = hi;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (pos < chapterStart[mid] + chapters[mid].v) {
        ans = mid;
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
    return ans;
  }

  /// Chapter range for a scope: 'all' | 'ot' | 'nt'.
  (int, int) scopeRange(String scope) {
    final last = chapters.length - 1;
    if (scope == 'ot' && books.length > 39) {
      return (0, books[38].start + books[38].chapters - 1);
    }
    if (scope == 'nt' && books.length > 39) return (books[39].start, last);
    return (0, last);
  }

  /// Jump search, ported from the web parseSearch: "John 3", "Psalms 23",
  /// or a bare book name (chapter 1). Returns a chapter index or null.
  int? parseSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final m = RegExp(r'^(.*?)\s+(\d+)$').firstMatch(q);
    final bookPart = m?.group(1) ?? q;
    final chapNum = m != null ? int.parse(m.group(2)!) : 1;
    final bi = books.indexWhere(
      (b) =>
          b.name.toLowerCase().startsWith(bookPart) ||
          b.abbr.toLowerCase() == bookPart.replaceAll(RegExp(r'\s'), ''),
    );
    if (bi < 0) return null;
    final book = books[bi];
    return book.start + chapNum.clamp(1, book.chapters) - 1;
  }

  static BibleData fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final books = [
      for (final b in json['books'] as List)
        Book(
          b['abbr'] as String,
          b['name'] as String,
          (b['chapters'] as num).toInt(),
          (b['start'] as num).toInt(),
        ),
    ];
    final chapters = [
      for (final c in json['chapters'] as List)
        Chapter(
          (c['b'] as num).toInt(),
          (c['c'] as num).toInt(),
          (c['v'] as num).toInt(),
        ),
    ];
    List<int> row(dynamic r) => [for (final n in r as List) (n as num).toInt()];
    final chapterArcs = [for (final r in json['chapterArcs'] as List) row(r)];
    final refs = [for (final r in json['refs'] as List) row(r)];

    final chapterStart = List<int>.filled(chapters.length, 0);
    var acc = 0;
    for (var i = 0; i < chapters.length; i++) {
      chapterStart[i] = acc;
      acc += chapters[i].v;
    }

    final connCount = List<int>.filled(chapters.length, 0);
    final partners = <int, Map<int, int>>{};
    void link(int a, int b) {
      final m = partners.putIfAbsent(a, () => <int, int>{});
      m[b] = (m[b] ?? 0) + 1;
    }

    for (final r in refs) {
      final fc = r[0], tc = r[2];
      connCount[fc]++;
      connCount[tc]++;
      link(fc, tc);
      link(tc, fc);
    }

    // Verse-level connections, bidirectional like the web v1
    // refsByVerse: each row is stored from its source verse and from
    // its target verse. Verses clamp to their chapter's length on
    // both sides (versePos clamps the key; the stored target verse
    // clamps explicitly).
    final verseConns = <int, List<List<int>>>{};
    void linkVerse(int fromCh, int fromV, int toCh, int toV, int votes) {
      if (fromCh < 0 || fromCh >= chapters.length) return;
      if (toCh < 0 || toCh >= chapters.length) return;
      final key = chapterStart[fromCh] + fromV.clamp(1, chapters[fromCh].v) - 1;
      final targetV = toV.clamp(1, chapters[toCh].v);
      verseConns.putIfAbsent(key, () => []).add([toCh, targetV, votes]);
    }

    for (final r in refs) {
      linkVerse(r[0], r[1], r[2], r[3], r[4]);
      linkVerse(r[2], r[3], r[0], r[1], r[4]);
    }

    return BibleData._(
      books,
      chapters,
      chapterArcs,
      refs,
      chapterStart,
      acc,
      connCount,
      partners,
      verseConns,
    );
  }

  /// Loads and indexes data.json off the UI thread.
  static Future<BibleData> load() async {
    final source = await rootBundle.loadString('assets/data.json');
    return compute(BibleData.fromJsonString, source);
  }
}

/// log10 for arc weighting, matching the web draw code.
double log10(num x) => math.log(x) / math.ln10;
