import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Canonical, translation-independent key for one verse:
/// `b{bookIndex}c{chapterInBook}v{verse}` (e.g. Psalm 23:1, book
/// index 18, is `b18c23v1`). Highlights and notes are keyed by this
/// string, so they survive translation switches and app restarts and
/// stay scoped to a profile, never to a translation.
String verseKey(int bookIndex, int chapterInBook, int verse) =>
    'b${bookIndex}c${chapterInBook}v$verse';

/// Parses a [verseKey] back into (bookIndex, chapterInBook, verse).
/// Returns null on any malformed input.
(int, int, int)? parseVerseKey(String key) {
  final match = RegExp(r'^b(\d+)c(\d+)v(\d+)$').firstMatch(key);
  if (match == null) return null;
  final book = int.tryParse(match.group(1)!);
  final chapter = int.tryParse(match.group(2)!);
  final verse = int.tryParse(match.group(3)!);
  if (book == null || chapter == null || verse == null) return null;
  return (book, chapter, verse);
}

/// The highlight palette. Each value carries a stable string [key]
/// used in the persisted JSON; the rendered tint lives in the theme
/// (WwColors.hl*), mapped at the rendering site.
enum HlColor {
  gold('gold'),
  green('green'),
  blue('blue'),
  pink('pink'),
  purple('purple');

  const HlColor(this.key);

  final String key;
}

/// Resolves a persisted color [key] to an [HlColor]; null on an
/// unknown or null key (defensive load drops those entries).
HlColor? hlColorFromKey(String? key) {
  if (key == null) return null;
  for (final color in HlColor.values) {
    if (color.key == key) return color;
  }
  return null;
}

/// One profile's user data: highlights (verse key -> color key) and
/// notes (verse key -> plain note text). Highlights and notes are
/// fully independent: clearing one never touches the other.
class ProfileData {
  ProfileData({Map<String, String>? highlights, Map<String, String>? notes})
    : highlights = highlights ?? <String, String>{},
      notes = notes ?? <String, String>{};

  final Map<String, String> highlights;
  final Map<String, String> notes;

  Map<String, dynamic> toJson() => {
    'highlights': Map<String, String>.from(highlights),
    'notes': Map<String, String>.from(notes),
  };

  /// Defensive parse: a non-map shape yields an empty profile;
  /// non-string values, unknown color keys, and notes that are empty
  /// after trimming are dropped, never thrown.
  factory ProfileData.fromJson(Object? json) {
    final profile = ProfileData();
    if (json is! Map) return profile;
    final highlights = json['highlights'];
    if (highlights is Map) {
      for (final entry in highlights.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! String) continue;
        final color = hlColorFromKey(value);
        if (color == null) continue;
        profile.highlights[key] = color.key;
      }
    }
    final notes = json['notes'];
    if (notes is Map) {
      for (final entry in notes.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! String) continue;
        if (value.trim().isEmpty) continue;
        profile.notes[key] = value;
      }
    }
    return profile;
  }
}

/// All profiles' user data, persisted as one JSON document:
/// `{"version":2,"activeProfileId":"default",
/// "names":{"default":"My Profile"},"seq":0,
/// "profiles":{"default":{"highlights":{...},"notes":{...}}}}`.
/// Version 1 documents (board run 4: profiles only) load with the
/// default profile active and unnamed — their data carries over
/// untouched.
class UserData {
  UserData({Map<String, ProfileData>? profiles})
    : profiles = profiles ?? <String, ProfileData>{};

  static const String defaultProfileId = 'default';
  static const int version = 2;

  /// Display name of the built-in profile until it is renamed.
  static const String defaultProfileName = 'My Profile';

  final Map<String, ProfileData> profiles;

  /// Explicit display names by profile id. Ids without an entry use
  /// a fallback (see [profileName]); fallbacks are never persisted.
  final Map<String, String> profileNames = <String, String>{};

  String? _activeProfileId;
  int _profileSeq = 0;

  /// Every profile id, in creation order. A store with no profiles
  /// at all still reports the built-in default profile — at least
  /// one profile always exists.
  List<String> get profileIds {
    final ids = <String>[
      ...profiles.keys,
      for (final id in profileNames.keys)
        if (!profiles.containsKey(id)) id,
    ];
    return ids.isEmpty ? const [defaultProfileId] : ids;
  }

  bool hasProfile(String profileId) => profileIds.contains(profileId);

  /// The active profile: the stored choice when it still names a
  /// real profile, else the default profile when it exists, else
  /// the first profile. Always a member of [profileIds].
  String get activeProfileId {
    final ids = profileIds;
    final stored = _activeProfileId;
    if (stored != null && ids.contains(stored)) return stored;
    if (ids.contains(defaultProfileId)) return defaultProfileId;
    return ids.first;
  }

  /// Makes [profileId] the active profile. Unknown ids are ignored.
  void setActiveProfile(String profileId) {
    if (!hasProfile(profileId)) return;
    _activeProfileId = profileId;
  }

  /// The display name of a profile: its explicit name, else the
  /// built-in name for the default profile, else a generic label.
  String profileName(String profileId) {
    final name = profileNames[profileId];
    if (name != null) return name;
    return profileId == defaultProfileId ? defaultProfileName : 'Profile';
  }

  static String _normalizedName(String name, String fallback) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  /// Creates a profile with a fresh id and makes it active.
  /// Returns the new profile's id. Creating the first profile also
  /// materializes the built-in default profile, so the profile list
  /// always shows real entries.
  String createProfile(String name) {
    if (profiles.isEmpty && profileNames.isEmpty) {
      _bucketForWrite(defaultProfileId);
    }
    String id;
    do {
      _profileSeq++;
      id = 'p$_profileSeq';
    } while (hasProfile(id));
    _bucketForWrite(id);
    profileNames[id] = _normalizedName(name, 'New profile');
    _activeProfileId = id;
    return id;
  }

  /// Renames a profile (the default profile included — its id never
  /// changes, only its display name). Unknown ids and names that are
  /// empty after trimming are ignored.
  void renameProfile(String profileId, String name) {
    if (!hasProfile(profileId)) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    profileNames[profileId] = trimmed;
  }

  /// Deletes a profile together with ALL of its highlights and
  /// notes. Deleting the active profile falls back to a remaining
  /// one (the default when it exists). The last remaining profile
  /// can never be deleted; unknown ids are ignored.
  void deleteProfile(String profileId) {
    final ids = profileIds;
    if (!ids.contains(profileId) || ids.length <= 1) return;
    final wasActive = activeProfileId == profileId;
    profiles.remove(profileId);
    profileNames.remove(profileId);
    if (wasActive || _activeProfileId == profileId) {
      _activeProfileId = null;
    }
  }

  /// One profile's notes in canonical order — book index, then
  /// chapter, then verse (numeric, never string order) — each entry
  /// carrying its parsed position. Notes whose key does not parse
  /// are dropped (defensive; our own writes always parse).
  List<({String key, int book, int chapter, int verse, String text})>
  notesFor(String profileId) {
    final profile = profiles[profileId];
    if (profile == null) return const [];
    final entries =
        <({String key, int book, int chapter, int verse, String text})>[];
    for (final entry in profile.notes.entries) {
      final parsed = parseVerseKey(entry.key);
      if (parsed == null) continue;
      entries.add((
        key: entry.key,
        book: parsed.$1,
        chapter: parsed.$2,
        verse: parsed.$3,
        text: entry.value,
      ));
    }
    entries.sort((a, b) {
      final byBook = a.book.compareTo(b.book);
      if (byBook != 0) return byBook;
      final byChapter = a.chapter.compareTo(b.chapter);
      if (byChapter != 0) return byChapter;
      return a.verse.compareTo(b.verse);
    });
    return entries;
  }

  /// Total highlights across ALL profiles (backup counts, board
  /// run 6): the sum over every profile bucket in the document.
  int get totalHighlights =>
      profiles.values.fold(0, (sum, p) => sum + p.highlights.length);

  /// Total notes across ALL profiles (backup counts, board run 6).
  int get totalNotes =>
      profiles.values.fold(0, (sum, p) => sum + p.notes.length);

  /// This document as a pretty-printed JSON string — the backup
  /// file's contents (board run 6). Exactly the [toJson] shape.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  ProfileData _bucketForWrite(String profileId) =>
      profiles.putIfAbsent(profileId, () => ProfileData());

  /// The highlight on [key] under [profileId]; null when the profile
  /// or the highlight does not exist.
  HlColor? highlight(String profileId, String key) {
    final profile = profiles[profileId];
    if (profile == null) return null;
    return hlColorFromKey(profile.highlights[key]);
  }

  /// Sets the highlight on [key] under [profileId]; a null [color]
  /// clears it. A non-null write creates the profile bucket.
  void setHighlight(String profileId, String key, HlColor? color) {
    if (color == null) {
      profiles[profileId]?.highlights.remove(key);
      return;
    }
    _bucketForWrite(profileId).highlights[key] = color.key;
  }

  /// The note on [key] under [profileId]; null when the profile or
  /// the note does not exist.
  String? note(String profileId, String key) => profiles[profileId]?.notes[key];

  /// Sets the note on [key] under [profileId]. Text that is empty
  /// after trimming clears the note. A non-empty write creates the
  /// profile bucket.
  void setNote(String profileId, String key, String text) {
    if (text.trim().isEmpty) {
      profiles[profileId]?.notes.remove(key);
      return;
    }
    _bucketForWrite(profileId).notes[key] = text;
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'activeProfileId': activeProfileId,
    'names': Map<String, String>.from(profileNames),
    'seq': _profileSeq,
    'profiles': {
      for (final entry in profiles.entries) entry.key: entry.value.toJson(),
    },
  };

  /// Defensive parse: wrong shapes anywhere in the document are
  /// dropped, never thrown — a corrupt document loads as whatever
  /// valid subset exists (empty if none). Version 1 documents have
  /// no names/active/seq keys and load with defaults for all three.
  factory UserData.fromJson(Map<String, dynamic> json) {
    final data = UserData();
    final rawNames = json['names'];
    if (rawNames is Map) {
      for (final entry in rawNames.entries) {
        final id = entry.key;
        final name = entry.value;
        if (id is! String || name is! String) continue;
        if (name.trim().isEmpty) continue;
        data.profileNames[id] = name;
      }
    }
    final rawActive = json['activeProfileId'];
    if (rawActive is String) data._activeProfileId = rawActive;
    final rawSeq = json['seq'];
    if (rawSeq is num) data._profileSeq = rawSeq.toInt();
    final rawProfiles = json['profiles'];
    if (rawProfiles is! Map) return data;
    for (final entry in rawProfiles.entries) {
      final id = entry.key;
      if (id is! String) continue;
      data.profiles[id] = ProfileData.fromJson(entry.value);
    }
    return data;
  }
}

/// Why a candidate backup document was rejected (board run 6,
/// Petra spec §2.7). Each class maps to one specific reason
/// sentence in the import error dialog.
enum BackupImportError {
  /// The file's bytes do not decode as JSON at all.
  notJson,

  /// Valid JSON, but not a Woven Word backup document: a
  /// non-object root, a missing or non-object `profiles` member,
  /// a profile bucket that is not an object, or a non-numeric
  /// `version`.
  notBackup,

  /// A backup document whose numeric `version` is newer than
  /// this build's [UserData.version].
  newerVersion,

  /// A backup-shaped document that parses to zero profile
  /// buckets, zero highlights, and zero notes.
  emptyDocument,
}

/// The outcome of validating a candidate backup document: either
/// the parsed [UserData] that would be installed, or the
/// [BackupImportError] that rejected it. Validation is pure — it
/// never writes anything.
class BackupImportResult {
  const BackupImportResult.valid(this.data) : error = null;
  const BackupImportResult.invalid(this.error) : data = null;

  final UserData? data;
  final BackupImportError? error;

  bool get isValid => error == null;
}

/// Persists a [UserData] model to SharedPreferences under the single
/// key `ww_user_data`, as its JSON string. On-device only, no network.
class UserDataStore {
  UserDataStore._(this._prefs, this.data);

  static const String storageKey = 'ww_user_data';

  final SharedPreferences _prefs;

  /// The live model. Mutate it through its API, then call [save];
  /// import replaces it wholesale through [replaceData].
  UserData data;

  /// The live model's backup document (see [UserData.exportJson]).
  String exportJson() => data.exportJson();

  /// Validates [source] as a backup document (board run 6, Petra
  /// spec §2.7). Acceptance by [UserData.fromJson] alone is NOT
  /// validation — that parser is defensive and silently drops
  /// malformed entries — so the document's shape is checked first:
  /// undecodable JSON, a non-object root, a missing/non-object
  /// `profiles` member, a non-object profile bucket, and a
  /// non-numeric `version` are all rejected as not-a-backup; a
  /// numeric version newer than [UserData.version] is rejected as
  /// newerVersion; a document that then parses to zero profile
  /// buckets AND zero highlights AND zero notes (bucket count from
  /// the parsed model's raw profiles map) is rejected as
  /// emptyDocument.
  static BackupImportResult validateImport(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return const BackupImportResult.invalid(BackupImportError.notJson);
    }
    if (decoded is! Map<String, dynamic>) {
      return const BackupImportResult.invalid(BackupImportError.notBackup);
    }
    final rawProfiles = decoded['profiles'];
    if (rawProfiles is! Map) {
      return const BackupImportResult.invalid(BackupImportError.notBackup);
    }
    for (final bucket in rawProfiles.values) {
      if (bucket is! Map) {
        return const BackupImportResult.invalid(BackupImportError.notBackup);
      }
    }
    final rawVersion = decoded['version'];
    if (rawVersion != null && rawVersion is! num) {
      return const BackupImportResult.invalid(BackupImportError.notBackup);
    }
    if (rawVersion is num && rawVersion > UserData.version) {
      return const BackupImportResult.invalid(
        BackupImportError.newerVersion,
      );
    }
    final parsed = UserData.fromJson(decoded);
    if (parsed.profiles.isEmpty &&
        parsed.totalHighlights == 0 &&
        parsed.totalNotes == 0) {
      return const BackupImportResult.invalid(
        BackupImportError.emptyDocument,
      );
    }
    return BackupImportResult.valid(parsed);
  }

  /// Loads the stored model; a missing or corrupt document loads as
  /// an empty model, never a throw.
  static Future<UserDataStore> load(SharedPreferences prefs) async {
    var data = UserData();
    try {
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = UserData.fromJson(decoded);
        }
      }
    } catch (_) {
      data = UserData();
    }
    return UserDataStore._(prefs, data);
  }

  /// Writes the model's JSON string to SharedPreferences.
  Future<void> save() async {
    await _prefs.setString(storageKey, jsonEncode(data.toJson()));
  }

  /// Replaces the live model with [replacement] wholesale and
  /// persists it (backup import, board run 6). The returned future
  /// completes only after the save has completed, so success
  /// feedback shown after it is a true receipt.
  Future<void> replaceData(UserData replacement) async {
    data = replacement;
    await save();
  }
}
