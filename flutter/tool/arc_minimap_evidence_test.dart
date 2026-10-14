// Evidence generator for the run-8 fix round (Defect 2): renders
// the ambient whole-Bible mini-map at the exact Home parameters
// and writes it as a PNG for pixel measurement.
//
// Home parameters (home_tab.dart): stage 1200x500, whole-Bible
// range (lo 0, hi totalChapters-1), density band = bandFor(
// densityFor(displayWidth)). At a 390dp phone width that band is
// 0.30; pass a different width via EVIDENCE_WIDTH if needed.
// includeLabels is false and includeArcs is true on Home when no
// chapter is selected — the state the founder screenshot shows.
//
// Run (from flutter/):
//   flutter test tool/arc_minimap_evidence_test.dart \
//     --dart-define=EVIDENCE_LABEL=before
// Writes ../team/specs/run8-fix-evidence/ambient-minimap-<label>.png
// Pixel stats: ../team/specs/run8-fix-evidence/compute_stats.py
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/data/bible_data.dart';
import 'package:woven_word/widgets/arc_stage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render ambient mini-map evidence capture', () async {
    const label = String.fromEnvironment(
      'EVIDENCE_LABEL',
      defaultValue: 'after',
    );
    const width = int.fromEnvironment('EVIDENCE_WIDTH', defaultValue: 390);
    final data = await BibleData.load();
    final band = bandFor(densityFor(width.toDouble()));
    // The band Home computes at phone width must be the one in the
    // brief; assert it so a capture can never silently drift.
    expect(band, 0.30, reason: 'Home band at ${width}dp width');
    final img = await renderArcImage(
      data: data,
      lo: 0,
      hi: data.totalChapters - 1,
      stage: const ui.Size(1200, 500),
      density: band,
      faint: false,
      includeArcs: true,
      includeLabels: false,
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    expect(png, isNotNull);
    final dir = Directory('../team/specs/run8-fix-evidence');
    await dir.create(recursive: true);
    final file = File('${dir.path}/ambient-minimap-$label.png');
    await file.writeAsBytes(png!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path} (${png.lengthInBytes} bytes, band $band)');
  });
}
