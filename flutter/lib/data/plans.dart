import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'bible_data.dart';
import 'tradition.dart';

/// Study Plans v2: verse-sized schedule engine (two modes),
/// target-derived built-ins, custom plans, v2 store document.

const int wwBuiltinVersesPerDay = 40;

class StudyPlanDef {
  const StudyPlanDef({required this.id, required this.name, this.bookIndices});
  final String id;
  final String name;
  final List<int>? bookIndices;
}

const List<StudyPlanDef> wwStudyPlans = [
  StudyPlanDef(
    id: 'gospels',
    name: 'The Gospels',
    bookIndices: [39, 40, 41, 42],
  ),
  StudyPlanDef(
    id: 'psalms-proverbs',
    name: 'Psalms & Proverbs',
    bookIndices: [18, 19],
  ),
  StudyPlanDef(id: 'whole-bible', name: 'The Whole Bible', bookIndices: null),
];

List<int> planChapters(BibleData data, StudyPlanDef plan) {
  final books =
      plan.bookIndices ?? [for (var i = 0; i < data.books.length; i++) i];
  return [
    for (final b in books)
      for (var c = 0; c < data.books[b].chapters; c++) data.books[b].start + c,
  ];
}

bool planAvailable(StudyPlanDef plan, WwTradition tradition, BibleData data) {
  final books =
      plan.bookIndices ?? [for (var i = 0; i < data.books.length; i++) i];
  return books.every((b) => canonContainsBook(tradition, data, b));
}

// ---- Engine §1 ----
List<List<int>> scheduleByVerses(
  BibleData data,
  List<int> chapters,
  int targetVerses,
) {
  final t = math.max(1, targetVerses);
  final days = <List<int>>[];
  var open = <int>[];
  var tot = 0;
  for (final ch in chapters) {
    final v = data.chapters[ch].v;
    if (open.isNotEmpty &&
        (tot >= t || (tot + v - t).abs() >= (tot - t).abs())) {
      days.add(open);
      open = <int>[];
      tot = 0;
    }
    open.add(ch);
    tot += v;
  }
  if (open.isNotEmpty) days.add(open);
  return days;
}

List<List<int>> scheduleByDays(
  BibleData data,
  List<int> chapters,
  int dayCount,
) {
  final c = chapters.length;
  if (c == 0) return [];
  final n = dayCount.clamp(1, c);
  var totalVerses = 0;
  for (final ch in chapters) {
    totalVerses += data.chapters[ch].v;
  }
  final days = <List<int>>[];
  var open = <int>[];
  var cum = 0;
  var closed = 0;
  for (var i = 0; i < chapters.length; i++) {
    final ch = chapters[i];
    open.add(ch);
    cum += data.chapters[ch].v;
    final remaining = c - (i + 1);
    if (closed < n - 1 &&
        (cum * n >= (closed + 1) * totalVerses ||
            remaining == n - closed - 1)) {
      days.add(open);
      open = <int>[];
      closed++;
    }
  }
  if (open.isNotEmpty) days.add(open);
  return days;
}

// ---- dates/helpers retained ----
String planDateKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

DateTime? _parseDateKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
  return planDateKey(parsed) == value ? parsed : null;
}

int calendarDaysBetween(DateTime fromLocal, DateTime toLocal) {
  final from = DateTime.utc(fromLocal.year, fromLocal.month, fromLocal.day);
  final to = DateTime.utc(toLocal.year, toLocal.month, toLocal.day);
  return to.difference(from).inDays;
}

int planDayFor({
  required String startedOn,
  required DateTime today,
  required int days,
}) {
  final start = _parseDateKey(startedOn);
  if (start == null) return 1;
  if (days < 1) return 1;
  return (calendarDaysBetween(start, today) + 1).clamp(1, days);
}

int planDoneCount(PlanProgress? progress, List<int> chapters) {
  if (progress == null) return 0;
  return chapters.where(progress.done.contains).length;
}

int planPercent(int done, int total) => total == 0 ? 0 : (done * 100) ~/ total;

class PlanProgress {
  PlanProgress({required this.startedOn, required this.done});
  final String startedOn;
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

// ---- v2 model §4.2 ----
enum PlanPaceMode { verses, days }

class PlanPace {
  const PlanPace.verses(this.versesPerDay)
    : mode = PlanPaceMode.verses,
      days = null;
  const PlanPace.days(this.days)
    : mode = PlanPaceMode.days,
      versesPerDay = null;
  final PlanPaceMode mode;
  final int? versesPerDay;
  final int? days;
  Map<String, dynamic> toJson() => mode == PlanPaceMode.verses
      ? {'mode': 'verses', 'versesPerDay': versesPerDay}
      : {'mode': 'days', 'days': days};
  @override
  bool operator ==(Object other) =>
      other is PlanPace &&
      other.mode == mode &&
      other.versesPerDay == versesPerDay &&
      other.days == days;
  @override
  int get hashCode => Object.hash(mode, versesPerDay, days);
}

class PlanSegment {
  const PlanSegment({required this.book, required this.from, required this.to});
  final int book;
  final int from;
  final int to;
  Map<String, dynamic> toJson() => {'book': book, 'from': from, 'to': to};
  @override
  bool operator ==(Object other) =>
      other is PlanSegment &&
      other.book == book &&
      other.from == from &&
      other.to == to;
  @override
  int get hashCode => Object.hash(book, from, to);
}

class CustomPlanDef {
  const CustomPlanDef({
    required this.id,
    required this.name,
    required this.segments,
    required this.pace,
  });
  final String id;
  final String name;
  final List<PlanSegment> segments;
  final PlanPace pace;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'segments': [for (final s in segments) s.toJson()],
    'pace': pace.toJson(),
  };
  @override
  bool operator ==(Object other) {
    if (other is! CustomPlanDef) return false;
    if (other.id != id || other.name != name || other.pace != pace) {
      return false;
    }
    if (other.segments.length != segments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (other.segments[i] != segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, name, pace, Object.hashAll(segments));
}

bool _progressMapEq(
  Map<String, Map<String, PlanProgress>> a,
  Map<String, Map<String, PlanProgress>> b,
) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final bv = b[e.key];
    if (bv == null || bv.length != e.value.length) return false;
    for (final pe in e.value.entries) {
      if (bv[pe.key] != pe.value) return false;
    }
  }
  return true;
}

bool _customMapEq(
  Map<String, List<CustomPlanDef>> a,
  Map<String, List<CustomPlanDef>> b,
) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final bv = b[e.key];
    if (bv == null || bv.length != e.value.length) return false;
    for (var i = 0; i < e.value.length; i++) {
      if (bv[i] != e.value[i]) return false;
    }
  }
  return true;
}

bool _seqEq(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

class PlansDocument {
  PlansDocument({
    Map<String, Map<String, PlanProgress>>? progress,
    Map<String, List<CustomPlanDef>>? custom,
    Map<String, int>? customSeq,
  }) : progress = progress ?? {},
       custom = custom ?? {},
       customSeq = customSeq ?? {};
  final Map<String, Map<String, PlanProgress>> progress;
  final Map<String, List<CustomPlanDef>> custom;
  final Map<String, int> customSeq;
  bool get isEmpty => progress.isEmpty && custom.isEmpty;

  Map<String, dynamic> toJson() => {
    'version': 2,
    'progress': {
      for (final e in progress.entries)
        if (e.value.isNotEmpty)
          e.key: {for (final p in e.value.entries) p.key: p.value.toJson()},
    },
    'custom': {
      for (final e in custom.entries)
        if (e.value.isNotEmpty) e.key: [for (final d in e.value) d.toJson()],
    },
    'customSeq': {...customSeq},
  };

  static PlansDocument fromJson(Object? decoded) {
    if (decoded is! Map) return PlansDocument();
    final progress = _parseProgressMap(decoded['progress']);
    final custom = <String, List<CustomPlanDef>>{};
    final rawCustom = decoded['custom'];
    if (rawCustom is Map) {
      for (final entry in rawCustom.entries) {
        final profileId = entry.key;
        if (profileId is! String) continue;
        final list = entry.value;
        if (list is! List) continue;
        final kept = <CustomPlanDef>[];
        final seen = <String>{};
        for (final item in list) {
          final def = _parseCustomDef(item);
          if (def == null) continue;
          if (!seen.add(def.id)) continue;
          kept.add(def);
        }
        if (kept.isNotEmpty) custom[profileId] = kept;
      }
    }
    final seq = <String, int>{};
    final rawSeq = decoded['customSeq'];
    if (rawSeq is Map) {
      for (final entry in rawSeq.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is int && v >= 0) seq[k] = v;
      }
    }
    // self-heal
    for (final e in custom.entries) {
      var highest = 0;
      for (final d in e.value) {
        final n = int.tryParse(d.id.substring('custom-'.length)) ?? 0;
        if (n > highest) highest = n;
      }
      final stored = seq[e.key] ?? 0;
      if (highest > stored) seq[e.key] = highest;
    }
    return PlansDocument(progress: progress, custom: custom, customSeq: seq);
  }

  @override
  bool operator ==(Object other) =>
      other is PlansDocument &&
      _progressMapEq(progress, other.progress) &&
      _customMapEq(custom, other.custom) &&
      _seqEq(customSeq, other.customSeq);
  @override
  int get hashCode =>
      Object.hash(progress.length, custom.length, customSeq.length);
}

CustomPlanDef? _parseCustomDef(Object? item) {
  if (item is! Map) return null;
  final id = item['id'];
  if (id is! String || !RegExp(r'^custom-\d+$').hasMatch(id)) return null;
  final n = int.tryParse(id.substring(7));
  if (n == null || n < 1) return null;
  final nameRaw = item['name'];
  if (nameRaw is! String) return null;
  final name = nameRaw.trim();
  if (name.isEmpty) return null;
  final segsRaw = item['segments'];
  if (segsRaw is! List || segsRaw.isEmpty) return null;
  final segs = <PlanSegment>[];
  for (final s in segsRaw) {
    if (s is! Map) return null;
    final book = s['book'];
    final from = s['from'];
    final to = s['to'];
    if (book is! int || book < 0) return null;
    if (from is! int || to is! int) return null;
    if (!(1 <= from && from <= to)) return null;
    segs.add(PlanSegment(book: book, from: from, to: to));
  }
  final paceRaw = item['pace'];
  if (paceRaw is! Map) return null;
  final mode = paceRaw['mode'];
  PlanPace pace;
  if (mode == 'verses') {
    final v = paceRaw['versesPerDay'];
    if (v is! int || v < 1 || v > 1000) return null;
    pace = PlanPace.verses(v);
  } else if (mode == 'days') {
    final d = paceRaw['days'];
    if (d is! int || d < 1) return null;
    pace = PlanPace.days(d);
  } else {
    return null;
  }
  return CustomPlanDef(id: id, name: name, segments: segs, pace: pace);
}

Map<String, Map<String, PlanProgress>> _parseProgressMap(Object? raw) {
  final out = <String, Map<String, PlanProgress>>{};
  if (raw is! Map) return out;
  for (final profileEntry in raw.entries) {
    final profileId = profileEntry.key;
    final plans = profileEntry.value;
    if (profileId is! String || plans is! Map) continue;
    for (final planEntry in plans.entries) {
      final planId = planEntry.key;
      final value = planEntry.value;
      if (planId is! String || value is! Map) continue;
      final startedOn = value['startedOn'];
      if (startedOn is! String || _parseDateKey(startedOn) == null) continue;
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

const String plansPrefsKey = 'ww_plans_v1';

class PlansStore {
  PlansStore._(this._prefs, this.document);
  final SharedPreferences _prefs;

  /// Assignable so an import can set the freshly loaded store's
  /// document wholesale before awaiting save() (spec §8.3).
  PlansDocument document;

  static Future<PlansStore> load(SharedPreferences prefs) async =>
      PlansStore._(prefs, parseDocument(prefs.getString(plansPrefsKey)));

  static PlansDocument parseDocument(String? raw) {
    if (raw == null) return PlansDocument();
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return PlansDocument();
    }
    if (decoded is Map &&
        decoded['version'] is int &&
        decoded['version'] == 2) {
      return PlansDocument.fromJson(decoded);
    }
    // v1 bare progress
    return PlansDocument(progress: _parseProgressMap(decoded));
  }

  static String encodeDocument(PlansDocument doc) => jsonEncode(doc.toJson());

  static Map<String, Map<String, PlanProgress>> parse(String? raw) =>
      parseDocument(raw).progress;

  PlanProgress? progressFor(String profileId, String planId) =>
      document.progress[profileId]?[planId];

  void startPlan(String profileId, String planId, DateTime today) {
    final plans = document.progress.putIfAbsent(
      profileId,
      () => <String, PlanProgress>{},
    );
    if (plans.containsKey(planId)) return;
    plans[planId] = PlanProgress(startedOn: planDateKey(today), done: {});
  }

  void toggleChapter(String profileId, String planId, int globalChapter) {
    final progress = document.progress[profileId]?[planId];
    if (progress == null) return;
    if (!progress.done.remove(globalChapter)) progress.done.add(globalChapter);
  }

  void restartPlan(String profileId, String planId) {
    final plans = document.progress[profileId];
    if (plans == null) return;
    plans.remove(planId);
    if (plans.isEmpty) document.progress.remove(profileId);
  }

  List<CustomPlanDef> customsFor(String profileId) =>
      document.custom[profileId] ?? const [];
  CustomPlanDef? customFor(String profileId, String planId) {
    for (final d in customsFor(profileId)) {
      if (d.id == planId) return d;
    }
    return null;
  }

  CustomPlanDef createCustom(
    String profileId, {
    required String name,
    required List<PlanSegment> segments,
    required PlanPace pace,
  }) {
    final n = (document.customSeq[profileId] ?? 0) + 1;
    final def = CustomPlanDef(
      id: 'custom-$n',
      name: name.trim(),
      segments: segments,
      pace: pace,
    );
    document.custom.putIfAbsent(profileId, () => <CustomPlanDef>[]).add(def);
    document.customSeq[profileId] = n;
    return def;
  }

  void updateCustom(String profileId, CustomPlanDef def) {
    final list = document.custom[profileId];
    if (list == null) return;
    final i = list.indexWhere((d) => d.id == def.id);
    if (i < 0) return;
    list[i] = def;
  }

  void deleteCustom(String profileId, String planId) {
    final list = document.custom[profileId];
    if (list != null) {
      list.removeWhere((d) => d.id == planId);
      if (list.isEmpty) document.custom.remove(profileId);
    }
    final plans = document.progress[profileId];
    if (plans != null) {
      plans.remove(planId);
      if (plans.isEmpty) document.progress.remove(profileId);
    }
  }

  Future<void> save() async {
    await _prefs.setString(plansPrefsKey, encodeDocument(document));
  }
}

// ---- Resolution §5.1 ----
class ResolvedPlan {
  const ResolvedPlan({
    required this.id,
    required this.name,
    required this.isCustom,
    required this.pace,
    required this.chapters,
    required this.schedule,
    required this.coverBooks,
    required this.totalVerses,
  });
  final String id;
  final String name;
  final bool isCustom;
  final PlanPace pace;
  final List<int> chapters;
  final List<List<int>> schedule;
  final List<int> coverBooks;
  final int totalVerses;
  int get days => schedule.length;
  int get totalChapters => chapters.length;
}

int _versesOf(BibleData data, List<int> chapters) {
  var s = 0;
  for (final ch in chapters) {
    s += data.chapters[ch].v;
  }
  return s;
}

ResolvedPlan resolveBuiltinPlan(BibleData data, StudyPlanDef def) {
  final chapters = planChapters(data, def);
  const pace = PlanPace.verses(wwBuiltinVersesPerDay);
  return ResolvedPlan(
    id: def.id,
    name: def.name,
    isCustom: false,
    pace: pace,
    chapters: chapters,
    schedule: scheduleByVerses(data, chapters, wwBuiltinVersesPerDay),
    coverBooks:
        def.bookIndices ?? [for (var i = 0; i < data.books.length; i++) i],
    totalVerses: _versesOf(data, chapters),
  );
}

List<int> customChapters(BibleData data, List<PlanSegment> segments) {
  final out = <int>[];
  final seen = <int>{};
  for (final seg in segments) {
    if (seg.book >= data.books.length || seg.book < 0) continue;
    final count = data.books[seg.book].chapters;
    if (seg.from > count) continue;
    final to = math.min(seg.to, count);
    for (var c = seg.from; c <= to; c++) {
      final g = data.books[seg.book].start + c - 1;
      if (seen.add(g)) out.add(g);
    }
  }
  return out;
}

ResolvedPlan resolveCustomPlan(BibleData data, CustomPlanDef def) {
  final chapters = customChapters(data, def.segments);
  final schedule = def.pace.mode == PlanPaceMode.verses
      ? scheduleByVerses(data, chapters, def.pace.versesPerDay!)
      : scheduleByDays(data, chapters, def.pace.days!);
  final cover = <int>[];
  for (final s in def.segments) {
    if (!cover.contains(s.book)) cover.add(s.book);
  }
  return ResolvedPlan(
    id: def.id,
    name: def.name,
    isCustom: true,
    pace: def.pace,
    chapters: chapters,
    schedule: schedule,
    coverBooks: cover,
    totalVerses: _versesOf(data, chapters),
  );
}

bool customAvailable(CustomPlanDef def, WwTradition tradition, BibleData data) {
  for (final s in def.segments) {
    if (s.book < 0 || s.book >= data.books.length) return false;
    if (!canonContainsBook(tradition, data, s.book)) return false;
  }
  return customChapters(data, def.segments).isNotEmpty;
}

({int customPlans, int plansInProgress}) plansBackupCounts(
  Map<String, dynamic> plansMember,
) {
  var customs = 0;
  var inProgress = 0;
  final c = plansMember['custom'];
  if (c is Map) {
    for (final v in c.values) {
      if (v is List) customs += v.length;
    }
  }
  final p = plansMember['progress'];
  if (p is Map) {
    for (final v in p.values) {
      if (v is Map) inProgress += v.length;
    }
  }
  return (customPlans: customs, plansInProgress: inProgress);
}

class PlanCardData {
  const PlanCardData({
    required this.plan,
    required this.started,
    required this.doneCount,
    required this.currentDay,
    required this.percent,
  });
  final ResolvedPlan plan;
  final bool started;
  final int doneCount;
  final int currentDay;
  final int percent;
}
