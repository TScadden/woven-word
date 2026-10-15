import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/screens/profiles_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

/// Current-device document used by the widget tests: 2 profiles,
/// 3 highlights, 3 notes.
const _currentJson =
    '{"version":2,"activeProfileId":"default",'
    '"names":{"default":"Mine","p1":"Family"},"seq":1,'
    '"profiles":{'
    '"default":{"highlights":{"b0c1v1":"gold","b0c1v2":"blue"},'
    '"notes":{"b0c1v1":"n1"}},'
    '"p1":{"highlights":{"b1c1v1":"pink"},'
    '"notes":{"b1c1v1":"n2","b1c1v2":"n3"}}}}';

/// The backup file used by the widget tests: 1 profile,
/// 2 highlights, 1 note.
const _fileJson =
    '{"version":2,"activeProfileId":"solo",'
    '"names":{"solo":"Imported"},"seq":0,'
    '"profiles":{"solo":{"highlights":{"b0c1v1":"gold","b39c1v1":"green"},'
    '"notes":{"b0c1v1":"hello"}}}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('backup counts', () {
    test('totals sum highlights and notes across all profiles', () {
      final data = UserData.fromJson(
        jsonDecode(_currentJson) as Map<String, dynamic>,
      );
      expect(data.profileIds.length, 2);
      expect(data.totalSpans, 3);
      expect(data.totalNotes, 3);
      expect(UserData().totalSpans, 0);
      expect(UserData().totalNotes, 0);
    });
  });

  group('backup validator', () {
    test('accepts a well-formed v2 document', () {
      final result = UserDataStore.validateImport(_fileJson);
      expect(result.isValid, isTrue);
      expect(result.data!.profileIds, ['solo']);
      expect(result.data!.totalSpans, 2);
      expect(result.data!.totalNotes, 1);
    });

    test('rejects undecodable JSON as notJson', () {
      expect(
        UserDataStore.validateImport('{not json').error,
        BackupImportError.notJson,
      );
      expect(
        UserDataStore.validateImport('').error,
        BackupImportError.notJson,
      );
    });

    test('rejects a non-object root as notBackup', () {
      expect(
        UserDataStore.validateImport('["a","list"]').error,
        BackupImportError.notBackup,
      );
      expect(
        UserDataStore.validateImport('42').error,
        BackupImportError.notBackup,
      );
    });

    test('rejects a missing or non-object profiles member as notBackup',
        () {
      expect(
        UserDataStore.validateImport('{"version":2}').error,
        BackupImportError.notBackup,
      );
      expect(
        UserDataStore.validateImport('{"version":2,"profiles":"junk"}').error,
        BackupImportError.notBackup,
      );
    });

    test('rejects a non-object profile bucket as notBackup', () {
      expect(
        UserDataStore.validateImport(
          '{"version":2,"profiles":{"default":"junk"}}',
        ).error,
        BackupImportError.notBackup,
      );
    });

    test('rejects a non-numeric version as notBackup', () {
      expect(
        UserDataStore.validateImport(
          '{"version":"2","profiles":{"default":{"highlights":{},'
          '"notes":{}}}}',
        ).error,
        BackupImportError.notBackup,
      );
    });

    test('rejects a newer version as newerVersion', () {
      expect(
        UserDataStore.validateImport(
          '{"version":99,"profiles":{"default":{"highlights":{},'
          '"notes":{}}}}',
        ).error,
        BackupImportError.newerVersion,
      );
    });

    test('rejects a document parsing to nothing as emptyDocument', () {
      expect(
        UserDataStore.validateImport('{"version":2,"profiles":{}}').error,
        BackupImportError.emptyDocument,
      );
      // Names alone do not rescue it: zero profile BUCKETS in the
      // raw profiles map, zero highlights, zero notes.
      expect(
        UserDataStore.validateImport(
          '{"version":2,"names":{"x":"X"},"profiles":{}}',
        ).error,
        BackupImportError.emptyDocument,
      );
    });

    test('accepts one empty profile bucket (bucket count is the test)',
        () {
      final result = UserDataStore.validateImport(
        '{"version":2,"profiles":{"default":{"highlights":{},'
        '"notes":{}}}}',
      );
      expect(result.isValid, isTrue);
      expect(result.data!.totalSpans, 0);
      expect(result.data!.totalNotes, 0);
    });

    test('a v1 document imports and upgrades to v3 on replace', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      const v1 =
          '{"version":1,"profiles":{"default":'
          '{"highlights":{"b18c23v1":"gold"},"notes":{"b18c23v1":"kept"}}}}';
      final result = UserDataStore.validateImport(v1);
      expect(result.isValid, isTrue);
      await store.replaceData(result.data!);
      final stored =
          jsonDecode(prefs.getString(UserDataStore.storageKey)!)
              as Map<String, dynamic>;
      expect(stored['version'], 3);
      expect(
        store.data.fullVerseColor('default', 'kjv', 'b18c23v1'),
        HlColor.gold,
      );
      expect(store.data.note('default', 'kjv', 'b18c23v1'), 'kept');
    });

    test('a v3 backup carries per-translation spans and imports '
        'them exactly (board run 10)', () {
      final data = UserData();
      data.applySpan(
        'default',
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 3,
          end: 6,
          anchor: 'the',
          color: HlColor.gold,
        ),
      );
      data.applySpan(
        'default',
        'web',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 0,
          end: -1,
          anchor: '',
          color: HlColor.blue,
        ),
      );
      data.setNote('default', 'web', 'b0c1v1', 'web note');
      final result = UserDataStore.validateImport(data.exportJson());
      expect(result.isValid, isTrue);
      expect(result.data!.toJson(), data.toJson());
      final span = result.data!.spansFor('default', 'kjv', 'b0c1v1').single;
      expect(span.anchor, 'the');
      expect(span.start, 3);
      expect(span.end, 6);
    });

    test('a legacy backup imports into the translation active at '
        'import (board run 10)', () {
      final result = UserDataStore.validateImport(
        _fileJson,
        legacyTranslation: 'web',
      );
      expect(result.isValid, isTrue);
      expect(
        result.data!.fullVerseColor('solo', 'web', 'b0c1v1'),
        HlColor.gold,
      );
      expect(result.data!.note('solo', 'web', 'b0c1v1'), 'hello');
      expect(result.data!.spansFor('solo', 'kjv', 'b0c1v1'), isEmpty);
    });
  });

  group('backup store round-trip', () {
    test('export -> import reproduces the identical document', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      final id = store.data.createProfile('Family');
      store.data.applySpan(
        'default',
        'kjv',
        HighlightSpan(
          verseKey: 'b0c1v1',
          start: 0,
          end: -1,
          anchor: '',
          color: HlColor.gold,
        ),
      );
      store.data.setNote(id, 'kjv', 'b39c1v1', 'family note');
      store.data.renameProfile('default', 'Mine');
      await store.save();

      final exported = store.exportJson();
      // Pretty-printed, and exactly the toJson shape.
      expect(exported, contains('\n'));
      expect(jsonDecode(exported), store.data.toJson());

      final result = UserDataStore.validateImport(exported);
      expect(result.isValid, isTrue);

      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      final store2 = await UserDataStore.load(prefs2);
      await store2.replaceData(result.data!);
      expect(store2.data.toJson(), store.data.toJson());
      expect(store2.exportJson(), exported);
    });

    test('malformed inputs are no-ops: stored string untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      store.data.setNote('default', 'kjv', 'b0c1v1', 'keep me');
      await store.save();
      final before = prefs.getString(UserDataStore.storageKey);

      const malformed = [
        '{not json',
        '["a","list"]',
        '{"version":2}',
        '{"version":2,"profiles":"junk"}',
        '{"version":2,"profiles":{"default":"junk"}}',
        '{"version":"2","profiles":{}}',
        '{"version":99,"profiles":{"default":{"highlights":{},'
            '"notes":{}}}}',
        '{"version":2,"profiles":{}}',
      ];
      for (final source in malformed) {
        final result = UserDataStore.validateImport(source);
        expect(result.isValid, isFalse, reason: source);
        // Validation is pure: nothing was written, and a reload
        // still returns the untouched model.
        expect(prefs.getString(UserDataStore.storageKey), before);
        final reloaded = await UserDataStore.load(prefs);
        expect(reloaded.data.note('default', 'kjv', 'b0c1v1'), 'keep me');
      }
    });

    test('replaceData swaps the model and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await UserDataStore.load(prefs);
      final old = store.data;
      final replacement = UserData.fromJson(
        jsonDecode(_fileJson) as Map<String, dynamic>,
      );
      await store.replaceData(replacement);
      expect(identical(store.data, replacement), isTrue);
      expect(identical(store.data, old), isFalse);
      final reloaded = await UserDataStore.load(prefs);
      expect(reloaded.data.toJson(), replacement.toJson());
    });
  });

  group('Profiles Backup section (widget)', () {
    Future<void> pumpProfiles(
      WidgetTester tester, {
      Future<Uint8List?> Function()? picker,
      Future<void> Function(String)? share,
      bool disableAnimations = false,
    }) async {
      SharedPreferences.setMockInitialValues({
        UserDataStore.storageKey: _currentJson,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          builder: (context, child) => disableAnimations
              ? MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                )
              : child!,
          home: ProfilesScreen(pickBackupFile: picker, shareBackup: share),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    /// Board run 8 (§2.1) put the General Conference section
    /// above Backup, so Profiles is now taller than this suite's
    /// default viewport and the Backup rows build only once
    /// scrolled into view — as a user reaches them. Scroll first;
    /// every assertion in this group is unchanged.
    Future<void> scrollToRow(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(find.text(label), 100);
      await tester.pump();
    }

    testWidgets('section renders with verbatim copy', (tester) async {
      await pumpProfiles(tester);
      await scrollToRow(tester, 'Import backup');
      expect(find.text('Backup'), findsOneWidget);
      expect(
        find.text(
          'Export saves every profile \u2014 with every '
          'translation\u2019s highlights and notes \u2014 as one JSON '
          'file. Import replaces everything here with the contents '
          'of a backup file. Nothing leaves this device unless you '
          'export it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Export backup'), findsOneWidget);
      expect(
        find.text('Share a JSON file of all your profiles'),
        findsOneWidget,
      );
      expect(find.text('Import backup'), findsOneWidget);
      expect(
        find.text('Replace current data from a backup file'),
        findsOneWidget,
      );
    });

    testWidgets('export shares the document and shows nothing after',
        (tester) async {
      String? shared;
      await pumpProfiles(tester, share: (json) async => shared = json);
      await scrollToRow(tester, 'Export backup');
      await tester.tap(find.text('Export backup'));
      await tester.pump();
      await tester.pump();
      expect(shared, isNotNull);
      // The v2 fixture loads through the run 10 migration, so
      // the shared document is the loaded model's v3 document.
      final loaded = UserData.fromJson(
        jsonDecode(_currentJson) as Map<String, dynamic>,
      );
      expect(jsonDecode(shared!), loaded.toJson());
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('picker cancellation is silent', (tester) async {
      await pumpProfiles(tester, picker: () async => null);
      await scrollToRow(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        (await prefs()).getString(UserDataStore.storageKey),
        _currentJson,
      );
    });

    testWidgets('malformed file: error dialog, state unchanged',
        (tester) async {
      await pumpProfiles(
        tester,
        picker: () async => Uint8List.fromList(utf8.encode('not json')),
      );
      await scrollToRow(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pump();
      await tester.pump();
      expect(find.text('This file could not be imported'), findsOneWidget);
      expect(
        find.text(
          'Nothing was changed. The file is not readable as a backup '
          '(it is not valid JSON).',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await prefs()).getString(UserDataStore.storageKey),
        _currentJson,
      );
      // Back to the top of the list, where the profile rows are.
      await tester.scrollUntilVisible(find.text('Mine'), -100);
      await tester.pump();
      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('error dialog under reduced motion renders instantly',
        (tester) async {
      await pumpProfiles(
        tester,
        disableAnimations: true,
        picker: () async => Uint8List.fromList(utf8.encode('{"version":2}')),
      );
      await scrollToRow(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pump();
      expect(find.text('This file could not be imported'), findsOneWidget);
      expect(
        find.text(
          'Nothing was changed. The file is not a Woven Word backup '
          'document.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('confirm names both sides; Cancel changes nothing',
        (tester) async {
      await pumpProfiles(
        tester,
        picker: () async => Uint8List.fromList(utf8.encode(_fileJson)),
      );
      await scrollToRow(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Replace all data?'), findsOneWidget);
      expect(
        find.text(
          'Importing this backup will replace all current data. '
          'The 2 profiles, 3 highlights, and 3 notes now on this '
          'device will be removed, and 1 profile, 2 highlights, and '
          '1 note from the file will take their place. This cannot '
          'be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        (await prefs()).getString(UserDataStore.storageKey),
        _currentJson,
      );
    });

    testWidgets('Replace installs the validated model, persists, snackbars',
        (tester) async {
      await pumpProfiles(
        tester,
        picker: () async => Uint8List.fromList(utf8.encode(_fileJson)),
      );
      await scrollToRow(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.pump();
      // Success feedback after persistence.
      expect(find.text('Data replaced from backup.'), findsOneWidget);
      // The screen reloaded from the replaced model. (Board run
      // 9: the tradition section makes the screen taller, so the
      // list is still scrolled at Backup — scroll back to the
      // profiles before asserting on them.)
      await tester.scrollUntilVisible(find.text('Imported'), -100);
      await tester.pump();
      expect(find.text('Imported'), findsOneWidget);
      expect(find.text('Mine'), findsNothing);
      // The persisted document equals the validated file model.
      final stored = (await prefs()).getString(UserDataStore.storageKey);
      final expected = UserData.fromJson(
        jsonDecode(_fileJson) as Map<String, dynamic>,
      );
      expect(jsonDecode(stored!), expected.toJson());
    });
  });
}
