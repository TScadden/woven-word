import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/deuterocanon.dart';
import '../data/highlights_index.dart';
import '../data/scripture_text.dart';
import '../data/tradition.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import 'reader_screen.dart';

/// The reader's shipped tint table for a span's highlight color:
/// the swatch IS the span's color identity (spec §6.2).
Color _tintFor(HlColor color) => switch (color) {
  HlColor.gold => WwColors.hlGold,
  HlColor.green => WwColors.hlGreen,
  HlColor.blue => WwColors.hlBlue,
  HlColor.pink => WwColors.hlPink,
  HlColor.purple => WwColors.hlPurple,
};

/// All Highlights (board run 11, spec §6.2): every span of the
/// active profile in the active translation, grouped by book in
/// the active tradition's canon order with chapter subheads —
/// the [highlights_index] grouping. Visibility is the run-10
/// rule: a span shows only when its book is in the active canon;
/// deuterocanon spans appear under Catholic and route to the
/// deuterocanon reader on tap, exactly like My Notes.
///
/// This screen is an index: tap → reader only. It never writes
/// [UserData]; all mutation lives in the reader.
class AllHighlightsScreen extends StatefulWidget {
  const AllHighlightsScreen({
    super.key,
    required this.data,
    this.onOpenVerse,
    this.deuteroLoader,
    this.textsLoader,
    this.tradition = WwTradition.none,
  });

  final BibleData data;

  /// Opens a row's verse through the shell's one open-chapter
  /// procedure: (bookIndex, chapterInBook, verse) — the My Notes
  /// signature. When null (standalone test pumps), row taps do
  /// nothing — in the app the shell always provides it.
  final void Function(int book, int chapterInBook, int verse)? onOpenVerse;

  /// Loads the deuterocanon table so spans on deuterocanon
  /// verses (book index ≥ 1000) render; null leaves those spans
  /// filtered out.
  final Future<DeuterocanonData?> Function()? deuteroLoader;

  /// Loads the scripture texts; defaults to [ScriptureText.load].
  /// Best-effort: failure leaves rows to fall back to their
  /// anchors (§6.1).
  final Future<ScriptureText> Function()? textsLoader;

  /// The tradition the app currently presents (canon dormancy).
  final WwTradition tradition;

  @override
  State<AllHighlightsScreen> createState() => _AllHighlightsScreenState();
}

class _AllHighlightsScreenState extends State<AllHighlightsScreen> {
  UserData _userData = UserData();
  String _profileId = UserData.defaultProfileId;
  ScriptureText? _texts;
  DeuterocanonData? _deutero;
  WwTranslation _translation = WwTranslation.kjv;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      _userData = store.data;
      _profileId = _userData.activeProfileId;
    } catch (_) {
      _userData = UserData();
      _profileId = UserData.defaultProfileId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _translation = WwTranslation.fromStored(
        prefs.getString(ReaderScreen.translationKey),
      );
    } catch (_) {
      // The default translation stands.
    }
    try {
      _texts = await (widget.textsLoader ?? ScriptureText.load)();
    } catch (_) {
      _texts = null;
    }
    try {
      _deutero = await widget.deuteroLoader?.call();
    } catch (_) {
      _deutero = null;
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// Reloads the store after returning from the reader, where
  /// spans may have changed (the My Notes `_reloadUserData`
  /// pattern).
  Future<void> _reloadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      if (!mounted) return;
      setState(() {
        _userData = store.data;
        _profileId = store.data.activeProfileId;
      });
    } catch (_) {
      // Keep the session copy.
    }
  }

  void _openInReader(int book, int chapterInBook, int verse) {
    widget.onOpenVerse?.call(book, chapterInBook, verse);
    _reloadUserData();
  }

  /// The active profile's spans in the active translation set
  /// (absent set = empty).
  List<HighlightSpan> get _activeSpans =>
      _userData.profiles[_profileId]?.spans[_translation.name] ?? const [];

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
          const Expanded(
            child: Text('All Highlights', style: WwType.screenTitle),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Text('Loading your highlights…', style: WwType.captionOnDark),
    );
  }

  Widget _body() {
    final spans = _activeSpans;
    if (spans.isEmpty) {
      // Branch 1 (I-4): the active translation's set holds no
      // spans at all — even when other translations hold spans.
      return _empty(
        title: 'No highlights yet in ${_translation.label}',
        body:
            'While reading, long-press a verse, then choose a color '
            'to highlight it. Highlights for '
            '${_userData.profileName(_profileId)} will gather here.',
      );
    }
    final groups = groupHighlights(
      data: widget.data,
      deutero: _deutero,
      spans: spans,
      tradition: widget.tradition,
      texts: _texts,
      translation: _translation,
    );
    if (groups.isEmpty) {
      // Branch 2 (I-4): the set holds spans, but every one is
      // canon-dormant under the current tradition.
      return _empty(
        title: 'No highlights to show here',
        body:
            "These highlights are for books outside your current "
            "tradition's canon. They are kept and return when you "
            'switch back.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      children: [
        Text(
          'Highlights in ${_userData.profileName(_profileId)} · '
          '${_translation.label}',
          style: WwType.captionOnDark,
        ),
        const SizedBox(height: 16),
        for (var gi = 0; gi < groups.length; gi++) ...[
          if (gi > 0) const SizedBox(height: 16),
          Text(groups[gi].bookName, style: WwType.selectionTitle),
          const SizedBox(height: 8),
          for (final chapterGroup in groups[gi].chapters) ...[
            Text(
              'Chapter ${chapterGroup.chapter}',
              style: WwType.captionOnDark.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final row in chapterGroup.rows) ...[
              _row(row),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }

  Widget _empty({required String title, required String body}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: WwType.selectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: WwType.captionOnDark,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(HighlightRowData row) {
    return Material(
      key: ValueKey('highlight-row-${row.span.verseKey}-${row.span.start}'),
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => _openInReader(row.book, row.chapter, row.verse),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _tintFor(row.span.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(row.refLabel, style: WwType.refLabelOnDark),
                    if (row.displayText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.displayText,
                        style: WwType.bodyOnDark,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
