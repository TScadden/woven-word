import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woven_word/theme/ww_theme.dart';

/// Reader theme package — Petra's contrast gate as executable
/// assertions. Every ratio is computed from the palette tokens
/// (WCAG relative luminance, the audit's method), never from a
/// screenshot. Text band: 4.5:1. Meaningful-icon band: 3.0:1.
/// The computed table is recorded in
/// team/specs/reader-theme-gate.md.
void main() {
  double ratio(Color fg, Color bg) {
    final l1 = fg.computeLuminance();
    final l2 = bg.computeLuminance();
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  String r(double v) => v.toStringAsFixed(2);

  for (final palette in [ReaderPalette.paper, ReaderPalette.dark]) {
    final name = palette.isDark ? 'dark' : 'paper';
    group('reader palette contrast ($name)', () {
      test('body ink on the page and chrome', () {
        expect(
          ratio(palette.ink, palette.bg),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on bg = ${r(ratio(palette.ink, palette.bg))}',
        );
        expect(
          ratio(palette.ink, palette.chrome),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on chrome = ${r(ratio(palette.ink, palette.chrome))}',
        );
        expect(
          ratio(palette.ink, palette.cardBg),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on cardBg = ${r(ratio(palette.ink, palette.cardBg))}',
        );
      });

      test('muted captions on the page, chrome, and cards', () {
        for (final surface in [palette.bg, palette.chrome, palette.cardBg]) {
          expect(
            ratio(palette.muted, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'muted on $surface = ${r(ratio(palette.muted, surface))}',
          );
        }
      });

      test('accent (small gold text) on the page and chrome', () {
        expect(
          ratio(palette.accent, palette.bg),
          greaterThanOrEqualTo(4.5),
          reason: 'accent on bg = ${r(ratio(palette.accent, palette.bg))}',
        );
        expect(
          ratio(palette.accent, palette.chrome),
          greaterThanOrEqualTo(4.5),
          reason:
              'accent on chrome = ${r(ratio(palette.accent, palette.chrome))}',
        );
      });

      test('field text and hint on the note-editor field fill', () {
        expect(
          ratio(palette.ink, palette.fieldFill),
          greaterThanOrEqualTo(4.5),
          reason:
              'ink on fieldFill = ${r(ratio(palette.ink, palette.fieldFill))}',
        );
        expect(
          ratio(palette.muted, palette.fieldFill),
          greaterThanOrEqualTo(4.5),
          reason:
              'muted on fieldFill = ${r(ratio(palette.muted, palette.fieldFill))}',
        );
      });

      test('the gold fill carries its label; the chip label reads '
          'on chrome; the unselected toggle label reads on chrome', () {
        expect(
          ratio(palette.onGoldFill, palette.goldFill),
          greaterThanOrEqualTo(4.5),
          reason:
              'onGold on goldFill = ${r(ratio(palette.onGoldFill, palette.goldFill))}',
        );
        expect(
          ratio(palette.chipLabel, palette.chrome),
          greaterThanOrEqualTo(4.5),
          reason:
              'chipLabel on chrome = ${r(ratio(palette.chipLabel, palette.chrome))}',
        );
        expect(
          ratio(palette.toggleUnselected, palette.chrome),
          greaterThanOrEqualTo(4.5),
          reason:
              'toggleUnselected on chrome = ${r(ratio(palette.toggleUnselected, palette.chrome))}',
        );
      });

      test('every highlight tint carries body ink and the ink-role '
          'verse number; gold marks on a tint meet the icon band', () {
        for (var i = 0; i < palette.tints.length; i++) {
          final tint = palette.tints[i];
          expect(
            ratio(palette.ink, tint),
            greaterThanOrEqualTo(4.5),
            reason: 'ink on tint $i = ${r(ratio(palette.ink, tint))}',
          );
          expect(
            ratio(palette.accent, tint),
            greaterThanOrEqualTo(3.0),
            reason: 'accent on tint $i = ${r(ratio(palette.accent, tint))}',
          );
        }
      });

      test('the selected verse carries body ink, plain and tinted; '
          'its outline meets the icon band against the page, its '
          'own fill, and an adjacent tint', () {
        final plain = palette.selectedBackground(null);
        expect(
          ratio(palette.ink, plain),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on selected plain = ${r(ratio(palette.ink, plain))}',
        );
        expect(
          ratio(palette.accent, palette.bg),
          greaterThanOrEqualTo(3.0),
          reason: 'outline on bg = ${r(ratio(palette.accent, palette.bg))}',
        );
        expect(
          ratio(palette.accent, plain),
          greaterThanOrEqualTo(3.0),
          reason:
              'outline on selected plain = ${r(ratio(palette.accent, plain))}',
        );
        for (var i = 0; i < palette.tints.length; i++) {
          final tint = palette.tints[i];
          final selected = palette.selectedBackground(tint);
          expect(
            ratio(palette.ink, selected),
            greaterThanOrEqualTo(4.5),
            reason:
                'ink on selected tint $i = ${r(ratio(palette.ink, selected))}',
          );
          expect(
            ratio(palette.accent, tint),
            greaterThanOrEqualTo(3.0),
            reason:
                'outline vs adjacent tint $i = ${r(ratio(palette.accent, tint))}',
          );
        }
      });

      test('the selection-mode overlay stack carries body ink in '
          'every composition, and the handles meet the icon band', () {
        final bases = <String, Color>{
          'page': palette.bg,
          'selected plain': palette.selectedBackground(null),
          for (var i = 0; i < palette.tints.length; i++)
            'tint $i': palette.tints[i],
          for (var i = 0; i < palette.tints.length; i++)
            'selected tint $i': palette.selectedBackground(palette.tints[i]),
        };
        for (final entry in bases.entries) {
          final stack = Color.alphaBlend(palette.selectionOverlay, entry.value);
          expect(
            ratio(palette.ink, stack),
            greaterThanOrEqualTo(4.5),
            reason:
                'ink under overlay on ${entry.key} = ${r(ratio(palette.ink, stack))}',
          );
          expect(
            ratio(palette.accent, stack),
            greaterThanOrEqualTo(3.0),
            reason:
                'handles on ${entry.key} stack = ${r(ratio(palette.accent, stack))}',
          );
        }
      });

      test('the connection dot reads on the page (icon band)', () {
        expect(
          ratio(palette.dotResting, palette.bg),
          greaterThanOrEqualTo(3.0),
          reason: 'dot on bg = ${r(ratio(palette.dotResting, palette.bg))}',
        );
      });
    });
  }

  test('paper palette is the shipped token set, value for value', () {
    final p = ReaderPalette.paper;
    expect(p.bg, WwColors.paper);
    expect(p.chrome, WwColors.paper);
    expect(p.cardBg, WwColors.paper);
    expect(p.ink, WwColors.ink);
    expect(p.muted, WwColors.mutedOnPaper);
    expect(p.accent, WwColors.goldTextOnPaper);
    expect(p.goldFill, WwColors.goldBright);
    expect(p.onGoldFill, WwColors.onGold);
    expect(p.tints, [
      WwColors.hlGold,
      WwColors.hlGreen,
      WwColors.hlBlue,
      WwColors.hlPink,
      WwColors.hlPurple,
    ]);
    expect(
      p.selectedBackground(null),
      Color.alphaBlend(WwColors.hlGold.withValues(alpha: 0.45), WwColors.paper),
    );
    expect(
      p.selectedBackground(WwColors.hlBlue),
      Color.alphaBlend(
        WwColors.hlGold.withValues(alpha: 0.45),
        WwColors.hlBlue,
      ),
    );
    expect(p.selectionOverlay, WwColors.hlGold.withValues(alpha: 0.50));
  });

  test('dark palette is the computed dark token set', () {
    final d = ReaderPalette.dark;
    expect(d.bg, WwColors.surface);
    expect(d.chrome, WwColors.nav);
    expect(d.cardBg, WwColors.surfaceHigh);
    expect(d.ink, WwColors.navInk);
    expect(d.muted, WwColors.mutedOnDark);
    expect(d.accent, WwColors.goldBright);
    expect(d.fieldFill, WwColors.surface);
    expect(d.tints, [
      WwColors.hlGoldDark,
      WwColors.hlGreenDark,
      WwColors.hlBlueDark,
      WwColors.hlPinkDark,
      WwColors.hlPurpleDark,
    ]);
    // A tinted verse's fill is unchanged by selection in dark;
    // a plain verse takes the gold wash over the page.
    expect(d.selectedBackground(WwColors.hlGoldDark), WwColors.hlGoldDark);
    expect(
      d.selectedBackground(null),
      Color.alphaBlend(WwColors.gold.withValues(alpha: 0.25), WwColors.surface),
    );
    expect(d.selectionOverlay, WwColors.gold.withValues(alpha: 0.20));
  });
}
