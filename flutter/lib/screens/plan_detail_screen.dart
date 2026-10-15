import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/plans.dart';
import '../theme/ww_theme.dart';

/// Comma grouping for counts, the shipped `HomeTab._fmt` style
/// (`1,189`, never `1189`).
String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// One study plan in full (board run 11, spec §4.6): the summary
/// card (status, progress, today's reading, Start), the derived
/// schedule with a per-chapter check toggle (the one completion
/// mechanism), and Restart with an explicit confirm dialog.
///
/// The screen loads its OWN [PlansStore] instance (the shipped
/// pattern: My Notes, Profiles, and the reader each load their
/// own store); the shell reloads its Home snapshot when this
/// screen pops, so the two never coexist as writers.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.data,
    required this.plan,
    required this.profileId,
    required this.onOpenChapter,
    this.now,
  });

  final BibleData data;
  final StudyPlanDef plan;

  /// The active profile at push time.
  final String profileId;

  /// Opens a chapter (a GLOBAL chapter index) in the reader.
  final void Function(int globalChapter) onOpenChapter;

  /// Test seam for the clock (the `textsLoader` pattern); defaults
  /// to [DateTime.now].
  final DateTime Function()? now;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  PlansStore? _store;
  bool _loaded = false;

  DateTime _today() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    PlansStore? store;
    try {
      final prefs = await SharedPreferences.getInstance();
      store = await PlansStore.load(prefs);
    } catch (_) {
      store = null;
    }
    if (!mounted) return;
    setState(() {
      _store = store;
      _loaded = true;
    });
  }

  /// Persists after a mutation. Fire-and-forget with a catch (the
  /// Profiles `_persist` pattern): the visible change never waits
  /// on disk.
  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.save();
    } catch (_) {
      // Session state already carries the change.
    }
  }

  PlanProgress? get _progress =>
      _store?.progressFor(widget.profileId, widget.plan.id);

  void _start() {
    final store = _store;
    if (store == null) return;
    setState(() => store.startPlan(widget.profileId, widget.plan.id, _today()));
    _persist();
  }

  void _toggle(int globalChapter) {
    final store = _store;
    if (store == null) return;
    setState(
      () =>
          store.toggleChapter(widget.profileId, widget.plan.id, globalChapter),
    );
    _persist();
  }

  Future<void> _restart() async {
    final plan = widget.plan;
    final confirmed = await wwShowDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WwColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.sheet),
        ),
        title: Text('Restart ${plan.name}?', style: WwType.selectionTitle),
        content: const Text(
          'Your check marks for this plan will be cleared, and the '
          'plan will return to not started. Your highlights and '
          'notes are not affected.',
          style: WwType.bodyOnDark,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, WwSpace.minTarget),
            ),
            child: const Text('Cancel', style: WwType.buttonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, WwSpace.minTarget),
            ),
            child: const Text('Restart', style: WwType.dangerActionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final store = _store;
    if (store == null) return;
    setState(() => store.restartPlan(widget.profileId, widget.plan.id));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _loaded ? _body() : _loading()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      decoration: const BoxDecoration(
        color: WwColors.nav,
        border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: WwColors.navInk),
            constraints: const BoxConstraints(
              minWidth: WwSpace.minTarget,
              minHeight: WwSpace.minTarget,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.plan.name, style: WwType.screenTitle)),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Text('Loading plan…', style: WwType.captionOnDark),
    );
  }

  Widget _body() {
    final data = widget.data;
    final plan = widget.plan;
    final chapters = planChapters(data, plan);
    final total = chapters.length;
    final progress = _progress;
    final started = progress != null;
    final done = planDoneCount(progress, chapters);
    final percent = planPercent(done, total);
    final complete = started && done == total;
    final currentDay = started
        ? planDayFor(
            startedOn: progress.startedOn,
            today: _today(),
            days: plan.days,
          )
        : 0;
    final schedule = planSchedule(data, plan);

    final String status;
    if (!started) {
      status = '${plan.days} days · ${_fmt(total)} chapters';
    } else if (complete) {
      status = 'Complete · ${_fmt(total)} of ${_fmt(total)} chapters · 100%';
    } else {
      status =
          'Day $currentDay of ${plan.days} · ${_fmt(done)} of '
          '${_fmt(total)} chapters · $percent%';
    }

    return ListView(
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      children: [
        Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: Container(
            padding: const EdgeInsets.all(WwSpace.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: WwType.bodyOnDark),
                if (started) ...[
                  const SizedBox(height: 8),
                  _progressBar(done, total),
                ],
                if (started && !complete) ...[
                  const SizedBox(height: 8),
                  const Text("TODAY'S READING", style: WwType.appSubtitle),
                  const SizedBox(height: 4),
                  Text(
                    [
                      for (final ch in schedule[currentDay - 1])
                        data.chapterName(ch),
                    ].join(' · '),
                    style: WwType.bodyOnDark,
                  ),
                ],
                if (complete) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'You have read every chapter in this plan.',
                    style: WwType.bodyOnDark,
                  ),
                ],
                if (!started) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const ValueKey('plan-start'),
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WwColors.goldBright,
                      foregroundColor: WwColors.onGold,
                      minimumSize: const Size.fromHeight(WwSpace.minTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(WwRadius.chip),
                      ),
                    ),
                    child: const Text(
                      'Start plan',
                      style: WwType.goldButtonLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var day = 1; day <= plan.days; day++) ...[
          if (day > 1) const SizedBox(height: 16),
          Text(
            'Day $day',
            style: WwType.controlLabel.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < schedule[day - 1].length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _chapterRow(
              schedule[day - 1][i],
              started: started,
              done: progress?.done.contains(schedule[day - 1][i]) ?? false,
            ),
          ],
        ],
        if (started) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('plan-restart'),
              onPressed: _restart,
              style: TextButton.styleFrom(
                minimumSize: const Size(64, WwSpace.minTarget),
              ),
              child: const Text(
                'Restart plan',
                style: WwType.dangerActionLabel,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The summary card's progress bar (spec §4.6): full
  /// card-content width, 4dp, track `borderDark`, fill
  /// `goldBright`, corners fully round. A static graphic — the
  /// value is carried redundantly by the status line's percent.
  Widget _progressBar(int done, int total) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: WwColors.borderDark,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: total == 0 ? 0 : width * done / total,
              height: 4,
              decoration: BoxDecoration(
                color: WwColors.goldBright,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }

  /// One schedule chapter row. Pre-start there is no toggle (the
  /// mechanism does not exist before the plan starts — nothing
  /// disabled, nothing dead); the label is a live tap target in
  /// every state. Checking is ungated: any chapter, any order.
  Widget _chapterRow(
    int globalChapter, {
    required bool started,
    required bool done,
  }) {
    final data = widget.data;
    final name = data.chapterName(globalChapter);
    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
        child: Row(
          children: [
            if (started) ...[
              Semantics(
                container: true,
                button: true,
                checked: done,
                label: done ? 'Mark $name as not read' : 'Mark $name as read',
                child: ExcludeSemantics(
                  child: InkWell(
                    key: ValueKey('plan-toggle-$globalChapter'),
                    borderRadius: BorderRadius.circular(WwRadius.row),
                    onTap: () => _toggle(globalChapter),
                    child: SizedBox(
                      width: WwSpace.minTarget,
                      height: WwSpace.minTarget,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: done
                                ? WwColors.goldBright
                                : Colors.transparent,
                            border: done
                                ? null
                                : Border.all(
                                    color: WwColors.mutedOnDark,
                                    width: 2,
                                  ),
                            borderRadius: BorderRadius.circular(WwRadius.input),
                          ),
                          child: done
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: WwColors.onGold,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: InkWell(
                key: ValueKey('plan-chapter-$globalChapter'),
                borderRadius: BorderRadius.circular(WwRadius.row),
                onTap: () => widget.onOpenChapter(globalChapter),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: WwSpace.minTarget,
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(name, style: WwType.controlLabel),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: WwColors.mutedOnDark,
            ),
          ],
        ),
      ),
    );
  }
}
