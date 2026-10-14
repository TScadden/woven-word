import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/screens/home_screen.dart';
import 'package:woven_word/screens/my_notes_screen.dart';
import 'package:woven_word/screens/profiles_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';
import 'package:woven_word/widgets/home_layout.dart';

import 'bible_data_test.dart' show fakeBibleJson;

/// A canon where Genesis 1 and John 1 each have 30 partners, so
/// their selection panels' partner Wraps span multiple rows.
String manyPartnersJson() {
  final base = jsonDecode(fakeBibleJson()) as Map<String, dynamic>;
  final books = base['books'] as List;
  int startOf(String name) =>
      (books.firstWhere((b) => b['name'] == name) as Map)['start'] as int;
  final john = startOf('John');
  base['refs'] = <List<int>>[
    for (var t = 1; t <= 30; t++) [0, 1, t, 1, 1],
    for (var k = 1; k <= 30; k++) [john, 1, john + k, 1, 1],
  ];
  return jsonEncode(base);
}

const _tolerance = 0.5;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BibleData fakeData() => BibleData.fromJsonString(fakeBibleJson());
  BibleData manyData() => BibleData.fromJsonString(manyPartnersJson());

  Future<void> pumpHome(
    WidgetTester tester, {
    required BibleData data,
    Size size = const Size(800, 600),
    Map<String, Object> prefs = const {},
    double? textScale,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        builder: (context, child) {
          var mq = MediaQuery.of(context);
          if (textScale != null) {
            mq = mq.copyWith(textScaler: TextScaler.linear(textScale));
          }
          if (disableAnimations) {
            mq = mq.copyWith(disableAnimations: true);
          }
          return MediaQuery(data: mq, child: child!);
        },
        home: HomeScreen(dataLoader: () async => data),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  ScrollController controller(WidgetTester tester) =>
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

  double viewportHeight(WidgetTester tester) =>
      tester.getSize(find.byType(CustomScrollView)).height;

  HomeLayout modelFor(
    WidgetTester tester,
    BibleData data, {
    required String scope,
    int? selected,
    required double width,
  }) {
    final el = tester.element(find.byType(CustomScrollView));
    return HomeLayout(
      data: data,
      scope: scope,
      viewportWidth: width,
      textScaler: MediaQuery.textScalerOf(el),
      ambientStyle: DefaultTextStyle.of(el).style,
      panel: selected == null ? null : homePanelData(data, selected),
    );
  }

  Finder sectionOf(String bookName) => find.ancestor(
    of: find.text(bookName),
    matching: find.byWidgetPredicate(
      (w) => w is Column && w.key is GlobalKey,
    ),
  );

  double sectionTopDiff(WidgetTester tester, String bookName) =>
      tester.getTopLeft(sectionOf(bookName).first).dy -
      tester.getTopLeft(find.byType(CustomScrollView)).dy;

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
  }

  Future<void> settleJump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  /// Asserts the landing for a jump to [bookIndex] whose post-jump
  /// selection is [selected]: top-aligned within tolerance, or
  /// clamped at maxScrollExtent with the section rendered.
  void expectLanding(
    WidgetTester tester,
    BibleData data, {
    required int bookIndex,
    required int selected,
    required String bookName,
    required double width,
    String scope = 'all',
  }) {
    final model = modelFor(
      tester,
      data,
      scope: scope,
      selected: selected,
      width: width,
    );
    final pos = controller(tester).position;
    final target = model.offsetOfBook(bookIndex);
    if (target <= pos.maxScrollExtent) {
      expect(
        controller(tester).offset,
        closeTo(target, _tolerance),
        reason: 'offset for $bookName',
      );
      expect(
        sectionTopDiff(tester, bookName).abs(),
        lessThanOrEqualTo(_tolerance),
        reason: 'rendered top for $bookName',
      );
    } else {
      expect(controller(tester).offset, pos.maxScrollExtent);
      expect(sectionOf(bookName), findsWidgets);
    }
  }

  group('T1 — extent truth', () {
    testWidgets('no selection, per scope (restore)', (tester) async {
      addTearDown(tester.view.reset);
      final data = fakeData();
      for (final scope in ['all', 'ot', 'nt']) {
        SharedPreferences.setMockInitialValues({'ww_home_scope': scope});
        await tester.pumpWidget(
          MaterialApp(
            theme: wwTheme(),
            home: HomeScreen(dataLoader: () async => data),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final model = modelFor(tester, data, scope: scope, width: 800);
        expect(
          controller(tester).position.maxScrollExtent,
          closeTo(model.totalExtent - viewportHeight(tester), _tolerance),
          reason: 'scope $scope',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('mid-Bible selection extent (restore, per scope)',
        (tester) async {
      addTearDown(tester.view.reset);
      final data = fakeData();
      final cases = <(String, int)>[
        ('all', data.books[18].start + 22), // Psalms 23
        ('ot', data.books[18].start + 22), // Psalms 23
        ('nt', data.books[42].start + 2), // John 3
      ];
      for (final (scope, selected) in cases) {
        SharedPreferences.setMockInitialValues({
          'ww_home_scope': scope,
          'ww_home_selected': selected,
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: wwTheme(),
            home: HomeScreen(dataLoader: () async => data),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        final model = modelFor(
          tester,
          data,
          scope: scope,
          selected: selected,
          width: 800,
        );
        expect(
          controller(tester).position.maxScrollExtent,
          closeTo(model.totalExtent - viewportHeight(tester), _tolerance),
          reason: 'scope $scope selected $selected',
        );
        // Unmount before the next case so its restore runs fresh.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('multi-row partner panel extent (per scope)', (tester) async {
      addTearDown(tester.view.reset);
      final data = manyData();
      final cases = <(String, int)>[
        ('all', 0), // Genesis 1, 30 partners
        ('ot', 0),
        ('nt', data.books[42].start), // John 1, 30 partners
      ];
      for (final (scope, selected) in cases) {
        SharedPreferences.setMockInitialValues({
          'ww_home_scope': scope,
          'ww_home_selected': selected,
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: wwTheme(),
            home: HomeScreen(dataLoader: () async => data),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        // The panel really does span multiple rows: its partners
        // wrap (panel height exceeds a one-row panel).
        final model = modelFor(
          tester,
          data,
          scope: scope,
          selected: selected,
          width: 800,
        );
        expect(model.panelHeight, greaterThan(300));
        expect(
          controller(tester).position.maxScrollExtent,
          closeTo(model.totalExtent - viewportHeight(tester), _tolerance),
          reason: 'scope $scope selected $selected',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('T2 — rendered positions after model jumps', () {
    testWidgets('spread of books land at the viewport top', (tester) async {
      addTearDown(tester.view.reset);
      final data = fakeData();
      await pumpHome(tester, data: data);
      final jumps = <(String, int, String)>[
        // (query, bookIndex, bookName)
        ('Psalms 1', 18, 'Psalms'),
        ('Ezekiel 1', 25, 'Ezekiel'),
        ('Matthew 1', 39, 'Matthew'),
        ('Romans 1', 44, 'Romans'),
        ('Revelation 1', 65, 'Revelation'),
        ('Genesis 1', 0, 'Genesis'),
      ];
      for (final (query, bookIndex, name) in jumps) {
        await search(tester, query);
        await settleJump(tester);
        expectLanding(
          tester,
          data,
          bookIndex: bookIndex,
          selected: data.books[bookIndex].start,
          bookName: name,
          width: 800,
        );
      }
    });

    testWidgets('clamped jump: offset == maxScrollExtent, section rendered',
        (tester) async {
      addTearDown(tester.view.reset);
      final data = fakeData();
      // A tall viewport leaves less travel than the last book's
      // model offset, so the jump must clamp.
      await pumpHome(tester, data: data, size: const Size(800, 2000));
      await search(tester, 'Revelation 1');
      await settleJump(tester);
      final model = modelFor(
        tester,
        data,
        scope: 'all',
        selected: data.books[65].start,
        width: 800,
      );
      final pos = controller(tester).position;
      expect(model.offsetOfBook(65), greaterThan(pos.maxScrollExtent));
      expect(controller(tester).offset, pos.maxScrollExtent);
      expect(sectionOf('Revelation'), findsWidgets);
    });
  });

  testWidgets('T3 — cold jump to a never-built book is the first scroll',
      (tester) async {
    addTearDown(tester.view.reset);
    final data = fakeData();
    await pumpHome(tester, data: data);
    // The target has never been built: nothing about Revelation is
    // in the tree before the jump.
    expect(sectionOf('Revelation'), findsNothing);
    expect(controller(tester).offset, 0);
    await search(tester, 'Revelation 1');
    await settleJump(tester);
    expectLanding(
      tester,
      data,
      bookIndex: 65,
      selected: data.books[65].start,
      bookName: 'Revelation',
      width: 800,
    );
  });

  testWidgets('T4 — framework cross-check with ensureVisible', (tester) async {
    addTearDown(tester.view.reset);
    final data = fakeData();
    await pumpHome(tester, data: data);
    await search(tester, 'Psalms 1');
    await settleJump(tester);
    final before = controller(tester).offset;
    final sectionContext = tester.element(sectionOf('Psalms').first);
    await Scrollable.ensureVisible(
      sectionContext,
      duration: Duration.zero,
      alignment: 0.0,
    );
    await tester.pump();
    expect(
      (controller(tester).offset - before).abs(),
      lessThanOrEqualTo(_tolerance),
    );
  });

  testWidgets('T5 — reduced motion lands after one pump', (tester) async {
    addTearDown(tester.view.reset);
    final data = fakeData();
    await pumpHome(tester, data: data, disableAnimations: true);
    await search(tester, 'Revelation 1');
    await tester.pump();
    final model = modelFor(
      tester,
      data,
      scope: 'all',
      selected: data.books[65].start,
      width: 800,
    );
    expect(
      controller(tester).offset,
      closeTo(model.offsetOfBook(65), _tolerance),
    );
    // No tween pending: further pumps do not move it.
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      controller(tester).offset,
      closeTo(model.offsetOfBook(65), _tolerance),
    );
  });

  testWidgets('T6 — motion is a real 300ms animateTo', (tester) async {
    addTearDown(tester.view.reset);
    final data = fakeData();
    await pumpHome(tester, data: data);
    await search(tester, 'Revelation 1');
    await tester.pump();
    await tester.pump();
    final model = modelFor(
      tester,
      data,
      scope: 'all',
      selected: data.books[65].start,
      width: 800,
    );
    final target = model.offsetOfBook(65);
    await tester.pump(const Duration(milliseconds: 150));
    final mid = controller(tester).offset;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(target));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(controller(tester).offset, closeTo(target, _tolerance));
  });

  group('T7 — second geometry (400 wide, text scale 1.3)', () {
    testWidgets('extent truth at second geometry', (tester) async {
      addTearDown(tester.view.reset);
      final data = manyData();
      await pumpHome(
        tester,
        data: data,
        size: const Size(400, 800),
        textScale: 1.3,
      );
      var model = modelFor(tester, data, scope: 'all', width: 400);
      expect(
        controller(tester).position.maxScrollExtent,
        closeTo(model.totalExtent - viewportHeight(tester), _tolerance),
      );
      // With the multi-row panel (Genesis 1 via restore).
      await tester.pumpWidget(const SizedBox());
      await pumpHome(
        tester,
        data: data,
        size: const Size(400, 800),
        textScale: 1.3,
        prefs: {'ww_home_selected': 0},
      );
      await tester.pump(const Duration(milliseconds: 400));
      model = modelFor(tester, data, scope: 'all', selected: 0, width: 400);
      expect(
        controller(tester).position.maxScrollExtent,
        closeTo(model.totalExtent - viewportHeight(tester), _tolerance),
      );
    });

    testWidgets('landings at second geometry', (tester) async {
      addTearDown(tester.view.reset);
      final data = fakeData();
      await pumpHome(
        tester,
        data: data,
        size: const Size(400, 800),
        textScale: 1.3,
      );
      for (final (query, bookIndex, name) in <(String, int, String)>[
        ('Psalms 1', 18, 'Psalms'),
        ('Revelation 1', 65, 'Revelation'),
      ]) {
        await search(tester, query);
        await settleJump(tester);
        expectLanding(
          tester,
          data,
          bookIndex: bookIndex,
          selected: data.books[bookIndex].start,
          bookName: name,
          width: 400,
        );
      }
    });
  });

  group('T8 — top bar under text scale', () {
    Finder topBar(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == WwColors.nav,
      ),
    );

    List<String> collectFlutterErrors() {
      final collected = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        collected.add(details.exceptionAsString());
      };
      addTearDown(() => FlutterError.onError = previous);
      return collected;
    }

    void expectNoOverflow(List<String> collected) {
      expect(
        collected.where((e) => e.contains('overflowed')),
        isEmpty,
        reason: 'collected Flutter errors: $collected',
      );
    }

    Future<void> pumpScreen(
      WidgetTester tester,
      Widget screen,
      double textScale,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: wwTheme(),
          builder: (context, child) {
            var mq = MediaQuery.of(context);
            mq = mq.copyWith(textScaler: TextScaler.linear(textScale));
            return MediaQuery(data: mq, child: child!);
          },
          home: screen,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('T8a — Home bar is exactly 56.0 at text scale 1.0',
        (tester) async {
      addTearDown(tester.view.reset);
      final data = fakeData();
      await pumpHome(
        tester,
        data: data,
        size: const Size(400, 800),
        textScale: 1.0,
      );
      expect(tester.getSize(topBar('Woven Word').first).height, 56.0);
    });

    testWidgets('T8b — Home bar: zero overflow at text scale 1.3',
        (tester) async {
      addTearDown(tester.view.reset);
      final collected = collectFlutterErrors();
      final data = fakeData();
      await pumpHome(
        tester,
        data: data,
        size: const Size(400, 800),
        textScale: 1.3,
      );
      expectNoOverflow(collected);
      expect(
        tester.getSize(topBar('Woven Word').first).height,
        greaterThan(56),
      );
    });

    testWidgets('T8c — Home bar: zero overflow at text scale 1.5',
        (tester) async {
      addTearDown(tester.view.reset);
      final collected = collectFlutterErrors();
      final data = fakeData();
      await pumpHome(
        tester,
        data: data,
        size: const Size(400, 800),
        textScale: 1.5,
      );
      expectNoOverflow(collected);
      expect(
        tester.getSize(topBar('Woven Word').first).height,
        greaterThan(56),
      );
    });

    testWidgets('T8d — Profiles and My Notes bars at text scale 1.3: '
        'no overflow, exactly 56.0', (tester) async {
      addTearDown(tester.view.reset);
      final collected = collectFlutterErrors();
      await pumpScreen(tester, const ProfilesScreen(), 1.3);
      expectNoOverflow(collected);
      expect(tester.getSize(topBar('Profiles').first).height, 56.0);
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, MyNotesScreen(data: fakeData()), 1.3);
      expectNoOverflow(collected);
      expect(tester.getSize(topBar('My Notes').first).height, 56.0);
    });
  });
}
