import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/bible_data.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import '../widgets/arc_stage.dart';

/// The Home tab's root (board run 7 part B, §2): top bar with the
/// profile chip, the pinned arc mini-map (display only), and a
/// scroll area holding the resume card, the selection panel, and
/// the Study section. The scope dropdown is retired — the map's
/// range derives from the selection (§2.2).
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.dataFuture,
    required this.userData,
    required this.selection,
    required this.resumeBound,
    required this.resumeSubtitle,
    required this.notesCount,
    required this.onOpenChapter,
    required this.onClearSelection,
    required this.onResume,
    required this.onOpenProfiles,
    required this.onOpenMyNotes,
    required this.onRetryLoad,
  });

  final Future<BibleData> dataFuture;
  final UserData userData;
  final int? selection;
  final bool resumeBound;
  final String resumeSubtitle;
  final int notesCount;
  final void Function(int ch) onOpenChapter;
  final VoidCallback onClearSelection;
  final VoidCallback onResume;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenMyNotes;
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
    final profileName =
        widget.userData.profileName(widget.userData.activeProfileId);
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
        const SizedBox(height: 16),
        _studySection(),
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

  Widget _studySection() {
    final count = widget.notesCount;
    final subtitle = count == 0
        ? 'No notes yet'
        : count == 1
        ? '1 note'
        : '$count notes';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
          child: Text('STUDY', style: WwType.appSubtitle),
        ),
        const SizedBox(height: 16),
        _placeRow(
          icon: Icons.notes,
          title: 'My Notes',
          subtitle: subtitle,
          onTap: widget.onOpenMyNotes,
        ),
      ],
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
