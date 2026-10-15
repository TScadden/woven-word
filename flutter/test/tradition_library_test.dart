import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/confession_data.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/library_tab.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

/// Board run 9: the Library root under each tradition — the
/// canon it presents is the tradition's, tiles absent (never
/// dead) when their layer is off or unloaded, counts computed
/// from the datasets at render.
class FakeTraditionState extends ChangeNotifier
    implements TraditionLayerState {
  @override
  WwTradition tradition = WwTradition.none;

  @override
  ConfessionData? confessionData;

  @override
  DeuterocanonData? deuterocanonData;

  void set(WwTradition t) {
    tradition = t;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DeuterocanonData fakeDeutero() => DeuterocanonData.parse(
    jsonEncode({
      'books': [
        {
          'slug': 'tobit',
          'name': 'Tobit',
          'abbr': 'Tob',
          'chapters': 14,
          'verseCounts': [for (var i = 0; i < 14; i++) 10],
        },
        {
          'slug': 'judith',
          'name': 'Judith',
          'abbr': 'Jdt',
          'chapters': 16,
          'verseCounts': [for (var i = 0; i < 16; i++) 10],
        },
      ],
    }),
  );

  DeuterocanonData fakeDeuteroGreek() => DeuterocanonData.parse(
    jsonEncode({
      'books': [
        {
          'slug': 'tobit',
          'name': 'Tobit',
          'abbr': 'Tob',
          'chapters': 14,
          'verseCounts': [for (var i = 0; i < 14; i++) 10],
        },
        {
          'slug': 'judith',
          'name': 'Judith',
          'abbr': 'Jdt',
          'chapters': 16,
          'verseCounts': [for (var i = 0; i < 16; i++) 10],
        },
        {
          'slug': 'esther-greek',
          'name': 'Esther (Greek)',
          'abbr': 'EstG',
          'chapters': 10,
          'verseCounts': [for (var i = 0; i < 10; i++) 10],
        },
        {
          'slug': 'daniel-greek',
          'name': 'Daniel (Greek)',
          'abbr': 'DanG',
          'chapters': 14,
          'verseCounts': [for (var i = 0; i < 14; i++) 10],
        },
      ],
    }),
  );

  ConfessionData fakeConfessions() {
    final data = fakeReaderData();
    return ConfessionData.parse(
      jsonEncode({
        'v': 1,
        'docs': [
          {
            'id': 'wcf',
            'title': 'Westminster Confession of Faith',
            'year': 1647,
            'url': 'https://example.org/wcf',
          },
          {
            'id': 'lbc1689',
            'title': '1689 London Baptist Confession',
            'year': 1689,
            'url': 'https://example.org/lbc',
          },
        ],
        'sections': [
          {'d': 0, 'id': '1.1', 'label': 'Chapter 1 · Section 1'},
          {'d': 1, 'id': '1.1', 'label': 'Chapter 1 · Section 1'},
        ],
        'edges': [
          [0, 0, 1],
          [1, 0, 1],
        ],
      }),
      chapterVerseCounts: [for (final c in data.chapters) c.v],
    );
  }

  Future<FakeTraditionState> pumpLibrary(
    WidgetTester tester, {
    required WwTradition tradition,
    ConfessionData? confessions,
    DeuterocanonData? deutero,
    List<String>? taps,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final data = fakeReaderData();
    final state = FakeTraditionState()
      ..tradition = tradition
      ..confessionData = confessions
      ..deuterocanonData = deutero;
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        home: LibraryRoot(
          dataFuture: Future.value(data),
          onTestament: (_) {},
          onOpenChapter: (_) {},
          traditionState: state,
          onOpenTanakh: () => taps?.add('tanakh'),
          onOpenCatholicOt: () => taps?.add('catholic-ot'),
          onOpenConfessions: () => taps?.add('confessions'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return state;
  }

  testWidgets('none: the shipped testament pair, nothing else', (
    tester,
  ) async {
    await pumpLibrary(tester, tradition: WwTradition.none);
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);
    expect(find.text('Tanakh'), findsNothing);
    expect(find.text('Confessions'), findsNothing);
  });

  testWidgets('jewish: the Tanakh tile alone, counted from the '
      'canon; its tap routes to the grid', (tester) async {
    final taps = <String>[];
    await pumpLibrary(tester, tradition: WwTradition.jewish, taps: taps);
    expect(find.text('Tanakh'), findsOneWidget);
    expect(find.text('39 books · 929 chapters'), findsOneWidget);
    expect(find.text('Old Testament'), findsNothing);
    expect(find.text('New Testament'), findsNothing);
    await tester.tap(find.text('Tanakh'));
    await tester.pump();
    expect(taps, ['tanakh']);
  });

  testWidgets('catholic: the OT tile counts the union canon', (
    tester,
  ) async {
    final taps = <String>[];
    await pumpLibrary(
      tester,
      tradition: WwTradition.catholic,
      deutero: fakeDeutero(),
      taps: taps,
    );
    // 39 core OT books + 2 extra; 929 + 30 chapters.
    expect(find.text('41 books · 959 chapters'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);
    await tester.tap(find.text('Old Testament'));
    await tester.pump();
    expect(taps, ['catholic-ot']);
  });

  testWidgets('catholic without the table loaded: no OT tile '
      'until the union canon can render', (tester) async {
    await pumpLibrary(tester, tradition: WwTradition.catholic);
    // No Old Testament tile and no counts: the shipped 39-book
    // tile would undercount the canon this tradition names.
    expect(find.text('Old Testament'), findsNothing);
    expect(find.text('39 books · 929 chapters'), findsNothing);
    expect(find.text('New Testament'), findsOneWidget);
  });

  testWidgets('catholic: Greek Esther/Daniel add grid tiles but '
      'not canon counts', (tester) async {
    await pumpLibrary(
      tester,
      tradition: WwTradition.catholic,
      deutero: fakeDeuteroGreek(),
    );
    // Same caption as the two-book table: the Greek editions are
    // alternate editions of core books already inside the 39.
    expect(find.text('41 books · 959 chapters'), findsOneWidget);
  });

  testWidgets('protestant: confessions tile appears only with '
      'its dataset, counted from it', (tester) async {
    final taps = <String>[];
    await pumpLibrary(tester, tradition: WwTradition.protestant, taps: taps);
    expect(find.text('Confessions'), findsNothing);
    expect(find.text('Old Testament'), findsOneWidget);
  });

  testWidgets('protestant with data: the tile lands below the '
      'testaments and routes out', (tester) async {
    final taps = <String>[];
    await pumpLibrary(
      tester,
      tradition: WwTradition.protestant,
      confessions: fakeConfessions(),
      taps: taps,
    );
    expect(find.text('Confessions'), findsOneWidget);
    expect(find.text('2 documents · 2 sections'), findsOneWidget);
    await tester.tap(find.text('Confessions'));
    await tester.pump();
    expect(taps, ['confessions']);
  });

  testWidgets('switching tradition live re-scopes the tiles', (
    tester,
  ) async {
    final state = await pumpLibrary(tester, tradition: WwTradition.none);
    expect(find.text('Old Testament'), findsOneWidget);
    state.set(WwTradition.jewish);
    await tester.pump();
    expect(find.text('Tanakh'), findsOneWidget);
    expect(find.text('Old Testament'), findsNothing);
    state.set(WwTradition.lds);
    await tester.pump();
    expect(find.text('Old Testament'), findsOneWidget);
    expect(find.text('Tanakh'), findsNothing);
  });
}
