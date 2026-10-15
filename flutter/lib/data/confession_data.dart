import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bible_data.dart';
import 'bundled_gzip.dart';

/// One historic confession in the Protestant connections layer
/// (board run 9): a public-domain document whose published
/// proof-text lists are citation facts (see
/// tools/confessions/README.md for sources and licences).
class ConfessionDoc {
  const ConfessionDoc({
    required this.id,
    required this.title,
    required this.year,
    required this.url,
  });

  final String id;
  final String title;
  final int year;

  /// The document's page at its host (OPC / CCEL) — the
  /// link-out target when a section has no anchor of its own.
  final String url;
}

/// One section of a confession (e.g. Westminster chapter 1,
/// section 1) and the verses its proof list cites.
class ConfessionSection {
  const ConfessionSection({
    required this.index,
    required this.docIndex,
    required this.id,
    required this.label,
    this.url,
  });

  /// Index into the bundled sections table (edge rows name it).
  final int index;

  /// Index into [ConfessionData.docs].
  final int docIndex;

  /// The document's own section id (e.g. "1.1").
  final String id;

  /// Display label (e.g. "Chapter 1 · Section 1").
  final String label;

  /// A per-section link-out URL when the host's own URL
  /// structure provides one; null falls back to the doc's URL.
  final String? url;
}

/// The Protestant connections dataset: confession sections plus
/// verse-level proof edges, parsed from the bundled
/// `assets/confessions.json.gz`.
///
/// The pipeline's shape is fixed:
/// ```
/// {"v":1,
///  "docs":[{"id":"wcf","title":"…","year":1647,"url":"https://…"}],
///  "sections":[{"d":0,"id":"1.1","label":"Chapter 1 · Section 1",
///               "u":"https://… or null"}],
///  "edges":[[sectionIndex, globalChapter, verse], …]}
/// ```
/// Canon discipline matches [ConferenceData]: edges naming a
/// chapter or verse outside the supplied canon are dropped,
/// never clamped (both bounds bind; lesson 18).
class ConfessionData {
  ConfessionData._(
    this._docs,
    this._sections,
    this._byVerse,
    this._bySection,
    this.edgeCount,
  );

  final List<ConfessionDoc> _docs;
  final List<ConfessionSection> _sections;

  /// (globalChapter, verse) -> citing section indices, in
  /// bundled (document, then section) order.
  final Map<(int, int), List<int>> _byVerse;

  /// sectionIndex -> its deduped (globalChapter, verse) proofs,
  /// sorted in canon order.
  final Map<int, List<(int, int)>> _bySection;

  /// Proof edges after dedupe and canon dropping.
  final int edgeCount;

  List<ConfessionDoc> get docs => List.unmodifiable(_docs);
  List<ConfessionSection> get sections => List.unmodifiable(_sections);

  ConfessionDoc docFor(ConfessionSection section) => _docs[section.docIndex];

  /// The link-out target for a section: its own URL when the
  /// pipeline recorded one, else its document's URL.
  String urlFor(ConfessionSection section) =>
      section.url ?? _docs[section.docIndex].url;

  /// Sections citing one verse, in bundled order (document
  /// order, then the document's own section order). An
  /// out-of-canon or uncited verse returns empty.
  List<ConfessionSection> sectionsForVerse(int globalChapter, int verse) {
    final found = _byVerse[(globalChapter, verse)];
    if (found == null || found.isEmpty) return const [];
    return [for (final i in found) _sections[i]];
  }

  /// Whether any section cites the verse (the reader's dot
  /// check without paying for the lookup).
  bool verseHasProofs(int globalChapter, int verse) =>
      _byVerse[(globalChapter, verse)]?.isNotEmpty ?? false;

  /// One section's cited verses, in canon order.
  List<(int, int)> versesForSection(int sectionIndex) =>
      _bySection[sectionIndex] ?? const [];

  /// Sections of one document, in the document's own order.
  List<ConfessionSection> sectionsOf(int docIndex) => [
    for (final s in _sections)
      if (s.docIndex == docIndex) s,
  ];

  /// Pure parse of the bundled shape (testable without the
  /// asset bundle), mirroring [ConferenceData.parse].
  static ConfessionData parse(
    String source, {
    required List<int> chapterVerseCounts,
  }) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final docs = <ConfessionDoc>[];
    final rawDocs = json['docs'];
    if (rawDocs is List) {
      for (final raw in rawDocs) {
        if (raw is! Map) continue;
        docs.add(
          ConfessionDoc(
            id: raw['id'] as String,
            title: raw['title'] as String,
            year: (raw['year'] as num).toInt(),
            url: raw['url'] as String,
          ),
        );
      }
    }
    final sections = <ConfessionSection>[];
    final rawSections = json['sections'];
    // Edge rows name sections by their RAW table index (the
    // pipeline emits the sections table and the edges against
    // it); a dropped section would shift every later index, so
    // the parse keeps a raw -> parsed remap and applies it to
    // the edges below.
    final rawToParsed = <int, int>{};
    if (rawSections is List) {
      for (var i = 0; i < rawSections.length; i++) {
        final raw = rawSections[i];
        if (raw is! Map) continue;
        final docIndex = (raw['d'] as num).toInt();
        if (docIndex < 0 || docIndex >= docs.length) continue;
        final urlRaw = raw['u'];
        rawToParsed[i] = sections.length;
        sections.add(
          ConfessionSection(
            index: sections.length,
            docIndex: docIndex,
            id: raw['id'] as String,
            label: raw['label'] as String,
            url: urlRaw is String ? urlRaw : null,
          ),
        );
      }
    }
    final byVerse = <(int, int), List<int>>{};
    final bySection = <int, List<(int, int)>>{};
    final seen = <(int, int, int)>{};
    var edgeCount = 0;
    final rawEdges = json['edges'];
    if (rawEdges is List) {
      for (final raw in rawEdges) {
        if (raw is! List || raw.length < 3) continue;
        final rawSectionIndex = (raw[0] as num).toInt();
        final chapter = (raw[1] as num).toInt();
        final verse = (raw[2] as num).toInt();
        final sectionIndex = rawToParsed[rawSectionIndex];
        if (sectionIndex == null) continue;
        if (chapter < 0 || chapter >= chapterVerseCounts.length) continue;
        if (verse < 1 || verse > chapterVerseCounts[chapter]) continue;
        if (!seen.add((sectionIndex, chapter, verse))) continue;
        edgeCount++;
        byVerse.putIfAbsent((chapter, verse), () => []).add(sectionIndex);
        bySection.putIfAbsent(sectionIndex, () => []).add((chapter, verse));
      }
    }
    for (final edges in bySection.values) {
      edges.sort((a, b) {
        final byChapter = a.$1.compareTo(b.$1);
        if (byChapter != 0) return byChapter;
        return a.$2.compareTo(b.$2);
      });
    }
    return ConfessionData._(docs, sections, byVerse, bySection, edgeCount);
  }

  /// [parse] against a parsed [BibleData] canon.
  static ConfessionData fromCanon(String source, BibleData canon) =>
      parse(source, chapterVerseCounts: [for (final c in canon.chapters) c.v]);

  /// Loads and indexes assets/confessions.json.gz off the UI
  /// thread — the asset ships gzipped and is inflated in the
  /// same isolate that parses it. A missing or malformed asset
  /// throws here; the shell's lazy loader catches it and degrades
  /// to an unloaded layer.
  static Future<ConfessionData> load(BibleData canon) async {
    final bytes = await loadBundledBytes('assets/confessions.json.gz');
    return compute(_parseConfessions, (bytes, canon));
  }
}

/// Top-level parse entry for [compute] in [ConfessionData.load]:
/// inflate, then parse via [ConfessionData.fromCanon] unchanged.
ConfessionData _parseConfessions((Uint8List, BibleData) args) =>
    ConfessionData.fromCanon(inflateBundledJson(args.$1), args.$2);
