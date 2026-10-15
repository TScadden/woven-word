import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/user_data.dart';

/// Board run 10 translation of the run 4/6 suites: whole-verse
/// highlights are now full-verse spans in a translation's set.
/// [setFull]/[fullColor] are the old setHighlight/highlight pair,
/// expressed against the kjv set.
void setFull(UserData data, String profile, String key, HlColor? color) {
  if (color == null) {
    data.clearVerseSpans(profile, 'kjv', key);
  } else {
    data.applySpan(
      profile,
      'kjv',
      HighlightSpan(verseKey: key, start: 0, end: -1, anchor: '', color: color),
    );
  }
}

HlColor? fullColor(UserData data, String profile, String key) =>
    data.fullVerseColor(profile, 'kjv', key);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = UserData.defaultProfileId;
  const key = 'b18c23v1';

  group('verseKey / parseVerseKey', () {
    test('format matches the canonical example (Psalm 23:1)', () {
      expect(verseKey(18, 23, 1), 'b18c23v1');
      expect(verseKey(0, 1, 1), 'b0c1v1');
      expect(verseKey(65, 21, 31), 'b65c21v31');
    });

    test('parse round-trips verseKey', () {
      expect(parseVerseKey(verseKey(18, 23, 1)), (18, 23, 1));
      expect(parseVerseKey('b0c1v1'), (0, 1, 1));
      expect(parseVerseKey(verseKey(39, 5, 17)), (39, 5, 17));
    });

    test('parse rejects garbage', () {
      expect(parseVerseKey(''), isNull);
      expect(parseVerseKey('garbage'), isNull);
      expect(parseVerseKey('b18c23'), isNull);
      expect(parseVerseKey('18c23v1'), isNull);
      expect(parseVerseKey('b18c23v1x'), isNull);
      expect(parseVerseKey('b-1c23v1'), isNull);
      expect(parseVerseKey('b18 c23 v1'), isNull);
    });
  });

  group('HlColor keys', () {
    test('stable string keys round-trip', () {
      for (final color in HlColor.values) {
        expect(hlColorFromKey(color.key), color);
      }
      expect(HlColor.gold.key, 'gold');
      expect(HlColor.green.key, 'green');
      expect(HlColor.blue.key, 'blue');
      expect(HlColor.pink.key, 'pink');
      expect(HlColor.purple.key, 'purple');
    });

    test('unknown keys resolve to null', () {
      expect(hlColorFromKey(null), isNull);
      expect(hlColorFromKey(''), isNull);
      expect(hlColorFromKey('orange'), isNull);
      expect(hlColorFromKey('GOLD'), isNull);
    });
  });

  group('highlights', () {
    test('set, re-color, and clear', () {
      final data = UserData();
      expect(fullColor(data, profile, key), isNull);

      setFull(data, profile, key, HlColor.gold);
      expect(fullColor(data, profile, key), HlColor.gold);

      setFull(data, profile, key, HlColor.blue);
      expect(fullColor(data, profile, key), HlColor.blue);

      setFull(data, profile, key, null);
      expect(fullColor(data, profile, key), isNull);
    });

    test('clearing an unknown profile is a no-op read', () {
      final data = UserData();
      setFull(data, 'nobody', key, null);
      expect(fullColor(data, 'nobody', key), isNull);
      expect(fullColor(data, 'nobody', 'b0c1v1'), isNull);
    });

    test('clearing a highlight leaves the note untouched', () {
      final data = UserData();
      setFull(data, profile, key, HlColor.pink);
      data.setNote(profile, 'kjv', key, 'keep me');
      setFull(data, profile, key, null);
      expect(fullColor(data, profile, key), isNull);
      expect(data.note(profile, 'kjv', key), 'keep me');
    });
  });

  group('notes', () {
    test('set, edit, and clear', () {
      final data = UserData();
      expect(data.note(profile, 'kjv', key), isNull);

      data.setNote(profile, 'kjv', key, 'first');
      expect(data.note(profile, 'kjv', key), 'first');

      data.setNote(profile, 'kjv', key, 'edited');
      expect(data.note(profile, 'kjv', key), 'edited');

      data.setNote(profile, 'kjv', key, '');
      expect(data.note(profile, 'kjv', key), isNull);
    });

    test('whitespace-only text clears the note', () {
      final data = UserData();
      data.setNote(profile, 'kjv', key, 'text');
      data.setNote(profile, 'kjv', key, '   \n\t ');
      expect(data.note(profile, 'kjv', key), isNull);
    });

    test('clearing a note leaves the highlight untouched', () {
      final data = UserData();
      setFull(data, profile, key, HlColor.green);
      data.setNote(profile, 'kjv', key, 'gone soon');
      data.setNote(profile, 'kjv', key, '');
      expect(data.note(profile, 'kjv', key), isNull);
      expect(fullColor(data, profile, key), HlColor.green);
    });
  });

  group('profile scoping', () {
    test('two profiles are fully independent', () {
      final data = UserData();
      setFull(data, 'alice', key, HlColor.gold);
      data.setNote('alice', 'kjv', key, 'alice note');
      setFull(data, 'bob', key, HlColor.purple);
      data.setNote('bob', 'kjv', key, 'bob note');

      expect(fullColor(data, 'alice', key), HlColor.gold);
      expect(fullColor(data, 'bob', key), HlColor.purple);
      expect(data.note('alice', 'kjv', key), 'alice note');
      expect(data.note('bob', 'kjv', key), 'bob note');

      setFull(data, 'alice', key, null);
      data.setNote('bob', 'kjv', key, '');
      expect(fullColor(data, 'alice', key), isNull);
      expect(fullColor(data, 'bob', key), HlColor.purple);
      expect(data.note('alice', 'kjv', key), 'alice note');
      expect(data.note('bob', 'kjv', key), isNull);
    });
  });

  group('serialization', () {
    test('round-trip preserves all data', () {
      final data = UserData();
      setFull(data, profile, key, HlColor.gold);
      setFull(data, profile, 'b0c1v1', HlColor.blue);
      data.setNote(profile, 'kjv', key, 'on the highlighted verse');
      data.setNote('other', 'kjv', 'b39c1v1', 'other profile note');

      final restored = UserData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), data.toJson());
      expect(fullColor(restored, profile, key), HlColor.gold);
      expect(restored.note('other', 'kjv', 'b39c1v1'), 'other profile note');
    });

    test('document shape matches the spec', () {
      final data = UserData();
      setFull(data, profile, key, HlColor.green);
      data.setNote(profile, 'kjv', key, 'shape');
      expect(data.toJson(), {
        'version': 3,
        'activeProfileId': 'default',
        'names': <String, String>{},
        'seq': 0,
        'profiles': {
          'default': {
            'spans': {
              'kjv': [
                {'v': key, 's': 0, 'e': -1, 'a': '', 'c': 'green'},
              ],
            },
            'notes': {
              'kjv': {key: 'shape'},
            },
          },
        },
      });
    });

    test('defensive load drops unknown colors and garbage, never throws', () {
      final restored = UserData.fromJson({
        'version': 1,
        'profiles': {
          'default': {
            'highlights': {key: 'orange', 'b0c1v1': 'gold', 'b0c1v2': 42},
            'notes': {key: 'kept', 'b0c1v1': '', 'b0c1v2': 7},
          },
          'broken': 'not a map',
          9: {'highlights': <String, String>{}},
        },
      });
      expect(fullColor(restored, profile, key), isNull);
      expect(fullColor(restored, profile, 'b0c1v1'), HlColor.gold);
      expect(fullColor(restored, profile, 'b0c1v2'), isNull);
      expect(restored.note(profile, 'kjv', key), 'kept');
      expect(restored.note(profile, 'kjv', 'b0c1v1'), isNull);
      expect(restored.note(profile, 'kjv', 'b0c1v2'), isNull);
    });

    test('defensive load tolerates a garbage top-level shape', () {
      expect(UserData.fromJson({}).toJson(), {
        'version': 3,
        'activeProfileId': 'default',
        'names': <String, String>{},
        'seq': 0,
        'profiles': <String, dynamic>{},
      });
      expect(UserData.fromJson({'profiles': 'junk'}).profiles, isEmpty);
      expect(
        UserData.fromJson({
          'profiles': {
            'default': {'highlights': 'junk', 'notes': 12},
          },
        }).profiles[profile]?.spans,
        isEmpty,
      );
    });
  });

  group('profiles', () {
    test('a fresh model has exactly the default profile, active', () {
      final data = UserData();
      expect(data.profileIds, ['default']);
      expect(data.activeProfileId, UserData.defaultProfileId);
      expect(data.profileName('default'), 'My Profile');
      expect(data.hasProfile('default'), isTrue);
      expect(data.hasProfile('nobody'), isFalse);
    });

    test('create adds a named profile and makes it active', () {
      final data = UserData();
      final id = data.createProfile('Family');
      expect(id, isNot('default'));
      expect(data.profileIds, ['default', id]);
      expect(data.profileName(id), 'Family');
      expect(data.activeProfileId, id);
    });

    test('create trims the name and falls back on a blank one', () {
      final data = UserData();
      final spaced = data.createProfile('  Kids  ');
      expect(data.profileName(spaced), 'Kids');
      final blank = data.createProfile('   ');
      expect(data.profileName(blank), 'New profile');
    });

    test('created ids never collide, even after deletes', () {
      final data = UserData();
      final a = data.createProfile('A');
      final b = data.createProfile('B');
      data.deleteProfile(a);
      final c = data.createProfile('C');
      expect({a, b, c}.length, 3);
      expect(data.profileIds, ['default', b, c]);
    });

    test('rename works for created and default profiles alike', () {
      final data = UserData();
      final id = data.createProfile('Old');
      data.renameProfile(id, 'New');
      expect(data.profileName(id), 'New');

      data.renameProfile('default', 'Mine');
      expect(data.profileName('default'), 'Mine');
      expect(data.profileIds, contains('default'));
    });

    test('rename ignores unknown ids and blank names', () {
      final data = UserData();
      final id = data.createProfile('Keep');
      data.renameProfile('ghost', 'Nope');
      data.renameProfile(id, '   ');
      expect(data.profileName(id), 'Keep');
      expect(data.hasProfile('ghost'), isFalse);
    });

    test('switching accepts real profiles and ignores unknown ids', () {
      final data = UserData();
      final id = data.createProfile('Other');
      expect(data.activeProfileId, id);
      data.setActiveProfile('default');
      expect(data.activeProfileId, 'default');
      data.setActiveProfile('ghost');
      expect(data.activeProfileId, 'default');
    });

    test('deleting a non-active profile leaves the active one alone', () {
      final data = UserData();
      final a = data.createProfile('A');
      final b = data.createProfile('B');
      data.setActiveProfile(a);
      data.deleteProfile(b);
      expect(data.profileIds, ['default', a]);
      expect(data.activeProfileId, a);
    });

    test('deleting the active profile falls back to the default', () {
      final data = UserData();
      final a = data.createProfile('A');
      data.createProfile('B');
      data.setActiveProfile(a);
      data.deleteProfile(a);
      expect(data.activeProfileId, 'default');
    });

    test('deleting the active profile falls back to a remaining one '
        'when the default is gone', () {
      final data = UserData();
      final a = data.createProfile('A');
      final b = data.createProfile('B');
      data.deleteProfile('default');
      data.setActiveProfile(b);
      data.deleteProfile(b);
      expect(data.profileIds, [a]);
      expect(data.activeProfileId, a);
    });

    test('the last remaining profile can never be deleted', () {
      final data = UserData();
      data.deleteProfile('default');
      expect(data.profileIds, ['default']);

      final a = data.createProfile('A');
      data.deleteProfile(a);
      data.deleteProfile('default');
      expect(data.profileIds, ['default']);
      expect(data.activeProfileId, 'default');
    });

    test('deleting a profile deletes its highlights and notes', () {
      final data = UserData();
      final a = data.createProfile('A');
      setFull(data, a, key, HlColor.gold);
      data.setNote(a, 'kjv', key, 'doomed');
      data.setNote('default', 'kjv', key, 'safe');
      data.deleteProfile(a);
      expect(fullColor(data, a, key), isNull);
      expect(data.note(a, 'kjv', key), isNull);
      expect(data.note('default', 'kjv', key), 'safe');
    });

    test('active-profile isolation: writes under one profile are '
        'invisible under another', () {
      final data = UserData();
      setFull(data, data.activeProfileId, key, HlColor.gold);
      data.setNote(data.activeProfileId, 'kjv', key, 'default note');

      final other = data.createProfile('Other');
      expect(data.activeProfileId, other);
      expect(fullColor(data, data.activeProfileId, key), isNull);
      expect(data.note(data.activeProfileId, 'kjv', key), isNull);

      data.setNote(data.activeProfileId, 'kjv', key, 'other note');
      data.setActiveProfile('default');
      expect(fullColor(data, data.activeProfileId, key), HlColor.gold);
      expect(data.note(data.activeProfileId, 'kjv', key), 'default note');
      expect(data.note(other, 'kjv', key), 'other note');
    });

    test('a version 1 document keeps the default profile data '
        'untouched', () {
      final restored = UserData.fromJson({
        'version': 1,
        'profiles': {
          'default': {
            'highlights': {key: 'gold'},
            'notes': {key: 'kept from run 4'},
          },
        },
      });
      expect(restored.activeProfileId, 'default');
      expect(restored.profileName('default'), 'My Profile');
      expect(fullColor(restored, 'default', key), HlColor.gold);
      expect(restored.note('default', 'kjv', key), 'kept from run 4');

      final roundTripped = UserData.fromJson(
        jsonDecode(jsonEncode(restored.toJson())) as Map<String, dynamic>,
      );
      expect(fullColor(roundTripped, 'default', key), HlColor.gold);
      expect(roundTripped.note('default', 'kjv', key), 'kept from run 4');
    });

    test('names, active id, and sequence survive a round-trip', () {
      final data = UserData();
      final id = data.createProfile('Family');
      data.renameProfile('default', 'Mine');
      data.setActiveProfile('default');

      final restored = UserData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.profileIds, ['default', id]);
      expect(restored.profileName('default'), 'Mine');
      expect(restored.profileName(id), 'Family');
      expect(restored.activeProfileId, 'default');

      final fresh = restored.createProfile('Fresh');
      expect(fresh, isNot(id));
      expect(restored.profileIds, ['default', id, fresh]);
    });

    test('a stale stored active id resolves to a real profile', () {
      final restored = UserData.fromJson({
        'version': 2,
        'activeProfileId': 'ghost',
        'names': <String, String>{},
        'profiles': {
          'default': {
            'highlights': <String, String>{},
            'notes': <String, String>{},
          },
        },
      });
      expect(restored.activeProfileId, 'default');
    });
  });

  group('notesFor (My Notes)', () {
    test('canonical order: book, then chapter, then verse, numeric', () {
      final data = UserData();
      data.setNote(profile, 'kjv', 'b18c23v10', 'psalm verse ten');
      data.setNote(profile, 'kjv', 'b0c1v2', 'genesis two');
      data.setNote(profile, 'kjv', 'b18c23v2', 'psalm verse two');
      data.setNote(profile, 'kjv', 'b0c2v1', 'genesis chapter two');
      data.setNote(profile, 'kjv', 'b0c1v10', 'genesis ten');

      final notes = data.notesFor(profile, 'kjv');
      expect(notes.map((n) => n.key).toList(), [
        'b0c1v2',
        'b0c1v10',
        'b0c2v1',
        'b18c23v2',
        'b18c23v10',
      ]);
      expect(notes.first.book, 0);
      expect(notes.first.chapter, 1);
      expect(notes.first.verse, 2);
      expect(notes.first.text, 'genesis two');
      expect(notes.last.book, 18);
      expect(notes.last.verse, 10);
    });

    test('scoped to the requested profile', () {
      final data = UserData();
      data.setNote('alice', 'kjv', 'b0c1v1', 'alice only');
      data.setNote('bob', 'kjv', 'b0c1v2', 'bob only');
      expect(data.notesFor('alice', 'kjv').single.text, 'alice only');
      expect(data.notesFor('bob', 'kjv').single.text, 'bob only');
      expect(data.notesFor('nobody', 'kjv'), isEmpty);
    });

    test('an empty profile has an empty list', () {
      final data = UserData();
      expect(data.notesFor(profile, 'kjv'), isEmpty);
    });
  });

  group('UserDataStore', () {
    test('save/load round-trip through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final store = await UserDataStore.load(prefs);
      expect(fullColor(store.data, profile, key), isNull);
      setFull(store.data, profile, key, HlColor.purple);
      store.data.setNote(profile, 'kjv', key, 'persisted');
      await store.save();

      expect(prefs.getString(UserDataStore.storageKey), isNotNull);
      final reloaded = await UserDataStore.load(prefs);
      expect(fullColor(reloaded.data, profile, key), HlColor.purple);
      expect(reloaded.data.note(profile, 'kjv', key), 'persisted');
    });

    test('profiles, names, and active id round-trip through the store',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final store = await UserDataStore.load(prefs);
      final id = store.data.createProfile('Family');
      store.data.setNote(id, 'kjv', key, 'family note');
      store.data.setNote('default', 'kjv', key, 'default note');
      store.data.setActiveProfile('default');
      await store.save();

      final reloaded = await UserDataStore.load(prefs);
      expect(reloaded.data.profileIds, ['default', id]);
      expect(reloaded.data.profileName(id), 'Family');
      expect(reloaded.data.activeProfileId, 'default');
      expect(reloaded.data.note(id, 'kjv', key), 'family note');
      expect(reloaded.data.note('default', 'kjv', key), 'default note');
    });

    test('missing or corrupt stored document loads as empty', () async {
      SharedPreferences.setMockInitialValues({
        UserDataStore.storageKey: '{not json',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      expect(store.data.profiles, isEmpty);

      SharedPreferences.setMockInitialValues({
        UserDataStore.storageKey: '["a","list"]',
      });
      final prefs2 = await SharedPreferences.getInstance();
      final store2 = await UserDataStore.load(prefs2);
      expect(store2.data.profiles, isEmpty);
    });
  });

  // ------------------------------------------------ board run 10

  group('spans (board run 10)', () {
    const text = 'In the beginning God created'; // length 28

    HighlightSpan span(int s, int e, HlColor c, {String a = ''}) =>
        HighlightSpan(verseKey: key, start: s, end: e, anchor: a, color: c);

    List<(int, int, HlColor)> triples(UserData d) => d
        .spansFor(profile, 'kjv', key)
        .map((s) => (s.start, s.end, s.color))
        .toList();

    test('a partial span applies to the exact range and reads back', () {
      final data = UserData();
      data.applySpan(
        profile,
        'kjv',
        span(3, 6, HlColor.gold, a: 'the'),
        verseText: text,
      );
      expect(triples(data), [(3, 6, HlColor.gold)]);
      expect(data.spansFor(profile, 'kjv', key).single.anchor, 'the');
      expect(fullColor(data, profile, key), isNull);
    });

    test('applying over an existing span recolors the intersection '
        'and keeps the tails', () {
      final data = UserData();
      data.applySpan(profile, 'kjv', span(4, 20, HlColor.gold), verseText: text);
      data.applySpan(profile, 'kjv', span(10, 14, HlColor.blue), verseText: text);
      expect(triples(data), [
        (4, 10, HlColor.gold),
        (10, 14, HlColor.blue),
        (14, 20, HlColor.gold),
      ]);
    });

    test('clearing a sub-range splits the span, keeping both tails', () {
      final data = UserData();
      data.applySpan(profile, 'kjv', span(4, 20, HlColor.gold), verseText: text);
      data.clearSpanRange(profile, 'kjv', key, 10, 14, verseText: text);
      expect(triples(data), [(4, 10, HlColor.gold), (14, 20, HlColor.gold)]);
    });

    test('adjacent same-color spans merge into one', () {
      final data = UserData();
      data.applySpan(profile, 'kjv', span(0, 5, HlColor.green), verseText: text);
      data.applySpan(profile, 'kjv', span(5, 9, HlColor.green), verseText: text);
      expect(triples(data), [(0, 9, HlColor.green)]);
    });

    test('a full-verse write replaces every span on the verse', () {
      final data = UserData();
      data.applySpan(profile, 'kjv', span(0, 5, HlColor.green), verseText: text);
      data.applySpan(profile, 'kjv', span(10, 15, HlColor.pink), verseText: text);
      setFull(data, profile, key, HlColor.purple);
      expect(triples(data), [(0, -1, HlColor.purple)]);
      expect(fullColor(data, profile, key), HlColor.purple);
    });

    test('clearVerseSpans removes all spans and leaves the note', () {
      final data = UserData();
      data.applySpan(profile, 'kjv', span(0, 5, HlColor.green), verseText: text);
      data.setNote(profile, 'kjv', key, 'still here');
      data.clearVerseSpans(profile, 'kjv', key);
      expect(data.spansFor(profile, 'kjv', key), isEmpty);
      expect(data.note(profile, 'kjv', key), 'still here');
    });

    test('spans on different verses never interact', () {
      final data = UserData();
      data.applySpan(profile, 'kjv', span(0, 5, HlColor.green), verseText: text);
      data.applySpan(
        profile,
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 0,
          end: 5,
          anchor: '',
          color: HlColor.pink,
        ),
        verseText: text,
      );
      expect(data.spansFor(profile, 'kjv', key).single.color, HlColor.green);
      expect(data.spansFor(profile, 'kjv', 'b0c1v1').single.color, HlColor.pink);
    });

    test('an open-ended span survives serialization open-ended', () {
      final data = UserData();
      setFull(data, profile, key, HlColor.blue);
      final restored = UserData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      final s = restored.spansFor(profile, 'kjv', key).single;
      expect(s.start, 0);
      expect(s.end, -1);
      expect(s.isFullVerse, isTrue);
    });
  });

  group('per-translation sets (board run 10)', () {
    test('a highlight made in KJV is invisible in WEB and intact '
        'on return', () {
      final data = UserData();
      setFull(data, profile, key, HlColor.gold);
      expect(data.spansFor(profile, 'web', key), isEmpty);
      expect(fullColor(data, profile, key), HlColor.gold);
      data.applySpan(
        profile,
        'web',
        HighlightSpan(
          verseKey: key,
          start: 0,
          end: 4,
          anchor: 'word',
          color: HlColor.pink,
        ),
      );
      expect(fullColor(data, profile, key), HlColor.gold);
      expect(data.spansFor(profile, 'web', key).single.color, HlColor.pink);
      expect(data.spansFor(profile, 'kjv', key).single.color, HlColor.gold);
    });

    test('notes follow the same per-translation rule', () {
      final data = UserData();
      data.setNote(profile, 'kjv', key, 'kjv note');
      expect(data.note(profile, 'web', key), isNull);
      expect(data.notesFor(profile, 'web'), isEmpty);
      data.setNote(profile, 'web', key, 'web note');
      expect(data.note(profile, 'kjv', key), 'kjv note');
      expect(data.note(profile, 'web', key), 'web note');
      expect(data.noteCountFor(profile), 2);
      expect(data.totalNotes, 2);
    });

    test('deleting in one translation leaves the other untouched', () {
      final data = UserData();
      data.setNote(profile, 'kjv', key, 'kjv note');
      data.setNote(profile, 'web', key, 'web note');
      data.setNote(profile, 'web', key, '');
      expect(data.note(profile, 'web', key), isNull);
      expect(data.note(profile, 'kjv', key), 'kjv note');
    });
  });

  group('migration (board run 10)', () {
    final v2Doc = {
      'version': 2,
      'activeProfileId': 'default',
      'names': <String, String>{},
      'seq': 0,
      'profiles': {
        'default': {
          'highlights': {key: 'gold', 'b0c1v1': 'blue'},
          'notes': {key: 'legacy note'},
        },
      },
    };

    test('a v2 document migrates into the translation active at '
        'upgrade, as full-verse spans', () {
      final restored = UserData.fromJson(v2Doc, legacyTranslation: 'web');
      expect(restored.fullVerseColor(profile, 'web', key), HlColor.gold);
      expect(restored.fullVerseColor(profile, 'web', 'b0c1v1'), HlColor.blue);
      expect(restored.note(profile, 'web', key), 'legacy note');
      final span = restored.spansFor(profile, 'web', key).single;
      expect(span.start, 0);
      expect(span.end, -1);
    });

    test('migration does not duplicate into other translations', () {
      final restored = UserData.fromJson(v2Doc, legacyTranslation: 'web');
      expect(restored.spansFor(profile, 'kjv', key), isEmpty);
      expect(restored.note(profile, 'kjv', key), isNull);
      expect(restored.totalSpans, 2);
      expect(restored.totalNotes, 1);
    });

    test('with no stored translation the migration lands in kjv', () {
      final restored = UserData.fromJson(v2Doc);
      expect(restored.fullVerseColor(profile, 'kjv', key), HlColor.gold);
      expect(restored.note(profile, 'kjv', key), 'legacy note');
    });

    test('store load migrates with the stored preference (WEB)', () async {
      SharedPreferences.setMockInitialValues({
        UserDataStore.storageKey: jsonEncode(v2Doc),
        translationPrefsKey: 'WEB',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      expect(store.data.fullVerseColor(profile, 'web', key), HlColor.gold);
      expect(store.data.note(profile, 'web', key), 'legacy note');
      expect(store.data.spansFor(profile, 'kjv', key), isEmpty);
      // The next save writes the v3 document.
      await store.save();
      final saved =
          jsonDecode(prefs.getString(UserDataStore.storageKey)!)
              as Map<String, dynamic>;
      expect(saved['version'], 3);
    });

    test('a v3 document round-trips spans and notes losslessly', () {
      final data = UserData();
      data.applySpan(
        profile,
        'kjv',
        HighlightSpan(
          verseKey: key,
          start: 3,
          end: 6,
          anchor: 'the',
          color: HlColor.gold,
        ),
      );
      data.applySpan(
        profile,
        'webc',
        HighlightSpan(
          verseKey: 'b1000c1v1',
          start: 0,
          end: -1,
          anchor: '',
          color: HlColor.purple,
        ),
      );
      data.setNote(profile, 'hebrew', key, 'hebrew set note');
      final restored = UserData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), data.toJson());
    });
  });
}
