import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bible_data.dart';
import 'tradition.dart';

/// Study Plans (board run 11, spec §4): three plans generated
/// from canon data, their schedules derived (never stored), and
/// per-profile progress persisted OUTSIDE `UserData` — the
/// backup format is untouched — under [plansPrefsKey].

/// One plan's fixed definition: id, name, day count, and the
/// books it covers in definition order (null = every book in the
/// data).
class StudyPlanDef {
  const StudyPlanDef({
    required this.id,
    required this.name,
    required this.days,
    this.bookIndices,
  });

  final String id;
  final String name;
  final int days;
  final List<int>? bookIndices;
}

/// The three plans, in the order Home offers them.
const List<StudyPlanDef> wwStudyPlans = [
  StudyPlanDef(
    id: 'gospels',
    name: 'The Gospels',
    days: 30,
    bookIndices: [39, 40, 41, 42],
  ),
  StudyPlanDef(
    id: 'psalms-proverbs',
    name: 'Psalms & Proverbs',
    days: 60,
    bookIndices: [18, 19],
  ),
  StudyPlanDef(
    id: 'whole-bible',
    name: 'The Whole Bible',
    days: 365,
    bookIndices: null,
  ),
];

/// The plan's chapters as global indices, in canonical
/// (BibleData) order: the definition's books in definition order,
/// each book's chapters expanded via `book.start`. Presentation
/// order (e.g. the Tanakh's Ketuvim order) never reorders a plan.
/// Totals are derived from [BibleData], never hard-coded.
List<int> planChapters(BibleData data, StudyPlanDef plan) {
  final books =
      plan.bookIndices ?? [for (var i = 0; i < data.books.length; i++) i];
  return [
    for (final b in books)
      for (var c = 0; c < data.books[b].chapters; c++) data.books[b].start + c,
  ];
}

/// A plan is offered only when EVERY book in its definition is
/// inside [tradition]'s canon. Switching tradition never mutates
/// plan state — an out-of-canon plan is simply not offered
/// (dormancy, the run-10 pattern).
bool planAvailable(StudyPlanDef plan, WwTradition tradition, BibleData data) {
  final books =
      plan.bookIndices ?? [for (var i = 0; i < data.books.length; i++) i];
  return books.every((b) => canonContainsBook(tradition, data, b));
}

/// The plan's schedule (spec §4.2, base/remainder — interpretation
/// I-2): with `T` chapters over `D` days, `base = T ~/ D` and
/// `rem = T % D`; day `i` (1-based) receives `base + 1` chapters
/// when `i <= rem`, else `base`, taken consecutively from
/// [planChapters] in order. Day sizes differ by at most 1,
/// earlier days are never smaller than later days, no day is
/// empty (every plan here has T > D), and concatenating the days
/// reproduces [planChapters] exactly.
List<List<int>> planSchedule(BibleData data, StudyPlanDef plan) {
  final chapters = planChapters(data, plan);
  final total = chapters.length;
  final days = plan.days;
  final base = total ~/ days;
  final rem = total % days;
  final schedule = <List<int>>[];
  var offset = 0;
  for (var i = 1; i <= days; i++) {
    final size = base + (i <= rem ? 1 : 0);
    schedule.add(chapters.sublist(offset, offset + size));
    offset += size;
  }
  return schedule;
}

/// 'yyyy-mm-dd' from [local]'s local components, zero-padded.
String planDateKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

/// A strict date-key parse: the `yyyy-mm-dd` shape AND a real
/// calendar date (verified by re-formatting to the identical
/// string, so month 13 and Feb 30 fail). Null when invalid.
DateTime? _parseDateKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
  return planDateKey(parsed) == value ? parsed : null;
}

/// Calendar days from [fromLocal] to [toLocal], computed through
/// UTC midnights (the [daysSinceEpochLocal] method) so DST can
/// never shift the difference.
int calendarDaysBetween(DateTime fromLocal, DateTime toLocal) {
  final from = DateTime.utc(fromLocal.year, fromLocal.month, fromLocal.day);
  final to = DateTime.utc(toLocal.year, toLocal.month, toLocal.day);
  return to.difference(from).inDays;
}

/// The plan's current day: `clamp(days since start + 1, 1,
/// days)`. An unparseable [startedOn] yields 1; a [startedOn] in
/// the future (clock skew) yields 1.
int planDayFor({
  required String startedOn,
  required DateTime today,
  required int days,
}) {
  final start = _parseDateKey(startedOn);
  if (start == null) return 1;
  return (calendarDaysBetween(start, today) + 1).clamp(1, days);
}

/// Done chapters that belong to THIS plan: the intersection of
/// the stored set with the plan's chapters, never the raw set,
/// so a corrupt store can never push progress past 100% or count
/// another plan's chapters.
int planDoneCount(PlanProgress? progress, List<int> chapters) {
  if (progress == null) return 0;
  return chapters.where(progress.done.contains).length;
}

/// Integer-floor percent: the same value on the Home card, in
/// the detail status, and in tests.
int planPercent(int done, int total) => total == 0 ? 0 : (done * 100) ~/ total;

/// One profile's progress in one plan.
class PlanProgress {
  PlanProgress({required this.startedOn, required this.done});

  /// 'yyyy-mm-dd' local start date.
  final String startedOn;

  /// Global chapter indices checked off.
  final Set<int> done;

  Map<String, dynamic> toJson() => {
    'startedOn': startedOn,
    'done': [...done]..sort(),
  };

  @override
  bool operator ==(Object other) =>
      other is PlanProgress &&
      other.startedOn == startedOn &&
      other.done.length == done.length &&
      other.done.containsAll(done);

  @override
  int get hashCode => Object.hash(startedOn, Object.hashAllUnordered(done));
}

/// The SharedPreferences key for the plans store.
const String plansPrefsKey = 'ww_plans_v1';

/// Per-profile plan progress, persisted as one SharedPreferences
/// string whose JSON is exactly
/// `{profileId: {planId: {"startedOn": "yyyy-mm-dd", "done": [int, …]}}}`.
///
/// Mutators are synchronous and in-memory; persistence is [save]
/// (the UI calls it fire-and-forget with a catch after each
/// mutation — the Profiles `_persist` pattern, so the visible
/// change never waits on disk).
class PlansStore {
  PlansStore._(this._prefs, this.state);

  final SharedPreferences _prefs;

  /// profileId -> planId -> progress.
  final Map<String, Map<String, PlanProgress>> state;

  static Future<PlansStore> load(SharedPreferences prefs) async =>
      PlansStore._(prefs, parse(prefs.getString(plansPrefsKey)));

  /// Defensive load (lesson 18/22 discipline): bad shapes are
  /// dropped entry by entry, never thrown. Unknown plan ids and
  /// unknown profile ids are PRESERVED verbatim (forward
  /// compatibility; display and counting filter by known
  /// definitions). Non-negative `done` integers beyond the canon
  /// are kept in state (they may belong to a plan not currently
  /// offered; counting always intersects).
  static Map<String, Map<String, PlanProgress>> parse(String? raw) {
    final out = <String, Map<String, PlanProgress>>{};
    if (raw == null) return out;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return out;
    }
    if (decoded is! Map) return out;
    for (final profileEntry in decoded.entries) {
      final profileId = profileEntry.key;
      final plans = profileEntry.value;
      if (profileId is! String || plans is! Map) continue;
      for (final planEntry in plans.entries) {
        final planId = planEntry.key;
        final value = planEntry.value;
        if (planId is! String || value is! Map) continue;
        final startedOn = value['startedOn'];
        if (startedOn is! String || _parseDateKey(startedOn) == null) {
          continue;
        }
        final rawDone = value['done'];
        if (rawDone is! List) continue;
        final done = <int>{
          for (final e in rawDone)
            if (e is int && e >= 0) e,
        };
        out.putIfAbsent(profileId, () => <String, PlanProgress>{})[planId] =
            PlanProgress(startedOn: startedOn, done: done);
      }
    }
    return out;
  }

  /// The JSON string [parse] reads back: `done` sorted ascending,
  /// empty parent maps omitted (a profile whose last plan is
  /// restarted away disappears from the JSON).
  static String encode(Map<String, Map<String, PlanProgress>> state) {
    final out = <String, dynamic>{};
    for (final profileEntry in state.entries) {
      if (profileEntry.value.isEmpty) continue;
      out[profileEntry.key] = {
        for (final planEntry in profileEntry.value.entries)
          planEntry.key: planEntry.value.toJson(),
      };
    }
    return jsonEncode(out);
  }

  PlanProgress? progressFor(String profileId, String planId) =>
      state[profileId]?[planId];

  /// Starts a plan today. No-op when an entry already exists.
  void startPlan(String profileId, String planId, DateTime today) {
    final plans = state.putIfAbsent(profileId, () => <String, PlanProgress>{});
    if (plans.containsKey(planId)) return;
    plans[planId] = PlanProgress(startedOn: planDateKey(today), done: {});
  }

  /// Toggles one chapter's check mark. No-op when the plan has
  /// no entry (the mechanism does not exist before the plan
  /// starts).
  void toggleChapter(String profileId, String planId, int globalChapter) {
    final progress = state[profileId]?[planId];
    if (progress == null) return;
    if (!progress.done.remove(globalChapter)) {
      progress.done.add(globalChapter);
    }
  }

  /// Removes the plan's entry entirely, pruning the now-empty
  /// profile map.
  void restartPlan(String profileId, String planId) {
    final plans = state[profileId];
    if (plans == null) return;
    plans.remove(planId);
    if (plans.isEmpty) state.remove(profileId);
  }

  Future<void> save() async {
    await _prefs.setString(plansPrefsKey, encode(state));
  }
}

/// Everything a Home plan card renders, computed by the shell
/// (spec §7.1): HomeTab formats and renders, it does not compute.
class PlanCardData {
  const PlanCardData({
    required this.def,
    required this.totalChapters,
    required this.started,
    required this.doneCount,
    required this.currentDay,
    required this.percent,
  });

  final StudyPlanDef def;
  final int totalChapters;
  final bool started;

  /// The intersected done count (§4.3).
  final int doneCount;

  /// 0 when not started (sentinel).
  final int currentDay;

  /// `planPercent(doneCount, totalChapters)`.
  final int percent;
}
