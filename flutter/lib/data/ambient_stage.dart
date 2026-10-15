import 'dart:math' as math;

import 'bible_data.dart';
import 'tradition.dart';

/// The ambient Home stage's data layer (HOME ARCH GOES AMBIENT,
/// spec team/specs/arch-ambient-home.md): which chapters may be
/// featured, how one is picked, and the per-chapter arc geometry
/// the stage painter consumes. Everything here is computed ONCE
/// from the loaded dataset — a rotation tick does one picker
/// draw and nothing else (spec §7).

/// How long one chapter is featured before the next draw
/// (spec §4: the founder's "every couple seconds", pinned).
const ambientInterval = Duration(seconds: 3);

/// How long the arcs morph between two features (spec §4).
const ambientMorphDuration = Duration(milliseconds: 600);

/// The eligibility floor as a fraction of the active canon's
/// median per-chapter connection count (spec §2, pinned by the
/// producer's brief).
const ambientFloorFraction = 0.25;

/// The median of [counts] (sorted; odd → the middle value,
/// even → the mean of the two middle values). Empty → 0.
double ambientMedianOf(List<int> counts) {
  if (counts.isEmpty) return 0;
  final sorted = [...counts]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid].toDouble();
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/// The chapters of [counts] (indexed by global chapter) that
/// pass the eligibility floor, restricted to chapters for which
/// [inCanon] holds: the median is taken over the canon chapters
/// only, the floor is [ambientFloorFraction] of it, and a
/// chapter is eligible when its total connection count is at or
/// above the floor (spec §2).
({List<int> pool, double median, double floor}) ambientEligible({
  required List<int> counts,
  required bool Function(int chapter) inCanon,
}) {
  final canonCounts = [
    for (var ch = 0; ch < counts.length; ch++)
      if (inCanon(ch)) counts[ch],
  ];
  final median = ambientMedianOf(canonCounts);
  final floor = ambientFloorFraction * median;
  return (
    pool: [
      for (var ch = 0; ch < counts.length; ch++)
        if (inCanon(ch) && counts[ch] >= floor) ch,
    ],
    median: median,
    floor: floor,
  );
}

/// The ambient pool for [tradition] over [data] (spec §2).
/// Canon membership is book-level: the books the tradition's
/// [CanonView] presents. Deuterocanon books pass
/// `canonContainsBook` under Catholic but carry no connection
/// data and no arcs (deuterocanon.dart's own doc), so the pool
/// iterates core chapters only (spec I-2): under Catholic the
/// pool is the full-core pool.
({List<int> pool, double median, double floor}) buildAmbientPool(
  BibleData data,
  WwTradition tradition,
) {
  final canonBooks = CanonView.forTradition(
    tradition,
    data,
  ).bookOrder.toSet();
  return ambientEligible(
    counts: data.chapterConnCount,
    inCanon: (ch) => canonBooks.contains(data.chapters[ch].b),
  );
}

/// The (first, last) global chapter indices of the tradition's
/// canon — the stage's arc range (spec §4). Falls back to the
/// whole canon when a view presents nothing.
(int, int) ambientRange(BibleData data, WwTradition tradition) {
  final order = CanonView.forTradition(tradition, data).bookOrder;
  if (order.isEmpty) return (0, data.totalChapters - 1);
  var lo = data.totalChapters - 1;
  var hi = 0;
  for (final b in order) {
    if (b < 0 || b >= data.books.length) continue;
    final book = data.books[b];
    lo = math.min(lo, book.start);
    hi = math.max(hi, book.start + book.chapters - 1);
  }
  return (lo, hi);
}

/// Uniform random picker over the eligible pool with no
/// immediate repeat (spec §3): the draw is an index into the
/// pool with the current chapter's slot skipped, so every
/// non-current member is equally likely.
class AmbientPicker {
  AmbientPicker([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;

  /// The next featured chapter, or null for an empty pool. A
  /// one-chapter pool returns its only chapter.
  int? next(List<int> pool, int? current) {
    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;
    final currentIndex = current == null ? -1 : pool.indexOf(current);
    if (currentIndex < 0) return pool[_random.nextInt(pool.length)];
    final r = _random.nextInt(pool.length - 1);
    return pool[r < currentIndex ? r : r + 1];
  }
}

/// One precomputed partner arc of a featured chapter: the exact
/// inputs `MiniSelectionPainter` derives per paint (spec §7) —
/// the partner chapter, the global verse positions of both
/// chapters' mid verses, and the pair's verse-ref count.
class AmbientArc {
  const AmbientArc({
    required this.partner,
    required this.fromPos,
    required this.toPos,
    required this.count,
  });

  final int partner;
  final int fromPos;
  final int toPos;
  final int count;
}

/// Per-chapter arc geometry for the whole dataset, computed
/// once (spec §7): chapter → its partner arcs, partner
/// ascending (the morph's rank order, spec §4).
Map<int, List<AmbientArc>> buildAmbientArcGeometry(BibleData data) {
  final out = <int, List<AmbientArc>>{};
  for (var ch = 0; ch < data.totalChapters; ch++) {
    final partners = data.chapterPartners[ch];
    if (partners == null || partners.isEmpty) continue;
    final fromPos = data.versePos(ch, (data.chapters[ch].v / 2).ceil());
    final sorted = partners.keys.toList()..sort();
    out[ch] = [
      for (final p in sorted)
        AmbientArc(
          partner: p,
          fromPos: fromPos,
          toPos: data.versePos(p, (data.chapters[p].v / 2).ceil()),
          count: partners[p]!,
        ),
    ];
  }
  return out;
}
