import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/data/tradition.dart';
import 'package:woven_word/screens/profiles_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

/// Board run 9: the Profiles "Your tradition" selector — the
/// run-8 General Conference toggle's coverage, re-mapped onto
/// the surface that replaced it (the run-7 re-mapping rule:
/// coverage moves, it is never dropped). Placement (after New
/// profile, before Backup), verbatim copy, one-node selected
/// semantics per row, and exactly one change emission per tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpProfiles(
    WidgetTester tester, {
    WwTradition tradition = WwTradition.none,
    ValueChanged<WwTradition>? onChanged,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        home: ProfilesScreen(
          tradition: tradition,
          onTraditionChanged: onChanged,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('section renders verbatim copy, after New profile, '
      'before Backup', (tester) async {
    await pumpProfiles(tester);
    expect(find.text('Your tradition'), findsOneWidget);
    expect(
      find.text(
        'Woven Word shapes itself around your tradition: the canon '
        'it presents, the connections it layers over each verse, '
        'and where reading links lead. Your profiles, highlights, '
        'and notes never change.',
      ),
      findsOneWidget,
    );
    // Placement: below the New profile button (measured before
    // scrolling — the list disposes far-off children).
    final newProfileY = tester.getTopLeft(find.text('New profile')).dy;
    final headerY = tester.getTopLeft(find.text('Your tradition')).dy;
    expect(headerY, greaterThan(newProfileY));
    // Every tradition row, with its honest coverage copy.
    expect(find.text('Bible only'), findsOneWidget);
    expect(
      find.text(
        'The woven web on its own: cross references, highlights, '
        'and notes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Latter-day Saint'), findsOneWidget);
    expect(
      find.text(
        'Adds the General Conference talks that cite each verse. '
        'Talks are read in Gospel Library or the Citation Index; '
        'no talk text is stored in this app.',
      ),
      findsOneWidget,
    );
    expect(find.text('Jewish'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Protestant'), 100);
    await tester.pump();
    expect(find.text('Protestant'), findsOneWidget);
    expect(
      find.text(
        'Adds the proof texts of the Westminster Confession (1647) '
        'and the 1689 London Baptist Confession to each verse.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Catholic'), 100);
    await tester.pump();
    expect(find.text('Catholic'), findsOneWidget);
    expect(
      find.text(
        'The 73-book canon: the deuterocanon, read in the World '
        'English Bible Catholic Edition. Catechism citations are '
        'not included yet.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Backup'), 100);
    await tester.pump();
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });

  testWidgets('semantics: one node per row, the selected flag '
      'carries the state', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProfiles(tester, tradition: WwTradition.jewish);

    // Bible only is NOT selected; Jewish is — each under exactly
    // one semantics node whose label is the tradition's name.
    var node = tester.getSemantics(find.bySemanticsLabel('Bible only'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(node.flagsCollection.isButton, isTrue);
    node = tester.getSemantics(find.bySemanticsLabel('Jewish'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
    await tester.scrollUntilVisible(find.text('Catholic'), 100);
    await tester.pump();
    node = tester.getSemantics(find.bySemanticsLabel('Catholic'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('a row tap emits exactly one change and moves the '
      'selection', (tester) async {
    final semantics = tester.ensureSemantics();
    final changes = <WwTradition>[];
    await pumpProfiles(tester, onChanged: changes.add);

    // Tap the row's description text (the whole row is the
    // target, the run-8 row rule).
    await tester.scrollUntilVisible(find.text('Protestant'), 100);
    await tester.pump();
    await tester.tap(
      find.text(
        'Adds the proof texts of the Westminster Confession (1647) '
        'and the 1689 London Baptist Confession to each verse.',
      ),
    );
    await tester.pump();
    expect(changes, [WwTradition.protestant]);
    var node = tester.getSemantics(find.bySemanticsLabel('Protestant'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
    await tester.scrollUntilVisible(find.text('Bible only'), -100);
    await tester.pump();
    node = tester.getSemantics(find.bySemanticsLabel('Bible only'));
    expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);

    // Tapping the selected row again emits nothing new (the
    // selection is already there — no redundant write).
    await tester.scrollUntilVisible(find.text('Protestant'), 100);
    await tester.pump();
    await tester.tap(find.text('Protestant'));
    await tester.pump();
    expect(changes, [WwTradition.protestant]);
    semantics.dispose();
  });

  testWidgets('the old conference switch is gone', (tester) async {
    await pumpProfiles(tester);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Show conference talks'), findsNothing);
    expect(find.text('General Conference'), findsNothing);
  });
}
