import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_data.dart';
import '../data/scripture_text.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';
import 'reader_screen.dart';

/// Whether a parsed note position names a real place in the canon.
/// Both bounds bind: [parseVerseKey] accepts zeros, so chapter 0
/// would compute global chapter −1 (a RangeError in the reference
/// label) and verse 0 would render as ":0" — corrupt-store keys
/// like `b0c0v1` are filtered here, never rendered (Maren, run 5).
bool notePositionInCanon(
  BibleData data,
  int book,
  int chapter,
  int verse,
) =>
    book >= 0 &&
    book < data.books.length &&
    chapter >= 1 &&
    chapter <= data.books[book].chapters &&
    verse >= 1;

/// My Notes: every note belonging to the active profile, in
/// canonical order (book, then chapter, then verse).
///
/// Each row shows the reference label, the verse's text in the
/// active translation, and the note itself. Tapping a row opens the
/// reader at that verse; notes can also be edited and deleted right
/// here, with the reader's editor semantics (board run 4): saving an
/// empty note removes it, and removing a note never touches the
/// verse's highlight.
///
/// Entry point: the notes button in the home top bar (research desk,
/// board run 5 — a dedicated notes list, one tap from home; burying
/// notes inside a profile or "saved" area is the discoverability
/// failure YouVersion's own redesign case study documents).
class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key, required this.data, this.onOpenVerse});

  final BibleData data;

  /// Opens a note's verse through the shell's one open-chapter
  /// procedure (board run 7 part B, §7.4): (bookIndex,
  /// chapterInBook, verse). When null (standalone test pumps), row
  /// taps do nothing — in the app the shell always provides it.
  final void Function(int book, int chapterInBook, int verse)? onOpenVerse;

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  UserDataStore? _store;
  UserData _userData = UserData();
  String _profileId = UserData.defaultProfileId;

  ScriptureText? _texts;
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
      _store = await UserDataStore.load(prefs);
      _userData = _store!.data;
      _profileId = _userData.activeProfileId;
    } catch (_) {
      _store = null;
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
      _texts = await ScriptureText.load();
    } catch (_) {
      // Snippets are best-effort: without the texts the list still
      // shows every reference and note, just no verse line.
      _texts = null;
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// Reloads the store after returning from the reader, where notes
  /// may have been added, edited, or removed.
  Future<void> _reloadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      if (!mounted) return;
      setState(() {
        _store = store;
        _userData = store.data;
        _profileId = store.data.activeProfileId;
      });
    } catch (_) {
      // Keep the session copy.
    }
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.save();
    } catch (_) {
      // Session state already carries the change.
    }
  }

  int _globalChapter(int book, int chapterInBook) =>
      widget.data.books[book].start + chapterInBook - 1;

  Future<void> _openInReader(int book, int chapterInBook, int verse) async {
    // §7.4: My Notes rows open through the shell's one procedure;
    // this screen's stack is left exactly as it was.
    widget.onOpenVerse?.call(book, chapterInBook, verse);
    _reloadUserData();
  }

  /// The note editor: the same paper sheet as the reader's (board
  /// run 4), carrying the same local border law — line idle,
  /// goldTextOnPaper focused, never the theme's goldBright border.
  void _editNote(String key, int globalChapter, int verse) {
    final data = widget.data;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WwColors.paper,
      isScrollControlled: true,
      sheetAnimationStyle: wwSheetAnimationStyle(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WwRadius.sheet),
        ),
      ),
      // The sheet OWNS its controller (run-8 fix round, Item 4
      // audit): disposing it from the sheet future's whenComplete
      // is the same lifetime bug the Profiles name dialog had —
      // the future can complete while the exit transition still
      // builds the field. See _NoteEditorSheet.
      builder: (_) => _NoteEditorSheet(
        refLabel: data.refName(globalChapter, verse),
        initialText: _userData.note(_profileId, key) ?? '',
        onSave: (text) {
          // UserData.setNote semantics (board run 4):
          // empty-after-trim removes the note.
          setState(() => _userData.setNote(_profileId, key, text));
          _persist();
        },
      ),
    );
  }

  Future<void> _deleteNote(String key, String refLabel) async {
    final confirmed = await wwShowDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WwColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.sheet),
        ),
        title: const Text('Remove this note?', style: WwType.selectionTitle),
        content: Text(
          'The note on $refLabel will be removed. This cannot be '
          'undone. Any highlight on the verse stays.',
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
            child: const Text('Remove', style: WwType.dangerActionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _userData.setNote(_profileId, key, ''));
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
          const Text('My Notes', style: WwType.screenTitle),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Text('Loading your notes…', style: WwType.captionOnDark),
    );
  }

  Widget _body() {
    // Defensive: notes are written only for real chapters, but a
    // hand-edited or corrupt store could hold a parseable key
    // outside the canon — those rows cannot open anywhere, so
    // they are filtered rather than crashing the list.
    final notes = _userData
        .notesFor(_profileId)
        .where(
          (n) => notePositionInCanon(widget.data, n.book, n.chapter, n.verse),
        )
        .toList();
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WwSpace.screenMargin,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No notes yet',
                style: WwType.selectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'While reading, tap any verse to add a note to it. '
                'Notes for ${_userData.profileName(_profileId)} '
                'will gather here.',
                style: WwType.captionOnDark,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      children: [
        Text(
          'Notes in ${_userData.profileName(_profileId)}',
          style: WwType.captionOnDark,
        ),
        const SizedBox(height: 16),
        for (final note in notes) ...[
          _noteRow(note),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _noteRow(
    ({String key, int book, int chapter, int verse, String text}) note,
  ) {
    final data = widget.data;
    final globalChapter = _globalChapter(note.book, note.chapter);
    final ref = data.refName(globalChapter, note.verse);
    final texts = _texts;
    final snippet = texts == null
        ? ''
        : texts.verseText(_translation, data, globalChapter, note.verse);
    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => _openInReader(note.book, note.chapter, note.verse),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ref, style: WwType.refLabelOnDark),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        snippet,
                        style: WwType.captionOnDark,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      note.text,
                      style: WwType.bodyOnDark,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit note',
                onPressed: () =>
                    _editNote(note.key, globalChapter, note.verse),
                icon: const Icon(Icons.edit, size: 20, color: WwColors.navInk),
                constraints: const BoxConstraints(
                  minWidth: WwSpace.minTarget,
                  minHeight: WwSpace.minTarget,
                ),
              ),
              IconButton(
                tooltip: 'Remove note',
                onPressed: () => _deleteNote(note.key, ref),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: WwColors.danger,
                ),
                constraints: const BoxConstraints(
                  minWidth: WwSpace.minTarget,
                  minHeight: WwSpace.minTarget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The My Notes note editor sheet: owns its [TextEditingController]
/// for exactly the sheet route's lifetime, so no dismissal path
/// (Save, Cancel, barrier, system back) can dispose the controller
/// while the sheet's exit transition still builds the field — the
/// lifetime bug the run-8 fix-round audit proved on the Profiles
/// name dialog's whenComplete disposal.
class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({
    required this.refLabel,
    required this.initialText,
    required this.onSave,
  });

  final String refLabel;
  final String initialText;
  final void Function(String text) onSave;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: WwSpace.screenMargin,
        right: WwSpace.screenMargin,
        top: WwSpace.screenMargin,
        bottom:
            WwSpace.screenMargin + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.refLabel, style: WwType.sheetRefTitle),
          const SizedBox(height: 8),
          const Text('Note', style: WwType.refLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            style: WwType.bodyOnPaper,
            minLines: 3,
            maxLines: 8,
            autofocus: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: WwColors.paper,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
                borderSide: const BorderSide(color: WwColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
                borderSide: const BorderSide(color: WwColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WwRadius.input),
                borderSide: const BorderSide(color: WwColors.goldTextOnPaper),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saving an empty note removes it.',
            style: WwType.captionOnPaper,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, WwSpace.minTarget),
                ),
                child: const Text('Cancel', style: WwType.paperButtonLabel),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  widget.onSave(_controller.text);
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: WwColors.goldBright,
                  minimumSize: const Size(64, WwSpace.minTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WwRadius.chip),
                  ),
                ),
                child: const Text('Save', style: WwType.goldButtonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
