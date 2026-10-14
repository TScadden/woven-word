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
        'version': 1,
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
        'version': 1,
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
