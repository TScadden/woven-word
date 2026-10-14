import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/theme/ww_theme.dart';

import 'fake_canon.dart';
import 'shell_pump.dart';

/// Run-8 fix round, Defect 1 — tab-bar GEOMETRY, asserted from
/// rendered positions (tester.getCenter on finders), never from
/// widget properties.
///
/// The defect: each tab slot's icon+label stack hugged the slot's
/// left edge while the gold indicator centered on the slot, so on
/// the founder's screenshot the content and the indicator visibly
/// disagreed. The three tabs are equal columns of the phone width;
/// every icon center must sit on its column center, the icons must
/// be equally spaced, and the indicator center must equal the
/// active column's center.
///
/// Geometry tolerance: 1.0dp. Rendered centers are exact rational
/// fractions of the view width at these sizes (390/3 = 130), so a
/// 1.0dp tolerance is loose enough for font/icon raster rounding
/// and far too tight for the defect (the pre-fix content sat a
/// full label-width off its column center).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tolerance = 1.0;

  Future<void> checkGeometry(
    WidgetTester tester, {
    required Size size,
    double? textScale,
  }) async {
    final data = fakeReaderData();
    await pumpShell(
      tester,
      data: data,
      texts: fakeReaderTexts(data),
      size: size,
      textScale: textScale,
    );

    final icons = <IconData>[
      Icons.home, // Home is the active tab: filled variant.
      Icons.menu_book_outlined,
      Icons.layers_outlined,
    ];
    final centers = [
      for (final icon in icons) tester.getCenter(find.byIcon(icon)),
    ];

    final slotWidth = size.width / 3;
    // (a) Equally spaced.
    final spacing1 = centers[1].dx - centers[0].dx;
    final spacing2 = centers[2].dx - centers[1].dx;
    expect(spacing1, closeTo(slotWidth, tolerance));
    expect(spacing2, closeTo(slotWidth, tolerance));
    expect(spacing1, closeTo(spacing2, tolerance));
    // (b) Each icon center == its column center.
    for (var i = 0; i < 3; i++) {
      expect(
        centers[i].dx,
        closeTo(slotWidth * (i + 0.5), tolerance),
        reason: 'tab $i icon center vs column center',
      );
    }

    // (c) The indicator's center == the active (Home) column's
    // center. The indicator is the one 32x2 goldBright-filled
    // Container in the tree (the badge, when present, is a
    // goldBright BoxDecoration, not a flat color Container, and
    // the default screen count is 1 so no badge renders anyway).
    final indicator = find.byWidgetPredicate(
      (w) => w is Container && w.color == WwColors.goldBright,
    );
    expect(indicator, findsOneWidget);
    final indicatorCenter = tester.getCenter(indicator);
    expect(indicatorCenter.dx, closeTo(centers[0].dx, tolerance));
    expect(indicatorCenter.dx, closeTo(slotWidth * 0.5, tolerance));
  }

  testWidgets('tab bar geometry at phone size 390x844', (tester) async {
    addTearDown(tester.view.reset);
    await checkGeometry(tester, size: const Size(390, 844));
  });

  testWidgets('tab bar geometry at 390x844, text scale 1.3', (tester) async {
    addTearDown(tester.view.reset);
    await checkGeometry(tester, size: const Size(390, 844), textScale: 1.3);
  });
}
