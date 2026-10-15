import 'bible_data.dart';
import 'scripture_text.dart';
import 'tradition.dart';

/// Verse of the Day (board run 11, spec §3): the day's verse is
/// drawn from a pool of the canon's most-connected verses, chosen
/// by a pure date rotation — the same verse all day, no repeat
/// within the pool's length in days. Everything in this file is
/// pure and unit-testable without widgets, SharedPreferences, or
/// the asset bundle.

/// One pool entry: a verse and its deduped connection count.
class VerseOfDayPick {
  const VerseOfDayPick({
    required this.chapter,
    required this.verse,
    required this.connectionCount,
  });

  /// Global chapter index.
  final int chapter;

  /// 1-based verse in the chapter.
  final int verse;

  final int connectionCount;

  @override
  bool operator ==(Object other) =>
      other is VerseOfDayPick &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.connectionCount == connectionCount;

  @override
  int get hashCode => Object.hash(chapter, verse, connectionCount);

  @override
  String toString() =>
      'VerseOfDayPick(chapter $chapter, verse $verse, '
      '$connectionCount connections)';
}

/// Whole days from the epoch to [localDate]'s local calendar day.
/// Resolved through UTC midnights so DST can never shift the
/// count, and time-of-day is ignored: every moment of one local
/// date yields the same value (the "same verse all day"
/// guarantee).
int daysSinceEpochLocal(DateTime localDate) => DateTime.utc(
  localDate.year,
  localDate.month,
  localDate.day,
).difference(DateTime.utc(1970, 1, 1)).inDays;

/// Builds the Verse of the Day pool: every verse of every chapter
/// whose book is inside [tradition]'s canon, ordered by
/// connection count descending with ties broken by canonical
/// order (chapter asc, then verse asc), truncated to [poolSize].
/// A canon holding fewer than [poolSize] verses yields every
/// verse (0-count verses included, in canonical order at the
/// tail) — never an error.
///
/// A verse's count IS `data.verseConnections(ch, v).length`: the
/// counts here are taken as the size of the distinct-target set
/// of the verse's stored connection rows, and
/// [BibleData.verseConnections] dedupes by exactly that target
/// key, so the two counts are identical by construction (the
/// suite asserts the equality on sampled verses).
List<VerseOfDayPick> buildVerseOfDayPool(
  BibleData data,
  WwTradition tradition, {
  int poolSize = 365,
}) {
  final picks = <VerseOfDayPick>[];
  for (var ch = 0; ch < data.chapters.length; ch++) {
    final chapter = data.chapters[ch];
    if (!canonContainsBook(tradition, data, chapter.b)) continue;
    for (var v = 1; v <= chapter.v; v++) {
      final raw = data.verseConnsByPos[data.versePos(ch, v)];
      var count = 0;
      if (raw != null && raw.isNotEmpty) {
        count = <int>{for (final e in raw) e[0] * 1000 + e[1]}.length;
      }
      picks.add(VerseOfDayPick(chapter: ch, verse: v, connectionCount: count));
    }
  }
  picks.sort((a, b) {
    final byCount = b.connectionCount.compareTo(a.connectionCount);
    if (byCount != 0) return byCount;
    final byChapter = a.chapter.compareTo(b.chapter);
    if (byChapter != 0) return byChapter;
    return a.verse.compareTo(b.verse);
  });
  if (picks.length > poolSize) return picks.sublist(0, poolSize);
  return picks;
}

/// The pick for [localDate] from a built [pool]: empty pool →
/// null, otherwise the date's day count modulo the pool length.
VerseOfDayPick? verseOfDayFromPool(
  List<VerseOfDayPick> pool,
  DateTime localDate,
) {
  if (pool.isEmpty) return null;
  return pool[daysSinceEpochLocal(localDate) % pool.length];
}

/// The pick for [localDate], building the pool fresh. Callers
/// that rebuild often (the shell) cache the pool and call
/// [verseOfDayFromPool] directly.
VerseOfDayPick? verseOfDayForDate(
  BibleData data,
  WwTradition tradition,
  DateTime localDate,
) => verseOfDayFromPool(buildVerseOfDayPool(data, tradition), localDate);

/// Reproduces the reader's translation resolution exactly
/// (reader_screen.dart `_availableTranslations` + `_effT`): the
/// tradition's translations for the book's testament, narrowed to
/// the texts actually bundled; the stored choice when it is among
/// them, KJV otherwise.
WwTranslation translationForVerseOfDay({
  required WwTranslation stored,
  required WwTradition tradition,
  required bool otBook,
  required bool Function(WwTranslation) hasTranslation,
}) {
  final available = translationsFor(
    tradition,
    otBook: otBook,
  ).where(hasTranslation);
  return available.contains(stored) ? stored : WwTranslation.kjv;
}

/// Everything the Home Verse of the Day card renders, computed by
/// the shell (spec §3.3): HomeTab formats and renders, it does
/// not compute.
class VerseOfDayCardData {
  const VerseOfDayCardData({
    required this.chapter,
    required this.verse,
    required this.reference,
    required this.connectionCount,
    required this.text,
    required this.translation,
  });

  /// Global chapter index of the pick.
  final int chapter;

  /// 1-based verse of the pick.
  final int verse;

  /// `data.refName(chapter, verse)`.
  final String reference;

  final int connectionCount;

  /// The verse's full text in [translation]; null while the texts
  /// are still loading, '' when they failed to load (a real
  /// in-canon verse with the KJV fallback never resolves to '').
  final String? text;

  /// The effective translation the text was resolved in.
  final WwTranslation translation;
}
