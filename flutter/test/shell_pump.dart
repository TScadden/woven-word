import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/data/scripture_text.dart';
import 'package:woven_word/screens/shell_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

/// Pumps the full shell with injected fake canon + texts (§12 test
/// seams), at a phone size by default.
Future<void> pumpShell(
  WidgetTester tester, {
  required BibleData data,
  required ScriptureText texts,
  Size size = const Size(360, 800),
  Map<String, Object> prefs = const {},
  double? textScale,
  bool disableAnimations = false,
  bool resetPrefs = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  if (resetPrefs) SharedPreferences.setMockInitialValues(prefs);
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
      home: WwShell(
        dataLoader: () async => data,
        textsLoader: () async => texts,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

/// Pumps long enough for a programmatic landing (post-frame
/// scheduling + the 300ms animateTo) to fully settle.
Future<void> settleLanding(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

/// Taps a bottom-tab slot by its label.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Opens a chapter in the reader through the Library root search
/// field (§3.4 resolver → §7.4 procedure).
Future<void> openViaSearch(WidgetTester tester, String query) async {
  await tapTab(tester, 'Library');
  await tester.enterText(find.byType(TextField).first, query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

/// The reader's stream list (the only list with an extent builder).
Finder readerList() => find.byWidgetPredicate(
  (w) => w is ListView && w.itemExtentBuilder != null,
);

/// The reader stream's scroll controller.
ScrollController readerController(WidgetTester tester) =>
    tester.widget<ListView>(readerList()).controller!;

/// Opens a chapter in the reader through the Library drill-down:
/// Library tab → testament tile → book tile → chapter cell.
/// Assumes the shell is at the Library root.
Future<void> drillToChapter(
  WidgetTester tester,
  BibleData data,
  int globalChapter,
) async {
  final chapter = data.chapters[globalChapter];
  final book = data.books[chapter.b];
  await tapTab(tester, 'Library');
  await tester.tap(
    find.text(chapter.b < 39 ? 'Old Testament' : 'New Testament'),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.scrollUntilVisible(find.text(book.name), 200);
  await tester.pump();
  await tester.tap(find.text(book.name));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.scrollUntilVisible(find.text('${chapter.c}'), 200);
  await tester.pump();
  await tester.tap(find.text('${chapter.c}').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}
