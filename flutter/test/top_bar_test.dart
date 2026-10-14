import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'bible_data_test.dart' show fakeBibleJson;
import 'package:woven_word/data/bible_data.dart';
import 'fake_canon.dart';
import 'shell_pump.dart';

/// T8 — top bar under text scale (Part A), RE-HOMED from
/// `home_scroll_test.dart` per Petra spec §9.2: the group moves,
/// assertions unchanged in substance; its pump seam is re-pointed
/// at the shell's Home tab and the Profiles/My Notes pushes inside
/// it. (T1–T7 retired with the monolith list; their coverage maps
/// to the reader tests, §9.2.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    Future<void> pumpHome(
      WidgetTester tester, {
      required double textScale,
    }) async {
      final data = BibleData.fromJsonString(fakeBibleJson());
      final texts = fakeReaderTexts(data);
      await pumpShell(
        tester,
        data: data,
        texts: texts,
        size: const Size(400, 800),
        textScale: textScale,
      );
    }

    testWidgets('T8a — Home bar is exactly 56.0 at text scale 1.0',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpHome(tester, textScale: 1.0);
      expect(tester.getSize(topBar('Woven Word').first).height, 56.0);
    });

    testWidgets('T8b — Home bar: zero overflow at text scale 1.3',
        (tester) async {
      addTearDown(tester.view.reset);
      final collected = collectFlutterErrors();
      await pumpHome(tester, textScale: 1.3);
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
      await pumpHome(tester, textScale: 1.5);
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
      await pumpHome(tester, textScale: 1.3);
      // Profiles is pushed inside the shell's Home navigator.
      await tester.tap(find.byTooltip('Profiles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expectNoOverflow(collected);
      expect(tester.getSize(topBar('Profiles').first).height, 56.0);
      // Back to Home root, then My Notes via the Study row.
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('My Notes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expectNoOverflow(collected);
      expect(tester.getSize(topBar('My Notes').first).height, 56.0);
    });
  });
}
