import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/confession_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/sefaria_data.dart';

import 'fake_canon.dart';
import 'shell_pump.dart';

/// Board run 9: the shell's tradition wiring — persistence,
/// the run-8 toggle's migration, per-tradition lazy loads, and
/// the guarantee that a tradition switch never touches the
/// user's own data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SefariaData> fakeSefaria(canon) async => SefariaData.parse(
    jsonEncode({
      'v': 1,
      'works': ['Mishnah Berakhot'],
      'links': [
        [0, 1, 0, 1],
      ],
    }),
    chapterVerseCounts: [for (final c in canon.chapters) c.v],
  );

  Future<ConfessionData> fakeConfessions(canon) async =>
      ConfessionData.parse(
        jsonEncode({
          'v': 1,
          'docs': [
            {
              'id': 'wcf',
              'title': 'Westminster Confession of Faith',
              'year': 1647,
              'url': 'https://example.org/wcf',
            },
          ],
          'sections': [
            {'d': 0, 'id': '1.1', 'label': 'Chapter 1 · Section 1'},
          ],
          'edges': [
            [0, 0, 1],
          ],
        }),
        chapterVerseCounts: [for (final c in canon.chapters) c.v],
      );

  Future<DeuterocanonData> fakeDeutero() async => DeuterocanonData.parse(
    jsonEncode({
      'books': [
        {
          'slug': 'tobit',
          'name': 'Tobit',
          'abbr': 'Tob',
          'chapters': 14,
          'verseCounts': [for (var i = 0; i < 14; i++) 10],
        },
      ],
    }),
  );

  Future<void> openProfiles(WidgetTester tester) async {
    // Home's profile chip carries the 'Profiles' tooltip (the
    // shipped tests' own way in).
    await tester.tap(find.byTooltip('Profiles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets('migration: a pre-run-9 install with the conference '
      'toggle on wakes up Latter-day Saint', (tester) async {
    final data = fakeReaderData();
    await pumpShell(
      tester,
      data: data,
      texts: fakeReaderTexts(data),
      prefs: {'ww_conference_layer': true},
      sefariaLoader: fakeSefaria,
      confessionLoader: fakeConfessions,
      deuteroLoader: fakeDeutero,
    );
    await openProfiles(tester);
    expect(find.text('Your tradition'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    final node = tester.getSemantics(
      find.bySemanticsLabel('Latter-day Saint'),
    );
    expect(node.flagsCollection.isSelected.name, 'isTrue');
    semantics.dispose();
  });

  testWidgets('restore: a stored tradition wakes up selected, '
      'and its Library tile is live', (tester) async {
    final data = fakeReaderData();
    await pumpShell(
      tester,
      data: data,
      texts: fakeReaderTexts(data),
      prefs: {'ww_tradition': 'jewish'},
      sefariaLoader: fakeSefaria,
      confessionLoader: fakeConfessions,
      deuteroLoader: fakeDeutero,
    );
    await tapTab(tester, 'Library');
    expect(find.text('Tanakh'), findsOneWidget);
    expect(find.text('Old Testament'), findsNothing);
  });

  testWidgets('selecting a tradition persists it and re-scopes '
      'the Library; user data is untouched', (tester) async {
    final data = fakeReaderData();
    const userData =
        '{"version":2,"activeProfileId":"default",'
        '"names":{"default":"My Profile"},"seq":0,'
        '"profiles":{"default":{"highlights":{"b0c1v1":"gold"},'
        '"notes":{"b0c1v1":"keep me"}}}}';
    await pumpShell(
      tester,
      data: data,
      texts: fakeReaderTexts(data),
      prefs: {'ww_user_data': userData},
      sefariaLoader: fakeSefaria,
      confessionLoader: fakeConfessions,
      deuteroLoader: fakeDeutero,
    );
    await openProfiles(tester);
    await tester.scrollUntilVisible(find.text('Protestant'), 100);
    await tester.pump();
    await tester.tap(find.text('Protestant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ww_tradition'), 'protestant');
    // The user's own store is byte-for-byte what it was: the
    // tradition switch never writes it.
    expect(prefs.getString('ww_user_data'), userData);
    // Back out of Profiles and into the Library: the
    // confessions tile is live now.
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tapTab(tester, 'Library');
    expect(find.text('Confessions'), findsOneWidget);
    expect(find.text('1 document · 1 section'), findsOneWidget);
  });

  testWidgets('bible only: no tradition tiles, no layer loads '
      'beyond the deuterocanon table', (tester) async {
    final data = fakeReaderData();
    var sefariaLoads = 0;
    var confessionLoads = 0;
    await pumpShell(
      tester,
      data: data,
      texts: fakeReaderTexts(data),
      sefariaLoader: (canon) async {
        sefariaLoads++;
        return fakeSefaria(canon);
      },
      confessionLoader: (canon) async {
        confessionLoads++;
        return fakeConfessions(canon);
      },
      deuteroLoader: fakeDeutero,
    );
    await tapTab(tester, 'Library');
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('Confessions'), findsNothing);
    expect(sefariaLoads, 0);
    expect(confessionLoads, 0);
  });
}
