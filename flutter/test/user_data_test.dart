import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/user_data.dart';

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
      expect(data.highlight(profile, key), isNull);

      data.setHighlight(profile, key, HlColor.gold);
      expect(data.highlight(profile, key), HlColor.gold);

      data.setHighlight(profile, key, HlColor.blue);
      expect(data.highlight(profile, key), HlColor.blue);

      data.setHighlight(profile, key, null);
      expect(data.highlight(profile, key), isNull);
    });

    test('clearing an unknown profile is a no-op read', () {
      final data = UserData();
      data.setHighlight('nobody', key, null);
      expect(data.highlight('nobody', key), isNull);
      expect(data.highlight('nobody', 'b0c1v1'), isNull);
    });

    test('clearing a highlight leaves the note untouched', () {
      final data = UserData();
      data.setHighlight(profile, key, HlColor.pink);
      data.setNote(profile, key, 'keep me');
      data.setHighlight(profile, key, null);
      expect(data.highlight(profile, key), isNull);
      expect(data.note(profile, key), 'keep me');
    });
  });

  group('notes', () {
    test('set, edit, and clear', () {
      final data = UserData();
      expect(data.note(profile, key), isNull);

      data.setNote(profile, key, 'first');
      expect(data.note(profile, key), 'first');

      data.setNote(profile, key, 'edited');
      expect(data.note(profile, key), 'edited');

      data.setNote(profile, key, '');
      expect(data.note(profile, key), isNull);
    });

    test('whitespace-only text clears the note', () {
      final data = UserData();
      data.setNote(profile, key, 'text');
      data.setNote(profile, key, '   \n\t ');
      expect(data.note(profile, key), isNull);
    });

    test('clearing a note leaves the highlight untouched', () {
      final data = UserData();
      data.setHighlight(profile, key, HlColor.green);
      data.setNote(profile, key, 'gone soon');
      data.setNote(profile, key, '');
      expect(data.note(profile, key), isNull);
      expect(data.highlight(profile, key), HlColor.green);
    });
  });

  group('profile scoping', () {
    test('two profiles are fully independent', () {
      final data = UserData();
      data.setHighlight('alice', key, HlColor.gold);
      data.setNote('alice', key, 'alice note');
      data.setHighlight('bob', key, HlColor.purple);
      data.setNote('bob', key, 'bob note');

      expect(data.highlight('alice', key), HlColor.gold);
      expect(data.highlight('bob', key), HlColor.purple);
      expect(data.note('alice', key), 'alice note');
      expect(data.note('bob', key), 'bob note');

      data.setHighlight('alice', key, null);
      data.setNote('bob', key, '');
      expect(data.highlight('alice', key), isNull);
      expect(data.highlight('bob', key), HlColor.purple);
      expect(data.note('alice', key), 'alice note');
      expect(data.note('bob', key), isNull);
    });
  });

  group('serialization', () {
    test('round-trip preserves all data', () {
      final data = UserData();
      data.setHighlight(profile, key, HlColor.gold);
      data.setHighlight(profile, 'b0c1v1', HlColor.blue);
      data.setNote(profile, key, 'on the highlighted verse');
      data.setNote('other', 'b39c1v1', 'other profile note');

      final restored = UserData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), data.toJson());
      expect(restored.highlight(profile, key), HlColor.gold);
      expect(restored.note('other', 'b39c1v1'), 'other profile note');
    });

    test('document shape matches the spec', () {
      final data = UserData();
      data.setHighlight(profile, key, HlColor.green);
      data.setNote(profile, key, 'shape');
      expect(data.toJson(), {
        'version': 2,
        'activeProfileId': 'default',
        'names': <String, String>{},
        'seq': 0,
        'profiles': {
          'default': {
            'highlights': {key: 'green'},
            'notes': {key: 'shape'},
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
      expect(restored.highlight(profile, key), isNull);
      expect(restored.highlight(profile, 'b0c1v1'), HlColor.gold);
      expect(restored.highlight(profile, 'b0c1v2'), isNull);
      expect(restored.note(profile, key), 'kept');
      expect(restored.note(profile, 'b0c1v1'), isNull);
      expect(restored.note(profile, 'b0c1v2'), isNull);
    });

    test('defensive load tolerates a garbage top-level shape', () {
      expect(UserData.fromJson({}).toJson(), {
        'version': 2,
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
        }).profiles[profile]?.highlights,
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
      data.setHighlight(a, key, HlColor.gold);
      data.setNote(a, key, 'doomed');
      data.setNote('default', key, 'safe');
      data.deleteProfile(a);
      expect(data.highlight(a, key), isNull);
      expect(data.note(a, key), isNull);
      expect(data.note('default', key), 'safe');
    });

    test('active-profile isolation: writes under one profile are '
        'invisible under another', () {
      final data = UserData();
      data.setHighlight(data.activeProfileId, key, HlColor.gold);
      data.setNote(data.activeProfileId, key, 'default note');

      final other = data.createProfile('Other');
      expect(data.activeProfileId, other);
      expect(data.highlight(data.activeProfileId, key), isNull);
      expect(data.note(data.activeProfileId, key), isNull);

      data.setNote(data.activeProfileId, key, 'other note');
      data.setActiveProfile('default');
      expect(data.highlight(data.activeProfileId, key), HlColor.gold);
      expect(data.note(data.activeProfileId, key), 'default note');
      expect(data.note(other, key), 'other note');
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
      expect(restored.highlight('default', key), HlColor.gold);
      expect(restored.note('default', key), 'kept from run 4');

      final roundTripped = UserData.fromJson(
        jsonDecode(jsonEncode(restored.toJson())) as Map<String, dynamic>,
      );
      expect(roundTripped.highlight('default', key), HlColor.gold);
      expect(roundTripped.note('default', key), 'kept from run 4');
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
          'default': {'highlights': <String, String>{}, 'notes': <String, String>{}},
        },
      });
      expect(restored.activeProfileId, 'default');
    });
  });

  group('notesFor (My Notes)', () {
    test('canonical order: book, then chapter, then verse, numeric', () {
      final data = UserData();
      data.setNote(profile, 'b18c23v10', 'psalm verse ten');
      data.setNote(profile, 'b0c1v2', 'genesis two');
      data.setNote(profile, 'b18c23v2', 'psalm verse two');
      data.setNote(profile, 'b0c2v1', 'genesis chapter two');
      data.setNote(profile, 'b0c1v10', 'genesis ten');

      final notes = data.notesFor(profile);
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
      data.setNote('alice', 'b0c1v1', 'alice only');
      data.setNote('bob', 'b0c1v2', 'bob only');
      expect(data.notesFor('alice').single.text, 'alice only');
      expect(data.notesFor('bob').single.text, 'bob only');
      expect(data.notesFor('nobody'), isEmpty);
    });

    test('an empty profile has an empty list', () {
      final data = UserData();
      expect(data.notesFor(profile), isEmpty);
    });
  });

  group('UserDataStore', () {
    test('save/load round-trip through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final store = await UserDataStore.load(prefs);
      expect(store.data.highlight(profile, key), isNull);
      store.data.setHighlight(profile, key, HlColor.purple);
      store.data.setNote(profile, key, 'persisted');
      await store.save();

      expect(prefs.getString(UserDataStore.storageKey), isNotNull);
      final reloaded = await UserDataStore.load(prefs);
      expect(reloaded.data.highlight(profile, key), HlColor.purple);
      expect(reloaded.data.note(profile, key), 'persisted');
    });

    test('profiles, names, and active id round-trip through the store',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final store = await UserDataStore.load(prefs);
      final id = store.data.createProfile('Family');
      store.data.setNote(id, key, 'family note');
      store.data.setNote('default', key, 'default note');
      store.data.setActiveProfile('default');
      await store.save();

      final reloaded = await UserDataStore.load(prefs);
      expect(reloaded.data.profileIds, ['default', id]);
      expect(reloaded.data.profileName(id), 'Family');
      expect(reloaded.data.activeProfileId, 'default');
      expect(reloaded.data.note(id, key), 'family note');
      expect(reloaded.data.note('default', key), 'default note');
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
}
