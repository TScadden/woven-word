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
/// `{"version":1,"profiles":{"default":{"highlights":{...},
/// "notes":{...}}}}`. Profile-ready by design: run 5 adds profiles
/// and a My Notes surface on top of this shape without a rewrite.
class UserData {
  UserData({Map<String, ProfileData>? profiles})
    : profiles = profiles ?? <String, ProfileData>{};

  static const String defaultProfileId = 'default';
  static const int version = 1;

  final Map<String, ProfileData> profiles;

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
    'profiles': {
      for (final entry in profiles.entries) entry.key: entry.value.toJson(),
    },
  };

  /// Defensive parse: wrong shapes anywhere in the document are
  /// dropped, never thrown — a corrupt document loads as whatever
  /// valid subset exists (empty if none).
  factory UserData.fromJson(Map<String, dynamic> json) {
    final data = UserData();
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

/// Persists a [UserData] model to SharedPreferences under the single
/// key `ww_user_data`, as its JSON string. On-device only, no network.
class UserDataStore {
  UserDataStore._(this._prefs, this.data);

  static const String storageKey = 'ww_user_data';

  final SharedPreferences _prefs;

  /// The live model. Mutate it through its API, then call [save].
  final UserData data;

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
}
