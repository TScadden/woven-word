import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bible_data.dart';
import '../data/confession_data.dart';
import '../data/deuterocanon.dart';
import '../data/reader_theme.dart';
import '../data/scripture_text.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import 'library_tab.dart';
import 'reader_screen.dart';

/// One tile in a [SectionedBookGrid]: a book's display name, its
/// chapter count, whether it is a deuterocanon book (its caption
/// says so), and where a tap leads.
class BookGridEntry {
  const BookGridEntry({
    required this.name,
    required this.chapters,
    required this.onTap,
    this.deutero = false,
  });

  final String name;
  final int chapters;
  final bool deutero;
  final VoidCallback onTap;
}

/// One headed run of book tiles in a [SectionedBookGrid].
class BookGridSection {
  const BookGridSection(this.title, this.entries);

  final String title;
  final List<BookGridEntry> entries;
}

/// A book grid in headed sections (board run 9): the Tanakh's
/// Torah / Nevi'im / Ketuvim under the Jewish tradition, and the
/// Catholic Old Testament (core and deuterocanon books in
/// Catholic order) under the Catholic tradition. Tile
/// construction and height derivation are the shipped book
/// grid's (§3.2.1), computed per section.
class SectionedBookGrid extends StatelessWidget {
  const SectionedBookGrid({
    super.key,
    required this.title,
    required this.sections,
    required this.onBack,
    required this.breadcrumbItems,
    required this.onBreadcrumb,
  });

  final String title;
  final List<BookGridSection> sections;
  final VoidCallback onBack;

  /// Breadcrumb items in the libraryTopBar shape.
  final List<(String, String)> breadcrumbItems;
  final void Function(String value) onBreadcrumb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: title,
              onBack: onBack,
              breadcrumbItems: breadcrumbItems,
              onBreadcrumb: onBreadcrumb,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                children: [
                  for (var s = 0; s < sections.length; s++) ...[
                    if (s > 0) const SizedBox(height: 24),
                    Text(
                      sections[s].title.toUpperCase(),
                      style: WwType.appSubtitle,
                    ),
                    const SizedBox(height: 12),
                    _sectionGrid(context, sections[s]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionGrid(BuildContext context, BookGridSection section) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 8) / 2;
        final innerWidth = tileWidth - 24;
        final metrics = TextMetrics(
          MediaQuery.textScalerOf(context),
          DefaultTextStyle.of(context).style,
        );
        var nameHeight = 0.0;
        for (final entry in section.entries) {
          final h = metrics.height(
            entry.name,
            WwType.bookTileTitle,
            maxWidth: innerWidth,
          );
          if (h > nameHeight) nameHeight = h;
        }
        final captionHeight = metrics.height(
          '50 chapters · Deuterocanon',
          WwType.captionOnDark,
          maxWidth: innerWidth,
        );
        final tileHeight = 12 + nameHeight + 4 + captionHeight + 12;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: tileWidth / tileHeight,
          ),
          itemCount: section.entries.length,
          itemBuilder: (context, i) {
            final entry = section.entries[i];
            final caption = entry.chapters == 1
                ? '1 chapter'
                : '${entry.chapters} chapters';
            return Material(
              color: WwColors.surface,
              borderRadius: BorderRadius.circular(WwRadius.row),
              child: InkWell(
                borderRadius: BorderRadius.circular(WwRadius.row),
                onTap: entry.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: WwType.bookTileTitle),
                      const SizedBox(height: 4),
                      Text(
                        entry.deutero ? '$caption · Deuterocanon' : caption,
                        style: WwType.captionOnDark,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The confessions browse root (board run 9, Protestant layer):
/// the layer's documents, each with its section and proof
/// counts, counted from the dataset at render time.
class ConfessionDocsScreen extends StatelessWidget {
  const ConfessionDocsScreen({
    super.key,
    required this.confessionData,
    required this.onBack,
    required this.onBreadcrumbRoot,
    required this.onOpenDoc,
  });

  final ConfessionData confessionData;
  final VoidCallback onBack;
  final VoidCallback onBreadcrumbRoot;
  final void Function(int docIndex) onOpenDoc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: 'Confessions',
              onBack: onBack,
              breadcrumbItems: const [
                ('library', 'Library'),
                ('__current', 'Confessions'),
              ],
              onBreadcrumb: (value) {
                if (value == 'library') onBreadcrumbRoot();
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                children: [
                  const Text(
                    'Historic confessions, with the scripture proofs '
                    'their authors published. Woven Word records '
                    'which verses each section cites; the confession '
                    'itself is read at its host.',
                    style: WwType.captionOnDark,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < confessionData.docs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _docRow(i),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docRow(int docIndex) {
    final doc = confessionData.docs[docIndex];
    final sections = confessionData.sectionsOf(docIndex);
    var proofs = 0;
    for (final s in sections) {
      proofs += confessionData.versesForSection(s.index).length;
    }
    final caption =
        '${doc.year} · ${sections.length} sections · '
        '$proofs proof texts';
    return Semantics(
      container: true,
      button: true,
      label: '${doc.title}, $caption',
      child: ExcludeSemantics(
        child: Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: () => onOpenDoc(docIndex),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(WwSpace.screenMargin),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(doc.title, style: WwType.selectionTitle),
                        const SizedBox(height: 2),
                        Text(caption, style: WwType.captionOnDark),
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
      ),
    );
  }
}

/// One confession's sections, in the document's own order, each
/// with its proof count.
class ConfessionSectionsScreen extends StatelessWidget {
  const ConfessionSectionsScreen({
    super.key,
    required this.confessionData,
    required this.docIndex,
    required this.onBack,
    required this.onBreadcrumb,
    required this.onOpenSection,
  });

  final ConfessionData confessionData;
  final int docIndex;
  final VoidCallback onBack;

  /// Breadcrumb selections: 'library' or 'confessions'.
  final void Function(String value) onBreadcrumb;
  final void Function(ConfessionSection section) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final doc = confessionData.docs[docIndex];
    final sections = confessionData.sectionsOf(docIndex);
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: doc.title,
              onBack: onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('confessions', 'Confessions'),
                ('__current', doc.title),
              ],
              onBreadcrumb: onBreadcrumb,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final section = sections[i];
                  final proofs = confessionData
                      .versesForSection(section.index)
                      .length;
                  return Material(
                    color: WwColors.surface,
                    borderRadius: BorderRadius.circular(WwRadius.row),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(WwRadius.row),
                      onTap: () => onOpenSection(section),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: WwSpace.minTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                section.label,
                                style: WwType.controlLabel.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              proofs == 1
                                  ? '1 proof text'
                                  : '$proofs proof texts',
                              style: WwType.captionOnDark,
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: WwColors.mutedOnDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One confession section's cited verses: reference + snippet
/// rows in canon order (the TalkView construction), plus the
/// read action out to the document at its host.
class ConfessionSectionScreen extends StatefulWidget {
  const ConfessionSectionScreen({
    super.key,
    required this.data,
    required this.confessionData,
    required this.section,
    required this.onBack,
    required this.onBreadcrumb,
    required this.onOpenVerse,
    this.textsLoader,
    this.externalLauncher,
  });

  final BibleData data;
  final ConfessionData confessionData;
  final ConfessionSection section;
  final VoidCallback onBack;

  /// Breadcrumb selections: 'library', 'confessions', 'sections'.
  final void Function(String value) onBreadcrumb;

  /// Opens a cited verse through the shell's one open-chapter
  /// procedure: (globalChapter, verse).
  final void Function(int globalChapter, int? verse) onOpenVerse;

  final Future<ScriptureText> Function()? textsLoader;

  /// Opens an external URL; defaults to url_launcher. Tests
  /// inject a fake through this seam (the TalkView pattern).
  final Future<bool> Function(Uri uri)? externalLauncher;

  @override
  State<ConfessionSectionScreen> createState() =>
      _ConfessionSectionScreenState();
}

class _ConfessionSectionScreenState extends State<ConfessionSectionScreen> {
  ScriptureText? _texts;
  WwTranslation _translation = WwTranslation.kjv;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Snippets follow the stored translation, the TalkView way.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _translation = WwTranslation.fromStored(
        prefs.getString(ReaderScreen.translationKey),
      );
    } catch (_) {}
    try {
      final texts = await (widget.textsLoader ?? ScriptureText.load)();
      if (mounted) setState(() => _texts = texts);
    } catch (_) {
      // Snippets are best-effort; references stand without them.
    }
  }

  Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _openExternal(String url) async {
    var ok = false;
    try {
      ok = await (widget.externalLauncher ?? _defaultLaunch)(Uri.parse(url));
    } catch (_) {
      ok = false;
    }
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: WwColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.chip),
        ),
        content: const Text(
          'The confession could not be opened.',
          style: WwType.bodyOnDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final doc = widget.confessionData.docFor(section);
    final verses = widget.confessionData.versesForSection(section.index);
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: section.label,
              onBack: widget.onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('confessions', 'Confessions'),
                ('sections', doc.title),
                ('__current', section.label),
              ],
              onBreadcrumb: widget.onBreadcrumb,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(WwSpace.screenMargin),
                children: [
                  Text(doc.title, style: WwType.selectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${doc.year} · ${section.label} cites '
                    '${verses.length == 1 ? '1 verse' : '${verses.length} verses'}',
                    style: WwType.captionOnDark,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        _openExternal(widget.confessionData.urlFor(section)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WwColors.goldBright,
                      foregroundColor: WwColors.onGold,
                      minimumSize: const Size.fromHeight(WwSpace.minTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(WwRadius.chip),
                      ),
                    ),
                    child: const Text(
                      'Read the confession',
                      style: WwType.goldButtonLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < verses.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _verseRow(verses[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verseRow((int, int) ref) {
    final (ch, v) = ref;
    final data = widget.data;
    final texts = _texts;
    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => widget.onOpenVerse(ch, v),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.refName(ch, v), style: WwType.refLabelOnDark),
              if (texts != null) ...[
                const SizedBox(height: 2),
                Text(
                  texts.verseText(_translation, data, ch, v),
                  style: WwType.snippet.copyWith(color: WwColors.mutedOnDark),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One deuterocanon book's chapter number grid (the shipped
/// chapter grid's construction, over the extra canon).
class DeuteroChapterGrid extends StatelessWidget {
  const DeuteroChapterGrid({
    super.key,
    required this.book,
    required this.onOpenChapter,
    required this.onBack,
    required this.onBreadcrumb,
  });

  final DeuteroBook book;
  final void Function(int chapterInBook) onOpenChapter;
  final VoidCallback onBack;

  /// Breadcrumb selections: 'library' or 'canon'.
  final void Function(String value) onBreadcrumb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WwColors.stage,
      body: SafeArea(
        child: Column(
          children: [
            libraryTopBar(
              title: book.name,
              onBack: onBack,
              breadcrumbItems: [
                ('library', 'Library'),
                ('canon', 'Old Testament'),
                ('__current', book.name),
              ],
              onBreadcrumb: onBreadcrumb,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth - 32;
                  final columns = math.max(
                    1,
                    ((contentWidth + 8) / 56).floor(),
                  );
                  return GridView.builder(
                    padding: const EdgeInsets.all(WwSpace.screenMargin),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: book.chapters,
                    itemBuilder: (context, i) {
                      return Material(
                        color: WwColors.surface,
                        borderRadius: BorderRadius.circular(WwRadius.row),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(WwRadius.row),
                          onTap: () => onOpenChapter(i + 1),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text('${i + 1}', style: WwType.bodyOnDark),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads one deuterocanon book (board run 9, Catholic layer):
/// the core reader's paged discipline — one chapter per page,
/// in-page scroll stops at the chapter's end, a horizontal swipe
/// turns to the next chapter — over the WEB Catholic Edition
/// text, with highlights and notes in the same user store (verse
/// keys use the book's reserved index, so My Notes and the
/// profiles carry them exactly like core verses). The woven web
/// does not cover these books and the first page says so
/// plainly; there are no connections here, so the verse actions
/// are the five highlight colors and Note.
class DeuteroReaderScreen extends StatefulWidget {
  const DeuteroReaderScreen({
    super.key,
    required this.deutero,
    required this.book,
    required this.initialChapter,
    this.initialVerse,
    required this.onBack,
    this.textsLoader,
    this.readerTheme,
    this.onReaderThemeChanged,
  });

  final DeuterocanonData deutero;
  final DeuteroBook book;

  /// 1-based chapter in [book] to open on.
  final int initialChapter;
  final int? initialVerse;
  final VoidCallback onBack;

  /// Loads the scripture texts; defaults to [ScriptureText.load].
  final Future<ScriptureText> Function()? textsLoader;

  /// The reader theme (reader theme package): the shell passes
  /// its live choice and its setter. Both are optional — a
  /// standalone pump resolves the theme from the preference
  /// itself, defaulting to Dark.
  final WwReaderTheme? readerTheme;
  final ValueChanged<WwReaderTheme>? onReaderThemeChanged;

  @override
  State<DeuteroReaderScreen> createState() => _DeuteroReaderScreenState();
}

class _DeuteroReaderScreenState extends State<DeuteroReaderScreen> {
  ScriptureText? _texts;
  UserDataStore? _store;
  String _profileId = UserData.defaultProfileId;
  late int _currentChapter;
  late final PageController _pager;
  (int, int)? _selected; // (chapterInBook, verse)
  final Map<String, GlobalKey> _verseKeys = {};

  // Text selection (board run 10): selection is a MODE, entered
  // by long-press — only the verse in selection mode renders as
  // a SelectableText (an always-on one would claim the pager's
  // horizontal swipes on Android). _selGen is bumped on every
  // selection-bar write so the verse's SelectableText is
  // recreated and the platform selection collapses onto the
  // applied tint.
  (int, int)? _selVerse;
  int _selGen = 0;

  // The reader theme (reader theme package): a local switch
  // (this top bar's own) wins once made; before that the passed
  // choice, then the stored preference, then Dark.
  WwReaderTheme? _localTheme;
  WwReaderTheme? _storedTheme;

  WwReaderTheme get _readerTheme =>
      _localTheme ?? widget.readerTheme ?? _storedTheme ?? WwReaderTheme.dark;

  ReaderPalette get _palette => _readerTheme == WwReaderTheme.dark
      ? ReaderPalette.dark
      : ReaderPalette.paper;

  Future<void> _setReaderTheme(WwReaderTheme next) async {
    if (next == _readerTheme) return;
    setState(() => _localTheme = next);
    final callback = widget.onReaderThemeChanged;
    if (callback != null) {
      callback(next);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(readerThemePrefsKey, next.storedValue);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter.clamp(1, widget.book.chapters);
    _pager = PageController(initialPage: _currentChapter - 1);
    _load();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    ScriptureText? texts;
    try {
      texts = await (widget.textsLoader ?? ScriptureText.load)();
    } catch (_) {
      texts = null;
    }
    UserDataStore? store;
    try {
      final prefs = await SharedPreferences.getInstance();
      store = await UserDataStore.load(prefs);
      _storedTheme = WwReaderTheme.fromStored(
        prefs.getString(readerThemePrefsKey),
      );
    } catch (_) {
      store = null;
    }
    if (!mounted) return;
    setState(() {
      _texts = texts;
      _store = store;
      _profileId = store?.data.activeProfileId ?? UserData.defaultProfileId;
    });
    if (widget.initialVerse != null) {
      _landOnAnchor(_currentChapter, widget.initialVerse!);
    }
  }

  Color _tintFor(HlColor color) => _palette.tintAt(color.index);

  void _goToChapter(int chapterInBook) {
    final target = chapterInBook.clamp(1, widget.book.chapters);
    if (target == _currentChapter) return;
    if (WwMotion.reduced(context)) {
      _pager.jumpToPage(target - 1);
    } else {
      _pager.animateToPage(
        target - 1,
        duration: WwMotion.push,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _landOnAnchor(int chapterInBook, int verse) async {
    var attempt = 0;
    while (attempt < 2 && mounted) {
      attempt++;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final key = _verseKeys['$chapterInBook:$verse'];
      final ctx = key?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: Duration.zero,
          alignment: 0.25,
        );
        return;
      }
    }
  }

  void _select(int chapterInBook, int verse) {
    // A tap on the verse in selection mode leaves the mode and
    // does nothing else (board run 10); a tap elsewhere clears
    // the mode and proceeds as the shipped tap.
    if (_selVerse == (chapterInBook, verse)) {
      setState(() => _selVerse = null);
      return;
    }
    setState(() {
      _selVerse = null;
      _selected = _selected == (chapterInBook, verse)
          ? null
          : (chapterInBook, verse);
    });
  }

  /// Long-press enters selection mode for the verse; the action
  /// bar closes (the selection bar is the surface while
  /// selecting).
  void _enterSelection(int chapterInBook, int verse) {
    setState(() {
      _selected = null;
      _selVerse = (chapterInBook, verse);
    });
  }

  /// The action bar's color write (board run 10): a full-verse
  /// span in the `webc` set — the only text this reader renders.
  /// A null color (None) clears all of the verse's spans.
  Future<void> _setHighlight(HlColor? color) async {
    final sel = _selected;
    final store = _store;
    if (sel == null || store == null) return;
    final key = verseKey(widget.book.bookIndex, sel.$1, sel.$2);
    final verses =
        _texts?.extraChapterVerses(widget.book.slug, sel.$1) ??
        const <String>[];
    final text = (sel.$2 >= 1 && sel.$2 <= verses.length)
        ? verses[sel.$2 - 1]
        : '';
    if (color == null) {
      store.data.clearVerseSpans(_profileId, 'webc', key);
    } else {
      store.data.applySpan(
        _profileId,
        'webc',
        HighlightSpan(
          verseKey: key,
          start: 0,
          end: -1,
          anchor: text,
          color: color,
        ),
        verseText: text,
      );
    }
    await store.save();
    if (mounted) setState(() {});
  }

  Future<void> _editNote() async {
    final sel = _selected;
    final store = _store;
    if (sel == null || store == null) return;
    final key = verseKey(widget.book.bookIndex, sel.$1, sel.$2);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: wwSheetAnimationStyle(context),
      backgroundColor: _palette.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DeuteroNoteEditor(
        title: widget.deutero.refLabel(widget.book.bookIndex, sel.$1, sel.$2),
        initial: store.data.note(_profileId, 'webc', key) ?? '',
        palette: _palette,
      ),
    );
    if (saved == null || !mounted) return;
    // UserData.setNote semantics: empty-after-trim removes.
    store.data.setNote(_profileId, 'webc', key, saved);
    await store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return Scaffold(
      backgroundColor: _palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: TextSelectionTheme(
                // Spec §3.4 (board run 10) as themed (reader
                // theme package): the core reader's selection
                // chrome, from the palette — identical values.
                data: TextSelectionThemeData(
                  selectionColor: _palette.selectionOverlay,
                  selectionHandleColor: _palette.accent,
                  cursorColor: _palette.accent,
                ),
                child: PageView.builder(
                  controller: _pager,
                  itemCount: book.chapters,
                  onPageChanged: (page) {
                    setState(() {
                      _currentChapter = page + 1;
                      _selected = null;
                      _selVerse = null;
                    });
                  },
                  itemBuilder: (context, page) => _chapterPage(page + 1),
                ),
              ),
            ),
            if (_selected != null && _selected!.$1 == _currentChapter)
              _actionBar(),
          ],
        ),
      ),
    );
  }

  /// The core reader's paper top bar, carrying the translation
  /// as a plain label — the deuterocanon is read in the WEB
  /// Catholic Edition only, so there is no toggle to offer.
  Widget _topBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: WwSpace.topBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _palette.chrome,
        border: Border(bottom: BorderSide(color: _palette.hairline)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: Icon(Icons.arrow_back, color: _palette.ink),
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              '${widget.book.name} $_currentChapter',
              style: _palette.titleStyle,
              maxLines: 2,
            ),
          ),
          _themeSwitch(),
          const SizedBox(width: 8),
          Text('WEB Catholic', style: _palette.toggleUnselectedStyle),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// The reader theme quick switch (reader theme package):
  /// the core reader top bar's control, same construction — one
  /// 48dp target whose icon names the theme a tap switches to.
  Widget _themeSwitch() {
    final theme = _readerTheme;
    final next = theme.other;
    return IconButton(
      tooltip: 'Reader theme: ${theme.label}. Switch to ${next.label} theme',
      onPressed: () => _setReaderTheme(next),
      icon: Icon(
        next == WwReaderTheme.dark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        color: _palette.accent,
      ),
    );
  }

  /// The docked verse action bar: five highlight swatches + None
  /// and the Note button, every target at least 48dp. Docked
  /// rather than anchored at the verse: this reader is its own
  /// screen, and a bar that is always in the same place is the
  /// plainer contract.
  Widget _actionBar() {
    final sel = _selected!;
    final key = verseKey(widget.book.bookIndex, sel.$1, sel.$2);
    final store = _store;
    final current = store?.data.fullVerseColor(_profileId, 'webc', key);
    final hasNote = store?.data.note(_profileId, 'webc', key) != null;
    final children = <Widget>[];
    for (final color in HlColor.values) {
      final name = switch (color) {
        HlColor.gold => 'Gold',
        HlColor.green => 'Green',
        HlColor.blue => 'Blue',
        HlColor.pink => 'Pink',
        HlColor.purple => 'Purple',
      };
      children.add(
        Semantics(
          container: true,
          button: true,
          selected: current == color,
          label: '$name highlight',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: _store == null ? null : () => _setHighlight(color),
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: WwSpace.minTarget,
                height: WwSpace.minTarget,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _tintFor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current == color
                            ? _palette.accent
                            : _palette.muted,
                        width: current == color ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    children.add(
      Semantics(
        container: true,
        button: true,
        selected: current == null,
        label: 'None highlight',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: _store == null ? null : () => _setHighlight(null),
            borderRadius: BorderRadius.circular(WwRadius.chip),
            child: Container(
              constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Text('None', style: _palette.toggleUnselectedStyle),
            ),
          ),
        ),
      ),
    );
    // Two rows, the core toolbar card's own arrangement: five
    // 48dp swatch targets and None cannot share one row with
    // the Note action and a close control at phone widths.
    return Container(
      decoration: BoxDecoration(
        color: _palette.chrome,
        border: Border(top: BorderSide(color: _palette.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: children),
          Row(
            children: [
              TextButton.icon(
                onPressed: _store == null ? null : _editNote,
                icon: const Icon(Icons.notes, size: 18),
                label: Text(hasNote ? 'Edit note' : 'Note'),
                style: TextButton.styleFrom(
                  foregroundColor: _palette.accent,
                  minimumSize: const Size(0, WwSpace.minTarget),
                  textStyle: WwType.controlLabel.copyWith(
                    color: _palette.accent,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _selected = null),
                icon: Icon(Icons.close, size: 20, color: _palette.muted),
                tooltip: 'Close verse actions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chapterPage(int chapterInBook) {
    final book = widget.book;
    final texts = _texts;
    final verses = texts == null
        ? const <String>[]
        : texts.extraChapterVerses(book.slug, chapterInBook);
    return ListView(
      key: ValueKey('deutero-page-$chapterInBook'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _labelBlock(chapterInBook, verses.length),
        for (var i = 0; i < verses.length; i++)
          _verseBlock(chapterInBook, i + 1, verses[i]),
        if (chapterInBook == book.chapters) _endBlock(),
      ],
    );
  }

  Widget _labelBlock(int chapterInBook, int verseCount) {
    final book = widget.book;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${book.name} $chapterInBook',
                  style: _palette.titleStyle,
                ),
              ),
              IconButton(
                onPressed: chapterInBook > 1
                    ? () => _goToChapter(chapterInBook - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                color: _palette.accent,
                disabledColor: _palette.line,
                tooltip: 'Previous chapter',
              ),
              IconButton(
                onPressed: chapterInBook < book.chapters
                    ? () => _goToChapter(chapterInBook + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: _palette.accent,
                disabledColor: _palette.line,
                tooltip: 'Next chapter',
              ),
            ],
          ),
          Text(
            verseCount == 1 ? '1 verse' : '$verseCount verses',
            style: _palette.captionStyle,
          ),
          if (chapterInBook == 1) ...[
            const SizedBox(height: 8),
            Text(
              'Part of the Catholic canon. The woven web does not '
              'yet cover the deuterocanon, so no cross references '
              'are recorded for these chapters.',
              style: _palette.captionStyle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _endBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('End of ${widget.book.name}', style: _palette.titleStyle),
          const SizedBox(height: 4),
          Text(
            'Read in the World English Bible, Catholic Edition.',
            style: _palette.captionStyle,
          ),
        ],
      ),
    );
  }

  Widget _verseBlock(int chapterInBook, int verse, String text) {
    final store = _store;
    final key = verseKey(widget.book.bookIndex, chapterInBook, verse);
    // Board run 10: spans in the webc set (the only text here).
    final spans =
        store?.data.spansFor(_profileId, 'webc', key) ??
        const <HighlightSpan>[];
    final fullColor = store?.data.fullVerseColor(_profileId, 'webc', key);
    final hl = fullColor ?? (spans.isNotEmpty ? spans.first.color : null);
    final hasNote = store?.data.note(_profileId, 'webc', key) != null;
    final selected = _selected == (chapterInBook, verse);
    var bg = Colors.transparent;
    if (selected) {
      // The core reader's audited selected construction (run 4),
      // from the palette (reader theme package): paper keeps the
      // shipped wash; dark keeps the tint and washes the plain
      // verse, the outline carrying selection either way.
      bg = _palette.selectedBackground(
        fullColor != null ? _tintFor(fullColor) : null,
      );
    } else if (fullColor != null) {
      bg = _tintFor(fullColor);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WwSpace.screenMargin),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? _palette.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Semantics(
          key: _verseKeys.putIfAbsent(
            '$chapterInBook:$verse',
            () => GlobalKey(),
          ),
          container: true,
          button: true,
          selected: selected,
          label:
              'Verse $verse${hasNote ? ', has note' : ''}'
              '${hl != null ? ', highlighted ${hl.key}' : ''}',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _select(chapterInBook, verse),
            onLongPress: () => _enterSelection(chapterInBook, verse),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Text(
                            '$verse',
                            style: spans.isNotEmpty || selected
                                ? _palette.verseNumberOnTintStyle
                                : _palette.verseNumberStyle,
                            textAlign: TextAlign.center,
                          ),
                          if (hasNote)
                            Icon(Icons.notes, size: 16, color: _palette.accent),
                        ],
                      ),
                    ),
                    Expanded(
                      // Board run 10: in selection mode the verse
                      // text is a SelectableText — drag or
                      // long-press takes the exact words and the
                      // selection bar colors the span. Outside the
                      // mode it is the shipped plain Text.
                      child: _selVerse == (chapterInBook, verse)
                          ? SelectableText.rich(
                              TextSpan(
                                children: _segments(
                                  text,
                                  spans,
                                  suppressBg: fullColor != null,
                                ),
                              ),
                              key: ValueKey(
                                'dtext-$chapterInBook-$verse-$_selGen',
                              ),
                              style: _palette.bodyStyle,
                              contextMenuBuilder: (menuContext, state) =>
                                  _selectionMenu(menuContext, state, key, text),
                            )
                          : Text.rich(
                              TextSpan(
                                children: _segments(
                                  text,
                                  spans,
                                  suppressBg: fullColor != null,
                                ),
                              ),
                              style: _palette.bodyStyle,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The verse text as segments (board run 10, spec §3.1): the
  /// core reader's disjoint span walk.
  List<TextSpan> _segments(
    String text,
    List<HighlightSpan> spans, {
    required bool suppressBg,
  }) {
    if (suppressBg || spans.isEmpty) return [TextSpan(text: text)];
    final out = <TextSpan>[];
    var cursor = 0;
    for (final span in spans) {
      final s = span.start.clamp(0, text.length);
      final e = (span.end == -1 ? text.length : span.end).clamp(0, text.length);
      if (e <= s) continue;
      if (s > cursor) out.add(TextSpan(text: text.substring(cursor, s)));
      out.add(
        TextSpan(
          text: text.substring(s, e),
          style: TextStyle(backgroundColor: _tintFor(span.color)),
        ),
      );
      cursor = e;
    }
    if (cursor < text.length) out.add(TextSpan(text: text.substring(cursor)));
    if (out.isEmpty) out.add(TextSpan(text: text));
    return out;
  }

  /// The selection action bar (board run 10, spec §2.2): the core
  /// reader's paper card — five swatches, Clear (selection range
  /// only), Copy — writing spans in the webc set.
  Widget _selectionMenu(
    BuildContext menuContext,
    EditableTextState state,
    String key,
    String verseText,
  ) {
    final selection = state.currentTextEditingValue.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return const SizedBox.shrink();
    }
    final len = verseText.length;
    final start = selection.start.clamp(0, len);
    final end = selection.end.clamp(0, len);
    if (end <= start) return const SizedBox.shrink();
    final store = _store;
    final spans =
        store?.data.spansFor(_profileId, 'webc', key) ??
        const <HighlightSpan>[];
    HlColor? covering;
    var overlaps = false;
    for (final span in spans) {
      final rs = span.start.clamp(0, len);
      final re = span.end == -1 ? len : span.end.clamp(0, len);
      if (rs < end && re > start) overlaps = true;
      if (rs <= start && re >= end) covering = span.color;
    }
    final anchors = state.contextMenuAnchors;
    final media = MediaQuery.sizeOf(menuContext);
    const barWidth = 352.0;
    const barHeight = 64.0;
    var left = anchors.primaryAnchor.dx - barWidth / 2;
    if (left < 8) left = 8;
    if (left > media.width - barWidth - 8) {
      left = media.width - barWidth - 8;
    }
    var top = anchors.primaryAnchor.dy - barHeight - 12;
    if (top < 8) {
      top = (anchors.secondaryAnchor?.dy ?? anchors.primaryAnchor.dy) + 12;
    }

    Widget swatch(HlColor color, String name) {
      final active = covering == color;
      return Semantics(
        container: true,
        button: true,
        selected: active,
        label: '$name highlight',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: store == null
                ? null
                : () => _applySelectionSpan(
                    state,
                    key,
                    verseText,
                    start,
                    end,
                    color,
                  ),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: WwSpace.minTarget,
              height: WwSpace.minTarget,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _tintFor(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? _palette.accent : _palette.muted,
                      width: active ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget action(IconData icon, String label, bool enabled, VoidCallback fn) {
      return Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: label,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? fn : null,
              child: SizedBox(
                width: WwSpace.minTarget,
                height: WwSpace.minTarget,
                child: Icon(
                  icon,
                  size: 20,
                  color: enabled ? _palette.ink : _palette.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: _palette.cardBg,
            borderRadius: BorderRadius.circular(WwRadius.sheet),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _palette.line),
                borderRadius: BorderRadius.circular(WwRadius.sheet),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  swatch(HlColor.gold, 'Gold'),
                  swatch(HlColor.green, 'Green'),
                  swatch(HlColor.blue, 'Blue'),
                  swatch(HlColor.pink, 'Pink'),
                  swatch(HlColor.purple, 'Purple'),
                  action(
                    Icons.format_color_reset,
                    'Clear highlight on selected text',
                    overlaps,
                    () => _applySelectionSpan(
                      state,
                      key,
                      verseText,
                      start,
                      end,
                      null,
                    ),
                  ),
                  action(Icons.copy, 'Copy selected text', true, () {
                    state.copySelection(SelectionChangedCause.toolbar);
                    state.hideToolbar();
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A deutero selection-bar write: [color] null clears the
  /// selected range. The menu hides first; the generation bump
  /// collapses the platform selection onto the applied tint.
  void _applySelectionSpan(
    EditableTextState state,
    String key,
    String verseText,
    int start,
    int end,
    HlColor? color,
  ) {
    state.hideToolbar();
    final store = _store;
    if (store == null) return;
    setState(() {
      _selGen++;
      _selVerse = null;
      if (color == null) {
        store.data.clearSpanRange(
          _profileId,
          'webc',
          key,
          start,
          end,
          verseText: verseText,
        );
      } else {
        store.data.applySpan(
          _profileId,
          'webc',
          HighlightSpan(
            verseKey: key,
            start: start,
            end: end,
            anchor: verseText.substring(start, end),
            color: color,
          ),
          verseText: verseText,
        );
      }
    });
    store.save();
  }
}

/// The deuterocanon note editor. The text controller is owned by
/// this State and disposed in dispose() — never from a route
/// future (LESSONS #33: a controller disposed from a sheet's
/// whenComplete throws while the exit transition still runs).
class _DeuteroNoteEditor extends StatefulWidget {
  const _DeuteroNoteEditor({
    required this.title,
    required this.initial,
    required this.palette,
  });

  final String title;
  final String initial;

  /// The reader palette this sheet renders from (reader theme
  /// package): the note editor follows the reader theme in both
  /// readers and in My Notes.
  final ReaderPalette palette;

  @override
  State<_DeuteroNoteEditor> createState() => _DeuteroNoteEditorState();
}

class _DeuteroNoteEditorState extends State<_DeuteroNoteEditor> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: widget.palette.sheetTitleStyle),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            style: widget.palette.smallBodyStyle,
            // Every surface set explicitly, as in both shipped note
            // editors: the app theme's input fill is tuned for dark
            // surfaces and would render this sheet's typed text
            // unreadable under the paper palette (ink on
            // surfaceHigh = 1.02:1). The palette carries the
            // sheet's own fill, borders, and focus color in both
            // themes (reader theme package).
            decoration: InputDecoration(
              hintText: 'Write a note',
              hintStyle: widget.palette.captionStyle,
              filled: true,
              fillColor: widget.palette.fieldFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
                borderSide: BorderSide(color: widget.palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
                borderSide: BorderSide(color: widget.palette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
                borderSide: BorderSide(color: widget.palette.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saving an empty note removes it.',
            style: widget.palette.captionStyle,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, WwSpace.minTarget),
                ),
                child: Text('Cancel', style: widget.palette.cancelStyle),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_ctl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.palette.goldFill,
                  foregroundColor: widget.palette.onGoldFill,
                  minimumSize: const Size(0, WwSpace.minTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                ),
                child: const Text('Save note', style: WwType.goldButtonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
