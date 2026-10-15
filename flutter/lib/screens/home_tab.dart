import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../data/plans.dart';
import '../data/user_data.dart';
import '../data/verse_of_day.dart';
import '../theme/ww_theme.dart';
import '../widgets/arc_stage.dart';

/// The Home tab's root (board run 7 part B, §2): top bar with the
/// profile chip, the pinned arc mini-map (display only), and a
/// scroll area holding, in order (board run 11, §1): Continue
/// reading, the selection panel, Verse of the Day, Study Plans,
/// and Study Tools. The scope dropdown is retired — the map's
/// range derives from the selection (§2.2). HomeTab renders the
/// values it is handed; the shell computes them (§7.1).
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.dataFuture,
    required this.userData,
    required this.selection,
    required this.resumeBound,
    required this.resumeSubtitle,
    required this.notesCount,
    required this.verseOfDay,
    required this.plans,
    required this.highlightsCount,
    required this.onOpenChapter,
    required this.onClearSelection,
    required this.onResume,
    required this.onOpenProfiles,
    required this.onOpenMyNotes,
    required this.onOpenVerseOfDay,
    required this.onOpenPlan,
    required this.onOpenHighlights,
    required this.onRetryLoad,
  });

  final Future<BibleData> dataFuture;
  final UserData userData;
  final int? selection;
  final bool resumeBound;
  final String resumeSubtitle;
  final int notesCount;

  /// The Verse of the Day card's data (§3.3); null = no card.
  final VerseOfDayCardData? verseOfDay;

  /// Offered plans only, in definition order (§7.1); empty = no
  /// Study Plans section.
  final List<PlanCardData> plans;

  /// The visible span count behind the Highlights tool caption
  /// (§5): exactly the rows the All Highlights tap reveals.
  final int highlightsCount;

  final void Function(int ch) onOpenChapter;
  final VoidCallback onClearSelection;
  final VoidCallback onResume;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenMyNotes;
  final void Function(int chapter, int verse) onOpenVerseOfDay;
  final void Function(String planId) onOpenPlan;
  final VoidCallback onOpenHighlights;
  final VoidCallback onRetryLoad;

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  static const _miniStage = Size(1200, 500);

  final _scrollCtl = ScrollController();
  final _images = <String, ui.Image>{};
  final _rendering = <String>{};

  @override
  void dispose() {
    _scrollCtl.dispose();
    for (final img in _images.values) {
      img.dispose();
    }
    super.dispose();
  }

  void scrollToTop() {
    if (!_scrollCtl.hasClients) return;
    if (WwMotion.reduced(context)) {
      _scrollCtl.jumpTo(0);
    } else {
      _scrollCtl.animateTo(0, duration: WwMotion.push, curve: WwMotion.curve);
    }
  }

  Future<void> _ensureMiniImage({
    required String key,
    required BibleData data,
    required int lo,
    required int hi,
    required double band,
    required bool includeArcs,
  }) async {
    if (_images.containsKey(key) || _rendering.contains(key)) return;
    _rendering.add(key);
    try {
      final img = await renderArcImage(
        data: data,
        lo: lo,
        hi: hi,
        stage: _miniStage,
        density: band,
        faint: false,
        includeArcs: includeArcs,
        includeLabels: false,
      );
      _images[key] = img;
      if (mounted) setState(() {});
    } finally {
      _rendering.remove(key);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: FutureBuilder<BibleData>(
          future: widget.dataFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return Column(
              children: [
                _topBar(),
                if (data != null) _miniMap(data),
                Expanded(
                  child: data != null
                      ? _scrollArea(data)
                      : _statusArea(snapshot),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusArea(AsyncSnapshot<BibleData> snapshot) {
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The web could not be woven.', style: WwType.bodyOnDark),
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onRetryLoad,
              style: TextButton.styleFrom(
                minimumSize: const Size(64, WwSpace.minTarget),
              ),
              child: Text(
                'Try again',
                style: WwType.buttonLabel.copyWith(color: WwColors.goldBright),
              ),
            ),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Woven Word', style: WwType.screenTitle),
          SizedBox(height: 12),
          Text('Weaving 344,799 connections…', style: WwType.captionOnDark),
        ],
      ),
    );
  }

  Widget _topBar() {
    final profileName = widget.userData.profileName(
      widget.userData.activeProfileId,
    );
    final initial = profileName.trim().isEmpty
        ? '?'
        : profileName.trim()[0].toUpperCase();
    return Container(
      constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      decoration: const BoxDecoration(
        color: WwColors.nav,
        border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Woven Word', style: WwType.appTitle),
                Text('BIBLE CROSS REFERENCES', style: WwType.appSubtitle),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Profiles',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onOpenProfiles,
                child: SizedBox(
                  width: WwSpace.minTarget,
                  height: WwSpace.minTarget,
                  child: Center(
                    child: Tooltip(
                      message: 'Profiles',
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: WwColors.goldBright,
                          shape: BoxShape.circle,
                        ),
                        child: Text(initial, style: WwType.avatarLetterOnGold),
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

  (int, int) _range(BibleData data) {
    final sel = widget.selection;
    if (sel == null) return (0, data.totalChapters - 1);
    final book = data.chapters[sel].b;
    return data.scopeRange(book < 39 ? 'ot' : 'nt');
  }

  Widget _miniMap(BibleData data) {
    final (lo, hi) = _range(data);
    return Container(
      decoration: const BoxDecoration(
        color: WwColors.stage,
        border: Border(bottom: BorderSide(color: WwColors.borderDarkSoft)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final band = bandFor(densityFor(w));
          final includeArcs = widget.selection == null;
          final key = '$lo-$hi-$band-$includeArcs';
          final img = _images[key];
          if (img == null) {
            _ensureMiniImage(
              key: key,
              data: data,
              lo: lo,
              hi: hi,
              band: band,
              includeArcs: includeArcs,
            );
          }
          return SizedBox(
            width: w,
            height: w * _miniStage.height / _miniStage.width,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _miniStage.width,
                height: _miniStage.height,
                child: Stack(
                  children: [
                    if (img != null)
                      RawImage(
                        image: img,
                        width: _miniStage.width,
                        height: _miniStage.height,
                        fit: BoxFit.fill,
                      ),
                    if (widget.selection != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: MiniSelectionPainter(
                            data: data,
                            lo: lo,
                            hi: hi,
                            stage: _miniStage,
                            selected: widget.selection,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scrollArea(BibleData data) {
    return ListView(
      controller: _scrollCtl,
      padding: const EdgeInsets.only(top: 16),
      children: [
        _resumeCard(),
        if (widget.selection != null) ...[
          const SizedBox(height: 16),
          _selectionPanel(data),
        ],
        if (widget.verseOfDay != null) ...[
          const SizedBox(height: 16),
          _verseOfDayCard(),
        ],
        if (widget.plans.isNotEmpty) ...[
          const SizedBox(height: 16),
          _plansSection(data),
        ],
        const SizedBox(height: 16),
        _toolsSection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _placeRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      child: Material(
        color: WwColors.surface,
        borderRadius: BorderRadius.circular(WwRadius.row),
        child: InkWell(
          borderRadius: BorderRadius.circular(WwRadius.row),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: WwColors.goldBright),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: WwType.controlLabel.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: WwType.captionOnDark),
                    ],
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
        ),
      ),
    );
  }

  Widget _resumeCard() {
    return _placeRow(
      icon: Icons.menu_book,
      title: widget.resumeBound ? 'Continue reading' : 'Start reading',
      subtitle: widget.resumeSubtitle,
      onTap: widget.onResume,
    );
  }

  // ------------------------------------------------ Verse of the Day

  /// The Verse of the Day card (run 11, §3.4): the whole card is
  /// the one tap target, opening the reader at the pick via the
  /// shell's callback. While the texts load (or after they fail)
  /// the label, reference, and count render as usual and the
  /// verse-text slot carries the pinned loading/failure string.
  Widget _verseOfDayCard() {
    final vod = widget.verseOfDay!;
    final hasText = vod.text != null && vod.text!.isNotEmpty;
    final bodyText = vod.text == null
        ? "Loading today's verse…"
        : vod.text!.isEmpty
        ? "Today's verse text could not be loaded."
        : vod.text!;
    final countCaption = vod.connectionCount == 1
        ? '1 connection'
        : '${_fmt(vod.connectionCount)} connections';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      child: Semantics(
        container: true,
        button: true,
        label: 'Verse of the Day, ${vod.reference}',
        child: ExcludeSemantics(
          child: Material(
            key: const ValueKey('votd-card'),
            color: WwColors.surface,
            borderRadius: BorderRadius.circular(WwRadius.row),
            child: InkWell(
              borderRadius: BorderRadius.circular(WwRadius.row),
              onTap: () => widget.onOpenVerseOfDay(vod.chapter, vod.verse),
              child: Container(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VERSE OF THE DAY', style: WwType.appSubtitle),
                    const SizedBox(height: 8),
                    Text(
                      bodyText,
                      style: hasText
                          ? WwType.verseOfDayBody
                          : WwType.captionOnDark,
                      textDirection: hasText && vod.translation.isRtl
                          ? TextDirection.rtl
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(vod.reference, style: WwType.refLabelOnDark),
                    const SizedBox(height: 4),
                    Text(countCaption, style: WwType.captionOnDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ Study Plans

  Widget _plansSection(BibleData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Text('STUDY PLANS', style: WwType.appSubtitle),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.plans.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _planCard(data, widget.plans[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One plan card (run 11, §4.4): a typographic cover (no
  /// artwork), the title and caption under it, and — only when
  /// the plan is started — the progress bar across the cover's
  /// bottom edge. The whole card is one tap target.
  Widget _planCard(BibleData data, PlanCardData card) {
    final def = card.def;
    final caption = !card.started
        ? '${def.days} days · ${_fmt(card.totalChapters)} chapters'
        : card.doneCount == card.totalChapters
        ? 'Complete · 100%'
        : 'Day ${card.currentDay} of ${def.days} · ${card.percent}%';
    final List<String> bookLines;
    if (def.bookIndices == null) {
      bookLines = [data.books.first.name, '…', data.books.last.name];
    } else {
      bookLines = [for (final b in def.bookIndices!) data.books[b].name];
    }
    return Semantics(
      container: true,
      button: true,
      label: '${def.name}, $caption',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: () => widget.onOpenPlan(def.id),
            child: SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The cover is fixed-geometry artwork (112 × 144,
                  // §4.4/§10): its book lines and meta are set in
                  // the cover's own scale, clamped at 1.0, because
                  // at text scale 2.0 four serif lines at the
                  // ambient 1.43 height measure ~149dp against the
                  // cover's 118dp inner height and overflow the
                  // pinned box (§10's no-overflow rule). The plan
                  // name and caption directly beneath the cover
                  // carry the same words at the user's full scale.
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.of(context).textScaler
                          .clamp(maxScaleFactor: 1.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(WwRadius.row),
                      child: Stack(
                        children: [
                          Container(
                            key: ValueKey('plan-cover-${def.id}'),
                            width: 112,
                            height: 144,
                            decoration: BoxDecoration(
                              color: WwColors.surfaceHigh,
                              border: Border.all(color: WwColors.borderDark),
                              borderRadius: BorderRadius.circular(WwRadius.row),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 2,
                                    color: WwColors.gold,
                                  ),
                                  const SizedBox(height: 8),
                                  for (final line in bookLines)
                                    Text(
                                      line,
                                      style: WwType.planCoverBook,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const Expanded(child: SizedBox()),
                                  Text(
                                    '${_fmt(card.totalChapters)} chapters',
                                    style: WwType.planCoverMeta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (card.started)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 4,
                              child: Container(
                                key: ValueKey('plan-progress-${def.id}'),
                                child: Stack(
                                  children: [
                                    Container(color: WwColors.borderDark),
                                    SizedBox(
                                      width:
                                          112 *
                                          card.doneCount /
                                          card.totalChapters,
                                      height: 4,
                                      child: Container(
                                        color: WwColors.goldBright,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    def.name,
                    style: WwType.controlLabel.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: WwType.captionOnDark,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ Study Tools

  Widget _toolsSection() {
    final notes = widget.notesCount;
    final notesCaption = notes == 0
        ? 'No notes yet'
        : notes == 1
        ? '1 note'
        : '$notes notes';
    final highlights = widget.highlightsCount;
    final highlightsCaption = highlights == 0
        ? 'No highlights yet'
        : highlights == 1
        ? '1 highlight'
        : '$highlights highlights';
    final profileName = widget.userData.profileName(
      widget.userData.activeProfileId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Text('STUDY TOOLS', style: WwType.appSubtitle),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Material(
            color: WwColors.surface,
            borderRadius: BorderRadius.circular(WwRadius.row),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _toolEntry(
                    key: const ValueKey('tool-my-notes'),
                    icon: Icons.notes,
                    label: 'My Notes',
                    caption: notesCaption,
                    onTap: widget.onOpenMyNotes,
                  ),
                  _toolEntry(
                    key: const ValueKey('tool-highlights'),
                    icon: Icons.highlight,
                    label: 'Highlights',
                    caption: highlightsCaption,
                    onTap: widget.onOpenHighlights,
                  ),
                  _toolEntry(
                    key: const ValueKey('tool-profiles'),
                    icon: Icons.person_outline,
                    label: 'Profiles',
                    caption: profileName,
                    captionMaxLines: 1,
                    onTap: widget.onOpenProfiles,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One Study Tools entry (run 11, §5): icon over label over
  /// caption, centered in its third of the card; the entry's hit
  /// area is its full column.
  Widget _toolEntry({
    required ValueKey<String> key,
    required IconData icon,
    required String label,
    required String caption,
    required VoidCallback onTap,
    int captionMaxLines = 2,
  }) {
    return Expanded(
      child: Semantics(
        container: true,
        button: true,
        label: '$label, $caption',
        child: ExcludeSemantics(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: WwColors.goldBright),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: WwType.controlLabel.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: WwType.captionOnDark,
                    textAlign: TextAlign.center,
                    maxLines: captionMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectionPanel(BibleData data) {
    final ch = widget.selection!;
    final c = data.chapters[ch];
    return Container(
      color: WwColors.surface,
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(data.chapterName(ch), style: WwType.selectionTitle),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(c.v)} verses · '
                      '${_fmt(data.chapterConnCount[ch])} connections',
                      style: WwType.captionOnDark,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear selection',
                onPressed: widget.onClearSelection,
                icon: const Icon(Icons.close, color: WwColors.navInk),
                constraints: const BoxConstraints(
                  minWidth: WwSpace.minTarget,
                  minHeight: WwSpace.minTarget,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => widget.onOpenChapter(ch),
            style: ElevatedButton.styleFrom(
              backgroundColor: WwColors.goldBright,
              foregroundColor: WwColors.onGold,
              minimumSize: const Size.fromHeight(WwSpace.minTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WwRadius.chip),
              ),
            ),
            child: Text(
              'Read ${data.chapterName(ch)}',
              style: WwType.goldButtonLabel,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Connected chapters', style: WwType.captionOnDark),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in data.partnersSorted(ch))
                _partnerChip(data, entry),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnerChip(BibleData data, MapEntry<int, int> entry) {
    return Material(
      color: WwColors.surfaceHigh,
      borderRadius: BorderRadius.circular(WwRadius.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.chip),
        onTap: () => widget.onOpenChapter(entry.key),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.chapterName(entry.key), style: WwType.controlLabel),
              const SizedBox(width: 6),
              Text(_fmt(entry.value), style: WwType.captionOnDark),
            ],
          ),
        ),
      ),
    );
  }
}
