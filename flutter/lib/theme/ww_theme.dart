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
  static const mutedOnDark = Color(0xFF9A947F); // ~5.6:1 on nav — captions
  static const hintOnDark = Color(0xFF8F8A76); // ~4.7:1 on black — hints

  // Gold.
  static const gold = Color(0xFFB8860B); // accent on paper, fills
  static const goldBright = Color(0xFFE8B33C); // titles/selection on dark
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
      hintStyle: const TextStyle(fontSize: 13, color: WwColors.mutedOnDark),
    ),
  );
}
