import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woven_word/screens/profiles_screen.dart';
import 'package:woven_word/theme/ww_theme.dart';

/// Board run 8, spec §2 / §7: the Profiles General Conference
/// toggle — placement (after New profile, before Backup), verbatim
/// copy C-1…C-4, the explicitly colored switch (§2.4.1), and the
/// one-node toggled semantics (§2.5), asserted in both states.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpProfiles(
    WidgetTester tester, {
    bool enabled = false,
    ValueChanged<bool>? onChanged,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: wwTheme(),
        home: ProfilesScreen(
          conferenceEnabled: enabled,
          onConferenceChanged: onChanged,
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
    expect(find.text('General Conference'), findsOneWidget);
    expect(
      find.text(
        'Conference talks are not stored in this app. When this is '
        'on, you can see which talks cite a verse, browse talks in '
        'the Library, and open each talk in Gospel Library or the '
        'Citation Index.',
      ),
      findsOneWidget,
    );
    expect(find.text('Show conference talks'), findsOneWidget);
    expect(
      find.text('Verse connections and the Library browse'),
      findsOneWidget,
    );
    // Placement (§2.1): below the New profile button.
    final newProfileY = tester.getTopLeft(find.text('New profile')).dy;
    final headerY = tester.getTopLeft(find.text('General Conference')).dy;
    expect(headerY, greaterThan(newProfileY));
    // Backup is still present and still last (§2.2 step 7).
    await tester.scrollUntilVisible(find.text('Backup'), 100);
    await tester.pump();
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });

  testWidgets('semantics: one toggled node, label exact, flag '
      'carries the state in both states', (tester) async {
    final semantics = tester.ensureSemantics();
    final flips = <bool>[];
    await pumpProfiles(tester, onChanged: flips.add);

    expect(find.bySemanticsLabel('Show conference talks'), findsOneWidget);
    var node = tester.getSemantics(
      find.bySemanticsLabel('Show conference talks'),
    );
    expect(node.flagsCollection.isToggled, ui.Tristate.isFalse);
    expect(node.flagsCollection.isButton, isTrue);

    // The whole row is the tap target: tap the subtitle text.
    await tester.tap(find.text('Verse connections and the Library browse'));
    await tester.pump();
    expect(flips, [true]);
    node = tester.getSemantics(find.bySemanticsLabel('Show conference talks'));
    expect(node.flagsCollection.isToggled, ui.Tristate.isTrue);

    // Tapping again flips back — one action, one write per tap.
    await tester.tap(find.text('Show conference talks'));
    await tester.pump();
    expect(flips, [true, false]);
    node = tester.getSemantics(find.bySemanticsLabel('Show conference talks'));
    expect(node.flagsCollection.isToggled, ui.Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('a tap directly on the Switch flips exactly once '
      '(§2.4 / D4: one action, one state write at the switch\u2019s '
      'own target)', (tester) async {
    final semantics = tester.ensureSemantics();
    final flips = <bool>[];
    await pumpProfiles(tester, onChanged: flips.add);

    expect(find.byType(Switch), findsOneWidget);
    var node = tester.getSemantics(
      find.bySemanticsLabel('Show conference talks'),
    );
    expect(node.flagsCollection.isToggled, ui.Tristate.isFalse);

    // Tap the switch itself, not the row around it: the switch
    // consumes its own tap, so the row's InkWell must not fire a
    // second toggle — exactly one onChanged emission, and the
    // toggled state inverts exactly once (false → true).
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(flips, [true]);
    node = tester.getSemantics(find.bySemanticsLabel('Show conference talks'));
    expect(node.flagsCollection.isToggled, ui.Tristate.isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    semantics.dispose();
  });

  testWidgets('the switch carries every color explicitly (§2.4.1) '
      'and a check glyph in the ON thumb only', (tester) async {
    await pumpProfiles(tester, enabled: true);
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.activeTrackColor, WwColors.goldBright);
    expect(sw.inactiveTrackColor, WwColors.surfaceHigh);
    expect(sw.activeThumbColor, WwColors.onGold);
    expect(sw.inactiveThumbColor, WwColors.mutedOnDark);
    expect(
      sw.trackOutlineColor!.resolve({WidgetState.selected}),
      Colors.transparent,
    );
    expect(sw.trackOutlineColor!.resolve(<WidgetState>{}), WwColors.borderDark);
    final onIcon = sw.thumbIcon!.resolve({WidgetState.selected});
    expect(onIcon, isNotNull);
    expect(onIcon!.icon, Icons.check);
    expect(onIcon.color, WwColors.goldBright);
    expect(sw.thumbIcon!.resolve(<WidgetState>{}), isNull);
    // No disabled state exists: the switch is always live.
    expect(sw.onChanged, isNotNull);
  });
}
