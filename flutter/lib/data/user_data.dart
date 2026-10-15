import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Canonical, translation-independent key for one verse:
/// `b{bookIndex}c{chapterInBook}v{verse}` (e.g. Psalm 23:1, book
/// index 18, is `b18c23v1`). Notes and highlight spans are keyed by
/// this string inside a per-translation set (board run 10, founder
/// ruling 2026-10-15: highlights and notes belong to the translation
/// they were made in), scoped to a profile, never to a tradition —
/// tradition only ever gates visibility (canon dormancy), never
/// storage.
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

/// The shared_preferences key holding the reader's translation
/// choice (board run 10: the constant lives in the data layer so
/// the store's legacy migration and the reader read one source of
/// truth; `ReaderScreen.translationKey` aliases it).
const String translationPrefsKey = 'ww_translation';

/// The per-translation set key for a stored translation
/// preference value (a `WwTranslation.label`: 'KJV', 'WEB', 'JPS',
/// 'Hebrew', 'WEBC'). Set keys are `WwTranslation.name` values
/// (`kjv`, `web`, `jps`, `hebrew`, `webc`); anything unrecognized
/// resolves to `kjv`, the same default the reader applies.
String translationKeyForLabel(String? label) => switch (label) {
  'WEB' => 'web',
  'JPS' => 'jps',
  'Hebrew' => 'hebrew',
  'WEBC' => 'webc',
  _ => 'kjv',
};

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

/// One highlighted span of one verse, in one translation (board
/// run 10). Offsets are character offsets into that translation's
/// verse text; because a span only ever renders against the
/// translation it was made in, the offsets are sound by
/// construction — no anchoring, no cross-translation mapping
/// (founder ruling, 2026-10-15). [end] == -1 means "to the end of
/// the verse" (a full-verse span, resolved at render). [anchor] is
/// the text the user selected, kept as provenance; migrated spans
/// (whose store held no text) carry an empty anchor.
class HighlightSpan {
  const HighlightSpan({
    required this.verseKey,
    required this.start,
    required this.end,
    required this.anchor,
    required this.color,
  });

  final String verseKey;
  final int start;
  final int end;
  final String anchor;
  final HlColor color;

  /// A full-verse span: starts at 0 and runs to the verse's end.
  bool get isFullVerse => start == 0 && end == -1;

  HighlightSpan copyWith({int? start, int? end, String? anchor}) =>
      HighlightSpan(
        verseKey: verseKey,
        start: start ?? this.start,
        end: end ?? this.end,
        anchor: anchor ?? this.anchor,
        color: color,
      );

  Map<String, dynamic> toJson() => {
    'v': verseKey,
    's': start,
    'e': end,
    'a': anchor,
    'c': color.key,
  };

  /// Defensive parse: any malformed field drops the span (null),
  /// never throws. Bounds bind on both sides (lesson 18).
  static HighlightSpan? fromJson(Object? json) {
    if (json is! Map) return null;
    final v = json['v'];
    final s = json['s'];
    final e = json['e'];
    final a = json['a'];
    final c = json['c'];
    if (v is! String || parseVerseKey(v) == null) return null;
    if (s is! num || e is! num) return null;
    final start = s.toInt();
    final end = e.toInt();
    if (start < 0) return null;
    if (end != -1 && end <= start) return null;
    if (a is! String) return null;
    final color = hlColorFromKey(c is String ? c : null);
    if (color == null) return null;
    return HighlightSpan(
      verseKey: v,
      start: start,
      end: end,
      anchor: a,
      color: color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HighlightSpan &&
      other.verseKey == verseKey &&
      other.start == start &&
      other.end == end &&
      other.anchor == anchor &&
      other.color == color;

  @override
  int get hashCode => Object.hash(verseKey, start, end, anchor, color);

  @override
  String toString() =>
      'HighlightSpan($verseKey $start..$end ${color.key} "$anchor")';
}

/// The arithmetic ceiling for a span end of -1 ("to the end of the
/// verse") during subtraction: larger than any real verse text.
const int _endInfinity = 1 << 30;

/// Subtracts `[cutStart, cutEnd)` from [spans] (all of one verse),
/// trimming or splitting overlapped spans with pure offset
/// arithmetic. [verseText], when the caller has it, is the ground
/// truth for the surviving pieces' anchor text; without it, a
/// piece's anchor is sliced from its source span's anchor when the
/// lengths agree, else empty — offsets are the truth either way,
/// the anchor is provenance.
List<HighlightSpan> _subtractRange(
  List<HighlightSpan> spans,
  int cutStart,
  int cutEnd, {
  String? verseText,
}) {
  final cutEndAbs = cutEnd == -1 ? _endInfinity : cutEnd;
  final out = <HighlightSpan>[];
  for (final span in spans) {
    final spanEndAbs = span.end == -1 ? _endInfinity : span.end;
    if (spanEndAbs <= cutStart || span.start >= cutEndAbs) {
      out.add(span);
      continue;
    }
    HighlightSpan piece(int from, int toAbs) {
      final to = toAbs >= _endInfinity ? -1 : toAbs;
      String anchor;
      if (verseText != null) {
        final hi = to == -1 ? verseText.length : to;
        anchor = (from >= 0 && hi >= from && hi <= verseText.length)
            ? verseText.substring(from, hi)
            : '';
      } else if (span.end != -1 &&
          span.anchor.length == span.end - span.start &&
          to != -1) {
        anchor = span.anchor.substring(from - span.start, to - span.start);
      } else {
        anchor = '';
      }
      return span.copyWith(start: from, end: to, anchor: anchor);
    }

    if (span.start < cutStart) out.add(piece(span.start, cutStart));
    if (spanEndAbs > cutEndAbs) out.add(piece(cutEndAbs, spanEndAbs));
  }
  return out;
}

/// Sorts [spans] by start and merges adjacent spans of one color
/// (end == next start), so coverage reads as the user made it:
/// two same-color halves of one verse become one span.
List<HighlightSpan> _normalizeSpans(List<HighlightSpan> spans) {
  if (spans.length < 2) return spans;
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final out = <HighlightSpan>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final prev = out.last;
    final next = sorted[i];
    if (prev.color == next.color && prev.end != -1 && prev.end == next.start) {
      final anchor =
          (prev.anchor.length == prev.end - prev.start &&
              (next.end == -1 ||
                  next.anchor.length == next.end - next.start))
          ? prev.anchor + next.anchor
          : '';
      out[out.length - 1] = HighlightSpan(
        verseKey: prev.verseKey,
        start: prev.start,
        end: next.end,
        anchor: anchor,
        color: prev.color,
      );
    } else {
      out.add(next);
    }
  }
  return out;
}

/// One profile's user data, per translation (board run 10):
/// highlight spans (translation key -> spans) and notes
/// (translation key -> verse key -> note text). Highlights and
/// notes are fully independent: clearing one never touches the
/// other.
class ProfileData {
  ProfileData({
    Map<String, List<HighlightSpan>>? spans,
    Map<String, Map<String, String>>? notes,
    this.readerArchExpanded = true,
  }) : spans = spans ?? <String, List<HighlightSpan>>{},
       notes = notes ?? <String, Map<String, String>>{};

  final Map<String, List<HighlightSpan>> spans;
  final Map<String, Map<String, String>> notes;

  /// Whether the reader's connection arch panel is expanded
  /// for this profile (reader arch package, founder request
  /// Oct 15, 2026: "remember what they last did (minimize or
  /// expand) so it's like a saved profile setting"). Defaults
  /// to expanded — the recorded first-run call (spec I-4).
  /// Persisted as the bucket's `readerArchExpanded` member; a
  /// document without the member (every pre-package backup)
  /// loads expanded.
  bool readerArchExpanded;

  /// Span count across every translation set.
  int get spanCount =>
      spans.values.fold(0, (sum, list) => sum + list.length);

  /// Note count across every translation set.
  int get noteCount =>
      notes.values.fold(0, (sum, byKey) => sum + byKey.length);

  Map<String, dynamic> toJson() => {
    'spans': {
      for (final entry in spans.entries)
        entry.key: [for (final span in entry.value) span.toJson()],
    },
    'notes': {
      for (final entry in notes.entries)
        entry.key: Map<String, String>.from(entry.value),
    },
    'readerArchExpanded': readerArchExpanded,
  };

  /// Defensive parse: wrong shapes are dropped, never thrown.
  /// A version < 3 bucket carries profile-level `highlights`
  /// (verse key -> color key) and flat `notes` (verse key ->
  /// text) with no translation recorded; those migrate into the
  /// [legacyTranslation] set — whole-verse highlights as
  /// full-verse spans — with no duplication into other sets
  /// (founder ruling, 2026-10-15).
  factory ProfileData.fromJson(Object? json, {String legacyTranslation = 'kjv'}) {
    final profile = ProfileData();
    if (json is! Map) return profile;
    // The reader arch setting (reader arch package): only a
    // bool is honored; an absent member (every pre-package
    // document) or a malformed one leaves the expanded
    // default. Import-time shape strictness lives in the
    // validator, not here (lesson 22).
    final rawArch = json['readerArchExpanded'];
    if (rawArch is bool) profile.readerArchExpanded = rawArch;
    final rawSpans = json['spans'];
    if (rawSpans is Map) {
      for (final entry in rawSpans.entries) {
        final t = entry.key;
        final list = entry.value;
        if (t is! String || list is! List) continue;
        final parsed = <HighlightSpan>[];
        for (final item in list) {
          final span = HighlightSpan.fromJson(item);
          if (span != null) parsed.add(span);
        }
        // Stored spans are normalized by construction; a foreign
        // document's are normalized on the way in, per verse.
        final byVerse = <String, List<HighlightSpan>>{};
        for (final span in parsed) {
          byVerse.putIfAbsent(span.verseKey, () => []).add(span);
        }
        final normalized = <HighlightSpan>[];
        for (final verseSpans in byVerse.values) {
          var acc = <HighlightSpan>[];
          for (final span in verseSpans) {
            acc = _normalizeSpans([
              ..._subtractRange(acc, span.start, span.end),
              span,
            ]);
          }
          normalized.addAll(acc);
        }
        if (normalized.isNotEmpty) profile.spans[t] = normalized;
      }
    } else {
      final legacy = json['highlights'];
      if (legacy is Map) {
        final migrated = <HighlightSpan>[];
        for (final entry in legacy.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || value is! String) continue;
          if (parseVerseKey(key) == null) continue;
          final color = hlColorFromKey(value);
          if (color == null) continue;
          migrated.add(
            HighlightSpan(
              verseKey: key,
              start: 0,
              end: -1,
              anchor: '',
              color: color,
            ),
          );
        }
        if (migrated.isNotEmpty) {
          migrated.sort((a, b) => a.verseKey.compareTo(b.verseKey));
          profile.spans[legacyTranslation] = migrated;
        }
      }
    }
    final rawNotes = json['notes'];
    if (rawNotes is Map) {
      // Version 3 shape: translation key -> (verse key -> text).
      // Legacy shape: verse key -> text directly (every value a
      // string). The value types decide, per bucket.
      final isV3Shape = rawNotes.values.any((v) => v is Map);
      if (isV3Shape) {
        for (final entry in rawNotes.entries) {
          final t = entry.key;
          final map = entry.value;
          if (t is! String || map is! Map) continue;
          final parsed = <String, String>{};
          for (final note in map.entries) {
            final key = note.key;
            final value = note.value;
            if (key is! String || value is! String) continue;
            if (value.trim().isEmpty) continue;
            parsed[key] = value;
          }
          if (parsed.isNotEmpty) profile.notes[t] = parsed;
        }
      } else {
        final parsed = <String, String>{};
        for (final entry in rawNotes.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is! String || value is! String) continue;
          if (value.trim().isEmpty) continue;
          parsed[key] = value;
        }
        if (parsed.isNotEmpty) profile.notes[legacyTranslation] = parsed;
      }
    }
    return profile;
  }
}

/// All profiles' user data, persisted as one JSON document:
/// `{"version":3,"activeProfileId":"default",
/// "names":{"default":"My Profile"},"seq":0,
/// "profiles":{"default":{"spans":{...},"notes":{...}}}}`.
/// Version 1 and 2 documents load through the same parse with the
/// migration of [ProfileData.fromJson] applied — their data
/// carries over, assigned to one translation, never duplicated.
class UserData {
  UserData({Map<String, ProfileData>? profiles})
    : profiles = profiles ?? <String, ProfileData>{};

  static const String defaultProfileId = 'default';
  static const int version = 3;

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
  /// notes, in every translation. Deleting the active profile falls
  /// back to a remaining one (the default when it exists). The last
  /// remaining profile can never be deleted; unknown ids are ignored.
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

  /// One profile's notes in ONE translation, in canonical order —
  /// book index, then chapter, then verse (numeric, never string
  /// order) — each entry carrying its parsed position. Notes whose
  /// key does not parse are dropped (defensive; our own writes
  /// always parse).
  List<({String key, int book, int chapter, int verse, String text})>
  notesFor(String profileId, String translationKey) {
    final profile = profiles[profileId];
    if (profile == null) return const [];
    final notes = profile.notes[translationKey];
    if (notes == null) return const [];
    final entries =
        <({String key, int book, int chapter, int verse, String text})>[];
    for (final entry in notes.entries) {
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

  /// Every note a profile holds, across all translations (the
  /// dormancy-aware empty state: a profile can hold notes that the
  /// current translation/canon does not show).
  int noteCountFor(String profileId) {
    final profile = profiles[profileId];
    if (profile == null) return 0;
    return profile.notes.values.fold(0, (sum, m) => sum + m.length);
  }

  /// Total highlight spans across ALL profiles and ALL
  /// translations (backup counts, board run 6/10): the sum over
  /// every profile bucket in the document. Dormancy and
  /// translation scoping are view rules; storage totals never
  /// filter.
  int get totalSpans => profiles.values.fold(
    0,
    (sum, p) => sum + p.spans.values.fold(0, (s, l) => s + l.length),
  );

  /// Total notes across ALL profiles and ALL translations
  /// (backup counts, board run 6).
  int get totalNotes => profiles.values.fold(
    0,
    (sum, p) => sum + p.notes.values.fold(0, (s, m) => s + m.length),
  );

  /// This document as a pretty-printed JSON string — the backup
  /// file's contents (board run 6). Exactly the [toJson] shape.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  ProfileData _bucketForWrite(String profileId) =>
      profiles.putIfAbsent(profileId, () => ProfileData());

  // ------------------------------------------------------------- spans

  /// The spans on [key] in [translationKey]'s set under
  /// [profileId], sorted by start, non-overlapping by construction.
  List<HighlightSpan> spansFor(
    String profileId,
    String translationKey,
    String key,
  ) {
    final profile = profiles[profileId];
    if (profile == null) return const [];
    final list = profile.spans[translationKey];
    if (list == null) return const [];
    return [for (final span in list) if (span.verseKey == key) span];
  }

  /// The color of the verse's full-verse span in [translationKey]'s
  /// set, or null. By the non-overlap invariant such a span is the
  /// verse's only span.
  HlColor? fullVerseColor(
    String profileId,
    String translationKey,
    String key,
  ) {
    for (final span in spansFor(profileId, translationKey, key)) {
      if (span.isFullVerse) return span.color;
    }
    return null;
  }

  /// Applies [span] to its verse in [translationKey]'s set: the
  /// span's range is first subtracted from the verse's existing
  /// spans (trim/split), then the span is inserted and coverage
  /// normalized — spans within a verse never overlap. [verseText],
  /// when the caller has it, grounds the trimmed pieces' anchors.
  void applySpan(
    String profileId,
    String translationKey,
    HighlightSpan span, {
    String? verseText,
  }) {
    final profile = _bucketForWrite(profileId);
    final existing = [
      for (final s in profile.spans[translationKey] ?? const <HighlightSpan>[])
        if (s.verseKey == span.verseKey) s,
    ];
    final others = [
      for (final s in profile.spans[translationKey] ?? const <HighlightSpan>[])
        if (s.verseKey != span.verseKey) s,
    ];
    final subtracted = _subtractRange(
      existing,
      span.start,
      span.end,
      verseText: verseText,
    );
    final merged = _normalizeSpans([...subtracted, span]);
    final all = [...others, ...merged];
    if (all.isEmpty) {
      profile.spans.remove(translationKey);
    } else {
      profile.spans[translationKey] = all;
    }
  }

  /// Clears coverage over `[start, end)` on [key] in
  /// [translationKey]'s set (the selection bar's Clear). `end` of
  /// -1 clears to the verse's end.
  void clearSpanRange(
    String profileId,
    String translationKey,
    String key,
    int start,
    int end, {
    String? verseText,
  }) {
    final profile = profiles[profileId];
    if (profile == null) return;
    final list = profile.spans[translationKey];
    if (list == null) return;
    final existing = [for (final s in list) if (s.verseKey == key) s];
    if (existing.isEmpty) return;
    final remaining = _subtractRange(existing, start, end, verseText: verseText);
    final all = [
      for (final s in list)
        if (s.verseKey != key) s,
      ...remaining,
    ];
    if (all.isEmpty) {
      profile.spans.remove(translationKey);
    } else {
      profile.spans[translationKey] = all;
    }
  }

  /// Clears every span on [key] in [translationKey]'s set (the
  /// verse toolbar's None).
  void clearVerseSpans(String profileId, String translationKey, String key) {
    final profile = profiles[profileId];
    if (profile == null) return;
    final list = profile.spans[translationKey];
    if (list == null) return;
    final all = [for (final s in list) if (s.verseKey != key) s];
    if (all.isEmpty) {
      profile.spans.remove(translationKey);
    } else {
      profile.spans[translationKey] = all;
    }
  }

  // ------------------------------------------------------------- notes

  /// The note on [key] in [translationKey]'s set under
  /// [profileId]; null when the profile, set, or note does not
  /// exist.
  String? note(String profileId, String translationKey, String key) =>
      profiles[profileId]?.notes[translationKey]?[key];

  /// Sets the note on [key] in [translationKey]'s set under
  /// [profileId]. Text that is empty after trimming clears the
  /// note. A non-empty write creates the profile bucket.
  void setNote(
    String profileId,
    String translationKey,
    String key,
    String text,
  ) {
    if (text.trim().isEmpty) {
      profiles[profileId]?.notes[translationKey]?.remove(key);
      return;
    }
    final profile = _bucketForWrite(profileId);
    profile.notes.putIfAbsent(translationKey, () => <String, String>{})[key] =
        text;
  }

  // ------------------------------------------------- profile settings

  /// Whether the reader's connection arch panel is expanded
  /// under [profileId] (reader arch package). A profile that
  /// does not exist resolves to the first-run default,
  /// expanded — read paths never create buckets.
  bool readerArchExpandedFor(String profileId) =>
      profiles[profileId]?.readerArchExpanded ?? true;

  /// Remembers the arch panel's expanded/minimized state for
  /// [profileId]. A write materializes the profile bucket,
  /// the same contract as [setNote].
  void setReaderArchExpanded(String profileId, bool expanded) {
    _bucketForWrite(profileId).readerArchExpanded = expanded;
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
  /// valid subset exists (empty if none). Version 1 and 2
  /// documents migrate their translation-less highlights and
  /// notes into the [legacyTranslation] set (a translation set
  /// key, see [translationKeyForLabel]).
  factory UserData.fromJson(
    Map<String, dynamic> json, {
    String legacyTranslation = 'kjv',
  }) {
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
      data.profiles[id] = ProfileData.fromJson(
        entry.value,
        legacyTranslation: legacyTranslation,
      );
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
  /// emptyDocument. A legacy (version < 3) document's highlights
  /// and notes migrate into the [legacyTranslation] set — the
  /// translation active at import (board run 10).
  static BackupImportResult validateImport(
    String source, {
    String legacyTranslation = 'kjv',
  }) {
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
      // Reader arch package: the per-profile arch setting,
      // when present, must be a bool — the same shape-gate
      // discipline as the bucket itself. Absent is valid:
      // pre-package backups import and default to expanded.
      final rawArch = bucket['readerArchExpanded'];
      if (rawArch != null && rawArch is! bool) {
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
    final parsed = UserData.fromJson(
      decoded,
      legacyTranslation: legacyTranslation,
    );
    if (parsed.profiles.isEmpty &&
        parsed.totalSpans == 0 &&
        parsed.totalNotes == 0) {
      return const BackupImportResult.invalid(
        BackupImportError.emptyDocument,
      );
    }
    return BackupImportResult.valid(parsed);
  }

  /// Loads the stored model; a missing or corrupt document loads as
  /// an empty model, never a throw. A legacy document migrates
  /// into the translation the stored preference names — the
  /// translation active at upgrade (board run 10).
  static Future<UserDataStore> load(SharedPreferences prefs) async {
    var data = UserData();
    final legacyTranslation = translationKeyForLabel(
      prefs.getString(translationPrefsKey),
    );
    try {
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = UserData.fromJson(
            decoded,
            legacyTranslation: legacyTranslation,
          );
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
