import 'bible_data.dart';
import 'scripture_text.dart';
import 'tradition.dart';
import 'verse_of_day_curation.dart';

/// Verse of the Day (board run 11, spec §3; pool rule replaced by
/// team/specs/verse-of-day-quotable.md, founder ruling Oct 15,
/// 2026 — "the verses should be ones that people can quote"): the
/// day's verse is drawn from a quotability pool, chosen by a pure
/// date rotation — the same verse all day, no repeat within the
/// pool's length in days. Everything in this file is pure and
/// unit-testable without widgets, SharedPreferences, or the asset
/// bundle.

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

/// The core canons' quotability floor (quotable spec §2.2): a
/// verse enters the core pool only when at least this many
/// distinct conference talks cite it.
const int votdCitationFloor = 25;

/// The Jewish canon's prominence floor (quotable spec §2.2): a
/// verse enters the Tanakh pool only at this many deduped
/// cross-reference connections. (The conference corpus is a
/// Latter-day Saint corpus; its signal is not used there.)
const int votdConnectionFloor = 55;

/// The degraded pool's size (quotable spec §2.5): when the
/// citation counts fail to load, the core pool falls back to the
/// shipped run 11 ranking truncated to this many verses.
const int votdFallbackPoolSize = 365;

const Set<String> _votdNumberWords = {
  'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
  'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
  'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
  'eighty', 'ninety', 'hundred', 'thousand',
};

final RegExp _votdBegat = RegExp(r'\bbegat\b');
final RegExp _votdItinerary = RegExp(
  r'\b(removed|departed|journeyed) from [a-z\-]+,? and (encamped|pitched)\b',
);
final RegExp _votdWordTokens = RegExp(r'[a-z]+');
final RegExp _votdWhitespace = RegExp(r'\s+');

/// Strips the punctuation set `.,;:!?()` from both ends of [word],
/// mirroring Python's `str.strip('.,;:!?()')` in the normative
/// predicate implementation.
String _stripVotdPunctuation(String word) {
  const strip = {'.', ',', ';', ':', '!', '?', '(', ')'};
  var start = 0;
  var end = word.length;
  while (start < end && strip.contains(word[start])) {
    start++;
  }
  while (end > start && strip.contains(word[end - 1])) {
    end--;
  }
  return word.substring(start, end);
}

/// Python's `str.isupper()` for one character: cased and upper.
bool _isUpperChar(String c) =>
    c.toUpperCase() == c && c.toLowerCase() != c;

/// The encoded quotability predicates (quotable spec §2.3), a
/// pure function of the verse's bundled KJV text: true when the
/// verse passes all four — i.e. it is NOT a genealogy line (P1,
/// "begat"), NOT an itinerary log entry (P2, "removed/departed/
/// journeyed from `place` and encamped/pitched"), NOT a census /
/// name list (P3, "the children of" with ≥ 2 spelled-out number
/// words, or a "these are the names of" opening), and NOT a
/// proper-name list by density (P4, in a verse of ≥ 6 words,
/// ≥ 45% of the non-initial words capitalized).
///
/// This is a Dart port of the normative implementation,
/// `tools/votd_curation/generate.py` (`predicates()`); the two
/// must match exactly, and the suite pins both with the same
/// exemplars (spec §5 test 1).
bool versePassesQuotabilityPredicates(String kjvText) {
  final low = kjvText.toLowerCase();
  // P1 — genealogy verb.
  if (_votdBegat.hasMatch(low)) return false;
  // P2 — itinerary log.
  if (_votdItinerary.hasMatch(low)) return false;
  // P3 — census / name list.
  final numberWords = _votdWordTokens
      .allMatches(low)
      .map((m) => m.group(0)!)
      .where(_votdNumberWords.contains)
      .length;
  if ((low.contains('the children of') && numberWords >= 2) ||
      low.startsWith('these are the names of') ||
      low.startsWith('and these are the names of')) {
    return false;
  }
  // P4 — name density.
  final toks = kjvText.trim().split(_votdWhitespace);
  if (toks.length >= 6) {
    final internal = <String>[];
    for (final w in toks.skip(1)) {
      final stripped = _stripVotdPunctuation(w);
      if (stripped.isNotEmpty) internal.add(stripped);
    }
    if (internal.isNotEmpty &&
        internal.where((w) => _isUpperChar(w[0])).length / internal.length >=
            0.45) {
      return false;
    }
  }
  return true;
}

/// Builds the Verse of the Day pool under the quotable rule
/// (team/specs/verse-of-day-quotable.md §2): a signal floor per
/// canon, the §2.3 encoded predicates, and the §2.4 curatorial
/// exclusions ([votdCuratorialExclusions], always applied).
///
/// - Canon membership is [canonContainsBook] intersected with
///   the core book range: only book indices < 1000 carry
///   connection data, so deuterocanon books never pool.
/// - Jewish tradition: the connections rule — verses with at
///   least [votdConnectionFloor] connections, ranked connections
///   descending then canonical order. [citationCount] is
///   ignored.
/// - Other traditions with [citationCount] provided: the
///   citation rule — verses cited by at least
///   [votdCitationFloor] distinct talks, ranked citations
///   descending, connections descending, canonical order. No
///   truncation and no padding: the floor is the standard.
/// - Other traditions without [citationCount] (the citation
///   signal failed to load): the §2.5 fallback — the shipped
///   run 11 ranking (connections descending, canonical order),
///   still filtered, truncated to [votdFallbackPoolSize].
///
/// The §2.3 predicates run when [kjvText] is provided (the shell
/// only builds the pool once texts are loaded, so in practice it
/// always is).
///
/// A verse's connection count IS
/// `data.verseConnections(ch, v).length`: the counts here are
/// taken as the size of the distinct-target set of the verse's
/// stored connection rows, and [BibleData.verseConnections]
/// dedupes by exactly that target key, so the two counts are
/// identical by construction (the suite asserts the equality on
/// sampled verses).
List<VerseOfDayPick> buildVerseOfDayPool(
  BibleData data,
  WwTradition tradition, {
  int Function(int globalChapter, int verse)? citationCount,
  String Function(int globalChapter, int verse)? kjvText,
}) {
  final isJewish = tradition == WwTradition.jewish;
  final useCitations = !isJewish && citationCount != null;
  // Candidates carry their citation count alongside the pick for
  // the citation ranking; it is not part of the pick's shape.
  final candidates = <(VerseOfDayPick, int)>[];
  for (var ch = 0; ch < data.chapters.length; ch++) {
    final chapter = data.chapters[ch];
    if (chapter.b >= 1000) continue;
    if (!canonContainsBook(tradition, data, chapter.b)) continue;
    for (var v = 1; v <= chapter.v; v++) {
      final raw = data.verseConnsByPos[data.versePos(ch, v)];
      var count = 0;
      if (raw != null && raw.isNotEmpty) {
        count = <int>{for (final e in raw) e[0] * 1000 + e[1]}.length;
      }
      final citations = useCitations ? citationCount(ch, v) : 0;
      if (isJewish) {
        if (count < votdConnectionFloor) continue;
      } else if (useCitations) {
        if (citations < votdCitationFloor) continue;
      }
      if (votdCuratorialExclusions.containsKey((ch, v))) continue;
      if (kjvText != null &&
          !versePassesQuotabilityPredicates(kjvText(ch, v))) {
        continue;
      }
      candidates.add((
        VerseOfDayPick(chapter: ch, verse: v, connectionCount: count),
        citations,
      ));
    }
  }
  candidates.sort((a, b) {
    if (useCitations) {
      final byCitations = b.$2.compareTo(a.$2);
      if (byCitations != 0) return byCitations;
    }
    final byCount = b.$1.connectionCount.compareTo(a.$1.connectionCount);
    if (byCount != 0) return byCount;
    final byChapter = a.$1.chapter.compareTo(b.$1.chapter);
    if (byChapter != 0) return byChapter;
    return a.$1.verse.compareTo(b.$1.verse);
  });
  var picks = [for (final c in candidates) c.$1];
  if (!isJewish && !useCitations && picks.length > votdFallbackPoolSize) {
    picks = picks.sublist(0, votdFallbackPoolSize);
  }
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
/// [verseOfDayFromPool] directly. The pool inputs forward to
/// [buildVerseOfDayPool] unchanged.
VerseOfDayPick? verseOfDayForDate(
  BibleData data,
  WwTradition tradition,
  DateTime localDate, {
  int Function(int globalChapter, int verse)? citationCount,
  String Function(int globalChapter, int verse)? kjvText,
}) => verseOfDayFromPool(
  buildVerseOfDayPool(
    data,
    tradition,
    citationCount: citationCount,
    kjvText: kjvText,
  ),
  localDate,
);

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
