import 'package:flutter/material.dart';

/// Woven Word design tokens.
///
/// The system comes from the Tabs design-audit skill
/// (~/workspace/skills/tabs-design-audit/SKILL.md): founder overrides win,
/// an explicit type scale, an 8dp grid with 16dp screen margins, 48dp
/// touch targets, contrast computed from tokens against WCAG thresholds,
/// a closed radius scale, and a fixed motion set with reduced-motion
/// support. The values are Woven Word's house identity: black arc stage,
/// cream reader paper, gold accents (measured from the web v1 CSS).
class WwColors {
  // Dark surfaces (elevation by step only, no shadows).
  static const stage = Color(0xFF000000); // L0 — arc stage
  static const nav = Color(0xFF0B0B10); // top bar
  static const surface = Color(0xFF14141C); // L1 — sheets, strips
  static const surfaceHigh = Color(0xFF1B1B24); // L2 — controls on dark
  static const borderDark = Color(0xFF33333F);
  static const borderDarkSoft = Color(0xFF2C2C36);

  // Light surfaces (reader).
  static const paper = Color(0xFFFFFDF8); // reader paper
  static const ink = Color(0xFF1A1A1A); // text on paper
  static const line = Color(0xFFE4DDCB); // hairlines on paper
  static const mutedOnPaper = Color(0xFF7A7466); // 4.6:1 on paper

  // Text on dark.
  static const navInk = Color(0xFFF2EAD8); // primary text on dark
  static const mutedOnDark = Color(0xFF9A947F); // 6.47:1 on nav · 5.63:1 on surfaceHigh — captions
  static const hintOnDark = Color(0xFF8F8A76); // 6.06:1 on stage — hints

  // Gold.
  // gold: fills, borders, large text, meaningful icons on paper ONLY —
  // 3.20:1 on paper fails normal text (Petra token audit, board run 2).
  static const gold = Color(0xFFB8860B);
  // goldTextOnPaper: the only gold for small text on paper — 4.62:1.
  static const goldTextOnPaper = Color(0xFF956D09);
  // goldBright: dark surfaces only (1.89:1 on paper) — titles/selection.
  static const goldBright = Color(0xFFE8B33C);
  static const onGold = Color(0xFF161300); // text on a gold fill

  // Arc web (measured from the web canvas).
  static const barA = Color(0xFFC9C2AB);
  static const barB = Color(0xFF8F8A7A);
  static const bookLabel = Color(0xFF7D7763); // 4.68:1 on black

  // Highlight palette (reader, screen d).
  static const hlGold = Color(0xFFF7E08A);
  static const hlGreen = Color(0xFFCFE6B8);
  static const hlBlue = Color(0xFFC3D9F2);
  static const hlPink = Color(0xFFF6CFDD);
  static const hlPurple = Color(0xFFDDD0F2);

  static const danger = Color(0xFFFFB9C0);
  static const dangerFill = Color(0xFF4A1F24);
}

/// Explicit type roles. Every TextStyle in the app comes from here;
/// a size outside this scale is drift (audit §3). Serif is the platform
/// serif chain, matching the web stack (Iowan / Palatino / Georgia).
class WwType {
  static const serif = 'Georgia';
  static const serifFallback = ['Palatino', 'Iowan Old Style', 'serif'];

  static const appTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: WwColors.goldBright,
  );
  /// Intro wordmark: the app name on the first-run intro screen.
  static const wordmark = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 56,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: WwColors.navInk,
  );
  static const appSubtitle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: WwColors.mutedOnDark,
  );
  static const screenTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: WwColors.goldBright,
  );
  static const selectionTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: WwColors.goldBright,
  );
  static const bodyOnDark = TextStyle(fontSize: 13, color: WwColors.navInk);
  static const captionOnDark = TextStyle(
    fontSize: 12,
    color: WwColors.mutedOnDark,
  );
  static const hint = TextStyle(fontSize: 12, color: WwColors.hintOnDark);
  static const controlLabel = TextStyle(
    fontSize: 13,
    color: WwColors.navInk,
  );
  static const buttonLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.navInk,
  );
  static const goldButtonLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: WwColors.onGold,
  );

  // Reader roles (paper surfaces). Palette law (board run 2 audit):
  // small gold text on paper is goldTextOnPaper only; gold is fills,
  // borders, and large text; goldBright is dark surfaces only — the
  // one reader exception is the goldBright FILL under an onGold
  // label (9.71:1, computed), never goldBright text on paper.
  static const readerTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: WwColors.ink,
  );
  static const readerBody = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 18,
    height: 1.55,
    color: WwColors.ink,
  );

  /// The verse's own text at the top of the connections sheet:
  /// readerBody at 15sp.
  static const readerSheetVerse = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 15,
    height: 1.55,
    color: WwColors.ink,
  );

  /// Connections sheet header: the verse reference.
  static const sheetRefTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: WwColors.ink,
  );
  static const refLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: WwColors.goldTextOnPaper,
  );
  static const snippet = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: WwColors.ink,
  );
  static const captionOnPaper = TextStyle(
    fontSize: 12,
    color: WwColors.mutedOnPaper,
  );
  static const bodyOnPaper = TextStyle(fontSize: 13, color: WwColors.ink);
  static const paperButtonLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.ink,
  );

  /// Paper button label in gold text: paperButtonLabel with
  /// goldTextOnPaper (4.62:1 on paper) — the "Try again" action on
  /// the reader error state (Petra Low-1, board run 3).
  static const paperButtonLabelGold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.goldTextOnPaper,
  );

  /// Paper button label when disabled: paperButtonLabel with
  /// mutedOnPaper (4.6:1 on paper) — the unavailable prev/next
  /// chapter button (Petra Low-1, board run 3).
  static const paperButtonLabelDisabled = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.mutedOnPaper,
  );
  static const translationUnselected = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.goldTextOnPaper,
  );
  static const verseNumber = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: WwColors.goldTextOnPaper,
  );

  /// Verse number on the selected-verse highlight (hlGold at 45%
  /// over paper = #FBF0C6): goldTextOnPaper fails there at 4.11:1,
  /// under the 4.5 normal-text floor; ink passes at 15.23:1 (Petra
  /// contrast finding, board run 3). Any goldTextOnPaper element
  /// that can sit on the selected background uses this role instead.
  static const verseNumberSelected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: WwColors.ink,
  );
}

/// Spacing: 8dp grid, 16dp screen margin (audit §5).
class WwSpace {
  static const screenMargin = 16.0;
  static const topBarHeight = 56.0;
  static const minTarget = 48.0;
}

/// Closed radius scale (audit §6): 8 input · 10 row · 12 chip ·
/// 16 sheet · pill.
class WwRadius {
  static const input = 8.0;
  static const row = 10.0;
  static const chip = 12.0;
  static const sheet = 16.0;
}

/// Motion (audit §8): the allowed set for this app. Push is a 300ms
/// slide from the right with no fade; reduced motion renders the final
/// state instantly.
class WwMotion {
  static const push = Duration(milliseconds: 300);
  static const expand = Duration(milliseconds: 220);
  static const curve = Curves.easeOut;
  static const curveInOut = Curves.easeInOut;

  static bool reduced(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;
}

/// Standard page route: slide in from the right, 300ms, no fade
/// (audit §8). Reduced motion swaps instantly.
class WwPageRoute<T> extends PageRouteBuilder<T> {
  WwPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        opaque: true,
        transitionDuration: WwMotion.push,
        reverseTransitionDuration: WwMotion.push,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.of(context).disableAnimations) return child;
          final offset =
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                ),
              );
          return SlideTransition(position: offset, child: child);
        },
      );
}

ThemeData wwTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: WwColors.stage,
    fontFamily: null,
    colorScheme: const ColorScheme.dark(
      primary: WwColors.goldBright,
      onPrimary: WwColors.onGold,
      surface: WwColors.surface,
      onSurface: WwColors.navInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: WwColors.nav,
      foregroundColor: WwColors.navInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WwColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WwRadius.input),
        borderSide: const BorderSide(color: WwColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WwRadius.input),
        borderSide: const BorderSide(color: WwColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WwRadius.input),
        borderSide: const BorderSide(color: WwColors.goldBright),
      ),
      // Input hints intentionally match the input text size (13sp) in
      // mutedOnDark; WwType.hint (12sp hintOnDark) is for standalone
      // hint text, not field placeholders (Petra Low-1, board run 2).
      hintStyle: const TextStyle(fontSize: 13, color: WwColors.mutedOnDark),
    ),
  );
}
