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

  // Dark-reader highlight palette (reader theme package): the
  // deep, saturated counterparts of the paper pastels, computed to
  // carry navInk body text on the black surface family — gold
  // 5.84:1, green 6.51:1, blue 7.54:1, pink 7.74:1, purple 8.27:1
  // (gate: team/specs/reader-theme-gate.md).
  static const hlGoldDark = Color(0xFF6E560F);
  static const hlGreenDark = Color(0xFF3E5A24);
  static const hlBlueDark = Color(0xFF2F4A6E);
  static const hlPinkDark = Color(0xFF6E3548);
  static const hlPurpleDark = Color(0xFF4E3A66);

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

  /// Reference label on dark surfaces (My Notes rows, board run 5):
  /// refLabel's size and weight in goldBright, the dark-surface
  /// gold (goldTextOnPaper is a paper-only role). Contrast computed
  /// at the run-5 gate.
  static const refLabelOnDark = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: WwColors.goldBright,
  );

  /// Destructive action label on dark dialogs (board run 5):
  /// buttonLabel's size and weight in the danger tint.
  static const dangerActionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.danger,
  );

  /// Primary action label on dark dialogs (board run 5): buttonLabel
  /// in goldBright; the disabled state uses mutedOnDark.
  static const dialogActionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.goldBright,
  );
  static const dialogActionLabelDisabled = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: WwColors.mutedOnDark,
  );

  /// The "Active" caption under the active profile's name (board
  /// run 5): caption size, goldBright — paired with a check icon so
  /// the state never rides on color alone (lesson 17).
  static const activeCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: WwColors.goldBright,
  );

  /// Profile avatar letters (board run 5): on the goldBright fill
  /// (onGold) and on surfaceHigh (goldBright).
  static const avatarLetterOnGold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: WwColors.onGold,
  );
  static const avatarLetterOnDark = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: WwColors.goldBright,
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
  // Board run 7 part B roles (§11 closed list — the only roles
  // this package adds).
  /// Tab bar label, selected: 12sp w600 goldBright (10.23:1 on nav).
  static const tabLabelSelected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: WwColors.goldBright,
  );

  /// Tab bar label, unselected: 12sp w600 mutedOnDark (6.47:1 on nav).
  static const tabLabelUnselected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: WwColors.mutedOnDark,
  );

  /// Screens count badge numeral: 10sp w700 onGold (9.71:1 on
  /// goldBright).
  static const badgeCount = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: WwColors.onGold,
  );

  /// Library book tile name: Georgia serif 17sp w600 navInk
  /// (15.29:1 on surface).
  static const bookTileTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: WwColors.navInk,
  );

  static const verseNumber = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: WwColors.goldTextOnPaper,
  );

  /// Verse number in ink, for every verse block that is selected
  /// or carries a highlight tint (Petra's run-4 audit): on those
  /// non-paper surfaces goldTextOnPaper computes 3.22–4.11, under
  /// the 4.5 normal-text floor, while ink computes 11.92–17.12.
  /// The resting, unhighlighted verse number keeps [verseNumber]
  /// (goldTextOnPaper, 4.62:1 on paper).
  static const verseNumberInk = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: WwColors.ink,
  );

  /// Verse of the Day text: the reader's serif metrics
  /// (readerBody: serif 18, height 1.55) in the dark-surface
  /// ink. Contrast in run-11 spec §9.
  static const verseOfDayBody = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 18,
    height: 1.55,
    color: WwColors.navInk,
  );

  /// Plan cover book line: serif 13 navInk on surfaceHigh.
  static const planCoverBook = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 13,
    color: WwColors.navInk,
  );

  /// Plan cover meta line: 12sp w600 goldBright on surfaceHigh.
  static const planCoverMeta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: WwColors.goldBright,
  );
}

/// Spacing: 8dp grid, 16dp screen margin (audit §5).
class WwSpace {
  static const screenMargin = 16.0;

  /// Minimum top-bar height; bars grow with their content under
  /// larger text scales.
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

/// Shows a dialog honoring reduced motion (audit §8, Petra run-5
/// condition): with animations disabled the dialog renders its
/// final state instantly instead of running the stock fade/scale
/// entrance, which never consults MediaQuery.disableAnimations.
Future<T?> wwShowDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (MediaQuery.of(context).disableAnimations) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => builder(context),
    );
  }
  return showDialog<T>(context: context, builder: builder);
}

/// Animation style for modal bottom sheets honoring reduced
/// motion (audit §8): zero-duration under reduced motion, the
/// stock style otherwise.
AnimationStyle? wwSheetAnimationStyle(BuildContext context) =>
    MediaQuery.of(context).disableAnimations
    ? const AnimationStyle(
        duration: Duration.zero,
        reverseDuration: Duration.zero,
      )
    : null;

/// One reader palette (reader theme package, founder ruling
/// Oct 15, 2026): every color and text-style role a reader surface
/// uses, resolved for one theme. Reader surfaces — both readers,
/// the verse toolbar, the selection bar and mode, the connections
/// sheet, the note editors — read roles from the palette and never
/// from a raw paper token, so a surface cannot stay paper-styled
/// inside a dark reader or vice versa.
///
/// The paper palette is the shipped design, value for value: its
/// roles are the shipped tokens and its selected-verse wash is the
/// shipped construction, so the paper reader renders identically.
/// The dark palette is a real token set on the app's black surface
/// family, computed from tokens before building (gate:
/// team/specs/reader-theme-gate.md): body ink is navInk, small
/// gold text is goldBright, and each highlight tint has a deep
/// counterpart above that carries navInk text (5.84–8.27:1), so
/// body text uses the ink role on the page AND on every tint in
/// both themes — no per-segment color switch exists.
class ReaderPalette {
  const ReaderPalette({
    required this.isDark,
    required this.bg,
    required this.chrome,
    required this.cardBg,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.line,
    required this.cardBorder,
    required this.accent,
    required this.goldFill,
    required this.onGoldFill,
    required this.fieldFill,
    required this.disabledText,
    required this.selectionOverlay,
    required this.dotResting,
    required this.toggleUnselected,
    required this.chipLabel,
    required this.wash,
    required this.washAlpha,
    required this.washOverTint,
    required this.tints,
  });

  final bool isDark;

  /// Page background; also the connections sheet's background.
  final Color bg;

  /// Top chrome: the reader top bar, the deutero action bar.
  final Color chrome;

  /// Floating cards on the page: verse toolbar, selection bar,
  /// note editors (all three), popup menus.
  final Color cardBg;

  /// Body text on bg/chrome/cardBg — and on every tint.
  final Color ink;

  /// Secondary text (captions, hints, quiet labels).
  final Color muted;

  /// Hairlines: chrome edges, sheet dividers.
  final Color hairline;

  /// Idle borders: cards, fields, toggles, swatches.
  final Color line;

  /// The verse toolbar card's border (stronger than [line] on
  /// paper, where the shipped card carries a muted border).
  final Color cardBorder;

  /// Small gold text and meaningful gold icons: reference labels,
  /// the resting verse number, selection handles and cursor, the
  /// selected verse's 2dp outline, note icons.
  final Color accent;

  /// Gold fills: the selected translation toggle, primary buttons.
  final Color goldFill;

  /// Label color on [goldFill].
  final Color onGoldFill;

  /// Note-editor field fill (one step off the editor's card).
  final Color fieldFill;

  /// Disabled action labels.
  final Color disabledText;

  /// Selection-mode overlay (run 10 §3.4's role, per theme).
  final Color selectionOverlay;

  /// The connection dot on a resting, untinted verse.
  final Color dotResting;

  /// The unselected translation toggle label's color.
  final Color toggleUnselected;

  /// The translation chip's label color (on [chrome]).
  final Color chipLabel;

  /// The selected verse's wash color and strength, and whether
  /// the wash applies over a tinted verse. Paper washes over tints
  /// (the shipped construction); dark does not — a tinted verse's
  /// fill is unchanged by selection and the outline carries it,
  /// the same end state paper reaches on a same-color tint.
  final Color wash;
  final double washAlpha;
  final bool washOverTint;

  /// Highlight tints, aligned with the highlight color order
  /// (gold, green, blue, pink, purple).
  final List<Color> tints;

  Color tintAt(int index) => tints[index];

  /// The selected verse's background: the wash over the verse's
  /// tint (or the page), per [washOverTint].
  Color selectedBackground(Color? tint) {
    if (tint != null && !washOverTint) return tint;
    return Color.alphaBlend(wash.withValues(alpha: washAlpha), tint ?? bg);
  }

  // Text roles (WwType bases, palette colors).
  TextStyle get titleStyle => WwType.readerTitle.copyWith(color: ink);
  TextStyle get bodyStyle => WwType.readerBody.copyWith(color: ink);
  TextStyle get sheetVerseStyle => WwType.readerSheetVerse.copyWith(color: ink);
  TextStyle get sheetTitleStyle => WwType.sheetRefTitle.copyWith(color: ink);
  TextStyle get refLabelStyle => WwType.refLabel.copyWith(color: accent);
  TextStyle get snippetStyle => WwType.snippet.copyWith(color: ink);
  TextStyle get captionStyle => WwType.captionOnPaper.copyWith(color: muted);
  TextStyle get smallBodyStyle => WwType.bodyOnPaper.copyWith(color: ink);
  TextStyle get buttonLabelStyle =>
      WwType.paperButtonLabel.copyWith(color: ink);
  TextStyle get buttonLabelAccentStyle =>
      WwType.paperButtonLabelGold.copyWith(color: accent);
  TextStyle get buttonLabelDisabledStyle =>
      WwType.paperButtonLabelDisabled.copyWith(color: disabledText);
  TextStyle get toggleUnselectedStyle =>
      WwType.translationUnselected.copyWith(color: toggleUnselected);
  TextStyle get chipLabelStyle =>
      WwType.goldButtonLabel.copyWith(color: chipLabel);
  TextStyle get verseNumberStyle => WwType.verseNumber.copyWith(color: accent);
  TextStyle get verseNumberOnTintStyle =>
      WwType.verseNumberInk.copyWith(color: ink);
  TextStyle get cancelStyle => isDark ? WwType.buttonLabel : buttonLabelStyle;

  static final ReaderPalette paper = ReaderPalette(
    isDark: false,
    bg: WwColors.paper,
    chrome: WwColors.paper,
    cardBg: WwColors.paper,
    ink: WwColors.ink,
    muted: WwColors.mutedOnPaper,
    hairline: WwColors.line,
    line: WwColors.line,
    cardBorder: WwColors.mutedOnPaper,
    accent: WwColors.goldTextOnPaper,
    goldFill: WwColors.goldBright,
    onGoldFill: WwColors.onGold,
    fieldFill: WwColors.paper,
    disabledText: WwColors.mutedOnPaper,
    selectionOverlay: WwColors.hlGold.withValues(alpha: 0.50),
    dotResting: WwColors.gold,
    toggleUnselected: WwColors.goldTextOnPaper,
    chipLabel: WwColors.onGold,
    wash: WwColors.hlGold,
    washAlpha: 0.45,
    washOverTint: true,
    tints: [
      WwColors.hlGold,
      WwColors.hlGreen,
      WwColors.hlBlue,
      WwColors.hlPink,
      WwColors.hlPurple,
    ],
  );

  static final ReaderPalette dark = ReaderPalette(
    isDark: true,
    bg: WwColors.surface,
    chrome: WwColors.nav,
    cardBg: WwColors.surfaceHigh,
    ink: WwColors.navInk,
    muted: WwColors.mutedOnDark,
    hairline: WwColors.borderDarkSoft,
    line: WwColors.borderDark,
    cardBorder: WwColors.borderDark,
    accent: WwColors.goldBright,
    goldFill: WwColors.goldBright,
    onGoldFill: WwColors.onGold,
    fieldFill: WwColors.surface,
    disabledText: WwColors.mutedOnDark,
    selectionOverlay: WwColors.gold.withValues(alpha: 0.20),
    dotResting: WwColors.goldBright,
    toggleUnselected: WwColors.mutedOnDark,
    chipLabel: WwColors.goldBright,
    wash: WwColors.gold,
    washAlpha: 0.25,
    washOverTint: false,
    tints: [
      WwColors.hlGoldDark,
      WwColors.hlGreenDark,
      WwColors.hlBlueDark,
      WwColors.hlPinkDark,
      WwColors.hlPurpleDark,
    ],
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
