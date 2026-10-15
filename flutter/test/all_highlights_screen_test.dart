import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/deuterocanon.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/data/user_data.dart';
import 'package:woven_word/screens/all_highlights_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fakeReaderData();
  final texts = fakeReaderTexts(data);
  final deutero = DeuterocanonData.parse(
    jsonEncode({
      'books': [
        {
          'slug': 'tobit',
          'name': 'Tobit',
          'abbr': 'Tob',
          'chapters': 2,
          'verseCounts': [10, 10],
        },
      ],
    }),
  );

  Map<String, Object> seedUserData(
    void Function(UserData) build, {
    String translation = 'KJV',
  }) {
    final userData = UserData();
    build(userData);
    return {
      'ww_user_data': jsonEncode(userData.toJson()),
      'ww_translation': translation,
    };
  }

  HighlightSpan span(
    String key, {
    int start = 0,
    int end = 5,
    String anchor = 'anchor',
    HlColor color = HlColor.gold,
  }) => HighlightSpan(
    verseKey: key,
    start: start,
    end: end,
    anchor: anchor,
    color: color,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Map<String, Object> prefs,
    WwTradition tradition = WwTradition.none,
    bool withDeutero = false,
    List<(int, int, int)>? opened,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        home: AllHighlightsScreen(
          data: data,
          tradition: tradition,
          textsLoader: () async => texts,
          deuteroLoader: withDeutero ? () async => deutero : null,
          onOpenVerse: (b, c, v) => opened?.add((b, c, v)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
  }

  testWidgets(
    'rendering: header, book heads, chapter subheads, rows, swatches',
    (tester) async {
      final prefs = seedUserData((u) {
        u.profiles['default'] = ProfileData(
          spans: {
            'kjv': [
              span('b0c1v1', anchor: 'genesis anchor', color: HlColor.gold),
              span('b0c2v3', anchor: 'genesis two', color: HlColor.blue),
              span('b42c1v1', anchor: 'john anchor', color: HlColor.pink),
            ],
          },
        );
      });
      await pumpScreen(tester, prefs: prefs);
      expect(find.text('Highlights in My Profile · KJV'), findsOneWidget);
      expect(find.text('Genesis'), findsOneWidget);
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Chapter 1'), findsWidgets);
      expect(find.text('Chapter 2'), findsOneWidget);
      expect(find.text('Genesis 1:1'), findsOneWidget);
      expect(find.text('genesis anchor'), findsOneWidget);
      expect(find.text('John 1:1'), findsOneWidget);

      Color swatchOf(String verseKey, int start) {
        final finder = find.byKey(ValueKey('highlight-row-$verseKey-$start'));
        final container = find.descendant(
          of: finder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        );
        final widget = tester.widget<Container>(container);
        return ((widget.decoration as BoxDecoration).color)!;
      }

      expect(swatchOf('b0c1v1', 0), WwColors.hlGold);
      expect(swatchOf('b0c2v3', 0), WwColors.hlBlue);
    },
  );

  testWidgets('row tap, core: onOpenVerse receives (book, chapter, verse)', (
    tester,
  ) async {
    final opened = <(int, int, int)>[];
    final prefs = seedUserData((u) {
      u.profiles['default'] = ProfileData(
        spans: {
          'kjv': [span('b42c3v7', anchor: 'john three')],
        },
      );
    });
    await pumpScreen(tester, prefs: prefs, opened: opened);
    await tester.tap(find.byKey(const ValueKey('highlight-row-b42c3v7-0')));
    expect(opened, [(42, 3, 7)]);
  });

  testWidgets(
    'row tap, deuterocanon: onOpenVerse receives the reserved book index',
    (tester) async {
      final opened = <(int, int, int)>[];
      final prefs = seedUserData((u) {
        u.profiles['default'] = ProfileData(
          spans: {
            'kjv': [span('b1000c2v4', anchor: 'tobit anchor')],
          },
        );
      });
      await pumpScreen(
        tester,
        prefs: prefs,
        tradition: WwTradition.catholic,
        withDeutero: true,
        opened: opened,
      );
      expect(find.text('Tobit'), findsOneWidget);
      expect(find.text('Tobit 2:4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('highlight-row-b1000c2v4-0')));
      expect(opened, [(1000, 2, 4)]);
    },
  );

  testWidgets('empty branch 1: no spans in the active set', (tester) async {
    await pumpScreen(tester, prefs: seedUserData((u) {}));
    expect(find.text('No highlights yet in KJV'), findsOneWidget);
    expect(
      find.text(
        'While reading, long-press a verse, then choose a color to highlight it. Highlights for My Profile will gather here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty branch 1 names the stored translation (WEB)', (
    tester,
  ) async {
    // Spans exist in the KJV set; the user is looking at WEB.
    final prefs = seedUserData((u) {
      u.profiles['default'] = ProfileData(
        spans: {
          'kjv': [span('b0c1v1')],
        },
      );
    }, translation: 'WEB');
    await pumpScreen(tester, prefs: prefs);
    expect(find.text('No highlights yet in WEB'), findsOneWidget);
  });

  testWidgets(
    'empty branch 2: spans exist but all canon-dormant; storage untouched',
    (tester) async {
      final prefs = seedUserData((u) {
        u.profiles['default'] = ProfileData(
          spans: {
            'kjv': [span('b42c1v1', anchor: 'nt anchor')],
          },
        );
      });
      await pumpScreen(tester, prefs: prefs, tradition: WwTradition.jewish);
      expect(find.text('No highlights to show here'), findsOneWidget);
      expect(
        find.text(
          "These highlights are for books outside your current tradition's canon. They are kept and return when you switch back.",
        ),
        findsOneWidget,
      );
      // The same seed under Bible only renders the row (dormancy is
      // visibility, never deletion).
      final storedBefore = (await SharedPreferences.getInstance()).getString(
        'ww_user_data',
      );
      await pumpScreen(
        tester,
        prefs: prefs,
        tradition: WwTradition.none,
        withDeutero: false,
      );
      // A fresh pump resets mock prefs from the same seed map; the
      // row renders and the stored document is unchanged.
      expect(find.text('John 1:1'), findsOneWidget);
      final storedAfter = (await SharedPreferences.getInstance()).getString(
        'ww_user_data',
      );
      expect(storedAfter, storedBefore);
    },
  );
}
