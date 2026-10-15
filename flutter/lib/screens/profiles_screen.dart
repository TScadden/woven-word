import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tradition.dart';
import '../data/user_data.dart';
import '../theme/ww_theme.dart';

/// What each tradition selection adds, in the row's own words
/// (board run 9): honest coverage copy, naming what the layer
/// holds and — for Catholic — what it does not hold yet.
const Map<WwTradition, String> _traditionDescriptions = {
  WwTradition.none:
      'The woven web on its own: cross references, highlights, '
      'and notes.',
  WwTradition.lds:
      'Adds the General Conference talks that cite each verse. '
      'Talks are read in Gospel Library or the Citation Index; '
      'no talk text is stored in this app.',
  WwTradition.jewish:
      'Tanakh order, the JPS 1917 translation and the Hebrew '
      'text, and each verse\u2019s connections on Sefaria.',
  WwTradition.protestant:
      'Adds the proof texts of the Westminster Confession (1647) '
      'and the 1689 London Baptist Confession to each verse.',
  WwTradition.catholic:
      'The 73-book canon: the deuterocanon, read in the World '
      'English Bible Catholic Edition. Catechism citations are '
      'not included yet.',
};

/// Profiles screen: on-device profiles, managed in place.
///
/// A profile is a named bucket of highlights and notes (board run 4's
/// [UserData] store). Creating, renaming, deleting, and switching all
/// happen here; the reader and My Notes read whichever profile is
/// active. Profiles never leave the device — there is no account and
/// no sync, and nothing on this screen pretends otherwise.
///
/// Entry point: the profile chip in the home top bar (research desk,
/// board run 5 — the category pattern is an identity entry at the top
/// of home: YouVersion's profile, the avatar entry in newer apps).
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({
    super.key,
    this.pickBackupFile,
    this.shareBackup,
    this.tradition = WwTradition.none,
    this.onTraditionChanged,
  });

  /// Picks a backup file and returns its bytes; a null return is a
  /// cancelled pick. Defaults to the system file picker. Tests
  /// inject a fake picker through this seam.
  final Future<Uint8List?> Function()? pickBackupFile;

  /// The tradition selection when this screen opens (board run 9).
  /// The shell owns the preference; this screen shows the value it
  /// was opened with and reports changes through
  /// [onTraditionChanged]. A standalone pump (tests) gets the
  /// Bible-only default and may change the selection locally.
  final WwTradition tradition;

  /// Called with the new selection the moment a tradition row is
  /// tapped — visible state first, persistence fire-and-forget at
  /// the owner.
  final ValueChanged<WwTradition>? onTraditionChanged;

  /// Shares the exported backup JSON. Defaults to the system share
  /// sheet. Tests inject a fake through this seam.
  final Future<void> Function(String json)? shareBackup;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  UserDataStore? _store;
  UserData _data = UserData();
  bool _loaded = false;
  late WwTradition _tradition;

  @override
  void initState() {
    super.initState();
    _tradition = widget.tradition;
    _load();
  }

  /// The tradition selection: one action for the whole row. The
  /// visible state changes first; the owner persists at tap time.
  void _selectTradition(WwTradition value) {
    if (value == _tradition) return;
    setState(() => _tradition = value);
    widget.onTraditionChanged?.call(value);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _store = await UserDataStore.load(prefs);
      _data = _store!.data;
    } catch (_) {
      // Persistence failure leaves an empty in-memory model; the
      // screen still renders (the session just cannot save).
      _store = null;
      _data = UserData();
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// Persists after a mutation. Fire-and-forget with a catch: the
  /// visible state is already updated, so a failed write only loses
  /// persistence, never the change the user just saw.
  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.save();
    } catch (_) {
      // Session state already carries the change.
    }
  }

  void _switch(String id) {
    if (id == _data.activeProfileId) return;
    setState(() => _data.setActiveProfile(id));
    _persist();
  }

  Future<void> _create() async {
    final name = await _nameDialog(
      title: 'New profile',
      actionLabel: 'Create',
      initial: '',
    );
    if (name == null || !mounted) return;
    setState(() => _data.createProfile(name));
    _persist();
  }

  Future<void> _rename(String id) async {
    final name = await _nameDialog(
      title: 'Rename profile',
      actionLabel: 'Save',
      initial: _data.profileName(id),
    );
    if (name == null || !mounted) return;
    setState(() => _data.renameProfile(id, name));
    _persist();
  }

  Future<void> _delete(String id) async {
    final profile = _data.profiles[id];
    final highlights = profile?.spanCount ?? 0;
    final notes = profile?.noteCount ?? 0;
    final name = _data.profileName(id);
    final confirmed = await wwShowDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WwColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.sheet),
        ),
        title: const Text('Delete profile?', style: WwType.selectionTitle),
        content: Text(
          '“$name” will be deleted along with everything in it: '
          '$highlights ${highlights == 1 ? 'highlight' : 'highlights'} and '
          '$notes ${notes == 1 ? 'note' : 'notes'}. '
          'This cannot be undone.',
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
            child: const Text('Delete', style: WwType.dangerActionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _data.deleteProfile(id));
    _persist();
  }

  /// Name entry dialog shared by create and rename. Returns the
  /// entered name, or null on cancel. The confirm action stays
  /// disabled while the field is empty after trimming.
  ///
  /// The dialog is a StatefulWidget that OWNS its controller
  /// (run-8 fix round, Item 4 audit): the previous construction
  /// disposed the controller from the dialog future's
  /// whenComplete, which fires while the route's exit transition
  /// still builds the field — every dismissal (Cancel, barrier,
  /// system back) threw "TextEditingController used after being
  /// disposed" in debug/profile builds. A State disposes its
  /// controller only when the route's subtree unmounts, after
  /// the transition has finished.
  Future<String?> _nameDialog({
    required String title,
    required String actionLabel,
    required String initial,
  }) {
    return wwShowDialog<String>(
      context: context,
      builder: (_) => _ProfileNameDialog(
        title: title,
        actionLabel: actionLabel,
        initial: initial,
      ),
    );
  }

  /// Export (board run 6): the full backup document goes to the
  /// system share sheet as one JSON file. The share sheet opening
  /// is the feedback — nothing is shown after it, and export
  /// mutates nothing.
  Future<void> _exportBackup() async {
    final json = _data.exportJson();
    final share = widget.shareBackup;
    if (share != null) {
      await share(json);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            name: 'woven-word-backup.json',
            mimeType: 'application/json',
          ),
        ],
        subject: 'Woven Word backup',
      ),
    );
  }

  /// The default import file pick: the system picker, JSON files.
  /// An empty result is a cancelled pick.
  Future<Uint8List?> _pickBackupFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return null;
    return files.first.xFile.readAsBytes();
  }

  /// Import (board run 6): pick → validate → confirm → replace
  /// wholesale → persist → success snackbar. A cancelled pick is a
  /// silent no-op; a malformed file opens the error dialog and
  /// changes nothing.
  Future<void> _importBackup() async {
    final bytes = await (widget.pickBackupFile ?? _pickBackupFile)();
    if (bytes == null || !mounted) return;
    final String source;
    try {
      source = utf8.decode(bytes);
    } catch (_) {
      await _showImportError(BackupImportError.notJson);
      return;
    }
    // Board run 10: a legacy backup (no per-translation sets)
    // imports into the translation active at import — the same
    // assignment rule as the in-place upgrade migration.
    var legacyKey = translationKeyForLabel(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      legacyKey = translationKeyForLabel(prefs.getString(translationPrefsKey));
    } catch (_) {}
    if (!mounted) return;
    final result = UserDataStore.validateImport(
      source,
      legacyTranslation: legacyKey,
    );
    if (!mounted) return;
    final error = result.error;
    if (error != null) {
      await _showImportError(error);
      return;
    }
    final incoming = result.data!;
    final confirmed = await _confirmImport(incoming);
    if (confirmed != true || !mounted) return;
    final store = _store;
    if (store == null) return;
    await store.replaceData(incoming);
    if (!mounted) return;
    setState(() => _data = store.data);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: WwColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.chip),
        ),
        content: const Text(
          'Data replaced from backup.',
          style: WwType.bodyOnDark,
        ),
      ),
    );
  }

  static String _counted(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

  /// The import confirm dialog: both sides' counts named (current
  /// data and the exact [UserData] instance to be installed, each
  /// counted by the same model getters), the destructive action
  /// last, in danger text only.
  Future<bool?> _confirmImport(UserData incoming) {
    final currentProfiles = _counted(
      _data.profileIds.length,
      'profile',
      'profiles',
    );
    final currentHighlights = _counted(
      _data.totalSpans,
      'highlight',
      'highlights',
    );
    final currentNotes = _counted(_data.totalNotes, 'note', 'notes');
    final fileProfiles = _counted(
      incoming.profileIds.length,
      'profile',
      'profiles',
    );
    final fileHighlights = _counted(
      incoming.totalSpans,
      'highlight',
      'highlights',
    );
    final fileNotes = _counted(incoming.totalNotes, 'note', 'notes');
    return wwShowDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WwColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.sheet),
        ),
        title: const Text('Replace all data?', style: WwType.selectionTitle),
        content: Text(
          'Importing this backup will replace all current data. '
          'The $currentProfiles, $currentHighlights, and $currentNotes '
          'now on this device will be removed, and $fileProfiles, '
          '$fileHighlights, and $fileNotes from the file will take '
          'their place. This cannot be undone.',
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
            child: const Text('Replace', style: WwType.dangerActionLabel),
          ),
        ],
      ),
    );
  }

  /// The import error dialog: nothing was changed, plus the
  /// specific reason the validator detected.
  Future<void> _showImportError(BackupImportError error) {
    final reason = switch (error) {
      BackupImportError.notJson =>
        'The file is not readable as a backup (it is not valid JSON).',
      BackupImportError.notBackup =>
        'The file is not a Woven Word backup document.',
      BackupImportError.newerVersion =>
        'This backup was made by a newer version of Woven Word.',
      BackupImportError.emptyDocument =>
        'This backup contains no profiles, highlights, or notes.',
    };
    return wwShowDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WwColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WwRadius.sheet),
        ),
        title: const Text(
          'This file could not be imported',
          style: WwType.selectionTitle,
        ),
        content: Text('Nothing was changed. $reason', style: WwType.bodyOnDark),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, WwSpace.minTarget),
            ),
            child: const Text('OK', style: WwType.dialogActionLabel),
          ),
        ],
      ),
    );
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
          const Text('Profiles', style: WwType.screenTitle),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Text('Loading profiles…', style: WwType.captionOnDark),
    );
  }

  Widget _body() {
    final ids = _data.profileIds;
    final active = _data.activeProfileId;
    return ListView(
      padding: const EdgeInsets.all(WwSpace.screenMargin),
      children: [
        const Text(
          'Highlights and notes belong to the active profile. '
          'Profiles live on this device only.',
          style: WwType.captionOnDark,
        ),
        const SizedBox(height: 16),
        for (final id in ids) ...[
          _profileRow(id, isActive: id == active, canDelete: ids.length > 1),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _create,
          style: ElevatedButton.styleFrom(
            backgroundColor: WwColors.goldBright,
            foregroundColor: WwColors.onGold,
            minimumSize: const Size.fromHeight(WwSpace.minTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(WwRadius.chip),
            ),
          ),
          child: const Text('New profile', style: WwType.goldButtonLabel),
        ),
        const SizedBox(height: 24),
        const Text('Your tradition', style: WwType.selectionTitle),
        const SizedBox(height: 4),
        const Text(
          'Woven Word shapes itself around your tradition: the '
          'canon it presents, the connections it layers over each '
          'verse, and where reading links lead. Your profiles, '
          'highlights, and notes never change.',
          style: WwType.captionOnDark,
        ),
        const SizedBox(height: 16),
        for (final t in WwTradition.values) ...[
          _traditionRow(t),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        const Text('Backup', style: WwType.selectionTitle),
        const SizedBox(height: 4),
        const Text(
          'Export saves every profile \u2014 with every '
          'translation\u2019s highlights and notes \u2014 as one JSON '
          'file. Import replaces everything here with the contents '
          'of a backup file. Nothing leaves this device unless you '
          'export it.',
          style: WwType.captionOnDark,
        ),
        const SizedBox(height: 16),
        _backupRow(
          icon: Icons.share,
          title: 'Export backup',
          subtitle: 'Share a JSON file of all your profiles',
          onTap: _exportBackup,
        ),
        const SizedBox(height: 8),
        _backupRow(
          icon: Icons.folder_open,
          title: 'Import backup',
          subtitle: 'Replace current data from a backup file',
          onTap: _importBackup,
        ),
      ],
    );
  }

  /// One Backup action row, built exactly like a profile row: the
  /// whole row is the tap target, icon + title + subtitle, with a
  /// disclosure chevron (board run 6, Petra spec §2.3).
  Widget _backupRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
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
    );
  }

  /// One tradition selection row (board run 9): the profile-row
  /// construction — the whole row is the tap target — with the
  /// selection carried by a check and by semantics, never by
  /// color alone. The row is ONE semantics node (container +
  /// selected flag, label exactly the tradition's name); its
  /// inner semantics are excluded so descendant text cannot
  /// merge into the node's label (lesson 25).
  Widget _traditionRow(WwTradition t) {
    final selected = t == _tradition;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: t.label,
      child: ExcludeSemantics(
        child: Material(
          color: WwColors.surface,
          borderRadius: BorderRadius.circular(WwRadius.row),
          child: InkWell(
            borderRadius: BorderRadius.circular(WwRadius.row),
            onTap: () => _selectTradition(t),
            child: Container(
              constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected
                        ? WwColors.goldBright
                        : WwColors.mutedOnDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.label,
                          style: WwType.controlLabel.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _traditionDescriptions[t]!,
                          style: WwType.captionOnDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileRow(
    String id, {
    required bool isActive,
    required bool canDelete,
  }) {
    final name = _data.profileName(id);
    final profile = _data.profiles[id];
    final highlights = profile?.spanCount ?? 0;
    final notes = profile?.noteCount ?? 0;
    final counts = highlights == 0 && notes == 0
        ? 'No highlights or notes yet'
        : '$highlights ${highlights == 1 ? 'highlight' : 'highlights'} · '
              '$notes ${notes == 1 ? 'note' : 'notes'}';
    return Material(
      color: WwColors.surface,
      borderRadius: BorderRadius.circular(WwRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(WwRadius.row),
        onTap: () => _switch(id),
        child: Container(
          constraints: const BoxConstraints(minHeight: WwSpace.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _avatar(name, isActive: isActive),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: WwType.controlLabel.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(counts, style: WwType.captionOnDark),
                    if (isActive) ...[
                      const SizedBox(height: 2),
                      const Text('Active', style: WwType.activeCaption),
                    ],
                  ],
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: WwColors.goldBright,
                ),
              IconButton(
                tooltip: 'Rename profile',
                onPressed: () => _rename(id),
                icon: const Icon(Icons.edit, size: 20, color: WwColors.navInk),
                constraints: const BoxConstraints(
                  minWidth: WwSpace.minTarget,
                  minHeight: WwSpace.minTarget,
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Delete profile',
                  onPressed: () => _delete(id),
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

  /// Profile avatar: a circle carrying the name's first letter.
  /// The active profile's avatar is the gold fill (onGold letter,
  /// the ratified pair); inactive avatars sit on surfaceHigh with
  /// a goldBright letter.
  Widget _avatar(String name, {required bool isActive}) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? WwColors.goldBright : WwColors.surfaceHigh,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: isActive ? WwType.avatarLetterOnGold : WwType.avatarLetterOnDark,
      ),
    );
  }
}

/// The profile name entry dialog (create + rename): owns its
/// [TextEditingController] for exactly the dialog route's
/// lifetime — see [_ProfilesScreenState._nameDialog] for why the
/// controller must not be disposed from the dialog future.
class _ProfileNameDialog extends StatefulWidget {
  const _ProfileNameDialog({
    required this.title,
    required this.actionLabel,
    required this.initial,
  });

  final String title;
  final String actionLabel;
  final String initial;

  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<_ProfileNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      backgroundColor: WwColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WwRadius.sheet),
      ),
      title: Text(widget.title, style: WwType.selectionTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: WwType.controlLabel,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Profile name',
          // Inside a surfaceHigh dialog the field steps DOWN
          // to surface so it reads as an inset, bordered
          // like every other input in the app (Petra FIX
          // D-2: the fill override is explicit, never the
          // theme's surfaceHigh input fill).
          filled: true,
          fillColor: WwColors.surface,
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
        onChanged: (_) => setState(() {}),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(64, WwSpace.minTarget),
          ),
          child: const Text('Cancel', style: WwType.buttonLabel),
        ),
        TextButton(
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(64, WwSpace.minTarget),
          ),
          child: Text(
            widget.actionLabel,
            style: canSubmit
                ? WwType.dialogActionLabel
                : WwType.dialogActionLabelDisabled,
          ),
        ),
      ],
    );
  }
}
