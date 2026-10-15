import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/conference_data.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/shell_screen.dart';

import 'fake_canon.dart';

/// Board run 8 plumbing: the conference layer toggle on
/// [ShellController] — off by default, and the dataset loads
/// lazily (first enable, or startup only when the persisted
/// choice is already on). A failing load degrades to an unloaded
/// layer, never a throw. Board run 9 re-map: the toggle IS the
/// tradition selection now — setConferenceEnabled delegates to
/// setTradition, persistence lives under `ww_tradition`
/// ('lds'/'none'), and a pre-run-9 `ww_conference_layer: true`
/// still wakes the layer up (the migration, asserted below).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BibleData canon;
  late String fixture;

  setUp(() {
    canon = fakeReaderData();
    fixture = File('test/fixtures/conference_fixture.json').readAsStringSync();
  });

  ShellController controller({
    Map<String, Object> prefs = const {},
    required Future<ConferenceData> Function(BibleData) loader,
  }) {
    SharedPreferences.setMockInitialValues(prefs);
    return ShellController(
      dataLoader: () async => canon,
      textsLoader: null,
      conferenceLoader: loader,
    );
  }

  testWidgets('default off: no load is attempted', (tester) async {
    await tester.runAsync(() async {
      var loads = 0;
      final ctl = controller(
        loader: (c) async {
          loads++;
          return ConferenceData.fromCanon(fixture, c);
        },
      );
      addTearDown(ctl.dispose);
      await ctl.dataFuture;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ctl.conferenceEnabled, isFalse);
      expect(ctl.conferenceData, isNull);
      expect(loads, 0);
    });
  });

  testWidgets('persisted on: startup loads the dataset once', (tester) async {
    await tester.runAsync(() async {
      var loads = 0;
      final ctl = controller(
        prefs: const {'ww_conference_layer': true},
        loader: (c) async {
          loads++;
          return ConferenceData.fromCanon(fixture, c);
        },
      );
      addTearDown(ctl.dispose);
      await ctl.dataFuture;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await ctl.ensureConferenceLoaded(); // joins the in-flight load
      expect(ctl.conferenceEnabled, isTrue);
      expect(ctl.conferenceData?.talkCount, 8);
      expect(loads, 1);
      // A second ensure is a no-op once loaded.
      await ctl.ensureConferenceLoaded();
      expect(loads, 1);
    });
  });

  testWidgets('setConferenceEnabled persists and loads lazily', (tester) async {
    await tester.runAsync(() async {
      var loads = 0;
      final ctl = controller(
        loader: (c) async {
          loads++;
          return ConferenceData.fromCanon(fixture, c);
        },
      );
      addTearDown(ctl.dispose);
      await ctl.dataFuture;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(loads, 0);

      await ctl.setConferenceEnabled(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(traditionPrefsKey), 'lds');
      expect(ctl.conferenceEnabled, isTrue);
      expect(ctl.conferenceData?.talkCount, 8);
      expect(loads, 1);

      await ctl.setConferenceEnabled(false);
      expect(prefs.getString(traditionPrefsKey), 'none');
      expect(ctl.conferenceEnabled, isFalse);
      // Disabling never unloads data already in memory.
      expect(ctl.conferenceData, isNotNull);
    });
  });

  testWidgets('a failed load degrades: no throw, layer stays empty', (
    tester,
  ) async {
    await tester.runAsync(() async {
      var attempts = 0;
      final ctl = controller(
        loader: (c) async {
          attempts++;
          throw StateError('asset missing');
        },
      );
      addTearDown(ctl.dispose);
      await ctl.dataFuture;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await ctl.setConferenceEnabled(true); // must not throw
      expect(ctl.conferenceEnabled, isTrue);
      expect(ctl.conferenceData, isNull);
      expect(attempts, 1);
      // A later ensure retries rather than latching the failure.
      await ctl.ensureConferenceLoaded();
      expect(attempts, 2);
      expect(ctl.conferenceData, isNull);
    });
  });
}
