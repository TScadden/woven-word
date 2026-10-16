import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/plans.dart';
import '../data/tradition.dart';
import '../theme/ww_theme.dart';

class _BookDraft {
  bool selected = false;
  bool range = false;
  int from = 1;
  int to = 1;
}

/// Plan editor (study plans v2, spec §6.1/§6.4): create and
/// edit share this screen; edit seeds from the stored def.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    super.key,
    required this.data,
    required this.tradition,
    required this.profileId,
    required this.initialDef,
  });

  final BibleData data;
  final WwTradition tradition;
  final String profileId;
  final CustomPlanDef? initialDef;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  PlansStore? _store;
  bool _loaded = false;
  late final TextEditingController _nameCtl;
  PlanPaceMode _mode = PlanPaceMode.verses;
  int _verses = 40;
  int _days = 30;
  final Map<int, _BookDraft> _books = {};
  List<PlanSegment> _carried = [];

  List<int> get _canonBooks => [
    for (var i = 0; i < widget.data.books.length; i++)
      if (canonContainsBook(widget.tradition, widget.data, i)) i,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialDef?.name ?? '');
    _nameCtl.addListener(() => setState(() {}));
    _seed();
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  void _seed() {
    for (final b in _canonBooks) {
      final d = _BookDraft();
      d.to = widget.data.books[b].chapters;
      _books[b] = d;
    }
    final def = widget.initialDef;
    if (def == null) return;
    if (def.pace.mode == PlanPaceMode.verses) {
      _mode = PlanPaceMode.verses;
      _verses = def.pace.versesPerDay!.clamp(5, 200);
    } else {
      _mode = PlanPaceMode.days;
      _days = def.pace.days!;
    }
    // Group segments by book.
    final byBook = <int, List<PlanSegment>>{};
    for (final seg in def.segments) {
      byBook.putIfAbsent(seg.book, () => []).add(seg);
    }
    final carried = <PlanSegment>[];
    for (final entry in byBook.entries) {
      final book = entry.key;
      final draft = _books[book];
      if (draft == null) {
        carried.addAll(entry.value);
        continue;
      }
      final count = widget.data.books[book].chapters;
      final live = [
        for (final s in entry.value)
          if (s.from <= count) s,
      ];
      final dead = [
        for (final s in entry.value)
          if (s.from > count) s,
      ];
      carried.addAll(dead);
      if (live.isEmpty) continue;
      int from;
      int to;
      if (live.length == 1) {
        from = live.first.from;
        to = live.first.to > count ? count : live.first.to;
      } else {
        from = live.map((s) => s.from).reduce((a, b) => a < b ? a : b);
        var m = live.map((s) => s.to).reduce((a, b) => a > b ? a : b);
        if (m > count) m = count;
        to = m;
      }
      draft.selected = true;
      if (from == 1 && to == count) {
        draft.range = false;
        draft.from = 1;
        draft.to = count;
      } else {
        draft.range = true;
        draft.from = from;
        draft.to = to;
      }
    }
    _carried = carried;
    // Days clamp to seeded coverage count.
    final chapters = _draftChaptersCount();
    if (_mode == PlanPaceMode.days) {
      _days = _days.clamp(1, chapters < 1 ? 1 : chapters);
    }
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

  List<PlanSegment> _editorSegments() {
    final out = <PlanSegment>[];
    for (var b = 0; b < widget.data.books.length; b++) {
      final d = _books[b];
      if (d == null || !d.selected) continue;
      final count = widget.data.books[b].chapters;
      if (d.range) {
        out.add(PlanSegment(book: b, from: d.from, to: d.to));
      } else {
        out.add(PlanSegment(book: b, from: 1, to: count));
      }
    }
    return out;
  }

  PlanPace get _draftPace => _mode == PlanPaceMode.verses
      ? PlanPace.verses(_verses)
      : PlanPace.days(_days);

  ResolvedPlan _resolved() {
    final def = CustomPlanDef(
      id: widget.initialDef?.id ?? 'custom-0',
      name: _nameCtl.text.trim(),
      segments: _editorSegments(),
      pace: _draftPace,
    );
    return resolveCustomPlan(widget.data, def);
  }

  int _draftChaptersCount() {
    final def = CustomPlanDef(
      id: 'custom-0',
      name: 'x',
      segments: _editorSegments(),
      pace: const PlanPace.verses(40),
    );
    return customChapters(widget.data, def.segments).length;
  }

  void _reclampDays() {
    final count = _draftChaptersCount();
    final maxDays = count < 1 ? 1 : count;
    if (_days > maxDays) _days = maxDays;
    if (_days < 1) _days = 1;
  }

  bool get _nameValid => _nameCtl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    final name = _nameCtl.text.trim();
    final segments = _editorSegments();
    if (widget.initialDef == null) {
      store.createCustom(
        widget.profileId,
        name: name,
        segments: segments,
        pace: _draftPace,
      );
    } else {
      store.updateCustom(
        widget.profileId,
        CustomPlanDef(
          id: widget.initialDef!.id,
          name: name,
          segments: [...segments, ..._carried],
          pace: _draftPace,
        ),
      );
    }
    try {
      await store.save();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
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
          Expanded(
            child: Text(
              widget.initialDef == null ? 'New plan' : 'Edit plan',
              style: WwType.screenTitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Text('Loading plan…', style: WwType.captionOnDark),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _segmented({
    required List<String> labels,
    required int selected,
    required void Function(int) onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: WwColors.surfaceHigh,
        border: Border.all(color: WwColors.borderDark),
        borderRadius: BorderRadius.circular(WwRadius.chip),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                selected: i == selected,
                label: labels[i],
                child: ExcludeSemantics(
                  child: Material(
                    color: i == selected
                        ? WwColors.goldBright
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(WwRadius.chip),
                      onTap: () => onSelect(i),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: WwSpace.minTarget,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          labels[i],
                          style: i == selected
                              ? WwType.goldButtonLabel
                              : WwType.buttonLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepperRow({
    required String label,
    required int value,
    required String decTooltip,
    required String incTooltip,
    required VoidCallback? onDec,
    required VoidCallback? onInc,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: WwType.controlLabel)),
        IconButton(
          tooltip: decTooltip,
          onPressed: onDec,
          icon: Icon(
            Icons.remove,
            size: 24,
            color: onDec == null ? WwColors.mutedOnDark : WwColors.navInk,
          ),
          constraints: const BoxConstraints(
            minWidth: WwSpace.minTarget,
            minHeight: WwSpace.minTarget,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            style: WwType.controlLabel.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          tooltip: incTooltip,
          onPressed: onInc,
          icon: Icon(
            Icons.add,
            size: 24,
            color: onInc == null ? WwColors.mutedOnDark : WwColors.navInk,
          ),
          constraints: const BoxConstraints(
            minWidth: WwSpace.minTarget,
            minHeight: WwSpace.minTarget,
          ),
        ),
      ],
    );
  }

  Widget _body() {
    final resolved = _resolved();
    final chapters = resolved.totalChapters;
    final valid = _nameValid && chapters >= 1;
    final maxDays = chapters < 1 ? 1 : chapters;
    return ListView(
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      children: [
        const Text('PLAN NAME', style: WwType.appSubtitle),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtl,
          style: WwType.controlLabel,
          textCapitalization: TextCapitalization.sentences,
          autofocus: false,
          decoration: InputDecoration(
            labelText: 'Plan name',
            labelStyle: const TextStyle(
              fontSize: 13,
              color: WwColors.mutedOnDark,
            ),
            filled: true,
            fillColor: WwColors.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WwRadius.input),
              borderSide: const BorderSide(color: WwColors.borderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WwRadius.input),
              borderSide: const BorderSide(color: WwColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(WwRadius.input),
              borderSide: const BorderSide(color: WwColors.goldBright),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('PACE', style: WwType.appSubtitle),
        const SizedBox(height: 8),
        Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: Container(
            padding: const EdgeInsets.all(WwSpace.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _segmented(
                  labels: const ['Daily amount', 'Finish in'],
                  selected: _mode == PlanPaceMode.verses ? 0 : 1,
                  onSelect: (i) => setState(() {
                    _mode = i == 0 ? PlanPaceMode.verses : PlanPaceMode.days;
                    _reclampDays();
                  }),
                ),
                const SizedBox(height: 16),
                if (_mode == PlanPaceMode.verses)
                  _stepperRow(
                    label: 'Verses per day',
                    value: _verses,
                    decTooltip: 'Decrease verses per day',
                    incTooltip: 'Increase verses per day',
                    onDec: _verses <= 5
                        ? null
                        : () => setState(() {
                            _verses = (_verses - 5).clamp(5, 200);
                          }),
                    onInc: _verses >= 200
                        ? null
                        : () => setState(() {
                            _verses = (_verses + 5).clamp(5, 200);
                          }),
                  )
                else
                  _stepperRow(
                    label: 'Days',
                    value: _days,
                    decTooltip: 'Decrease days',
                    incTooltip: 'Increase days',
                    onDec: _days <= 1
                        ? null
                        : () => setState(() => _days = _days - 1),
                    onInc: _days >= maxDays
                        ? null
                        : () => setState(() => _days = _days + 1),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('COVERAGE', style: WwType.appSubtitle),
        const SizedBox(height: 8),
        for (var i = 0; i < _canonBooks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _bookRow(_canonBooks[i]),
        ],
        const SizedBox(height: 16),
        Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: Container(
            padding: const EdgeInsets.all(WwSpace.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmt(resolved.totalChapters)} chapters · '
                  '${_fmt(resolved.totalVerses)} verses · '
                  '${_fmt(resolved.days)} days',
                  style: WwType.bodyOnDark,
                ),
                if (!_nameValid) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Give your plan a name to save it.',
                    style: WwType.captionOnDark,
                  ),
                ],
                if (chapters < 1) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Choose at least one chapter to save your plan.',
                    style: WwType.captionOnDark,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const ValueKey('plan-editor-save'),
          onPressed: valid ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: WwColors.goldBright,
            foregroundColor: WwColors.onGold,
            disabledBackgroundColor: WwColors.surfaceHigh,
            minimumSize: const Size.fromHeight(WwSpace.minTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(WwRadius.chip),
            ),
          ),
          child: Text(
            widget.initialDef == null ? 'Save plan' : 'Save changes',
            style: valid
                ? WwType.goldButtonLabel
                : WwType.dialogActionLabelDisabled,
          ),
        ),
      ],
    );
  }

  Widget _bookRow(int book) {
    final data = widget.data;
    final name = data.books[book].name;
    final count = data.books[book].chapters;
    final draft = _books[book]!;
    void toggle() {
      setState(() {
        draft.selected = !draft.selected;
        _reclampDays();
      });
    }

    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Semantics(
                  container: true,
                  button: true,
                  checked: draft.selected,
                  label: 'Include $name',
                  child: ExcludeSemantics(
                    child: InkWell(
                      key: ValueKey('plan-editor-toggle-$book'),
                      borderRadius: BorderRadius.circular(WwRadius.row),
                      onTap: toggle,
                      child: SizedBox(
                        width: WwSpace.minTarget,
                        height: WwSpace.minTarget,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: draft.selected
                                  ? WwColors.goldBright
                                  : Colors.transparent,
                              border: draft.selected
                                  ? null
                                  : Border.all(
                                      color: WwColors.mutedOnDark,
                                      width: 2,
                                    ),
                              borderRadius: BorderRadius.circular(
                                WwRadius.input,
                              ),
                            ),
                            child: draft.selected
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
                Expanded(
                  child: InkWell(
                    key: ValueKey('plan-editor-book-$book'),
                    borderRadius: BorderRadius.circular(WwRadius.row),
                    onTap: toggle,
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
                Flexible(
                  child: Text(
                    '$count chapters',
                    style: WwType.captionOnDark,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (draft.selected) ...[
              const SizedBox(height: 8),
              _segmented(
                labels: const ['Whole book', 'Chapter range'],
                selected: draft.range ? 1 : 0,
                onSelect: (i) => setState(() {
                  draft.range = i == 1;
                  _reclampDays();
                }),
              ),
              if (draft.range) ...[
                const SizedBox(height: 8),
                _stepperRow(
                  label: 'First chapter',
                  value: draft.from,
                  decTooltip: 'Decrease first chapter for $name',
                  incTooltip: 'Increase first chapter for $name',
                  onDec: draft.from <= 1
                      ? null
                      : () => setState(() {
                          draft.from = draft.from - 1;
                          _reclampDays();
                        }),
                  onInc: draft.from >= draft.to
                      ? null
                      : () => setState(() {
                          draft.from = draft.from + 1;
                          _reclampDays();
                        }),
                ),
                _stepperRow(
                  label: 'Last chapter',
                  value: draft.to,
                  decTooltip: 'Decrease last chapter for $name',
                  incTooltip: 'Increase last chapter for $name',
                  onDec: draft.to <= draft.from
                      ? null
                      : () => setState(() {
                          draft.to = draft.to - 1;
                          _reclampDays();
                        }),
                  onInc: draft.to >= count
                      ? null
                      : () => setState(() {
                          draft.to = draft.to + 1;
                          _reclampDays();
                        }),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
