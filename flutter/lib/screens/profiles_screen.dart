import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/user_data.dart';
import '../theme/ww_theme.dart';

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
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  UserDataStore? _store;
  UserData _data = UserData();
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
    final highlights = profile?.highlights.length ?? 0;
    final notes = profile?.notes.length ?? 0;
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
  Future<String?> _nameDialog({
    required String title,
    required String actionLabel,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return wwShowDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final canSubmit = controller.text.trim().isNotEmpty;
            return AlertDialog(
              backgroundColor: WwColors.surfaceHigh,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WwRadius.sheet),
              ),
              title: Text(title, style: WwType.selectionTitle),
              content: TextField(
                controller: controller,
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
                onChanged: (_) => setDialogState(() {}),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, WwSpace.minTarget),
                  ),
                  child: const Text('Cancel', style: WwType.buttonLabel),
                ),
                TextButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(dialogContext).pop(controller.text)
                      : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, WwSpace.minTarget),
                  ),
                  child: Text(
                    actionLabel,
                    style: canSubmit
                        ? WwType.dialogActionLabel
                        : WwType.dialogActionLabelDisabled,
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
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
      height: WwSpace.topBarHeight,
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
      ],
    );
  }

  Widget _profileRow(
    String id, {
    required bool isActive,
    required bool canDelete,
  }) {
    final name = _data.profileName(id);
    final profile = _data.profiles[id];
    final highlights = profile?.highlights.length ?? 0;
    final notes = profile?.notes.length ?? 0;
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
        style: isActive
            ? WwType.avatarLetterOnGold
            : WwType.avatarLetterOnDark,
      ),
    );
  }
}
