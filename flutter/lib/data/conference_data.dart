import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bible_data.dart';

/// One LDS General Conference talk in the connections layer
/// (board run 8, data layer only — no UI consumes this yet).
///
/// Mirrors one row of the bundled `assets/conference.json` talks
/// table, which the studio pipeline emits in the compact shape
/// `{"i","t","s","y","e","n","u","c","x"}`; [ConferenceData.parse]
/// expands it to these named fields.
class ConferenceTalk {
  const ConferenceTalk({
    required this.id,
    required this.title,
    required this.speaker,
    required this.year,
    required this.session,
    required this.sessionName,
    required this.url,
    required this.urlIsConference,
    this.indexUrl,
  });

  /// Stable id: the talk's index in the bundled talks table, and
  /// the first element of every edge that cites from this talk.
  final int id;
  final String title;
  final String speaker;
  final int year;

  /// Conference session within the year: 'A' (April) or 'O'
  /// (October). October is the later conference in a year — the
  /// ordering rule every newest-first sort in [ConferenceData]
  /// applies.
  final String session;

  /// The session's display name as emitted by the pipeline, e.g.
  /// 'Sunday Morning'. Carried verbatim; never derived.
  final String sessionName;

  /// The talk's Gospel Library link, or null when the pipeline
  /// has no link for this talk.
  final String? url;

  /// True when [url] is the conference-level fallback link (the
  /// conference's own page) rather than this talk's own page —
  /// the pipeline's `c: 1` flag. A reader action can use this to
  /// label the link honestly.
  final bool urlIsConference;

  /// The talk's own page on the Scripture Citation Index
  /// (scriptures.byu.edu) — the pipeline's `x` field, recorded
  /// from the index's conference pages (founder correction,
  /// Oct 14, 2026: Gospel Library's archive bottoms out at
  /// 1971–1979, so a talk with no per-talk Gospel Library link
  /// opens here instead). Null when the pipeline recorded none.
  final String? indexUrl;

  /// 'April 2024' / 'October 2024'.
  String get conferenceLabel => '${session == 'O' ? 'October' : 'April'} $year';
}

/// Session rank for newest-first ordering: October ('O', 1) sorts
/// before April ('A', 0) within the same year.
int _sessionRank(String session) => session == 'O' ? 1 : 0;

/// Newest-first talk order, the one sort every surface shares:
/// year descending, October before April within a year, then
/// dataset order within one conference (spec §3.3 — a conference
/// is a program, and its talks keep the order they were given;
/// never a title re-sort). Ids are bundled-table indices, so id
/// ascending IS dataset order, and it makes the order total.
int _newestFirst(ConferenceTalk a, ConferenceTalk b) {
  final byYear = b.year.compareTo(a.year);
  if (byYear != 0) return byYear;
  final bySession = _sessionRank(b.session).compareTo(_sessionRank(a.session));
  if (bySession != 0) return bySession;
  return a.id.compareTo(b.id);
}

/// Top-level parse entry for [compute] in [ConferenceData.load].
/// The chapter table crosses the isolate boundary as plain
/// `[bookIndex, chapterInBook, verseCount]` rows — always sendable.
ConferenceData _parsePayload((String, List<List<int>>) args) {
  final (source, rows) = args;
  return ConferenceData.parse(
    source,
    chapterVerseCounts: [for (final r in rows) r[2]],
    chapters: [for (final r in rows) Chapter(r[0], r[1], r[2])],
  );
}

/// The General Conference connections dataset (board run 8):
/// talks plus verse-level citation edges from talks to Bible
/// verses, parsed from the bundled `assets/conference.json`.
///
/// The pipeline's shape is fixed:
/// ```
/// {"v":1,
///  "talks":[{"i":0,"t":"title","s":"speaker","y":2024,"e":"O",
///            "n":"Sunday Morning","u":"https://… or null","c":0,
///            "x":"https://scriptures.byu.edu/… or null"}],
///  "edges":[[talkId, globalChapterZeroBased, verse], …]}
/// ```
/// `c` is 1 when `u` is a conference-level fallback link; `x` is
/// the talk's own Scripture Citation Index page, or null. Edges
/// are verse-level and may contain duplicates (overlapping cited
/// ranges emit the same verse twice) — [parse] dedupes them.
///
/// Canon discipline matches [BibleData]: an edge naming a chapter
/// or verse outside the supplied canon is dropped, never clamped
/// into a different verse (both bounds bind — chapter/verse 0 and
/// negatives drop too; lesson 18). The canon enters only as data
/// the caller passes in ([parse]'s counts + chapter table, or a
/// [BibleData] via [fromCanon] / [load]); no canon table is
/// hardcoded here.
class ConferenceData {
  ConferenceData._(
    this._talks,
    this._byId,
    this._byVerse,
    this._byTalk,
    this._chapters,
    this.edgeCount,
  );

  final List<ConferenceTalk> _talks;
  final Map<int, ConferenceTalk> _byId;

  /// (globalChapter, verse) -> citing talks, unsorted; sorting
  /// happens on read so the order lives in exactly one place.
  final Map<(int, int), List<ConferenceTalk>> _byVerse;

  /// talkId -> its deduped (globalChapter, verse) citations,
  /// sorted in canon order (chapter, then verse).
  final Map<int, List<(int, int)>> _byTalk;

  /// The canon's chapter table (book index + chapter-in-book per
  /// global chapter) when the caller supplied one, used by
  /// [refsForTalk] to label groups. Null for counts-only parses.
  final List<Chapter>? _chapters;

  /// Citation edges after dedupe and canon dropping — the count
  /// every coverage surface reports.
  final int edgeCount;

  /// Every talk in the dataset, in bundled (id) order.
  List<ConferenceTalk> get talks => List.unmodifiable(_talks);

  int get talkCount => _talks.length;

  /// Earliest conference year in the dataset; null when empty.
  int? get firstYear => _talks.isEmpty
      ? null
      : _talks.map((t) => t.year).reduce((a, b) => a < b ? a : b);

  /// Latest conference year in the dataset; null when empty.
  int? get lastYear => _talks.isEmpty
      ? null
      : _talks.map((t) => t.year).reduce((a, b) => a > b ? a : b);

  ConferenceTalk? talkById(int id) => _byId[id];

  /// Talks citing one verse, newest first (year descending,
  /// October before April within a year, dataset order within
  /// one conference). An out-of-canon or uncited verse returns
  /// an empty list.
  List<ConferenceTalk> talksForVerse(int globalChapter, int verse) {
    final found = _byVerse[(globalChapter, verse)];
    if (found == null || found.isEmpty) return const [];
    return [...found]..sort(_newestFirst);
  }

  /// Whether any talk cites the verse (a surface's dot/badge
  /// check without paying for the sort).
  bool verseHasTalks(int globalChapter, int verse) =>
      _byVerse[(globalChapter, verse)]?.isNotEmpty ?? false;

  /// One talk's cited references, grouped by chapter and sorted
  /// in canon order: `(bookIndex, chapterInBook, verses)` with
  /// verses ascending inside each group. An unknown talk id
  /// returns an empty list.
  ///
  /// Book labels come from the chapter table supplied to [parse]
  /// (production loads always supply it, via [load] / [fromCanon]).
  /// A counts-only parse has no book boundaries, so its groups
  /// fall back to a single-book reading (book 0, chapter =
  /// global chapter + 1) — correct only for single-book canons.
  List<(int, int, List<int>)> refsForTalk(int talkId) {
    final edges = _byTalk[talkId];
    if (edges == null || edges.isEmpty) return const [];
    // Edges are stored canon-sorted, so groups form in one pass:
    // consecutive edges in the same chapter extend the last group.
    final groups = <(int, int, List<int>)>[];
    for (final (chapter, verse) in edges) {
      final (book, chapterInBook) = _bookChapter(chapter);
      if (groups.isNotEmpty) {
        final last = groups.last;
        if (last.$1 == book && last.$2 == chapterInBook) {
          last.$3.add(verse);
          continue;
        }
      }
      groups.add((book, chapterInBook, [verse]));
    }
    return groups;
  }

  (int, int) _bookChapter(int globalChapter) {
    final chapters = _chapters;
    if (chapters != null &&
        globalChapter >= 0 &&
        globalChapter < chapters.length) {
      final ch = chapters[globalChapter];
      return (ch.b, ch.c);
    }
    return (0, globalChapter + 1);
  }

  /// Every conference present in the dataset as
  /// `(year, session, talkCount)`, newest first (year descending,
  /// October before April within a year).
  ///
  /// The count is talks with at least one Bible citation (spec
  /// §4.1) — exactly the talks that are keys of [_byTalk], the
  /// deduped-edge index built by [parse]. A conference whose
  /// talks cite no Bible verses has a zero count and is absent
  /// from the result (spec §4.2).
  List<(int, String, int)> conferences() {
    final counts = <(int, String), int>{};
    for (final talk in _talks) {
      if (!(_byTalk[talk.id]?.isNotEmpty ?? false)) continue;
      final key = (talk.year, talk.session);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final result = [
      for (final e in counts.entries) (e.key.$1, e.key.$2, e.value),
    ];
    result.sort((a, b) {
      final byYear = b.$1.compareTo(a.$1);
      if (byYear != 0) return byYear;
      return _sessionRank(b.$2).compareTo(_sessionRank(a.$2));
    });
    return result;
  }

  /// The talks of one conference, in the dataset's own session
  /// order (spec §4.3 + §3.3): filtering [_talks] preserves the
  /// bundled (id) order, and no re-sort is applied — a conference
  /// is a program, and its talks keep the order they were given.
  List<ConferenceTalk> talksInConference(int year, String session) {
    return [
      for (final t in _talks)
        if (t.year == year && t.session == session) t,
    ];
  }

  /// Pure parse of the bundled shape (testable without the asset
  /// bundle), mirroring [BibleData.fromJsonString]'s discipline.
  ///
  /// [chapterVerseCounts] is the canon bound for edge validation:
  /// its length is the chapter count and each entry is that
  /// chapter's verse count. [chapters], when supplied, is the
  /// same canon's chapter table and labels [refsForTalk] groups;
  /// pass both from the same [BibleData] (or use [fromCanon]).
  static ConferenceData parse(
    String source, {
    required List<int> chapterVerseCounts,
    List<Chapter>? chapters,
  }) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final talks = <ConferenceTalk>[];
    final byId = <int, ConferenceTalk>{};
    final rawTalks = json['talks'];
    if (rawTalks is List) {
      for (final raw in rawTalks) {
        if (raw is! Map) continue;
        final urlRaw = raw['u'];
        final indexRaw = raw['x'];
        final talk = ConferenceTalk(
          id: (raw['i'] as num).toInt(),
          title: raw['t'] as String,
          speaker: raw['s'] as String,
          year: (raw['y'] as num).toInt(),
          session: raw['e'] as String,
          sessionName: raw['n'] as String,
          url: urlRaw is String ? urlRaw : null,
          urlIsConference: (raw['c'] as num? ?? 0).toInt() == 1,
          indexUrl: indexRaw is String ? indexRaw : null,
        );
        talks.add(talk);
        byId[talk.id] = talk;
      }
    }

    final byVerse = <(int, int), List<ConferenceTalk>>{};
    final byTalk = <int, List<(int, int)>>{};
    final seen = <(int, int, int)>{};
    var edgeCount = 0;
    final rawEdges = json['edges'];
    if (rawEdges is List) {
      for (final raw in rawEdges) {
        if (raw is! List || raw.length < 3) continue;
        final talkId = (raw[0] as num).toInt();
        final chapter = (raw[1] as num).toInt();
        final verse = (raw[2] as num).toInt();
        final talk = byId[talkId];
        if (talk == null) continue;
        // Canon clamp by dropping, both bounds (lesson 18): an
        // edge outside the canon names no real verse.
        if (chapter < 0 || chapter >= chapterVerseCounts.length) continue;
        if (verse < 1 || verse > chapterVerseCounts[chapter]) continue;
        if (!seen.add((talkId, chapter, verse))) continue; // dedupe
        edgeCount++;
        byVerse.putIfAbsent((chapter, verse), () => []).add(talk);
        byTalk.putIfAbsent(talkId, () => []).add((chapter, verse));
      }
    }
    for (final edges in byTalk.values) {
      edges.sort((a, b) {
        final byChapter = a.$1.compareTo(b.$1);
        if (byChapter != 0) return byChapter;
        return a.$2.compareTo(b.$2);
      });
    }

    return ConferenceData._(talks, byId, byVerse, byTalk, chapters, edgeCount);
  }

  /// [parse] against a parsed [BibleData] canon — the form every
  /// production caller uses, so counts and chapter table can
  /// never disagree.
  static ConferenceData fromCanon(String source, BibleData canon) => parse(
    source,
    chapterVerseCounts: [for (final c in canon.chapters) c.v],
    chapters: canon.chapters,
  );

  /// Loads and indexes assets/conference.json off the UI thread,
  /// mirroring [ScriptureText.load]. A missing or malformed asset
  /// throws here; the shell's lazy loader catches it and degrades
  /// to an unloaded layer (failures-as-values at the call site).
  static Future<ConferenceData> load(BibleData canon) async {
    final source = await rootBundle.loadString('assets/conference.json');
    final rows = [
      for (final c in canon.chapters) [c.b, c.c, c.v],
    ];
    return compute(_parsePayload, (source, rows));
  }
}
